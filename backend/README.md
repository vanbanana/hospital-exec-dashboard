# backend/ — EDSS Go 服务 + 数据库迁移与种子（PostgreSQL）

> **状态**：可实施生产库设计（演示期用同一套种子灌出契约锚点数据）。
> **来源**：由 `/tmp/modeling/schema/` 10 个建模 lane 经 3 轮独立审核（0 BLOCKER/0 MAJOR）后装配。
> **目标**：PostgreSQL 15+（开发验证用 15.15 实测通过；compose 用 postgres:16-alpine）。

## 目录

```
cmd/server/      # edss —— API 服务入口(config → pg pool → router → listen,优雅停机)
cmd/migrate/     # edss-migrate —— 迁移执行器(apply/baseline/status/seed)
internal/
  config/        # env fail-fast 加载(见下 env 全表)
  envelope/      # 统一包络唯一出口(error-codes §1)
  middleware/    # trace_id · slog 请求日志+进程内计数器 · panic→10000 · session
  clock/         # sim.clock 唯一业务时间源(禁 time.Now 业务化)
  router/        # 引擎 + register_<epic>.go 分域注册
  handler/ repo/ # 分域实现:e1 context/home · e2 ops · e3 staff · e4 screen/topics · P3 auth/write/sim/system
migrations/      # 结构迁移,按文件名序号顺序执行(0000 → 0900),非幂等 → 追踪表收口
seed/            # 确定性种子,按文件名序号顺序执行(1001 → 5001),幂等可重跑
```

薄查询层：handler → repo → dws/ads/dwd 已预聚合表 → 契约 JSON。无聚合重算管线。

## 跑法

```bash
export GOPROXY=https://goproxy.cn,direct   # proxy.golang.org 本机不可达
go run ./cmd/server                      # :8080
go vet ./... && go test ./... && go build ./...
```

env（`internal/config` 启动期 fail-fast，全有默认值，演示环境零配置可跑）：

