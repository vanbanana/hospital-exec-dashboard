# EDSS 设计文档集 — 阅读与变更指南

> 项目：院长查询与决策支持系统（EDSS，双形态：工作台 `/workbench` + 大屏 `/screen`）
> 约束：无真实医院环境；数据**双轨供给**（默认契约 mock + `VITE_USE_MOCK=0` Go 真后端，39 端点已落地）；`api-contract.md` 是数据契约，**契约先行**。
> **v2.0 说明**：原 v1.1 为"单一大屏+Go 全量后端"基线；v2.0 改为"工作台为主的双形态前端工程"。此后端已于 2026-09-27 按 `database-schema.md` v2.0 落地，P3 批（2026-09-28）再补齐 auth 会话/RBAC、写侧 8 端点、sim 控制面 5 端点与 `deploy/` 三件套（39 端点 + 58 表 hospital_edss 库，见 `../backend/README.md`）；仍预留：契约 §15 深层穿透端点（R01–R03/R09/R12/R13）、Fact/Derived 管线与告警引擎、仿真生成引擎、Redis。

## 文档地图（建议阅读顺序）

| 序 | 文档 | 内容 | 读者 | 状态 |
| :- | :--- | :--- | :--- | :--- |
| 0 | [architecture.md](architecture.md) | 双形态定位、技术栈裁剪（对照真实 package.json）、拓扑、分期路线 | 全员 | v2.1 ✅ |
| 1 | [api-contract.md](api-contract.md) | **数据契约**：端点/字段/枚举/单位/权限 | 前后端 | v2.0 ✅ |
| 2 | [frontend-architecture.md](frontend-architecture.md) | 路由、布局、设计系统（`--wb-*` token/Wb 原语）、设计红线、mock 纪律 | 前端 | v2.2 ✅ |
| 3 | [simulation-plan.md](simulation-plan.md) | 数据供给三层演进（组件内→src/mock→api 层→真后端）、mock 纪律、演示剧本 | 全员 | v2.1 ✅ |
| 4 | [error-codes.md](error-codes.md) | 响应包络、错误码注册表、前端处理矩阵 | 前后端 | v1.2（v1.1 冻结基线 + 增补注册） |
| 5 | [acceptance.md](acceptance.md) | 门禁、前端设计验收、数据层验收 | 全员 | v2.1 ✅ |
| 6 | [database-schema.md](database-schema.md) | 六 schema 库表设计、指标字典、自洽校验 | 后端/数据 | v2.0 ✅ |
| 7 | [design-tokens.md](design-tokens.md) | 设计令牌治理：L0 原色/L1 语义唯一出处、R1–R7 规则与白名单 | 前端 | 已生效 ✅ |
| 8 | [frontend-api.md](frontend-api.md) | 前端接口用法：每端点怎么调、字段怎么用、空错态渲染、双轨切换 | 前端 | v1.0 ✅ |
| 9 | [sim-runbook.md](sim-runbook.md) | 仿真控制面运行手册：/sim/* curl 操作、演示流程、台账审计（契约 §16） | 演示操作员/值班开发 | 已生效 ✅ |

关联文档（非本目录）：`../院长查询与决策支持系统_深度调研与功能需求规格白皮书.md`（需求源头）、`../backend/README.md`（Go 后端与库表跑法）、`../archive/design/workbench-home.png`（工作台首页视觉参考）、`../archive/smart-hospital-cockpit/`（大屏视觉参考工程）、`../archive/output/`（早期设计快照，只读）。

## 变更纪律

1. **契约变更**：`api-contract.md` + `error-codes.md`——字段只增不删不改名、枚举只增不改；改动先改文档、后写代码。
2. **口径变更**（指标公式/eff_score 等）：指标字典 version +1，不动接口形状。
3. **新增页面**：先登记 `frontend-architecture.md` 路由表与设计规范，再实现。
4. **设计红线与 token 变更**：改 `frontend-architecture.md` 对应节 + `src/styles/workbench.css`，双侧同步。
5. **文档版本**：各文档头部标版本号；任何 PR 改契约需在提交信息标注 `[contract]`。

## 修订记录

| 版本 | 日期 | 内容 |
| v1.0 | 2026-09-18 | 六文档初版 |
| v1.1 | 2026-09-18 | 两轮审查修订：可空PK哨兵、Fact/Derived 双轨制、字段补齐、金额单位统一元、枚举附录、告警去重键、时钟纪律、演示运行手册、验证验收基线、env/部署规格 |
| v2.0 | 2026-09-26 | **双形态改版**：产品定位改为工作台为主+大屏为辅；前端实际落地 12 页 + `--wb-*` 设计体系；契约收敛至演示落地范围；后端/数据库/仿真器降级为未实施目标态；新增设计红线与 agy 产物审查原则 |
| v2.1 | 2026-09-27 | **后端落地翻页**：Go 服务读侧 21 端点 + 57 表 hospital_edss 库建成（E0–E5），双轨数据供给（mock 默认 + `VITE_USE_MOCK=0` 真链路）；文档地图补登 design-tokens/frontend-api；门禁机械检查路径 `src/ backend/` 修正 |
| v2.2 | 2026-09-28 | **P3 批翻页**：auth 会话（sys.user_session + edss_sid Cookie）+ RBAC、写侧 8 端点（R04–R08/R10/R15/R16）双端落地、sim 控制面 5 端点（admin 闸）、`deploy/` 三件套建成；库表 57→58；文档地图补登 sim-runbook；验收门禁 `go test` 改全量 |
