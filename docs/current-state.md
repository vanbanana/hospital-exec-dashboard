# 当前实现清单

> 本文记录源码支持的页面、端点、配置及边界；不代表接收方部署或全部运行验收已完成。

## 1. 项目范围与技术栈

无法取得真实医院数据是固定约束。项目使用 PostgreSQL 确定性合成种子和虚拟业务时钟，前端通过 Go API 取数；没有运行时业务假数据兜底。真实医院接入和医院指标对账不纳入工程验收。

| 项目 | 当前实现 |
| --- | --- |
| 前端 | Vue 3、TypeScript、Vite 8、Vue Router 4、ECharts 6、lucide-vue-next；Node ≥22.12 |
| 取数与共享状态 | 原生 fetch、Vue composable/模块共享响应式状态；无 Axios、Pinia |
| 后端 | Go 1.27、Gin、GORM、pgx；无 Redis 服务 |
| 数据库 | PostgreSQL 16 为开发/CI/Compose 基准 |
| SQL | 18 个迁移文件、13 个种子文件；六 schema 共 60 张业务表，另有 public.schema_migrations 台账 |
| 时间 | sim.clock.virtual_now 是业务时间源；种子锚点 2026-10-28 09:00+08:00 |

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
- 备份工具已支持目标库、SHA256 清单、并发锁、保留策略、失败状态与全表/序列恢复比较；提供周期备份/巡检/资源采样模板。/stats 增加路由延迟和运行时指标，认证压测、三个查询索引与两种事务日汇总已补齐。调度需要在部署主机启用，恢复与容量需要在目标环境验证，高可用未实现。详见 [运维性能手册](operations-performance.md)。

## 6. 检查入口的差别

`make ci` 包含前端类型/单测/构建、Go vet/build/race 和机械检查，**不包含**部署配置测试、浏览器、容器交付与恢复演练。GitHub CI 还运行部署配置与运维脚本语法检查、演示浏览器和生产权限模式浏览器；后者使用 HTTP 与非 Secure Cookie，不验证 HTTPS。

检查结果应登记版本、输入、命令、通过项和未测项。测试数量不等于覆盖率；源码能力不代表已在目标部署启用。

## 7. 工作台与大屏切换

工作台顶栏“数据大屏”依据真实会话 allowed_pages 中的 /workbench/overview 展示；大屏“返回工作台”保留合法本地 returnTo 地址和查询参数。非法参数回退工作台；返回尝试退出全屏，快照失败仍可导航。

顶栏不重复显示日期；业务日期仍在数据日期和统计口径提示中展示，大屏时钟保留。

## 8. Docker 交付边界

离线包包含 linux/amd64 前后端与 PostgreSQL 镜像、源码、校验值、初始化/启停/备份脚本和 HTTPS 配置。全新库显式播种，已有库只迁移；initialize 检测到已有迁移台账时拒绝重播种。默认只绑定本机、使用真实会话授权并关闭公开大屏、演示角色切换及仿真控制面。

源码 ZIP 不包含镜像。公网部署需部署者提供服务器、DNS、安全组和 TLS；不附带永久托管服务。运行步骤见 [离线说明](../deploy/delivery/README.md)。
