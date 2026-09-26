# XX市人民医院 · 院长查询与决策支持系统（EDSS）

**双形态院长决策系统**：`/workbench` 浅色工作台（主，日常管理用）+ `/screen` 深色演示大屏（展示用）。前期无真实医院环境，全量模拟数据；`docs/api-contract.md` 为数据契约，未来接 mock server / 真实后端只换数据源。

## 快速开始

前置：Node ≥18

```bash
npm install && npm run dev   # http://localhost:5173 → 自动重定向 /workbench
```

| 路由 | 内容 |
| :--- | :--- |
| `/workbench` | 工作台首页（KPI/趋势/排行/预警/待办） |
| `/workbench/{overview,medical,operations,hr,research,patient,quality,assets,compare,topics,settings}` | 11 个业务子页 |
| `/screen` | 深蓝大屏（过渡稿；目标设计见 `smart-hospital-cockpit/` 视觉参考） |

## 文档与工作方式

`AGENTS.md` 为工作方式与硬规则（先读）；`docs/README.md` 为文档索引。核心规范：`docs/api-contract.md`（数据契约）、`docs/frontend-architecture.md`（前端设计系统与红线）、`docs/architecture.md`（技术栈与分期）。

## 技术栈

Vue3 + TS + Vite + VueRouter + ECharts + lucide-vue-next（无后端、无 Pinia/axios——见 architecture §1 白名单）。
