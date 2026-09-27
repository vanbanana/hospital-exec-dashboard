// edss-migrate:迁移执行器(EO-B 任务书 /tmp/p3-orch/task-eo-b.md)
// migrations/*.sql 非幂等(CREATE TABLE 多数无 IF NOT EXISTS),靠
// public.schema_migrations 追踪已应用文件;既有 dev 库已全量建表但无追踪
// → -baseline 收养(只登记不执行)。seed/*.sql 幂等,可随 -seed 重跑。
package main

import (
	"context"
	"flag"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"time"

	"github.com/jackc/pgx/v5"
)

func main() {
	var (
		baseline = flag.Bool("baseline", false, "收养:把全部迁移文件名标记已应用(不执行 SQL),供既有库")
		status   = flag.Bool("status", false, "打印 文件名×applied/pending 对照表后退出")
		withSeed = flag.Bool("seed", false, "迁移阶段完成后继续按名序跑种子目录全部文件(幂等)")
		dsn      = flag.String("dsn", "", "postgres DSN;空则取 $DATABASE_URL,再回退内置演示库")
		dir      = flag.String("dir", "", "迁移目录;空则取 $MIGRATIONS_DIR,再回退 migrations")
		seedDir  = flag.String("seeddir", "", "种子目录;空则取 $SEED_DIR,再回退 seed")
	)
	flag.Parse()

	if err := run(context.Background(), *dsn, *dir, *seedDir, *baseline, *status, *withSeed); err != nil {
		fmt.Fprintf(os.Stderr, "edss-migrate: %v\n", err)
		os.Exit(1)
	}
}

func run(ctx context.Context, dsnFlag, dirFlag, seedDirFlag string, baseline, status, withSeed bool) error {
	dsn := dsnFlag
	if dsn == "" {
		dsn = envOr("DATABASE_URL", "postgres://localhost/hospital_edss?sslmode=disable")
	}
	dir := dirFlag
	if dir == "" {
		dir = envOr("MIGRATIONS_DIR", "migrations")
	}
	seedDir := seedDirFlag
	if seedDir == "" {
		seedDir = envOr("SEED_DIR", "seed")
	}

	files, err := listSQL(dir)
	if err != nil {
		return err
	}

	cfg, err := pgx.ParseConfig(dsn)
	if err != nil {
		return fmt.Errorf("dsn 解析失败: %w", err)
	}
	// 迁移/种子是整文件多语句脚本,pgx 默认扩展协议一次只能一条——必须 simple protocol
	cfg.DefaultQueryExecMode = pgx.QueryExecModeSimpleProtocol
	conn, err := pgx.ConnectConfig(ctx, cfg)
	if err != nil {
		return fmt.Errorf("连接失败: %w", err)
	}
	defer conn.Close(ctx)

	// 会话级咨询锁防双跑(任务书定死锁键);进程退出连接断开即自动释放
	if _, err := conn.Exec(ctx, "SELECT pg_advisory_lock(861022)"); err != nil {
		return fmt.Errorf("pg_advisory_lock: %w", err)
	}
	defer conn.Exec(ctx, "SELECT pg_advisory_unlock(861022)")

	// 追踪表放 public——不占 sys/dim/dwd/dws/ads/sim 六 schema 清单
	if _, err := conn.Exec(ctx, `CREATE TABLE IF NOT EXISTS public.schema_migrations(
		version text PRIMARY KEY,
		applied_at timestamptz NOT NULL DEFAULT now())`); err != nil {
		return fmt.Errorf("建追踪表: %w", err)
	}
	applied, err := loadApplied(ctx, conn)
	if err != nil {
		return err
	}

	switch {
	case status:
		for _, f := range files {
			state := "pending"
			if applied[f] {
				state = "applied"
			}
			fmt.Printf("%-40s %s\n", f, state)
		}
	case baseline:
		// 反向校验:已在追踪的库再收养多半是用错旗标
		if len(applied) > 0 {
			return fmt.Errorf("schema_migrations 非空(%d 条):库已在追踪,无需 -baseline", len(applied))
		}
		tx, err := conn.Begin(ctx)
		if err != nil {
			return err
		}
		defer tx.Rollback(ctx)
		for _, f := range files {
			if _, err := tx.Exec(ctx, `INSERT INTO public.schema_migrations(version) VALUES($1)`, f); err != nil {
				return fmt.Errorf("baseline 登记 %s: %w", f, err)
			}
		}
		if err := tx.Commit(ctx); err != nil {
			return err
		}
		fmt.Printf("baseline: marked %d files applied (no SQL executed)\n", len(files))
	default:
		// 收养守卫:追踪表空但 sys.dict 已存在 = 既有库未登记,重放会撞已建表
		if len(applied) == 0 {
			var built bool
			if err := conn.QueryRow(ctx, `SELECT to_regclass('sys.dict') IS NOT NULL`).Scan(&built); err != nil {
				return fmt.Errorf("收养守卫查询: %w", err)
			}
			if built {
				return fmt.Errorf("既有库已建表但未登记,请先 -baseline")
			}
		}
		var n, m int
		for _, f := range files {
			if applied[f] {
				m++
				continue
			}
			if err := applyFile(ctx, conn, filepath.Join(dir, f), f); err != nil {
				return err
			}
			n++
		}
		fmt.Printf("applied %d, skipped %d\n", n, m)
	}

	if withSeed && !status {
		seedFiles, err := listSQL(seedDir)
		if err != nil {
			return err
		}
		for _, f := range seedFiles {
			// 种子幂等,逐文件单事务——中途失败重跑即可,无版本登记
			if err := execTx(ctx, conn, filepath.Join(seedDir, f), ""); err != nil {
				return fmt.Errorf("seed %s: %w", f, err)
			}
			fmt.Printf("seed: %s ok\n", f)
		}
	}
	return nil
}

