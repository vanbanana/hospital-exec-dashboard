# 总体架构设计 — EDSS

> 版本：v2.4，2026-10-09 静态对齐。实现数量、端口和配置以 [当前实现清单](current-state.md) 为统一索引；字段和语义以 [API 契约](api-contract.md) 为准。
> 无法取得真实医院数据是固定约束。工程目标与验收见 [工程质量提升计划](engineering-acceptance.md)，不再等待医院样本或接口。

## 0. 产品定位与形态

同一数据底座，两种渲染形态：

| 形态 | 路由 | 用途 |
| --- | --- | --- |
| 工作台 | `/workbench/*` | 浅色管理台；14 个导航页面，按 allowed_pages 展示；另有 access 回退页 |
| 大屏 | `/screen` | 深色态势展示；视觉参考为只读 archive/smart-hospital-cockpit/ |

两形态使用同一工程、同一 API 层和契约。业务数据为持久化合成数据，界面显示 demo 来源；前端请求失败必须显示错误或陈旧数据，不能编造业务值。品牌文案降级和测试替身与业务数据兜底分别管理。

## 1. 技术栈白名单

| 组件 | 状态与使用方式 |
| --- | --- |
| Vue 3 + TypeScript + Vite 8 | 已使用；Node ≥22.12 |
| Vue Router 4 | 已使用；所有页面视图懒加载 |
| ECharts 6 | 已使用；src/charts.ts 按需注册，chartPresets 统一主题 |
| lucide-vue-next | 已使用；线性图标来源 |
| 原生 fetch + Vue composable | 已使用；client.ts 拆包络，模块共享会话/偏好/日期 |
| Go 1.27 + Gin + GORM + pgx + PostgreSQL 16 | 已使用；60 张业务表，18 个迁移、13 个种子文件 |
| golang.org/x/crypto bcrypt | 已使用；登录口令校验 |
| Pinia、Redis | 未安装/未启用；按具体需求评估，不是工程验收前置条件 |
| Axios | 不引入；已有 fetch 客户端 |
| Element Plus、Tailwind 等样式框架 | 未引入；现有 Wb 原语与设计令牌，新增依赖先确认 |

## 2. 系统拓扑

```text
浏览器
  ├─ 工作台：WorkbenchLayout + 14 个导航页 + AccessView
  └─ 大屏：ScreenLayout + ScreenView + Scr* 组件
       ↓ src/api/* 与共享 composable → client.ts
       ↓ /api（开发 Vite 5173；部署 Nginx 静态站点和同源反代）
Go API :8080 → handler → repo → PostgreSQL 16
                               sys/dim/dwd/dws/ads/sim
```

开发代理固定 localhost:8080，Vite 使用 strictPort，5173 占用即失败。部署为 db → backend → web 的健康依赖：PG 可连接，迁移完成并具有初始化业务数据后 `/ready` 才成功。基础配置 seed 默认关闭；production 覆盖强制关闭自动播种。

Nginx 在 web 容器终结 TLS，后端内网使用 HTTP。基础配置只发布 HTTP；edssprod 演示覆盖发布 8093/8443；production 默认发布 HTTP 80 重定向 HTTPS 443。API 调试端口绑定回环；PG 基础/production 不发布，edssprod 仅回环发布 5433。详见 [部署手册](production-deploy.md)。

## 3. 后端与数据路径

Go 单体包含 cmd/server、cmd/migrate 和 internal/{config,envelope,middleware,clock,router,handler,repo}。开启 sim 时注册 40 个方法/路径组合，关闭时 35 个；完整清单见 [current-state.md](current-state.md)。会话持久化到 sys.user_session，edss_sid 为 HttpOnly Cookie。

种子在初始化阶段生成明细、汇总和集市。运行 API 读取预聚合数据，并写会话、审计、个人偏好、规则开关、告警和工单。sim.clock.virtual_now 是业务时间源；包络 ts、会话期限和运维计时使用传输/运维墙钟。

**未实现**：常驻 Fact/Derived 管线、自动告警扫描、仿真生成引擎、契约中的五级深层穿透和 ChatBI 等预留功能。tick 只推进时钟，跨日不会重算 ads 快照；工单办结也不会自动让指标恢复。种子中的派生 SQL 不等于常驻生成服务。

契约形状与实现分离便于演进，但新数据源或新口径仍需字段、单位、权限和统计语义验证；不能仅凭 JSON 形状相同声称兼容。

