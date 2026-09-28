# 生产部署 Checklist — EDSS

> 读者：上线/运维操作员。与 `docs/sim-runbook.md`（演示态）对应——本文只管**生产形态**。
> 标注口径：✅=当前代码已具备（配 env 即生效）；⚠️=代码具备但依赖外部队件；❌=未实现，需外部方案或后续迭代。

## 1. 形态开关（三项全置才进入生产语义）

| 项 | 生产值 | 状态 | 说明 |
| :--- | :--- | :--- | :--- |
| `SIM_ENABLED` | `0` | ✅ 已具备 | `/sim/*` 路由不注册，撞 `NoRoute → 10003`（契约 §16） |
| `DEMO_ROLE_SWITCH` | `0` | ✅ 已具备 | 演示角色切换总闸（契约 §2.1 演进注·生产形态）：`available_roles` 收敛会话自身一档、`?role=` 读侧忽略（等效自回显）、写侧异名一律 `20004`。前端按 `available_roles.length>1` 自动隐藏切换下拉 |
| `AUTH_COOKIE_SECURE` | `1` | ✅ 已具备 | `edss_sid` 追加 `Secure`；**仅 HTTPS 部署置位**，HTTP 下置 1 会导致浏览器拒存 Cookie |

> ⚠️ **compose 透传缺口**：`deploy/docker-compose.yml` 的 backend `environment` 清单当前未含 `DEMO_ROLE_SWITCH`——容器内未设即回演示态。生产 compose 部署前须补 `DEMO_ROLE_SWITCH: ${DEMO_ROLE_SWITCH:-0}`（同 `SIM_ENABLED` 式样），`docker-compose.yml` 归 D1 lane。

## 2. 凭证与口令

| 项 | 状态 | 说明 |
| :--- | :--- | :--- |
| 会话凭证 | ✅ 已具备 | 不透明令牌（crypto/rand 32B）→ `edss_sid` Cookie（HttpOnly/SameSite=Lax/12h）或 `Authorization: Bearer`；库内只落 sha256，泄库≠会话泄露；滑动续期 <6h 阈值 |
| JWT | ❌ 未实现 | 当前会话为 PG 表态会话（`sys.user_session`），非无状态 JWT；`POST /auth/refresh`（契约 R12）为远期保留端点，未实施 |
| 口令散列 | ✅ 已具备 | bcrypt（种子与登录校验同 cost） |
| 口令轮换/改密 | ❌ 未实现 | 无自助改密端点（`20103` 为预留码）；轮换只能走 SQL：`UPDATE sys."user" SET password_hash=<bcrypt>` + 吊销 `sys.user_session` 存量会话；演示口令 `Edss@2026` 上生产前必须全量替换 |
| 登录防爆破 | ✅ 已具备 | 双层：账号侧 15min 内 `login_fail` ≥5 → `20104` 锁（计数源 `sys.audit_log`）；IP 侧 nginx `limit_req_zone edss_login` 10r/s burst=5（deploy/nginx.conf，超限裸 503 不进包络） |

## 3. 传输与边界

| 项 | 状态 | 说明 |
| :--- | :--- | :--- |
| TLS 终结 | ⚠️ 需外部 | nginx.conf 已含 443 server block（安全头+HSTS+登录限流与 :80 同口径）；证书由 `deploy/certs` 自签脚本/真实证书链供给，compose 挂载 `/etc/nginx/certs/` 并 publish 443 |
| 安全响应头 | ✅ 已具备 | 双层下发：Go `securityHeaders` 中间件全响应带（nosniff/DENY/Referrer-Policy/Permissions-Policy/CSP + `/api/` no-store）；nginx 同口径作用于 SPA 文档面。CSP=`default-src 'self'; img-src 'self' data:; style-src 'self' 'unsafe-inline'; script-src 'self'`（ECharts canvas + Vue scoped 已核；实测破版则降级 `Content-Security-Policy-Report-Only`） |
| `TRUSTED_PROXY_CIDRS` | ✅ 已具备 | XFF 可信代理白名单；反代异机/异容器必须放开（compose 内网默认 `172.16.0.0/12`），否则审计 ip 记成代理地址 |
| RBAC | ✅ 已具备 | 静态角色矩阵（`middleware/rbac.go`）：settings/config 读面限 admin/president；`/sim/*` 全端点限 admin；写侧 `?role=` 越权切换 `20005`，生产态异名直接 `20004` |

## 4. 数据与迁移

| 项 | 状态 | 说明 |
| :--- | :--- | :--- |
| 备份/恢复 | ⚠️ 需外部 | 依赖 `pg_dump` 例行任务（cron/CI/LB 外编排）：`pg_dump -Fc -d hospital_edss -f edss_$(date +%F).dump`；恢复 `pg_restore -d hospital_edss --clean edss_*.dump`；演示库要求备份窗口内停写 |
| 迁移升级 | ✅ 已具备 | `edss-migrate`：`apply` 跑未应用迁移（`schema_migrations` 追踪、文件级单事务、advisory lock 防双跑）；既有库接入先 `-baseline` 收养；升级序=备份 → `edss-migrate`（**不带 -seed**）→ 探活 |
| 种子灌库 | ✅ 已具备 | `SEED_ON_BOOT`/`edss-migrate -seed`；**生产须置空/0**——种子幂等但会重置种子域为演示锚点 |
| 审计 | ✅ 已具备 | `sys.audit_log` 全量登录/写操作（含演示切换双身份 detail）；保留/归档策略属外部运维 |

## 5. 运行面

| 项 | 状态 | 说明 |
| :--- | :--- | :--- |
| 日志 | ✅ 已具备 | slog JSON → stdout；`LOG_LEVEL=info`（生产建议 `info`，排障临时 `warn/debug`）；每请求一行 method/route/status/latency_ms/trace_id |
| 健康检查 | ✅ 已具备 | `GET /health`（恒 200，LB 存活探针，nginx 透出）；`GET /ready`（DB ping+关键表行数，compose healthcheck 用，**nginx 不透出**）；`GET /stats`（内部运维面，不透出） |
| 优雅停机 | ✅ 已具备 | SIGINT/SIGTERM → 10s drain → 连接池关闭 |
| 时钟 | ✅ 已具备 | 业务时= `sim.clock.virtual_now`（唯一时间源）；生产无 tick 入口（`/sim/*` 不注册），`virtual_now` 冻结在种子锚点——**接真库前须确认业务时间源口径**（演示库按静态切面出数） |

## 6. 上线步骤速查

```bash
# 1. .env 按 .env.production.example 填齐(POSTGRES_PASSWORD 必须强口令)
# 2. 备份现库 → 迁移 → 起栈
pg_dump -Fc -d hospital_edss -f /backup/edss_pre_$(date +%F).dump
docker compose -f deploy/docker-compose.yml --env-file .env.production up -d --build
# 3. 冒烟:登录 → profile roles 一档 → /health
curl -s http://localhost/health
curl -s -c ck -X POST http://localhost/api/v1/auth/login -H 'Content-Type: application/json' -d '{"username":"<账号>","password":"<口令>"}'
curl -s -b ck http://localhost/api/v1/auth/profile   # available_roles 应仅自身一档
```
