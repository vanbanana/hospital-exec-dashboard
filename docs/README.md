# EDSS 设计文档集 — 阅读与变更指南

> 项目：市中心医院·综合运营决策指挥大屏（院长查询与决策支持系统 EDSS）
> 约束：前期无真实医院环境，全量模拟数据；API 契约即未来对接真实 HIS/EMR 的预留接口，**契约先行、冻结管理**。

## 文档地图（建议阅读顺序）

| 序 | 文档 | 内容 | 读者 |
| :- | :--- | :--- | :--- |
| 0 | [architecture.md](architecture.md) | 技术栈裁剪、系统拓扑、写侧双轨制（Fact Producer ↔ Derived Pipeline）、工程基线、部署 | 全员 |
| 1 | [database-schema.md](database-schema.md) | sys/dim/dwd/dws/ads/sim 六 schema 全部表结构、指标字典、自洽校验、MVP外模块对账 | 后端/数据 |
| 2 | [error-codes.md](error-codes.md) | 统一响应包络、错误码注册表、前端处理矩阵 | 全员 |
| 3 | [api-contract.md](api-contract.md) | **冻结契约**：全部端点请求/响应、枚举附录、权限矩阵、端点总表 | 前后端 |
| 4 | [frontend-architecture.md](frontend-architecture.md) | HTTP层、Pinia store 边界、路由表、**点击→跳转地图**、反馈规范、组件迁移表 | 前端 |
| 5 | [simulation-plan.md](simulation-plan.md) | 虚拟时钟、仿真生成模型、告警引擎语义、ETL 切换运行手册、**演示剧本与运行手册 §9** | 后端/演示 |
| 6 | [acceptance.md](acceptance.md) | 三层验证体系、CI 门禁、P1 验收清单、首个 vertical slice | 全员 |

关联文档（非本目录）：`../院长查询与决策支持系统_深度调研与功能需求规格白皮书.md`（需求源头）、`../output/2026-09-18-*.md`（**设计线的视觉冻结快照**——注意：output 中 design-tokens.css 与 src/styles/variables.css 已有漂移，以 src/ 实现为准；product-definition 中 "Tailwind/ECharts" 声明与实现不符，组件迁移表见 frontend-architecture §10）。

## 变更纪律

1. **契约变更**：`api-contract.md` + `error-codes.md` 受冻结规则约束（字段只增不删不改名、枚举只增不改）；改动先改文档、双方 review、后写代码。
2. **表结构变更**：只走 `backend/migrations/` 新迁移文件 + 同步 `database-schema.md`；禁止改历史迁移。
3. **口径变更**（指标公式/eff_score 等）：`sys.metric_def.version` +1，不动接口形状。
4. **新增组件/页面**：先登记 `frontend-architecture.md` §5 点击地图与 §4 路由表。
5. **文档版本**：各文档头部标版本号（当前 v1.1）；任何 PR 改契约需在提交信息标注 `[contract]`。

## 落地顺序（建议）

1a. `backend/migrations`（golang-migrate `NNNNNN_*.up/down.sql`）+ **维度种子**（dim/指标字典/账号/alert_rule，Go 代码组织于 `seed/`）
1b. **事实播种**（`-seed -seed-days 180`）→ `sim validate` 8 条全绿
2. Go 骨架：http 包络 + errcode + JWT + /healthz + /auth + /screen/snapshot（先返回契约示例静态 JSON 解锁前端）
3. 前端骨架：router/pinia/http.ts/types.ts + /login + /screen 接 snapshot（逐面板替换硬编码）
4. Simulator DayGen+Intraday+SimTick → 大屏数据转活
5. 告警链：AlertScan → /alerts → dispatch → /todos
6. 下钻链：dept cockpit → groups → drg groups → cases → case 详情
7. 验收：按 `acceptance.md` §3 清单逐项过

## 修订记录

| 版本 | 日期 | 内容 |
| v1.0 | 2026-09-18 | 六文档初版 |
| v1.1 | 2026-09-18 | 两轮审查修订：可空PK哨兵、Fact/Derived 双轨制、字段补齐（surg_level/building_code/dept_id等）、金额单位统一元、枚举附录、告警去重键、时钟纪律、演示运行手册、验证验收基线、env/部署规格 |