## 4. 实施历史与当前工程路线

| 阶段 | 实施范围 | 当前说明 |
| --- | --- | --- |
| 历史 P0/P0.5 | 原 12 页与设计体系、集中前端 mock | 页面基线已扩展；mock 已退役 |
| 历史 P2/P3 | Go 查询、认证、写闭环、sim 控制面、三服务部署 | 已实现相应功能，边界见当前清单 |
| 已执行整改 | 偏好行为、科室工单、强制脱敏、TLS 部署、回归基础、备份恢复脚本 | 证据见 quality-remediation-plan.md；不代表全部高标准通过 |
| 下一轮 E1–E5 | 契约与权限、交互、恢复、交付、性能与持续安全 | 顺序和完成条件见 engineering-acceptance.md，待实施 |

Pinia、Redis 或额外基础设施不是必做阶段。真实医院数据接入不属于当前路线；合成样本的口径、业务状态和数据一致性属于工程路线。

## 5. 安全与数据范围

- 基础演示默认允许公开大屏和演示角色切换；这些默认值不应用于共享安全部署。production 覆盖强制 SIM_ENABLED=0、DEMO_ROLE_SWITCH=0、AUTH_COOKIE_SECURE=1、SCREEN_PUBLIC=0、SEED_ON_BOOT=0。
- 登录使用 bcrypt、PG 会话和 Cookie；失败锁定为同用户名五次/十五分钟，计数源为 sys.audit_log。没有 Redis 锁或 refresh 队列。
- 生产模式对已注册业务端点显式授权；未知角色和未登记业务路由拒绝。domain 聚合范围未定义时拒绝全院数据；科室工单/人员过滤及非管理姓名脱敏已实现，科室统计待内部契约与合成样本实现。
- 大屏前端公开路由与 API 权限分开：SCREEN_PUBLIC=0 时请求必须有合法会话及范围授权。
- 同源开发/部署不使用 CORS 中间件。密钥存于被忽略的 .env/.env.* 或被忽略的证书私钥文件，不提交仓库。
- 当前依赖、权限与恢复证据有明确范围；全面安全审计、容量、高可用和医院现场业务验收未获证明。

## 6. 部署与运行入口

使用 npm ci 复现前端依赖。云开发 scripts/cloud-dev.sh 管理本项目合成库，项目默认 edss-dev，继续已有环境时设置 EDSS_DEV_PROJECT。初始化、生产安全配置、备份恢复与故障步骤以 [production-deploy.md](production-deploy.md) 为准。

“production”是安全配置名称，数据仍为 demo。可在隔离合成库上验证 HTTPS、Secure Cookie、权限、恢复和负载，不要求医院数据。预期达到的工程能力以 [工程验收计划](engineering-acceptance.md) 的实测条件评判。

## 7. 运维与性能增补

备份管理/恢复内容校验、周期巡检和资源采样、内部 /stats 路由延迟、认证业务压测与追加索引见 [实施手册](operations-performance.md)。实现已加入工作树，定时器未启用，运行服务与数据库尚未升级到这些能力；容量与恢复结果须另行记录。

本轮性能整改新增 `1010_outpatient_daily_rollup.sql`：`dws.outpatient_daily` 按东八区自然日保存门诊小时表的同口径五项累计。迁移先锁源表、回填，再注册 INSERT/UPDATE/DELETE 语句级增量触发器与 TRUNCATE 清空触发器；源事实与汇总在同一事务内提交或回滚，不使用 TTL 缓存、不依赖手工刷新。只加表/函数/触发器，现有表结构不改；业务表增加至 59、迁移增加至 17。整日窗口走汇总，非整日窗口仍按小时事实查询。维护窗口应用，需独立比较原始 SQL、时区边界、修改/删除/回滚和并发写入结果。

门诊汇总后仍有收费查询瓶颈，新增 `1020_charge_daily_rollup.sql` 和 `dws.charge_daily`：按日期/科室汇总收费类别，保持院级总额与 level=2 科室过滤原语义，INSERT/UPDATE/DELETE/TRUNCATE 与源表同事务更新。迁移执行前锁源表，不允许与写入并发回填。业务表 60 张、迁移 18 个；恢复校验新增触发器定义/启用状态及业务 schema 函数摘要。前台调度资源快照包含 cloud-dev 独立 API，巡检日志保留连接池与运行时数值。
