# XX市人民医院 · 院长查询与决策支持系统（EDSS）

> **置顶：[工程质量提升计划](docs/engineering-acceptance.md)** — 后续修复顺序与完成条件。本轮约8分的依据、失败和限制见 [验收证据](docs/quality8-evidence.md)，历史见 [整改记录](docs/quality-remediation-plan.md)。

**双形态院长决策系统**：`/workbench` 浅色工作台（主，日常管理用）+ `/screen` 深色演示大屏（展示用）。无法取得医院真实数据是固定约束，真实系统接入和医院指标对账不纳入验收。数据由持久化合成种子库+仿真时钟供给：**前端单轨经 vite proxy/nginx 打 Go 真后端**（开启仿真时 40 个方法/路径组合，关闭时 35 个，见 [当前清单](docs/current-state.md)），无 mock 层、无假数据兜底。`docs/api-contract.md` 为数据契约；合成数据正确性与其余工程能力必须可验证。

恢复历史与当前验证：[恢复状态](docs/recovery-status.md) · [原始上下文](docs/recovered-context.md)。

## 快速开始

前置：Node ≥22.12、Docker、Python 3。首次初始化合成数据库需要数分钟。接续已有云环境时按启动说明设置 `EDSS_DEV_PROJECT`（本会话为 `edss-remediation`），默认新项目名为 `edss-dev`；不要在已有端口上重复起栈。

```bash
npm ci
scripts/cloud-dev.sh start  # 持久化数据库 + 迁移 + 首次演示种子 + Go API
npm run dev                # http://localhost:5173 → 自动重定向 /workbench
```

| 路由 | 内容 |
| :--- | :--- |
| `/workbench` | 工作台首页（KPI/趋势/排行/预警/待办） |
| `/workbench/{overview,medical,operations,hr,research,patient,quality,assets,compare,topics,settings}` | 11 个业务子页 |
| `/workbench/{tasks,preferences}` | 按授权范围办理工单、保存个人偏好 |
| `/screen` | 深蓝大屏（已建成；唯一视觉基准 `archive/smart-hospital-cockpit/`，旧过渡稿已删） |

## 文档与工作方式

`AGENTS.md` 为工作方式与硬规则（先读）；`docs/README.md` 为文档索引。核心规范：`docs/api-contract.md`（数据契约）、`docs/frontend-architecture.md`（前端设计系统与红线）、`docs/architecture.md`（技术栈与分期）。后端跑法见 `backend/README.md`。

## 技术栈

前端 Vue3 + TS + Vite + VueRouter + ECharts + lucide-vue-next（无 Pinia/axios——见 architecture §1 白名单）；后端 `backend/`：Go + Gin + GORM + PostgreSQL（Go1.27、PG16，跑法见 `backend/README.md`；数量见当前清单）。


云环境与部署步骤见 [部署与恢复手册](docs/production-deploy.md)。当前业务数据来源为 `demo`。工程验收使用合成样本；真实医院接入不作为缺陷或阻塞项。production 表示安全部署配置，不表示医院现场业务验收。

运维与性能新增入口见 [实施手册](docs/operations-performance.md)：备份/恢复内容校验、周期巡检、路由延迟指标及认证业务压测。云会话周期调度已运行，运行栈已升级；非空恢复及故障演练见整改记录。systemd 开机调度与外部通知仍由部署平台负责。
