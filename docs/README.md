# EDSS 文档索引与变更指南

> **置顶：[工程质量提升与验收计划](engineering-acceptance.md)**。已执行修复的命令与结果见 [整改记录](quality-remediation-plan.md)。
> 2026-10-09 对齐：无法取得真实医院数据是固定约束，医院系统接入和医院指标对账不纳入验收。工程能力及合成数据正确性继续严格验收。

## 文档地图

| 文档 | 职责 | 使用方式 |
| --- | --- | --- |
| [current-state.md](current-state.md) | 当前方法/路径、页面、栈、配置、已知边界 | 先读；数量和部署事实的统一索引 |
| [engineering-acceptance.md](engineering-acceptance.md) | 下一轮修复顺序、范围与高标准完成条件 | 计划；待实施不算通过 |
| [quality8-evidence.md](quality8-evidence.md) | 本轮8分评价、持续容量、恢复、失败和未测项 | 运行证据及机器摘要 |
| [quality-remediation-plan.md](quality-remediation-plan.md) | 已修复缺陷、历史命令、结果及未测项 | 证据记录，不等于全工程验收完成 |
| [architecture.md](architecture.md) | 双形态、技术栈白名单、拓扑与实现边界 | v2.4 |
| [api-contract.md](api-contract.md) | 路径、字段、枚举、单位、null 和权限 | v2.0 字段基线及增补；冻结契约 |
| [error-codes.md](error-codes.md) | 包络、业务码、HTTP 映射与当前错误处理 | 号码与语义稳定，行为按当前实现 |
| [frontend-architecture.md](frontend-architecture.md) | 路由、布局、设计系统、数据与交互纪律 | v2.4 |
| [frontend-api.md](frontend-api.md) | 端点调用与消费位置、字段和空错态 | v1.1；与契约配合 |
| [design-tokens.md](design-tokens.md) | 颜色/字号/间距/圆角令牌治理 | 令牌增改先登记 |
| [simulation-plan.md](simulation-plan.md) | 合成数据、时钟、场景和未实现生成能力 | v2.2 |
| [sim-runbook.md](sim-runbook.md) | admin 仿真控制操作及限制 | 仅开启 SIM_ENABLED 时 |
| [database-schema.md](database-schema.md) | 六 schema、60 业务表、迁移/种子和勾稽 | v2.1；历史目标和当前行为分开 |
| [acceptance.md](acceptance.md) | 现有本地与 CI 门禁、回归标准 | v2.3；命令能力不混同 |
| [operations-performance.md](operations-performance.md) | 周期备份、内容恢复校验、巡检、指标、认证压测和索引 | 实现规格；激活和容量结果另行记录 |
| [production-deploy.md](production-deploy.md) | 云启动、演示/安全部署、备份恢复与升级 | production 是安全配置，数据仍为 demo |
| [后端手册](../backend/README.md) | Go 运行、环境变量、SQL 清单与测试库 | 当前 SQL 正本在仓库 |
| [部署入口](../deploy/README.md) | Compose 文件用途 | 快速跳转部署手册 |
| [工作方式](../AGENTS.md) | 契约先行、文件边界、依赖与交付纪律 | 开始修改前阅读 |

关联资产：根目录《院长查询与决策支持系统_深度调研与功能需求规格白皮书.md》为**历史需求研究**，其中真实系统接入、全功能愿景及预估不作为当前实现或验收结论。archive/ 为只读历史参考；工作台参考 archive/design/workbench-home.png，大屏参考 archive/smart-hospital-cockpit/。/tmp/modeling 等外部编排资产仅属历史来源，不是启动或修改 SQL 的前置条件。

## 变更纪律

1. 契约演进先改 api-contract.md/error-codes.md，再实现；已有路径、字段、枚举和语义保持稳定，新增可选字段明确默认与兼容行为。
2. 指标口径变化登记公式、单位、过滤范围和版本；合成数据也必须可独立验证。
3. 新页面先更新路由/交互表，再实现；新增或修改令牌先改 design-tokens.md，并对齐 tokens.css。基元样式由 workbench.css/screen.css 消费令牌。
4. 改动方法/路径、页面、迁移、配置和行为时同步 current-state.md 及对应手册；预留和未验证能力不得写成已实现。
5. 验证记录包含版本、命令、输入与结果，区分通过/未通过/未验证；历史数目不自动作为当前事实。下面旧版本表只记录当时状态，VITE_USE_MOCK 已退役。

## 修订记录

| 版本 | 日期 | 内容 |
| --- | --- | --- |
| v1.0 | 2026-09-18 | 六文档初版 |
| v1.1 | 2026-09-18 | 两轮审查修订：可空PK哨兵、Fact/Derived 双轨制、字段补齐、金额单位统一元、枚举附录、告警去重键、时钟纪律、演示运行手册、验证验收基线、env/部署规格 |
| v2.0 | 2026-09-26 | **双形态改版**：产品定位改为工作台为主+大屏为辅；前端实际落地 12 页 + `--wb-*` 设计体系；契约收敛至演示落地范围；后端/数据库/仿真器降级为未实施目标态；新增设计红线与 agy 产物审查原则 |
| v2.1 | 2026-09-27 | **后端落地翻页**：Go 服务读侧 21 端点 + 57 表 hospital_edss 库建成（E0–E5），双轨数据供给（mock 默认 + `VITE_USE_MOCK=0` 真链路）；文档地图补登 design-tokens/frontend-api；门禁机械检查路径 `src/ backend/` 修正 |
| v2.2 | 2026-09-28 | **P3 批翻页**：auth 会话（sys.user_session + edss_sid Cookie）+ RBAC、写侧 8 端点（R04–R08/R10/R15/R16）双端落地、sim 控制面 5 端点（admin 闸）、`deploy/` 三件套建成；库表 57→58；文档地图补登 sim-runbook；验收门禁 `go test` 改全量 |
| v2.3 | 2026-09-28 | **前端假数据清零**：`src/mock/` 整层摘除、`VITE_USE_MOCK` 开关下线——数据供给切真后端单轨；`system_date`/屏显时钟假兜底清除；双轨口径文档翻页 |
| v2.4 | 2026-10-09 | 文档对齐：40/35 方法路径、14 导航页与 access、15 迁移/13 种子、TLS/权限/偏好与仿真边界；真实医院数据移出验收，新增工程质量提升计划 |