| env | 默认 | 语义 |
| :--- | :--- | :--- |
| `DATABASE_URL` | `postgres://localhost/hospital_edss?sslmode=disable` | PG DSN |
| `PORT` | `8080` | API 监听端口 |
| `DB_MAX_OPEN` | `25` | 连接池上限 |
| `DB_MAX_IDLE` | `5` | 空闲连接数 |
| `DB_MAX_LIFETIME_MIN` | `30` | 连接最大存活（分钟） |
| `LOG_LEVEL` | `info` | slog 级别：`debug\|info\|warn\|error` |
| `SIM_ENABLED` | `1` | `0`=/sim/* 路由不注册（命中 NoRoute → 10003） |
| `AUTH_COOKIE_SECURE` | （空） | `1`=`edss_sid` Cookie 追加 `Secure`（HTTPS 部署置位） |
| `TRUSTED_PROXY_CIDRS` | `127.0.0.1,::1` | XFF 可信代理 CIDR（逗号分隔）；反代异机/异容器部署须放开代理网段，否则 `audit_log`/`user_session` 的 ip 记成代理地址；置空字符串 = 不信任何代理 |

- 契约端点：`/api/v1/` + 契约路径（`auth/profile`、`workbench/**`、`screen/snapshot`）
- 前端切换：`vite.config` 已代理 `/api`→`:8080`；`VITE_USE_MOCK=0 npm run dev` 即真链路

## 迁移执行器（edss-migrate）

`cmd/migrate` 单文件、stdlib flag、pgx simple protocol（多语句文件必需）；连接后 `pg_advisory_lock` 防双跑。

```bash
go run ./cmd/migrate            # apply:按文件名序跑未应用迁移
go run ./cmd/migrate -status    # 文件名×applied/pending 对照表后退出
go run ./cmd/migrate -baseline  # 收养:全部迁移标记已应用(不执行 SQL)——供既有库
go run ./cmd/migrate -seed      # apply 完成后按名序跑 seed/ 全部文件(幂等)
```

| 旗标 | 默认 | 语义 |
| :--- | :--- | :--- |
| `-dsn` | `$DATABASE_URL` → `postgres://localhost/hospital_edss?sslmode=disable` | PG DSN |
| `-dir` | `$MIGRATIONS_DIR` → `migrations` | 迁移目录 |
| `-seeddir` | `$SEED_DIR` → `seed` | 种子目录 |

- **追踪表** `public.schema_migrations(version PK, applied_at)`：version 存文件名（如 `0300_dws_agg.sql`），不占六 schema 清单。
- **每文件单事务**：失败回滚即未应用，重跑=首跑——与非幂等迁移文件兼容。
- **收养守卫**：`schema_migrations` 空 ∧ `sys.dict` 已存在 → 拒跑并提示先 `-baseline`（防把既有库当新库重放）；`-baseline` 时追踪表非空则提示无需收养。
- 全新库流程：`createdb hospital_edss && go run ./cmd/migrate -seed`（一条命令建结构+灌种子）；既有 dev 库先 `-baseline` 收养一次。
- **全新库自检**（改动种子/迁移后必跑——迁移先于种子执行，跨文件依赖只能在此序下验证）：
  ```bash
  createdb hospital_edss_fresh && DATABASE_URL=postgres://localhost/hospital_edss_fresh ./edss-migrate -seed
  # 冒烟:三演示账号 Edss@2026 + admin Admin@123 登录应全 code=0;验毕 dropdb hospital_edss_fresh
  ```

## infra 端点（根挂，不入 /api/v1 契约面——同 /health 先例）

| 端点 | 探什么 | 出什么 |
| :--- | :--- | :--- |
| `GET /health` | 无依赖 | `{"status":"up"}`，恒 200——LB 存活探针，nginx 透出 |
| `GET /ready` | DB Ping（500ms 超时）+ `sim.clock`、`dws.hospital_oper_day` 行数 ≥1 | 全过 200（返回两表行数）；任一失败 503——compose healthcheck 用，nginx **不透出** |
| `GET /stats` | — | `uptime_s`/`requests_total`/`in_flight`/`by_status`/DB 池 `sql.DBStats`——内部运维面，nginx **不透出** |

## 日志与优雅停机

slog JSON → stdout，每请求一行（RequestLog 中间件）：

| 字段 | 语义 |
| :--- | :--- |
| `method` / `route` / `status` / `latency_ms` | 方法与路由模板（`c.FullPath()`，空则 URL path）、HTTP 状态、毫秒耗时 |
| `trace_id` | 贯穿包络的请求号 |
| `errors` | 仅 `c.Errors` 非空时附（内部 err 已上链） |

- `status≥500` → `Error`，其余 `Info`；panic 经 Recovery 打 `value`+`stack`+`trace_id` 后回 10000。
- 级别由 `LOG_LEVEL` 控制，未知值回 `info`。
- `SIGINT`/`SIGTERM` → `http.Server.Shutdown`（10s drain）→ 连接池 `Close`；日志序列 `shutdown: draining` → `shutdown: complete`。

## 端口归一（照 `docs/architecture.md` §6）

dev 形态（本机）：

| 端口 | 用途 | 必开 | 备注 |
| :--- | :--- | :--- | :--- |
| 5173 | vite dev 唯一 canonical（proxy /api→:8080） | ✅ | 5174/5175 = 占用时 vite 自动递增漂移，非受配端口 |
| 8080 | Go API | 真链路时 | `PORT` env |
| 5432 | 本地 PG | 真链路时 | brew postgresql@15/16 |
| — | vite proxy `/api`→`localhost:8080` | — | target 硬编码于 `vite.config.ts` |

prod 形态（compose 三服务，本仓库 `deploy/`）：

| 端口 | 用途 | 暴露面 |
| :--- | :--- | :--- |
| 80 | nginx：`/` 静态 SPA + `/api` 反代 + `/health` 透出（TLS 终结在更外层 LB） | 公网唯一入口，`WEB_PORT` 改绑 |
| 8080 | backend | 内网；`127.0.0.1:${BACKEND_PORT}` 调试透出 |
| 5432 | postgres | 仅内网，不 publish |

## compose 部署（`deploy/`，build context=仓库根）

```bash
make up        # = docker compose -f deploy/docker-compose.yml up -d --build
make logs      # 跟随日志
make down      # 停服(pgdata 卷保留)
```

拓扑：`web`（nginx:80，SPA + `/api` 反代 + `/health`）→ `backend`（edss:8080）→ `db`（postgres:16-alpine，仅内网）。
启动序：db `pg_isready` healthy → backend 容器内 `edss-migrate`（`SEED_ON_BOOT=1` 时追加 `-seed` 首启灌演示种子）→ `exec edss` → `/ready` 探活。
`deploy/Dockerfile` 单文件多 target（`backend`/`web`）；`.env.example` 有全部可调变量，compose 变量均 `${VAR:-def}` 兜底——无 `.env` 也能起。

## 演示账号

三个演示账号口令统一为 `Edss@2026`（散列烤进 `seed/1001_sys_defs.sql` 本体；迁移 `0910_sys_user_session.sql` 的 UPDATE 为既有库修复件——`edss-migrate` 先迁移后种子，全新库上该 UPDATE 零命中）：

| 账号 | 角色 | 口令 |
| :--- | :--- | :--- |
| `president` | 院长（全院） | `Edss@2026` |
| `ops_director` | 运营办主任（运营质量域） | `Edss@2026` |
| `dept_leader` | 骨科主任（本科室） | `Edss@2026` |

其余 4 个种子账号（`admin`/`vp_medical`/`med_director`/`fin_director`）口令未重置（EA 交接口径，避免越权改超出口径的账号）。

> **登录锁定语义（§2.3）**：同一用户名 15 分钟内 `login_fail` ≥5 次 → `20104` 拒绝（计数源=`sys.audit_log`，故锁定期内的撞锁尝试不再写 `login_fail`，防自我续锁；`reason=banned` 行不计入）。已知取舍：攻击者拿已知用户名连错 5 次即可锁该账号 15 分钟——契约口径按用户名计数而非按 IP，演示环境接受此 DoS 面；如需解锁直接清该用户近期 `login_fail` 审计行或等窗口过期。

## 迁移清单（migrations/ 13 文件）

| 序 | 文件 | 内容 |
|---|---|---|
| 0000 | `0000_schemas.sql` | 六 schema（sys/dim/dwd/dws/ads/sim）唯一属主 |
| 0100 | `0100_sys_org.sql` | sys 系统域（user/dict/metric_def/audit/notice/data_source/user_pref） |
| 0110 | `0110_dim_public.sql` | dim 公共维度（date/campus/building/department/staff/drg_group/ward/device/drug） |
| 0120/0130 | newdom 两域 | L8 维表（material/discipline）与 dwd 事实表（hr_cost/research/feedback/critical/infection/adverse/energy/supply） |
| 0200/0210 | dwd 两域 | 业务流事实（outpatient_hourly/inpatient_move/bed_state_day/charge_day/insurance）+ 临床事实（surgery_case/drg_case） |
| 0300 | `0300_dws_agg.sql` | dws 聚合层（hospital_oper_day/dept_oper_day/drg_dept_period/metric_value） |
| 0400/0410 | ads 两域 | 工作台集市（work_item/dept_rank_day/radar/benchmark/exam_indicator）+ 大屏集市（alert/today_kpi/campus_status） |
| 0500 | `0500_sim.sql` | 仿真时钟/参数/日志 |
| 0900 | `0900_sys_user_dept_fk.sql` | **延迟挂载**：`fk_user_department` ON DELETE RESTRICT（防科室删除静默升格账号权限） |
| 0910 | `0910_sys_user_session.sql` | sys.user_session 会话表 + 演示账号口令重置 |

## 种子清单（seed/ 13 文件，相位序）

| 相位 | 文件 | 内容 |
|---|---|---|
| Ⅰa 定义 | `1001_sys_defs.sql` + `1002_l8_defs.sql` | sys.dict 全行 + sys.metric_def 全行（各 lane 供稿已并入） |
| Ⅰb 维度 | `1100_dim_public.sql` | 科室 81 / 人员 2,368 / DRG 病组 / 病区床位 / 设备 68 台 |
| Ⅱ.pre | `1150_sys_deferred.sql` | user.dept_id 回填 + 环 FK 收口 |
| Ⅱ 事实 | `2010/2020/203x` | dwd 全事实（门诊 41 万行/住院移动 33 万/DRG 10.4 万/手术 2.4 万） |
| Ⅲa 聚合 | `3001_dws_agg.sql` | 日/周期聚合，全部 `INSERT…SELECT` 自 dwd 派生 |
| Ⅲb 集市 | `3020/3030` | 工作台与大屏集市，事实层派生 ±10% 容差 |
| Ⅳ 仿真 | `5001_sim.sql` | sim.clock 锚定 BASE_DATE=2026-10-28 |

## 数据纪律

- **幂等**：所有种子可重复执行（ON CONFLICT DO NOTHING + 键域 DELETE 先导 + identity `setval` 后移）；迁移**非幂等**，由 `schema_migrations` 追踪表收口（重复执行靠 `-status` 判定，不靠文件内容）。
- **确定性**：零 `random()`/零 `now()`——伪随机一律 `md5(主键)` 派生，全库可复现。
- **锚点**（详见 `docs/database-schema.md` §勾稽）：BASE_DATE=2026-10-28；在院 1,846 / 床用 92.1% / 月出院 8,109 / ALOS 6.8 / 月门急诊 123,443 / 月医疗收入 14,800 万（住院 71%·门诊 25%·其他 4%）。
- **费用真源**：`dwd.charge_day`（门诊次均≈300 元 / 住院次均≈13,000 元）；`outpatient_hourly.fee_total` 逐日归一到 charge_day。
- `backend/` 下 SQL 与 `/tmp/modeling/schema/` lane 源文件一一对应；改数据请改 lane 源再装配，勿直接改本目录。

## 断言脚本

基准目录 `/tmp/backend-orch/`（编排产物，非本仓库）——`e{1,2,4}-check.sh` 在顶层、`e3-check.sh` 在 `collections/` 子目录（`PORT=808N bash …`）；newman 集合 `collections/e{1..4}.json`。EO epic 门禁脚本 `/tmp/p3-orch/eo-check.sh`（health/ready/stats/migrate/graceful/回归抽查）。
