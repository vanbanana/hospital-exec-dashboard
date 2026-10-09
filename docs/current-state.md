# 当前实现清单

> 2026-10-09，依据当前工作树与运行验收。记录已实现行为；本轮结果见 [验收证据](quality8-evidence.md)，历史见 [整改记录](quality-remediation-plan.md)，后续标准见 [工程验收计划](engineering-acceptance.md)。

## 1. 项目范围与技术栈

无法取得真实医院数据是固定约束。项目使用 PostgreSQL 确定性合成种子和虚拟业务时钟，前端通过 Go API 取数；没有运行时业务假数据兜底。真实医院接入和医院指标对账不纳入工程验收。

| 项目 | 当前实现 |
| --- | --- |
| 前端 | Vue 3、TypeScript、Vite 8、Vue Router 4、ECharts 6、lucide-vue-next；Node ≥22.12 |
| 取数与共享状态 | 原生 fetch、Vue composable/模块共享响应式状态；无 Axios、Pinia |
| 后端 | Go 1.27、Gin、GORM、pgx；无 Redis 服务 |
| 数据库 | PostgreSQL 16 为开发/CI/Compose 基准；PG15 兼容属于历史验证 |
| SQL | 18 个迁移文件、13 个种子文件；六 schema 共 60 张业务表，另有 public.schema_migrations 台账 |
| 时间 | sim.clock.virtual_now 是业务时间源；种子锚点 2026-10-28 09:00+08:00，与文档日期无关 |

## 2. 页面与路由

工作台导航共 **14 项**：首页、overview、medical、operations、hr、research、patient、quality、assets、compare、topics、settings、tasks、preferences。实际显示由 `profile.allowed_pages` 限制。

`src/views/workbench/` 共 **15 个视图文件**，额外的 `AccessView` 是 `/workbench/access` 无可用页面时的回退页，不计入导航。另有 `/login` 和 `/screen`。所有页面视图均懒加载，两个布局直接导入。

根路径重定向 `/workbench`；已登录访问登录页转向首个授权页面或 access。工作台子域未知路径重定向首页；根级未知路径同样回退工作台并经过权限守卫。大屏前端 `meta.public` 仅豁免路由守卫，`SCREEN_PUBLIC=0` 时 API 仍检查会话及角色/范围。

## 3. HTTP 端点清单

计数单位为 **HTTP 方法 + 路径**，路径参数沿用 Gin 的 `:id/:code` 记法。`SIM_ENABLED=1` 时 **40 个：29 GET、10 POST、1 PUT**；其中 `/api/v1` 下 37 个，根级运维 3 个。关闭仿真后 **35 个：27 GET、7 POST、1 PUT**。端点存在不代表每个角色均可调用。

| 方法 | 路径 | 条件 |
| --- | --- | --- |
| GET | `/api/v1/auth/profile` | 常驻 |
| POST | `/api/v1/auth/login` | 常驻 |
| POST | `/api/v1/auth/logout` | 常驻 |
| GET | `/api/v1/hospital/profile` | 常驻 |
| GET | `/api/v1/workbench/home/kpis` | 常驻 |
| GET | `/api/v1/workbench/home/trends` | 常驻 |
| GET | `/api/v1/workbench/home/top10` | 常驻 |
| GET | `/api/v1/workbench/home/indicators` | 常驻 |
| GET | `/api/v1/workbench/home/progress` | 常驻 |
| GET | `/api/v1/workbench/home/alerts` | 常驻 |
| GET | `/api/v1/workbench/home/notices` | 常驻 |
| GET | `/api/v1/workbench/overview` | 常驻 |
| GET | `/api/v1/workbench/medical` | 常驻 |
| GET | `/api/v1/workbench/operations` | 常驻 |
| GET | `/api/v1/workbench/compare` | 常驻 |
| GET | `/api/v1/workbench/hr` | 常驻 |
| GET | `/api/v1/workbench/research` | 常驻 |
| GET | `/api/v1/workbench/patient` | 常驻 |
| GET | `/api/v1/workbench/quality` | 常驻 |
| GET | `/api/v1/workbench/assets` | 常驻 |
| GET | `/api/v1/workbench/topics` | 常驻 |
| GET | `/api/v1/workbench/settings/config` | 常驻 |
| GET | `/api/v1/workbench/settings/preferences` | 常驻 |
| PUT | `/api/v1/workbench/settings/preferences` | 常驻 |
| POST | `/api/v1/workbench/settings/rules/:code` | 常驻 |
| POST | `/api/v1/alerts/:id/ack` | 常驻 |
| POST | `/api/v1/alerts/:id/dispatch` | 常驻 |
| POST | `/api/v1/alerts/:id/close` | 常驻 |
| GET | `/api/v1/todos` | 常驻 |
| POST | `/api/v1/todos/:id/status` | 常驻 |
| GET | `/api/v1/staff` | 常驻 |
| GET | `/api/v1/screen/snapshot` | 常驻 |
| GET | `/api/v1/sim/clock` | SIM_ENABLED=1 |
| POST | `/api/v1/sim/clock` | SIM_ENABLED=1 |
| POST | `/api/v1/sim/tick` | SIM_ENABLED=1 |
| POST | `/api/v1/sim/reset` | SIM_ENABLED=1 |
| GET | `/api/v1/sim/jobs` | SIM_ENABLED=1 |
| GET | `/health` | 常驻 |
| GET | `/ready` | 常驻 |
| GET | `/stats` | 常驻 |

注册来源：`backend/internal/router/router.go` 和 `register_*.go`。字段与单位以 [API 契约](api-contract.md) 为准；预留端点不计入清单。

## 4. 启动与部署配置

