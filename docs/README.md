# EDSS 文档索引与变更指南

> 用户操作先读 [使用指南](user-guide.md)，启动步骤见 [README](../README.md)。实现边界见 [current-state.md](current-state.md)。
> 对齐：无法取得真实医院数据是固定约束，医院系统接入和医院指标对账不纳入验收。工程能力及合成数据正确性继续严格验收。

## 文档地图

| 文档 | 职责 | 使用方式 |
| --- | --- | --- |
| [user-guide.md](user-guide.md) | 登录、指标、预警工单、偏好与大屏体验 | 用户操作手册 |
| [current-state.md](current-state.md) | 当前方法/路径、页面、栈、配置、已知边界 | 先读；数量和部署事实的统一索引 |
| [engineering-acceptance.md](engineering-acceptance.md) | 后续修复顺序、范围与高标准完成条件 | 计划；待实施不算通过 |
| [quality8-evidence.md](quality8-evidence.md) | 验证范围与限制 | 检查入口及证据要求 |
| [quality-remediation-plan.md](quality-remediation-plan.md) | 维护与验收要求 | 当前边界与维护纪律 |
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


## 变更纪律

1. 契约演进先改 api-contract.md/error-codes.md，再实现；已有路径、字段、枚举和语义保持稳定，新增可选字段明确默认与兼容行为。
2. 指标口径变化登记公式、单位、过滤范围和版本；合成数据也必须可独立验证。
3. 新页面先更新路由/交互表，再实现；新增或修改令牌先改 design-tokens.md，并对齐 tokens.css。基元样式由 workbench.css/screen.css 消费令牌。
4. 改动方法/路径、页面、迁移、配置和行为时同步 current-state.md 及对应手册；预留和未验证能力不得写成已实现。


源码交付包省略 archive 历史参考工程、研究资料和过程记录，运行与构建不依赖这些资产。