// applyFile 单事务执行整文件 + 登记版本;失败回滚即未应用,重跑=首跑
func applyFile(ctx context.Context, conn *pgx.Conn, path, version string) error {
	start := time.Now()
	if err := execTx(ctx, conn, path, version); err != nil {
		return fmt.Errorf("%s: %w", version, err)
	}
	fmt.Printf("apply: %s ok (%dms)\n", version, time.Since(start).Milliseconds())
	return nil
}

// execTx 在单事务内执行整份 SQL;version 非空时同事务登记 schema_migrations
func execTx(ctx context.Context, conn *pgx.Conn, path, version string) error {
	content, err := os.ReadFile(path)
	if err != nil {
		return err
	}
	tx, err := conn.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx) // Commit 后返回 ErrTxClosed,安全忽略
	if _, err := tx.Exec(ctx, stripPsqlMeta(string(content))); err != nil {
		return err
	}
	if version != "" {
		if _, err := tx.Exec(ctx, `INSERT INTO public.schema_migrations(version) VALUES($1)`, version); err != nil {
			return err
		}
	}
	return tx.Commit(ctx)
}

// stripPsqlMeta 剥离 psql 客户端元命令行(\set/\copy 等)——服务端不认。
// 种子内唯一用到的是 \set ON_ERROR_STOP,其语义已由"逐文件单事务"等价覆盖。
func stripPsqlMeta(sql string) string {
	var b strings.Builder
	for line := range strings.Lines(sql) {
		if !strings.HasPrefix(strings.TrimSpace(line), `\`) {
			b.WriteString(line)
		}
	}
	return b.String()
}

func loadApplied(ctx context.Context, conn *pgx.Conn) (map[string]bool, error) {
	rows, err := conn.Query(ctx, `SELECT version FROM public.schema_migrations`)
	if err != nil {
		return nil, fmt.Errorf("读追踪表: %w", err)
	}
	defer rows.Close()
	set := map[string]bool{}
	for rows.Next() {
		var v string
		if err := rows.Scan(&v); err != nil {
			return nil, err
		}
		set[v] = true
	}
	return set, rows.Err()
}

func listSQL(dir string) ([]string, error) {
	ents, err := os.ReadDir(dir)
	if err != nil {
		return nil, fmt.Errorf("读目录 %s: %w", dir, err)
	}
	var files []string
	for _, e := range ents {
		if !e.IsDir() && strings.HasSuffix(e.Name(), ".sql") {
			files = append(files, e.Name())
		}
	}
	sort.Strings(files)
	return files, nil
}

func envOr(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}