| 模式 | 主机默认入口 | 数据与安全行为 |
| --- | --- | --- |
| 本地源码开发 | Vite 5173，API 127.0.0.1:8080 | Vite strictPort，端口占用即失败；/api 代理到 localhost:8080 |
| 基础 Compose | HTTP 80，API 127.0.0.1:8080；PG 不发布 | 演示安全开关默认开启；SEED_ON_BOOT 默认 0；新库必须显式初始化 |
| 基础 + edssprod 覆盖 | HTTP 8093、HTTPS 8443、API 127.0.0.1:8095、PG 127.0.0.1:5433 | 演示隔离栈；镜像自签证书，仍使用基础演示开关 |
| 基础 + production 覆盖 | HTTP 80 重定向 HTTPS 443；API 仅回环，PG 不发布 | 正式证书文件、非空口令；seed/sim/演示角色切换强制 0，Secure Cookie=1、SCREEN_PUBLIC=0；三服务 restart unless-stopped |

端口可按相应配置变量覆盖。TLS 在 web 容器的 Nginx 终结，API 内网使用 HTTP。production 覆盖不初始化业务数据：应先在隔离环境初始化合成库、核对并恢复到新库，再配置 DSN；无需医院数据。空库不能通过 `/ready`，web 等待 backend healthy。

`scripts/cloud-dev.sh` 默认项目 `edss-dev`，只管理内网 `db:5432/hospital_edss`。正常启动只迁移，全新库才播种；中断初始化须显式 seed。接续已有环境时设置对应 `EDSS_DEV_PROJECT`，不另建相同端口的栈。运行步骤见 [部署手册](production-deploy.md)。

## 5. 已实现边界与待改进项

- 生产模式对已注册业务端点显式授权。未定义的 domain 聚合拒绝全院读取；工单和人员支持科室过滤，非管理身份强制姓名脱敏；个人偏好归实际会话。科室聚合能力仍待内部契约与实现，可使用合成样本完成。
- 系统设置中的 HIS/EMR 等来源、同步时间和状态是合成登记，没有连接医院系统。规则开关和个人偏好可写，来源与用户表为读取展示。
- 科研、患者、质量、资产 API 无 range 参数，页面已移除无效时间切换并注明固定统计口径；根级未知路径已回退工作台。
- 告警与工单状态闭环已实现，办结不自动重算指标。sim tick 只推进时钟，跨日 ads 快照保持最近派生切面；常驻 Fact/Derived、自动告警扫描与生成引擎未实现。
- `client.ts` 对非 auth/* 的 401 清会话并跳登录，不实现 refresh 队列。登录锁定展示错误文案，没有倒计时；大屏手动重试并每 30 秒轮询，没有重连倒计时。
- 备份工具已支持目标库、SHA256 清单、并发锁、保留策略、失败状态与全表/序列恢复比较；提供周期备份/巡检/资源采样模板。/stats 增加路由延迟和运行时指标，认证压测、三个查询索引与两种事务日汇总已补齐。运行库迁移已应用，正式镜像已升级，云会话调度与非空恢复已验证；持续容量结果按整改记录，高可用未实现。详见 [运维性能手册](operations-performance.md)。

## 6. 检查入口的差别

`make ci` 包含前端类型/单测/构建、Go vet/build/race 和机械检查，**不包含**部署配置测试、浏览器、容器交付与恢复演练。GitHub CI 还运行部署配置与运维脚本语法检查、演示浏览器和生产权限模式浏览器；后者使用 HTTP 与非 Secure Cookie，不验证 HTTPS。

此前本地 HTTPS、备份、故障恢复等结果保留在 [整改记录](quality-remediation-plan.md)。文档对齐轮仅作静态核对；当前运行验收轮已执行回归、非空恢复、故障及持续负载，结果分开登记，不能用此前仅编译的记录代替。测试数量不等于覆盖率。

当前新增 1010 门诊日汇总与 1020 收费日/科室汇总，共 60 张业务表、18 个迁移。合成运行库已应用全部迁移；触发器将事实与汇总置于同一事务，非整日门诊窗口仍读原始小时事实。云会话已运行前台备份/巡检/资源调度器，systemd 模板未安装；宿主重启与外部通知仍须部署平台负责。当前验收进展见 quality-remediation-plan.md，30分钟认证混合查询已达固定目标，成功46.6RPS、各路由p95≤1秒、总错误率约0.10%；该结果包含DB重建干扰，不代表写容量或最大容量。

## 2026-10-09 工作台／大屏入口

工作台顶栏新增「数据大屏」，依据真实会话 allowed_pages 判断院级入口；大屏顶栏新增「返回工作台」，保留本地 returnTo 的完整页面地址。返回尝试退出全屏，非法返回参数回退工作台，快照失败时仍可返回。
验证：58 项前端单测、类型／生产构建、3 项真实后端浏览器切换测试通过；1568×880 双页面截图和 1100px 入口可见性已检查，无页面脚本异常。

## 2026-10-09 顶栏与 Docker 交付

移除工作台顶栏重复日期，保留页面数据日期提示和大屏时钟。交付包提供三种 linux/amd64 离线镜像、源码、校验值、初始化／启停／备份脚本与 HTTPS 配置。全新卷 18 迁移、13 种子完成；日常启动仅迁移（applied0/skipped18），重复播种被拒绝。停机重启前后迁移／运营日／手术数 18/730/24266 一致；备份成功。容器浏览器 5 项、前端单测58、生产构建、部署检查7项通过。TLS 校验证书、Secure/HttpOnly Cookie、认证 profile 已实测，HTTPS 浏览器未另跑。

本轮云内三服务健康；当前环境无公网端口发布与部署凭据，CF 临时隧道请求被策略403拒绝，未生成公网地址。按 deploy/delivery/README.md 可在自有云服务器部署。
