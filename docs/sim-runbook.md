# 仿真控制面运行手册 — /sim/*(契约 §16 档 A)

> 适用：演示环境(`SIM_ENABLED` 开启)。生产形态不注册 `/sim` 路由，`NoRoute → 10003`。
> 读者：演示操作员 / 值班开发。**操作入口只有 curl 与 psql**——无 UI 控制面。

## 1. 启停

```bash
cd backend
SIM_ENABLED=1 go run ./cmd/server   # 默认即 1;PORT=8094 覆盖端口
SIM_ENABLED=0 go run ./cmd/server   # 生产形态:/sim/* 全部 404+10003
```

`/sim/*` 路由注册与否只取决于 `SIM_ENABLED` env(config.go fail-fast)。**会话闸**（§2.3 已落地）：全部端点（含 GET）限 `admin` 会话——无会话 → `20001`，非 admin 角色 → `20004`。

> **生产形态配套**：`SIM_ENABLED=0` 之外，生产部署还应置 `DEMO_ROLE_SWITCH=0`（契约 §2.1 演进注）——关闭 `?role=` 演示切换：`available_roles` 收敛为会话自身一档、读侧异名忽略、写侧异名 `20004`。两项无关联动、`default "1"`；清单见 `docs/production-deploy.md`。

## 2. 时钟模型(必读)

- `sim.clock.virtual_now` 是全库唯一"现在"(`internal/clock`),页面 `system_date`/`server_time`、各 `本月/近30日` 窗口都随它走。
- **tick 只动时钟,不重跑派生**:ads 快照层(`today_kpi`/`campus_status`/`alert_event`/`dept_rank_day`)跨日后维持"最近派生切面"冻结语义——即大屏 KPI 数字不变、告警仍挂原时刻,但 `dept_ranking` 读侧已做 `MAX(date ≤ today)` 兜底,不空板。
- 播种窗口 `2025-01-01 ~ 2026-12-31`(`seed_end`),tick 上界 `seed_end + 1 天`;工作台日期窗内跨日仍有真实播种数据可读。
- 安全边界:同日 tick 全系统一致;跨日 tick 大屏快照冻结(见上),属契约语义不是 bug。

## 3. curl 速查(替换 $B=http://localhost:8094)

```bash
B=http://localhost:8094

# 前置:admin 登录拿会话 Cookie(/sim/* 全端点限 admin 会话;口令见 seed/1001_sys_defs.sql 注释)
curl -s -c /tmp/edss.jar -X POST $B/api/v1/auth/login \
  -H 'Content-Type: application/json' -d '{"username":"admin","password":"Admin@123"}' | jq .code

# 看时钟与种子余量(演示前必查:virtual_now 距 seed_end 余量)
curl -s -b /tmp/edss.jar $B/api/v1/sim/clock | jq .data

# 快进 60 分钟(同日;上限 43200=30天/次)
curl -s -b /tmp/edss.jar -X POST $B/api/v1/sim/tick -d '{"minutes":60}' | jq .data

# 定点跳(晨会剧本起点)
curl -s -b /tmp/edss.jar -X POST $B/api/v1/sim/clock -d '{"virtual_now":"2026-10-28T07:55:00+08:00"}' | jq .data

# 复位回开箱锚点 2026-10-28 09:00+08(幂等,演示收尾必做;AT TIME ZONE 钉死上海历,与 DB TZ 无关)
curl -s -b /tmp/edss.jar -X POST $B/api/v1/sim/reset -d '{}' | jq .data

# 作业台账
curl -s -b /tmp/edss.jar "$B/api/v1/sim/jobs?size=20" | jq '.data.list[] | {job,virtual_date,job_status,started_at}'

# 散场:吊销会话(幂等)
curl -s -b /tmp/edss.jar -X POST $B/api/v1/auth/logout && rm /tmp/edss.jar
```

错误处置:`10001` 参数不合法 → `data.fields` 看字段;`35002` 越播种边界或 scope=full 未开放 → reset;`35003` 有 running 批次 → 查 `sim/jobs?status=running`。

## 4. 演示流程

1. 开场前:`GET /sim/clock` 确认 `virtual_now` 在锚点、`seed_end` 余量充足
2. `POST /sim/reset` 保证开箱态 → `GET /health` 200
3. 剧本中按需 `POST /sim/tick {minutes}` 或 `POST /sim/clock {virtual_now}` 驱动页面时间变化;大屏页需**手动刷新**重锚屏显时钟(快照按 30s 轮询自动跟随亦可)
4. **散场必做:`POST /sim/reset`** —— sim.clock 是共享库全局状态,不复位会把所有日期窗查询带到漂移日

## 5. 台账审计

每次 tick/set/reset 落 `sim.job_log` 一行(job/virtual_date/rows_cnt=推进分钟数/job_status),可经 `GET /sim/jobs` 或 `psql` 直查:

```bash
psql -d hospital_edss -c "SELECT id,job,virtual_date,rows_cnt,job_status,started_at FROM sim.job_log ORDER BY id DESC LIMIT 10;"
```

## 6. 已知边界与冻结声明

- `seed_end` 事实源:`sim.profile.seed_end` 键,缺省回退 `MAX(dwd.charge_day.date)`;当前库走回退路径(=2026-12-31),补键用
  `INSERT INTO sim.profile(key,val) VALUES('seed_end','"2026-12-31"') ON CONFLICT (key) DO NOTHING;`
- `scope:"full"`(全量重灌)未开放 → `35002`;全量重灌走运维命令:`for f in seed/*.sql; do psql -d hospital_edss -v ON_ERROR_STOP=1 -f "$f"; done`(种子幂等)
- `paused`/`speed` 为 auto-runner 预留列,手动 tick 不读;`POST /sim/clock` 可改但无消费方
- tick **非幂等**(重复提交=重复推进);并发 tick 由 `sim.clock` 行锁串行
