# 市中心医院 · 综合运营决策指挥大屏（EDSS）

面向医院决策层的 2048×1152 实时运营指挥大屏 + 五级下钻分析系统。**前期无真实医院环境，全量数据由仿真器生成；API 契约即未来对接真实 HIS/EMR 的预留接口**（详见 `docs/`）。

## 快速开始

前置：Go ≥1.22 / Node ≥18 / Docker（或本地 PG16+Redis7）

```bash
# 1. 起依赖
docker compose up -d db redis

# 2. 后端（首次自动 migrate+seed 180 天仿真数据）
cd backend && cp .env.example .env   # 填 JWT_SECRET
go run ./cmd/server -migrate -seed    # 之后正常 go run ./cmd/server

# 3. 前端
npm install && npm run dev            # http://localhost:5173 → /screen
```

完整部署形态（生产）：`docker compose up` 一键起 db+redis+backend+web(nginx:80)。

## 演示账号（仅本地/演示环境，勿用于生产）

| 账号 | 密码 | 角色 | 能做什么 |
| :--- | :--- | :--- | :--- |
| admin | Admin@123 | admin | 全部 + /sim 控制 + unmask 实名 |
| president | President@123 | president | 大屏/下钻/督办/unmask |
| ops | Ops@123 | ops_director | 大屏/下钻/督办 |
| viewer | Viewer@123 | viewer | 只读（无督办、无 case_no） |

## 文档

`docs/README.md` 为索引。核心契约：`docs/api-contract.md`（冻结）、`docs/database-schema.md`、`docs/frontend-architecture.md`、`docs/error-codes.md`、`docs/simulation-plan.md`（演示手册 §9）、`docs/acceptance.md`（验收基线）。

## 技术栈

Vue3 + TS + Vite + Pinia + VueRouter + ElementPlus(下钻页) + ECharts / Go + Gin + GORM v2 / PostgreSQL 16（六 schema 分层）/ Redis（refresh 吊销+热缓存+登录计数）/ Docker Compose。

## 常用操作

```bash
# 演示重置（恢复开箱状态）
curl -X POST localhost:8080/api/v1/sim/reset -H "Authorization: Bearer <admin>"
# 时钟快进
curl -X POST localhost:8080/api/v1/sim/clock -d '{"virtual_now":"2026-09-18T07:55:00+08:00","speed":12}' -H "Authorization: Bearer <admin>"
# 数据自洽校验
go run ./cmd/server -validate
```
