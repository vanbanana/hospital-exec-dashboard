# 前端接口文档 — 院长查询与决策支持系统 (EDSS)

> **版本**：v1.0（对齐 `docs/api-contract.md` v2.0 基线）
> **制定日期**：2026-09-27
> **适用端**：前端工程 `src/`（Vue3 + TS + Vite），含 `/workbench` 工作台与 `/screen` 大屏两形态。

---

## 0. 文档定位与维护纪律

### 0.1 本文是什么

**前端实现接口的唯一索引**。前端代码里出现的每一次取数（端点、参数、字段、空态/错误态渲染约定）都必须能对回本文件。

与 `docs/api-contract.md` 的分工：

| 文件 | 管什么 |
| :--- | :--- |
| `docs/api-contract.md` | **定字段**——端点、字段名、枚举、单位、示例负载、契约演进。全系统冻结契约（权威） |
| `docs/error-codes.md` | **定包络**——响应包络、错误码注册表、HTTP 映射、前端统一处理矩阵 |
| **本文档** | **定用法**——每个端点前端怎么调、参数怎么传、响应字段怎么用、空态/错误态怎么渲染、mock key 与消费位置 |

**字段级冲突裁决**：本文字段表与契约示例不一致时，**一律以契约为准**，并立即停下回报（同 AGENTS.md §0：文档矛盾不自行裁决）。

### 0.2 维护纪律

1. **改接口 = 先改本文档**：任何前端代码的取数改动（换端点、换字段、换空态行为）之前，必须先改本文档对应节；契约层新增端点/字段走契约演进流程（先改 `api-contract.md`）。
2. 字段名一律 **snake_case**，逐字符照抄契约，不得自创别名；发现契约字段与本文冲突 → 回报，不改名。
3. 每个端点一节，固定栏目顺序：**端点+方法 → 请求参数表 → 响应字段表 → 前端消费位置 → 空态与错误态 → mock key**。新增端点按同模板补节。
4. 状态变化（如未接入端点完成接入、预留端点启用）须同步更新 §16 覆盖总表。

### 0.3 当前接入形态（mock / 真后端双轨）

- 统一取数入口：`api<T>(key, params)`（`src/api/client.ts`），`key` = 契约端点路径去掉前导 `/`（如 `'workbench/overview'`）。
- 工作台端点均有薄封装函数（`src/api/workbench.ts`），视图**不直接调 `api()`**，经封装函数取数。
- **双轨切换**：`VITE_USE_MOCK`(默认 `1`) 走 `src/mock/` 注册表（120 ms 延迟 + 深拷贝）；`=0` 时 `api()` 经 vite proxy(`/api` → `localhost:8080`)打 **Go 后端** `/api/v1/<key>`，拆 `ApiEnvelope` 包络——`code!==0` 抛带数值 `code`/`fields`/`trace_id` 的 Error，`useAsyncData.toApiError` 透传到五态；HTTP 层失败（无包络）抛 `[api] http N`。视图层对来源无感。
- **Mock 参数校验**（仅 mock 轨）：带参 resolver 对枚举外取值抛 `Error{ code: 10001 }`（`src/mock/index.ts` 内 `ENUM_DOMAIN`/`assertParams`）；必填缺席与空串同样抛 10001——真后端轨下同一语义由 Gin handler 下发（HTTP400 + `data.fields`）。
- **Go 后端运行**（详见 `backend/README.md`）：`brew services start postgresql@15` → `cd backend && go run ./cmd/server`（默认 DSN `postgres://localhost/hospital_edss?sslmode=disable`，端口 `PORT`）；前端 `VITE_USE_MOCK=0 npm run dev`。

---

## 1. 通用约定

### 1.1 响应包络（Envelope）

契约 §1.1 / error-codes §1。所有接口经统一包络：

```json
{ "code": 0, "message": "ok", "data": { }, "trace_id": "req-xxx", "ts": 1758153000 }
```

| 字段 | 类型 | 前端用法 |
| :--- | :--- | :--- |
| `code` | int | `0` = 成功；非 0 走错误码矩阵。列表为空仍 `code=0` + `data.list=[]` |
| `message` | string | 中文提示，默认直显；前端**禁止按 message 文案做逻辑判断**（一律按 `code`） |
| `data` | any / null | 业务负载；失败时 `null` 或含 `fields` 校验明细 |
| `trace_id` | string | 报错反馈随用户问题上送 |
| `ts` | int | Unix 秒 |

**特例**：`code=31004`（指标暂无数据）是全系统唯一"HTTP 200 + 非 0 code"合法形态，`api` 层 resolve `null`，页面自渲空态。

### 1.2 分页

- 分页负载 `{ list, page, size, total }` + 查询参数 `?page=1&size=20`（`size ≤ 100`）**仅用于契约 §15 远期预留端点**（如 `/cases`、`/todos`）。
- 当前工作台所有端点均为**定长卡片式负载，不带分页字段**；前端不得自行加分页参数。

### 1.3 单位与格式规范（契约 §1.3 / §1.4）

| 项 | 规范 |
| :--- | :--- |
| 金额 | 聚合/统计口径 = **万元**（2 位小数）；明细/次均口径 = **元**。量纲由 `unit` 字段显式声明，前端不猜 |
| 比率 | 带 `%` 的展示值直接给浮点数（`92.1` 即 `92.1%`），前端渲染时拼 `%` 或按 `unit` 字段 |
| `delta` | 格式化字符串：`+3.6%` / `-0.3` / `+12项` / `持平`，**直接渲染不解析** |
| `dir` | 严格三态 `up` / `down` / `flat`，驱动箭头与涨跌色 |
| `tone` | 语义色枚举 `primary` / `teal` / `green` / `amber` / `red` / `navy`；API 禁下十六进制，色值由 `--wb-*` token 映射 |
| `icon` | Lucide 图标名（如 `Stethoscope`），前端按图标名白名单映射组件 |
| 告警级别 | 英文枚举 `urgent` / `major` / `minor` → 前端映射中文 高/中/低 |
| 日期 | `YYYY-MM-DD`；时间戳 = Unix 秒或 ISO 8601（`2026-10-28T08:30:00+08:00`）；日期时间 = `YYYY-MM-DD HH:mm`；`10-28`、`08:12` 等短格式一律前端格式化 |
| `bar_pct` | 条形宽度归一化百分比（`val / max * 100`），前端直接当宽度用 |
| 图表量纲 | 趋势/构成/多序列响应必须显式带 `unit` 字段（或节注声明） |

### 1.4 公共参数

| 参数 | 取值 | 说明 |
| :--- | :--- | :--- |
| `range` | `本月` / `本季` / `本年` | 时间范围三值（中文字面量原样传）。各端点默认值见各节；契约未标注默认的（operations、hr），前端缺省按 `本年`（见 `src/api/workbench.ts`） |
| `tab` | `门急诊` / `住院` / `手术` | 仅 `/workbench/medical` |
| `dim` | `scale` / `benefit` / `efficiency` / `quality` | 仅 `/workbench/compare`，英文枚举 |
| `topic` | `drg` / `insurance` / `exam` / `outp_fund` | 仅 `/workbench/topics`，英文枚举 |

以上参数均由 `WbSeg` 等原语产生，**只传枚举内值**；非法值后端回 `10001`。

### 1.5 演示基准日

`BASE_DATE = 2026-10-28`（周三工作日）。所有 mock 数据锚定该日：KPI/月累计锚定 10 月，`occurred_at`/`sync`/`login` 等时间字段均不晚于基准日，`server_time = 2026-10-28T08:30:00+08:00`。前端文案涉及"今日/本月"一律按基准日解释。

### 1.6 空态/错误态总纲（各节只写端点差异）

按 AGENTS.md §3.3 与 error-codes.md §4：

| 情况 | 前端渲染约定 |
| :--- | :--- |
| `list=[]`（code=0） | 对应区块渲**空态**：表格空表、图表空坐标轴、卡片区空占位；不报错不白屏 |
| `code=31004` | `api` 层 resolve `null` → 页面/面板自渲空态 |
| 图表字段缺失/为 null | 画空坐标轴，不报错 |
| `code=10001` 非法参数 | 面板/页面错误态 + 重试入口；前端应先校验枚举防呆 |
| `code=20001/20003` | 清凭证跳 `/login`（演示期无登录页 → 按当前角色降级展示） |
| `code=20004` | 跳 `/403` |
| `code=10005` | 节流提示，触发按钮置冷却 |
| 其余非 0 code | 统一错误提示（展示 `message`，附 `trace_id`） |
| HTTP 5xx / 断网 | 工作台：面板错误态 + 重试；大屏：断线重试态（顶部红条 + 自动重连倒计时） |
| 重试成功前 | 旧数据保留并标 stale（有刷新态后） |

---

## 2. 认证与上下文域 `/auth` & `/hospital`

> 契约 §2。演示级认证：无 Bearer Token，`?role=` 直接切上下文。
> **当前状态：两个端点已注册 mock 并接入视图**（消费位置见各节）。接入顺序：先注册 mock key 再改视图。

### 2.1 `GET /auth/profile`

- **契约锚点**：§2.1。获取当前操作人身份与可切换的模拟角色列表。

**请求参数**

| 参数名 | 取值 | 默认 | 说明 |
| :--- | :--- | :--- | :--- |
| `role` | `president` / `ops_director` / `dept_leader` | 无 | 可选。切换上下文角色：院长 / 运营办主任 / 骨科主任 |

**响应字段**（`data`）

| 字段 | 类型 | 单位 | 可为null | 说明 |
| :--- | :--- | :--- | :--- | :--- |
| `user` | object | — | 否 | 当前操作人 |
| &nbsp;&nbsp;`id` | int | — | 否 | 用户 ID |
| &nbsp;&nbsp;`username` | string | — | 否 | 登录名 |
| &nbsp;&nbsp;`real_name` | string | — | 否 | 姓名（如 `王建国`） |
| &nbsp;&nbsp;`title` | string | — | 否 | 职务展示名（如 `院长`） |
| &nbsp;&nbsp;`dept_id` | int | — | **是** | `null` = 院级视角；库存储哨兵 `0`，API 对外序列化为 `null`（契约 §2.1 注） |
| &nbsp;&nbsp;`dept_name` | string | — | 否 | 科室名（院级为 `全院`） |
| &nbsp;&nbsp;`avatar` | string | — | 否 | 头像资源路径（`src/assets/` 内） |
| &nbsp;&nbsp;`role` | string | — | 否 | 当前角色枚举，同 `role` 参数 |
| `available_roles` | object[] | — | 否 | 可切换角色列表（演示期下拉数据源） |
| &nbsp;&nbsp;`role` | string | — | 否 | 角色枚举 |
| &nbsp;&nbsp;`name` | string | — | 否 | 展示名（如 `院长 (王建国)`） |
| &nbsp;&nbsp;`scope` | string | — | 否 | 数据范围文案（如 `全院`、`本科室`） |
| `system_date` | string | YYYY-MM-DD | 否 | 系统日期，恒为 BASE_DATE |
| `weekday` | string | — | 否 | 中文星期（如 `星期三`） |

**前端消费位置**

- `src/api/auth.ts`——`getAuthProfile(role?)` 透传 `?role=`。
- `src/components/workbench/WorkbenchHeader.vue`——头像、`user.title`、日期行（`system_date`+`weekday`）、铃铛告警角标（复用 `workbench/home/alerts` 计数）；头像区点击展开角色下拉（消费 `available_roles` 的 `name`/`scope`），选中即经 `?role=` 重取切换上下文。
- 各业务视图 `WbPageHead`——`system_date` 经 `useSystemDate()`（`src/api/useSystemDate.ts`，模块级共享单次请求）渲"数据截至"后缀；chrome 级取数，失败静默回退演示基准日 `2026-10-28`，不进页面五态。
- 取回未渲：`user.id`、`user.username`、`user.real_name`、`user.dept_name`（演示期 UI 无落位，登记备查）。

**空态与错误态**

- `data=null` / `code=20001`：头部降级为只读默认身份展示（演示期不跳登录页）。
- `role` 非法 → `code=10001`：resolver 抛错走五态错误路径（演示期可演练非法参数分支）。
- 可返回错误码：`10001`、`20001`。

**mock key**：`auth/profile`（resolver 按 `role` 返回对应角色档案）

### 2.2 `GET /hospital/profile`

- **契约锚点**：§2.2。医院基本配置与院训文化。

**请求参数**：无

**响应字段**（`data`）

| 字段 | 类型 | 单位 | 可为null | 说明 |
| :--- | :--- | :--- | :--- | :--- |
| `name` | string | — | 否 | 医院名（`XX市人民医院`），对齐设计稿品牌位 |
| `english_name` | string | — | 否 | 对外展示名（`PEOPLE'S HOSPITAL`，非逐字翻译） |
| `level` | string | — | 否 | 等评（`三级甲等综合医院`） |
| `motto` | string[] | — | 否 | 院训 4 词（`厚德/精医/仁爱/创新`） |
| `slogans` | string[] | — | 否 | 首页 Hero 标语 2 行 |
| `pillars` | string[] | — | 否 | 至上理念 3 条（对应 Hero 书法柱图片 alt） |

**前端消费位置**

- `src/components/workbench/WorkbenchSidebar.vue`——`name`/`english_name`/`motto`。
- `src/components/workbench/WorkbenchHero.vue`——`slogans`/`pillars`（图片资产 alt）。

**空态与错误态**

- 字段缺失/`data=null`：品牌区回退现有硬编码文案，不留白。
- 可返回错误码：`10001`。

**mock key**：`hospital/profile`

---

## 3. 工作台首页 `/workbench/home/*`

> 契约 §3，对应 `src/views/workbench/HomeView.vue` 的 6 张子卡片。7 个端点**一卡片一端点**，互不依赖、独立加载。

### 3.1 `GET /workbench/home/kpis`

- **契约锚点**：§3.1。首页顶栏 5 大核心 KPI 卡片，当月业务量口径。

**请求参数**：无

**响应字段**（`data`）

| 字段 | 类型 | 单位 | 可为null | 说明 |
| :--- | :--- | :--- | :--- | :--- |
| `period` | string | — | 否 | 口径标识（`本月`），渲染于区块角标 |
| `list` | object[] | — | 否 | KPI 项集（WbStatItem + `key`），5 项 |
| &nbsp;&nbsp;`key` | string | — | 否 | 业务键（`outpatient`/`inpatient`/`surgery`/`revenue`/`staff`），前端按 key 定卡片底色与 ¥ 徽标特例 |
| &nbsp;&nbsp;`label` | string | — | 否 | 指标名 |
| &nbsp;&nbsp;`value` | string | — | 否 | 展示值含千分位（`123,000`），直接渲染 |
| &nbsp;&nbsp;`unit` | string | — | 可缺省/空串 | 量纲（金额卡为 `万元`） |
| &nbsp;&nbsp;`delta` | string | — | 可缺省 | 环比变动串，直渲 |
| &nbsp;&nbsp;`dir` | string | — | 可缺省 | `up`/`down`/`flat` 箭头方向 |
| &nbsp;&nbsp;`icon` | string | — | 可缺省 | Lucide 图标名 |
| &nbsp;&nbsp;`tone` | string | — | 可缺省 | 语义色枚举 |

> `value` 与 §3.2 月度走势 10 月点位严格自洽（123000 / 8120 / 1286 / 14800）。

**前端消费位置**：`src/components/workbench/WorkbenchKpiCards.vue` ← `getHomeKpis()`

**空态与错误态**

- `list=[]`：KPI 网格渲空占位（不渲卡片）。
- `icon`/`tone` 缺省：按 `key` 兜底映射。
- 可返回错误码：`10001` → 卡片区错误态 + 重试。

**mock key**：`workbench/home/kpis`

### 3.2 `GET /workbench/home/trends`

- **契约锚点**：§3.2。医疗业务走势图，4 个 Tab 切换，本期 vs 同期逐月对比。

**请求参数**：无

**响应字段**（`data`）

| 字段 | 类型 | 单位 | 可为null | 说明 |
| :--- | :--- | :--- | :--- | :--- |
| `months` | string[] | — | 否 | 12 个月份标签（`1月`…`12月`），X 轴 |
| `series` | object | — | 否 | 键 = 指标中文名（`门急诊人次`/`住院人次`/`手术台次`/`医疗收入`），键序即 Tab 序 |
| &nbsp;&nbsp;`{键}.unit` | string | — | 否 | 量纲（`人次`/`台`/`万元`），轴名与 tooltip 用 |
| &nbsp;&nbsp;`{键}.current` | number[] | 见 `unit` | 否 | 本期 12 月序列 |
| &nbsp;&nbsp;`{键}.last` | number[] | 见 `unit` | 否 | 去年同期 12 月序列 |

**前端消费位置**：`src/components/workbench/TrendChartCard.vue` ← `getHomeTrend()`

**空态与错误态**

- `series` 缺某指标键或数组为空：该 Tab 画空坐标轴，其余 Tab 正常。
- 可返回错误码：`10001` → 图位错误态 + 重试。

**mock key**：`workbench/home/trends`

### 3.3 `GET /workbench/home/top10`

- **契约锚点**：§3.3。科室业务量 TOP10（当前口径 = 住院人次排行）。

**请求参数**：无

**响应字段**（`data`）

| 字段 | 类型 | 单位 | 可为null | 说明 |
| :--- | :--- | :--- | :--- | :--- |
| `metric_name` | string | — | 否 | 排行口径（`住院人次`），渲于卡标题 |
| `max_val` | number | 人次 | 否 | 条形归一化参照值（榜首外留白） |
| `list` | object[] | — | 否 | TOP10 项集 |
| &nbsp;&nbsp;`rank` | int | — | 否 | 名次 1–10 |
| &nbsp;&nbsp;`name` | string | — | 否 | 科室名 |
| &nbsp;&nbsp;`value` | number | 人次 | 否 | 住院人次；条形宽 `value/max_val*100` |

**前端消费位置**：`src/components/workbench/DepartmentTop10Card.vue` ← `getHomeTop10()`

**空态与错误态**

- `list=[]`：排行区空态。
- 可返回错误码：`10001` → 卡片区错误态 + 重试。

**mock key**：`workbench/home/top10`

### 3.4 `GET /workbench/home/indicators`

- **契约锚点**：§3.4。运营关键效率与质量指标（首页右中卡片）。

**请求参数**：无

**响应字段**（`data`）

| 字段 | 类型 | 单位 | 可为null | 说明 |
| :--- | :--- | :--- | :--- | :--- |
| `list` | object[] | — | 否 | 指标项集（5 项） |
| &nbsp;&nbsp;`code` | string | — | 否 | 指标字典码（`ALOS`/`BED_USE_RATE`/`DRUG_RATIO`/`MATERIAL_RATIO`/`MED_SVC_RATIO`） |
| &nbsp;&nbsp;`name` | string | — | 否 | 指标中文名 |
| &nbsp;&nbsp;`value` | string | 见 `unit` | 否 | 展示值 |
| &nbsp;&nbsp;`unit` | string | — | 可缺省 | `天`/`%` |
| &nbsp;&nbsp;`delta` | string | — | 可缺省 | 变动串直渲 |
| &nbsp;&nbsp;`dir` | string | — | 可缺省 | `up`/`down`/`flat` |
| &nbsp;&nbsp;`icon` | string | — | 可缺省 | Lucide 图标名 |
| &nbsp;&nbsp;`tone` | string | — | 可缺省 | 语义色枚举（替代原十六进制，契约 §3.4 注） |

**前端消费位置**：`src/components/workbench/KeyIndicatorsCard.vue` ← `getHomeIndicators()`

**空态与错误态**

- `list=[]`：指标卡空态。
- 可返回错误码：`10001` → 卡片区错误态 + 重试。

**mock key**：`workbench/home/indicators`

### 3.5 `GET /workbench/home/progress`

- **契约锚点**：§3.5。院级重点工作进度与督办项。

**请求参数**：无

**响应字段**（`data`）

| 字段 | 类型 | 单位 | 可为null | 说明 |
| :--- | :--- | :--- | :--- | :--- |
| `list` | object[] | — | 否 | 重点工作项集（5 项） |
| &nbsp;&nbsp;`id` | int | — | 否 | 事项 ID |
| &nbsp;&nbsp;`name` | string | — | 否 | 事项名 |
| &nbsp;&nbsp;`progress` | int | % | 否 | 进度 0–100，进度条宽 |
| &nbsp;&nbsp;`status` | string | — | 否 | 状态文案（`进行中`/`待启动`） |

**前端消费位置**：`src/components/workbench/WorkProgressCard.vue` ← `getHomeProgress()`

**空态与错误态**

- `list=[]`：进度卡空态。
- 可返回错误码：`10001` → 卡片区错误态 + 重试。

**mock key**：`workbench/home/progress`

### 3.6 `GET /workbench/home/alerts`

- **契约锚点**：§3.6。首页运营风险预警动态。

**请求参数**：无

**响应字段**（`data`）

| 字段 | 类型 | 单位 | 可为null | 说明 |
| :--- | :--- | :--- | :--- | :--- |
| `list` | object[] | — | 否 | 预警项集（5 条） |
| &nbsp;&nbsp;`id` | int | — | 否 | 告警事件 ID |
| &nbsp;&nbsp;`level` | string | — | 否 | 英文枚举 `urgent`/`major`/`minor` → 前端映射 高/中/低 |
| &nbsp;&nbsp;`title` | string | — | 否 | 预警标题 |
| &nbsp;&nbsp;`occurred_at` | string | YYYY-MM-DD | 否 | 发生日期 |
| &nbsp;&nbsp;`rule_code` | string | — | 否 | 触发规则码（`INPT_FEE_SURGE` 等，对齐 schema 种子） |

**前端消费位置**：`src/components/workbench/RiskAlertsCard.vue` ← `getHomeAlerts()`

**空态与错误态**

- `list=[]`：预警卡渲"暂无预警"空态。
- 可返回错误码：`10001` → 卡片区错误态 + 重试。

**mock key**：`workbench/home/alerts`

### 3.7 `GET /workbench/home/notices`

- **契约锚点**：§3.7。行政通知与待办事项列表。

**请求参数**：无

**响应字段**（`data`）

| 字段 | 类型 | 单位 | 可为null | 说明 |
| :--- | :--- | :--- | :--- | :--- |
| `list` | object[] | — | 否 | 通知项集（5 条） |
| &nbsp;&nbsp;`id` | int | — | 否 | 通知 ID |
| &nbsp;&nbsp;`text` | string | — | 否 | 通知标题 |
| &nbsp;&nbsp;`date` | string | YYYY-MM-DD | 否 | 发布日期 |
| &nbsp;&nbsp;`urgent` | bool | — | 否 | `true` 渲急件标识 |

**前端消费位置**：`src/components/workbench/NoticesTodosCard.vue` ← `getHomeNotices()`

**空态与错误态**

- `list=[]`：通知卡空态。
- 可返回错误码：`10001` → 卡片区错误态 + 重试。

**mock key**：`workbench/home/notices`

---

## 4. 综合概览 `GET /workbench/overview`

- **契约锚点**：§4.1。对应 `src/views/workbench/OverviewView.vue`；`range` 切换触发整页重取。

**请求参数**

| 参数名 | 取值 | 默认 | 说明 |
| :--- | :--- | :--- | :--- |
| `range` | `本月`/`本季`/`本年` | `本年` | 时间范围；`本年` 时核心指标 = 1~10 月累计 |

**响应字段**（`data`）

| 字段 | 类型 | 单位 | 可为null | 说明 |
| :--- | :--- | :--- | :--- | :--- |
| `range` | string | — | 否 | 回显当前口径 |
| `stats` | WbStatItem[] | — | 否 | 核心指标条 6 项（`WbStatStrip` 直渲） |
| `scale_revenue_trend` | object | — | 否 | 业务规模×收入双轴图 |
| &nbsp;&nbsp;`months` | string[] | — | 否 | 12 月标签 |
| &nbsp;&nbsp;`outpatient` | number[] | 人次 | 否 | 门急诊逐月（柱） |
| &nbsp;&nbsp;`revenue` | number[] | 万元 | 否 | 医疗收入逐月（线） |
| &nbsp;&nbsp;`units` | object | — | 否 | `{ outpatient, revenue }` 轴名 |
| `income_structure` | object | — | 否 | 收入结构环图 |
| &nbsp;&nbsp;`unit` | string | — | 否 | 恒 `%` |
| &nbsp;&nbsp;`list` | object[] | — | 否 | `{ name, value }` 构成项（住院/门诊/其他） |
| `dept_share_top8` | object | — | 否 | 科室服务量 TOP8 条形榜 |
| &nbsp;&nbsp;`metric` | string | — | 否 | 度量说明（`住院收入（万元·本月）`），渲于副标 |
| &nbsp;&nbsp;`unit` | string | — | 否 | `万元` |
| &nbsp;&nbsp;`list` | object[] | — | 否 | `{ name, value, bar_pct }`，`bar_pct` 条形宽 |
| `live_inpatient` | object[] | — | 否 | 实时在院动态 6 项 |
| &nbsp;&nbsp;`label` | string | — | 否 | 项名 |
| &nbsp;&nbsp;`value` | string | — | 否 | 展示值 |
| &nbsp;&nbsp;`tone` | string | — | 否 | 语义色（圆点色映射） |

> `range=本年` 时 `stats` 累计值与 `scale_revenue_trend` 前 10 个月求和严格相等（契约 §4.1 注1）。

> **实现注记**：`scale_revenue_trend` 副标轴名消费 `units.revenue`；`income_structure` 环图 tooltip 与图例后缀均消费 `unit`；收入结构面板"…累计"口径文案绑 `data.range`（已取数据的真实口径，stale 时显示旧档而非控件态）；dept_share_top8 的 metric 文案与值随 range 等比缩放、bar_pct 重归一。

**前端消费位置**：`src/views/workbench/OverviewView.vue` ← `getOverview(range)`；`watch(range)` 重取。

**空态与错误态**

- `stats=[]`：指标条空态；`scale_revenue_trend`/子结构为 null：对应图画空坐标；`dept_share_top8.list=[]`/`live_inpatient=[]`：区块空态。
- `range` 非法 → `10001` → 页级错误态 + 重试。

**mock key**：`workbench/overview`

---

## 5. 医疗业务 `GET /workbench/medical`

- **契约锚点**：§5.1。对应 `src/views/workbench/MedicalView.vue`；`tab` × `range` 两级维度，任一变化整页重取。

**请求参数**

| 参数名 | 取值 | 默认 | 说明 |
| :--- | :--- | :--- | :--- |
| `tab` | `门急诊`/`住院`/`手术` | `门急诊` | 业务维度 |
| `range` | `本月`/`本季`/`本年` | `本年` | 时间范围 |

**响应字段**（`data`，三 tab 同构）

| 字段 | 类型 | 单位 | 可为null | 说明 |
| :--- | :--- | :--- | :--- | :--- |
| `tab` | string | — | 否 | 回显维度 |
| `range` | string | — | 否 | 回显口径 |
| `stats` | WbStatItem[] | — | 否 | 指标条 6 项；**恒为当月/当前口径，不随 `range` 累计**（契约 §5.1 注） |
| `trend` | object | — | 否 | 主趋势图 |
| &nbsp;&nbsp;`title` | string | — | 否 | 图题 |
| &nbsp;&nbsp;`name` | string | — | 否 | 序列名（随 tab 变，见差异表） |
| &nbsp;&nbsp;`unit` | string | — | 否 | 量纲 |
| &nbsp;&nbsp;`months` | string[] | — | 否 | 12 月标签 |
| &nbsp;&nbsp;`values` | number[] | 见 `unit` | 否 | 逐月序列 |
| `distribution` | object | — | 否 | 构成/分布图 |
| &nbsp;&nbsp;`title` | string | — | 否 | 图题 |
| &nbsp;&nbsp;`sub` | string | — | 否 | 副标 |
| &nbsp;&nbsp;`type` | string | — | 否 | `bar`/`pie`，决定 ECharts 形态 |
| &nbsp;&nbsp;`unit` | string | — | 否 | 量纲 |
| &nbsp;&nbsp;`categories` | string[] | — | 否 | 类目轴/图例项 |
| &nbsp;&nbsp;`values` | number[] | 见 `unit` | 否 | 数值序列（与 categories 等长） |
| `table` | object | — | 否 | 科室明细表（`WbTable` 直渲） |
| &nbsp;&nbsp;`columns` | object[] | — | 否 | 列元数据 `{ key, title, width?, align?, num? }`，服务端下发 |
| &nbsp;&nbsp;`rows` | object[] | — | 否 | 行对象，键 = `columns[].key` |

**跨 tab 差异**（结构不变，语义随 `tab` 变）：

| `tab` | `trend.name`/`unit` | `distribution` | `table` 差异 |
| :--- | :--- | :--- | :--- |
| `门急诊` | 门急诊人次 / `人次` | 就诊高峰时段分布，`type=bar`，`unit=人次` | `cnt`=诊疗人次，`avg`=次均费用（**元**） |
| `住院` | 出院人数 / `人次` | 病区床位占用，`type=bar`，`unit=%` | `cnt`=出院人次，`avg`=次均费用（**元**） |
| `手术` | 手术台次 / `台` | 手术分级构成，`type=pie`，`unit=%` | `cnt`=手术台次，`avg`=平均手术时长（**分钟**） |

> 列键集合固定 `dept/cnt/yoy/share/avg/drug`；`avg` 跨 tab 同键异义，前端按列 `title`/单位渲染（契约 §5.1 跨 Tab 注）。

**前端消费位置**：`src/views/workbench/MedicalView.vue` ← `getMedical(tab, range)`

**空态与错误态**

- `stats=[]`/`table.rows=[]`/`distribution.values=[]`：对应区块空态（表格空表、分布图空坐标）。
- `tab`/`range` 非法 → `10001` → 页级错误态 + 重试。

**mock key**：`workbench/medical`

---

## 6. 运营管理 `GET /workbench/operations`

- **契约锚点**：§6.1。对应 `src/views/workbench/OperationsView.vue`。

**请求参数**

| 参数名 | 取值 | 默认 | 说明 |
| :--- | :--- | :--- | :--- |
| `range` | `本月`/`本季`/`本年` | 本年（前端缺省） | 契约未显式标注默认；`getOperations()` 缺省 `本年` |

**响应字段**（`data`）

| 字段 | 类型 | 单位 | 可为null | 说明 |
| :--- | :--- | :--- | :--- | :--- |
| `stats` | WbStatItem[] | — | 否 | 指标条 6 项（收入万元、次均元口径混排，按 `unit` 渲染） |
| `revenue_trend` | object | — | 否 | 收入/成本/结余三序列趋势 |
| &nbsp;&nbsp;`months` | string[] | — | 否 | 12 月标签 |
| &nbsp;&nbsp;`income` | number[] | 万元 | 否 | 医疗收入逐月 |
| &nbsp;&nbsp;`cost` | number[] | 万元 | 否 | 成本逐月 |
| &nbsp;&nbsp;`balance` | number[] | 万元 | 否 | 结余逐月；结余率 = `balance/income*100%` 前端推导（契约 §6.1 注1） |
| `cost_controls` | object[] | — | 否 | 精细化控费指标 6 项（进度条+红线刻度） |
| &nbsp;&nbsp;`name` | string | — | 否 | 指标名 |
| &nbsp;&nbsp;`value` | string | — | 否 | 当前值（含单位后缀，如 `28.4%`/`12.6元`） |
| &nbsp;&nbsp;`target` | string | — | 否 | 目标文案（`≤30%` 等） |
| &nbsp;&nbsp;`status` | string | — | 否 | `达标`/`超标`，超标项警示色 |
| &nbsp;&nbsp;`pct` | number | % | 否 | 进度条填充 0–100 |
| &nbsp;&nbsp;`mark_pct` | number | % | 否 | 红线阈值在 0–100 刻度上的位置（契约 §6.1 注2） |
| `dept_table` | object | — | 否 | 科室收入成本表 |
| &nbsp;&nbsp;`columns` | object[] | — | 否 | 键集 `dept/income/cost/balance/margin/drug_ratio/mat_ratio` |
| &nbsp;&nbsp;`rows` | object[] | — | 否 | 行对象；金额列为万元字符串 |

> **实现注记**：`revenue_trend` 渲为 `income` 柱 + `cost` 虚线（万元，同轴）+ `balance/income` 推导结余率折线（%，右轴）；科室表副标"{range} · 按医疗收入排序"随 `range` 派生。

**前端消费位置**：`src/views/workbench/OperationsView.vue` ← `getOperations(range)`

**空态与错误态**

- `cost_controls=[]`：控费进度条区空态；`dept_table.rows=[]`：空表。
- `range` 非法 → `10001` → 页级错误态 + 重试。

**mock key**：`workbench/operations`

---

## 7. 人力资源 `GET /workbench/hr`

- **契约锚点**：§7.1。对应 `src/views/workbench/HrView.vue`。

**请求参数**

| 参数名 | 取值 | 默认 | 说明 |
| :--- | :--- | :--- | :--- |
| `range` | `本月`/`本季`/`本年` | 本年（前端缺省） | 契约未显式标注默认；`getHr()` 缺省 `本年` |

**响应字段**（`data`）

| 字段 | 类型 | 单位 | 可为null | 说明 |
| :--- | :--- | :--- | :--- | :--- |
| `stats` | WbStatItem[] | — | 否 | 指标条 6 项（含 `医护比` 用 `note` 承载目标文案） |
| `structure` | object | — | 否 | 人员构成环图 |
| &nbsp;&nbsp;`unit` | string | — | 否 | 恒 `%` |
| &nbsp;&nbsp;`list` | object[] | — | 否 | `{ name, value, count }`：`value`=占比 %，`count`=人数（图例/悬浮） |
| `titles` | object | — | 否 | 岗位 × 职称矩阵堆叠图（契约 §7.1 注1） |
| &nbsp;&nbsp;`unit` | string | — | 否 | `人` |
| &nbsp;&nbsp;`categories` | string[] | — | 否 | 岗位轴（医师/护理/医技/行政后勤） |
| &nbsp;&nbsp;`series` | object[] | — | 否 | `{ name, values }`：职称序列（正高/副高/中级/初级及以下），`values` 与 categories 等长 |
| `dept_staffing` | object | — | 否 | 科室定岗编制表（8 行） |
| &nbsp;&nbsp;`columns` | object[] | — | 否 | 键集 `dept/quota/actual/doctor/nurse/ratio/gap/status` |
| &nbsp;&nbsp;`rows` | object[] | — | 否 | `status` ∈ `充足`/`紧张`/`紧缺`；`ratio` 可现 `"—"`（麻醉科），直渲 |

> **实现注记**：`gap` 列警示色按同行 `status` 枚举判定（非 `充足` 即告警），不另设数值阈值；`structure` 环图 tooltip/图例后缀消费 `unit`；`titles` 面板副标直渲 `categories`。

**前端消费位置**：`src/views/workbench/HrView.vue` ← `getHr(range)`

**空态与错误态**

- `structure.list=[]`：环图空态；`titles.series=[]`：矩阵图空坐标；`dept_staffing.rows=[]`：空表。
- `range` 非法 → `10001` → 页级错误态 + 重试。

**mock key**：`workbench/hr`

---

## 8. 科研教学 `GET /workbench/research`

- **契约锚点**：§8.1。对应 `src/views/workbench/ResearchView.vue`。

**请求参数**：无

**响应字段**（`data`）

| 字段 | 类型 | 单位 | 可为null | 说明 |
| :--- | :--- | :--- | :--- | :--- |
| `stats` | WbStatItem[] | — | 否 | 指标条 6 项；`delta` 含 `+12项`/`+14篇` 等数量型变动，直渲 |
| `project_trend` | object | — | 否 | 课题经费年度趋势（柱+线） |
| &nbsp;&nbsp;`unit` | string | — | 否 | `万元`（funds 序列量纲；national/provincial 单位为项） |
| &nbsp;&nbsp;`years` | string[] | — | 否 | 年度轴 `2021`–`2025` |
| &nbsp;&nbsp;`national` | number[] | 项 | 否 | 国家级课题逐年 |
| &nbsp;&nbsp;`provincial` | number[] | 项 | 否 | 省部级课题逐年 |
| &nbsp;&nbsp;`funds` | number[] | 万元 | 否 | 科研经费逐年 |
| `paper_distribution` | object | — | 否 | 论文分区构成 |
| &nbsp;&nbsp;`unit` | string | — | 否 | `篇` |
| &nbsp;&nbsp;`categories` | string[] | — | 否 | 分区类目（一区 Top…中文核心） |
| &nbsp;&nbsp;`values` | number[] | 篇 | 否 | 各类数量 |
| `disciplines` | object | — | 否 | 重点学科表（学科级口径，非末级科室，契约 §8.1 注） |
| &nbsp;&nbsp;`columns` | object[] | — | 否 | 键集 `name/level/leader/projects/funds/papers/transfer` |
| &nbsp;&nbsp;`rows` | object[] | — | 否 | `funds`/`transfer` 为万元字符串 |

> **实现注记**：`project_trend` 渲为 `national`/`provincial` 堆叠双柱（项，左轴）+ `funds` 经费折线（右轴，副标单位消费 `unit`）；`paper_distribution.categories` 直渲面板副标；`disciplines` 副标为固定分层文案（`level` 枚举按行渲染于表格）。柱侧计数单位`项`无契约字段（视图内展示字面量），待契约补 `count_unit`。

**前端消费位置**：`src/views/workbench/ResearchView.vue` ← `getResearch()`

**空态与错误态**

- 各图序列为空：空坐标；`disciplines.rows=[]`：空表。
- 可返回错误码：`10001` → 页级错误态 + 重试。

**mock key**：`workbench/research`

---

## 9. 患者服务 `GET /workbench/patient`

- **契约锚点**：§9.1。对应 `src/views/workbench/PatientView.vue`。

**请求参数**：无

**响应字段**（`data`）

| 字段 | 类型 | 单位 | 可为null | 说明 |
| :--- | :--- | :--- | :--- | :--- |
| `stats` | WbStatItem[] | — | 否 | 指标条 6 项；`delta` 含 `-6件`/`+12件`/`-3分钟` 等，直渲 |
| `satisfaction_trend` | object | — | 否 | 满意度双序列趋势（近 6 月） |
| &nbsp;&nbsp;`unit` | string | — | 否 | 恒 `%` |
| &nbsp;&nbsp;`months` | string[] | — | 否 | `5月`–`10月` |
| &nbsp;&nbsp;`outpatient` | number[] | % | 否 | 门诊满意度逐月 |
| &nbsp;&nbsp;`inpatient` | number[] | % | 否 | 住院满意度逐月 |
| `channel_distribution` | object | — | 否 | 预约渠道构成 |
| &nbsp;&nbsp;`unit` | string | — | 否 | 恒 `%` |
| &nbsp;&nbsp;`list` | object[] | — | 否 | `{ name, value }` 5 类渠道 |
| `complaints_praises` | object | — | 否 | 投诉表扬流水表 |
| &nbsp;&nbsp;`columns` | object[] | — | 否 | 键集 `date/type/dept/channel/content/status/score` |
| &nbsp;&nbsp;`rows` | object[] | — | 否 | `status` 五态枚举 `待核实`/`处理中`/`已整改`/`已办结`/`已归档`（契约 §9.1 注2）；`date` 为 `YYYY-MM-DD` |

> **实现注记**：`satisfaction_trend` 面板副标单位、`channel_distribution` 环图 tooltip 与图例后缀均消费各自 `unit` 字段；渠道面板副标静态"各渠道占比"（该分段器不触发取数，契约无 `range` 参数——文案不随死控件联动，防口径撒谎）；流水表副标仅渲行数，不再声明时间窗（`近 30 日` 为契约外口径，已删）。

**前端消费位置**：`src/views/workbench/PatientView.vue` ← `getPatient()`

**空态与错误态**

- `complaints_praises.rows=[]`：空表（"本月无投诉表扬流水"口径仍 code=0）。
- 图序列为空：空坐标。
- 可返回错误码：`10001` → 页级错误态 + 重试。

**mock key**：`workbench/patient`

---

## 10. 质量与安全 `GET /workbench/quality`

- **契约锚点**：§10.1。对应 `src/views/workbench/QualityView.vue`。

**请求参数**：无

**响应字段**（`data`）

| 字段 | 类型 | 单位 | 可为null | 说明 |
| :--- | :--- | :--- | :--- | :--- |
| `stats` | WbStatItem[] | — | 否 | 指标条 6 项（`抗菌药物使用强度` unit=`DDDs`；`不良事件上报` 用 `note` 承载百床口径） |
| `infection_trend` | object | — | 否 | 院感发生率趋势 + 控制线 |
| &nbsp;&nbsp;`unit` | string | — | 否 | 恒 `%` |
| &nbsp;&nbsp;`target` | number | % | 否 | 控制线值 `2.0`，ECharts markLine |
| &nbsp;&nbsp;`months` | string[] | — | 否 | `5月`–`10月` |
| &nbsp;&nbsp;`rates` | number[] | % | 否 | 院感率逐月（越线→受控剧情，契约 §10.1 注1） |
| `adverse_events` | object | — | 否 | 不良事件分类构成 |
| &nbsp;&nbsp;`unit` | string | — | 否 | `起` |
| &nbsp;&nbsp;`categories` | string[] | — | 否 | 7 类事件（跌倒坠床…其他） |
| &nbsp;&nbsp;`values` | number[] | 起 | 否 | 各类数量 |
| `rules_compliance` | object | — | 否 | 核心制度执行合规表（8 项） |
| &nbsp;&nbsp;`columns` | object[] | — | 否 | 键集 `name/sample/pass/rate/issues` |
| &nbsp;&nbsp;`rows` | object[] | — | 否 | `rate = pass/sample*100%` 严格自洽（契约 §10.1 注3），`rate` 带 `%` 后缀直渲 |

> **实现注记**：院感面板副标与 markLine 文案均消费 `infection_trend.target`+`unit`；不良事件面板"累计上报 N {unit}"中单位消费 `adverse_events.unit`、口径词不随死控件分段器联动（契约无 `range` 参数，静态如实描述）；核心制度面板副标静态"抽查结果"。

**前端消费位置**：`src/views/workbench/QualityView.vue` ← `getQuality()`

**空态与错误态**

- `infection_trend.rates=[]`：趋势空坐标（target 线仍可画）；`rules_compliance.rows=[]`：空表。
- 可返回错误码：`10001` → 页级错误态 + 重试。

**mock key**：`workbench/quality`

---

## 11. 资产与后勤 `GET /workbench/assets`

- **契约锚点**：§11.1。对应 `src/views/workbench/AssetsView.vue`。

**请求参数**：无

**响应字段**（`data`）

| 字段 | 类型 | 单位 | 可为null | 说明 |
| :--- | :--- | :--- | :--- | :--- |
| `stats` | WbStatItem[] | — | 否 | 指标条 6 项（含 `亿元`/`台`/`单` 等单位混排，按 `unit` 渲染） |
| `energy_trend` | object | — | 否 | 能耗费用趋势（近 6 月，分项与总计自洽） |
| &nbsp;&nbsp;`unit` | string | — | 否 | `万元` |
| &nbsp;&nbsp;`months` | string[] | — | 否 | `5月`–`10月` |
| &nbsp;&nbsp;`total` | number[] | 万元 | 否 | 总能耗逐月 |
| &nbsp;&nbsp;`electricity` | number[] | 万元 | 否 | 电逐月 |
| &nbsp;&nbsp;`water` | number[] | 万元 | 否 | 水逐月 |
| &nbsp;&nbsp;`gas` | number[] | 万元 | 否 | 气逐月 |
| `stock_alerts` | object[] | — | 否 | 库存预警 6 项 |
| &nbsp;&nbsp;`name` | string | — | 否 | 物资名 |
| &nbsp;&nbsp;`days` | number | 天 | 否 | 库存可用天数（契约 §11.1 注2） |
| &nbsp;&nbsp;`level` | string | — | 否 | `urgent` → `紧急补货`（红），`major`/`minor` → `关注`（琥珀） |
| `large_equipments` | object | — | 否 | 大型设备效益表（7 台） |
| &nbsp;&nbsp;`columns` | object[] | — | 否 | 键集 `name/dept/count/open_rate/monthly/income/roi` |
| &nbsp;&nbsp;`rows` | object[] | — | 否 | `open_rate` 纯浮点 %（`96.8`），`income` 万元字符串，`roi` ∈ `良好`/`一般`/`偏低` |

> **实现注记**：`energy_trend` 渲为 `total` 面积主线 + `electricity`/`water`/`gas` 细线分量（同轴，副标单位消费 `unit`）；`large_equipments` 副标"单价 ≥100 万元设备"对齐 §11.1 口径；`open_rate` 警示色按同行 `roi=偏低` 判定，不另设数值阈值。

**前端消费位置**：`src/views/workbench/AssetsView.vue` ← `getAssets()`

**空态与错误态**

- `stock_alerts=[]`：库存预警区渲"无预警"空态；`large_equipments.rows=[]`：空表。
- 可返回错误码：`10001` → 页级错误态 + 重试。

**mock key**：`workbench/assets`

---

## 12. 对比分析 `GET /workbench/compare`

- **契约锚点**：§12.1。对应 `src/views/workbench/CompareView.vue`；`dim` × `range` 两级维度。

**请求参数**

| 参数名 | 取值 | 默认 | 说明 |
| :--- | :--- | :--- | :--- |
| `dim` | `scale`/`benefit`/`efficiency`/`quality` | `scale` | 对比维度（英文枚举） |
| `range` | `本月`/`本季`/`本年` | `本月` | 时间范围 |

**`dim` → UI 映射**（契约原表，前端 WbSeg 标签据此）：

| `dim` | UI 名 | 默认核心度量 | 单位 |
| :--- | :--- | :--- | :--- |
| `scale` | 业务量 | 业务量当量 | 当量/人次 |
| `benefit` | 收入 | 医疗收入 | 万元 |
| `efficiency` | 效率 | 床位周转次数 | 次 |
| `quality` | 质量 | 质量综合评分 | 分 |

**响应字段**（`data`）

| 字段 | 类型 | 单位 | 可为null | 说明 |
| :--- | :--- | :--- | :--- | :--- |
| `dimension` | string | — | 否 | 回显维度 |
| `range` | string | — | 否 | 回显口径 |
| `radar` | object | — | 否 | 全院 6 维能力雷达（0–100 分） |
| &nbsp;&nbsp;`indicators` | object[] | — | 否 | `{ name, max }` 6 个维度轴，`max` 恒 100 |
| &nbsp;&nbsp;`series` | object[] | — | 否 | `{ name, value }` 2 序列：`本院` / `区域同级均值`，`value` 与 indicators 等长 |
| `benchmarks` | object[] | — | 否 | 对标明细 6 项 |
| &nbsp;&nbsp;`name` | string | — | 否 | 指标名（含量纲说明） |
| &nbsp;&nbsp;`ours` | string | — | 否 | 本院值 |
| &nbsp;&nbsp;`region` | string | — | 否 | 区域同级均值 |
| &nbsp;&nbsp;`bench` | string | — | 否 | 标杆值 |
| &nbsp;&nbsp;`gap` | string | — | 否 | `= 本院 − 区域均值`（契约 §12.1 注2），带 `+/-` 直渲 |
| `table` | object | — | 否 | 科室对比榜 |
| &nbsp;&nbsp;`columns` | object[] | — | 否 | 键集 `rank/dept/metric/yoy/outp/inpt/days/sat`；`metric` 列标题随 `dim` 变 |
| &nbsp;&nbsp;`rows` | object[] | — | 否 | 行内另含 `bar_pct`（不在 columns 中），条形宽用；`metric` = `outp + inpt×10` 服务端实算（契约 §12.1 注4） |

> **实现注记**：表副标"当前维度：{dim} · 按{range}排序"随视图 `dim`/`range` 状态派生。

**前端消费位置**：`src/views/workbench/CompareView.vue` ← `getCompare(dim, range)`

**空态与错误态**

- `radar.series=[]`/`table.rows=[]`：雷达空坐标/空表；`benchmarks=[]`：对标区空态。
- `dim`/`range` 非法 → `10001` → 页级错误态 + 重试。

**mock key**：`workbench/compare`

---

## 13. 专题分析 `GET /workbench/topics`

- **契约锚点**：§13.1。对应 `src/views/workbench/TopicsView.vue`；`topic` × `range` 两级维度。

**请求参数**

| 参数名 | 取值 | 默认 | 说明 |
| :--- | :--- | :--- | :--- |
| `topic` | `drg`/`insurance`/`exam`/`outp_fund` | 无（必传） | 专题键；UI 名依次为 DRG付费 / 医保基金 / 三级国考 / 门诊统筹 |
| `range` | `本月`/`本季`/`本年` | `本年` | 时间范围 |

**响应字段**（`data`，四专题同构）

| 字段 | 类型 | 单位 | 可为null | 说明 |
| :--- | :--- | :--- | :--- | :--- |
| `topic` | string | — | 否 | 回显专题 |
| `range` | string | — | 否 | 回显口径 |
| `stats` | WbStatItem[] | — | 否 | 指标条 6 项（随专题换指标集） |
| `chart` | object | — | 否 | 主图（随专题换形态） |
| &nbsp;&nbsp;`title` | string | — | 否 | 图题 |
| &nbsp;&nbsp;`sub` | string | — | 否 | 副标 |
| &nbsp;&nbsp;`type` | string | — | 否 | `bar`/`line` |
| &nbsp;&nbsp;`unit` | string | — | 否 | 量纲 |
| &nbsp;&nbsp;`months` | string[] | — | 可缺省 | 月份轴（line 形态用） |
| &nbsp;&nbsp;`categories` | string[] | — | 可缺省 | 类目轴（bar 形态用） |
| &nbsp;&nbsp;`values` | number[] | 见 `unit` | 否 | 数值序列 |
| `table` | object | — | 否 | 专题明细表 |
| &nbsp;&nbsp;`title` | string | — | 否 | 表题 |
| &nbsp;&nbsp;`sub` | string | — | 否 | 表副标 |
| &nbsp;&nbsp;`columns` | object[] | — | 否 | 列元数据（键集随专题，见差异表） |
| &nbsp;&nbsp;`rows` | object[] | — | 否 | 行对象 |

**跨 topic 差异**：

| `topic` | `chart` | `table.columns` 键集 |
| :--- | :--- | :--- |
| `drg` | `type=bar`，`unit=例`，`categories`=RW 分段 `<0.5/0.5-1/1-2/2-5/5-10/≥10` | `dept/cmi/cases/cost_idx/time_idx/rw2/profit` |
| `insurance` | `type=line`，`unit=万元`，`months`=近 6 月 | `type/cases/fund/self/ratio/status` |
| `exam` | `type=line`，`unit=%`，`months`=近 6 月 | `name/full/score/trend/owner` |
| `outp_fund` | `type=line`，`unit=万元`，`months`=近 6 月 | `dept/cases/fund/avg/chronic` |

> `drg` 表 `profit` 为 DRG 结余（万元，带 `+/-`）；`stats` 中 `RW≥2 占比` 与 chart 分段合计自洽（契约 §13.1 注1）。

**前端消费位置**：`src/views/workbench/TopicsView.vue` ← `getTopics(topic, range)`

**空态与错误态**

- `chart.values=[]`：主图空坐标；`table.rows=[]`：空表。
- `topic`/`range` 非法 → `10001` → 页级错误态 + 重试。

**mock key**：`workbench/topics`

---

## 14. 系统设置 `GET /workbench/settings/config`

- **契约锚点**：§13.2。对应 `src/views/workbench/SettingsView.vue`；单端点供给设置页全部四个区块。

**请求参数**：无

**响应字段**（`data`）

| 字段 | 类型 | 单位 | 可为null | 说明 |
| :--- | :--- | :--- | :--- | :--- |
| `data_sources` | object[] | — | 否 | 数据源连接状态 6 项 |
| &nbsp;&nbsp;`name` | string | — | 否 | 系统名（HIS/EMR/LIS/HRP/医保…） |
| &nbsp;&nbsp;`type` | string | — | 否 | 类型与时效（`业务库 · 准实时` 等） |
| &nbsp;&nbsp;`status` | string | — | 否 | `已连接`/`异常`，异常项警示色 |
| &nbsp;&nbsp;`sync` | string | YYYY-MM-DD HH:mm | 否 | 最近同步时间 |
| `thresholds` | object[] | — | 否 | 预警阈值规则 7 项 |
| &nbsp;&nbsp;`name` | string | — | 否 | 指标名 |
| &nbsp;&nbsp;`rule` | string | — | 否 | 规则表达式文案（`连续 3 日 > 95%`） |
| &nbsp;&nbsp;`level` | string | — | 否 | `urgent`/`major`/`minor` |
| &nbsp;&nbsp;`enabled` | bool | — | 否 | 开关态（UI 可本地点击翻转；演示期无写接口，不持久化） |
| `users` | object[] | — | 否 | 权限用户 6 项 |
| &nbsp;&nbsp;`name` | string | — | 否 | 账号/角色名 |
| &nbsp;&nbsp;`role` | string | — | 否 | 角色文案（`院领导`/`部门负责人`/`科室主任` 等） |
| &nbsp;&nbsp;`scope` | string | — | 否 | 数据范围 |
| &nbsp;&nbsp;`login` | string | YYYY-MM-DD HH:mm | 否 | 最近登录 |
| &nbsp;&nbsp;`status` | string | — | 否 | `启用`/`停用` |
| `preferences` | object | — | 否 | 系统偏好 |
| &nbsp;&nbsp;`default_range` | string | — | 否 | 默认时间口径（`本月`/`本季`/`本年`） |
| &nbsp;&nbsp;`refresh_interval` | string | — | 否 | 刷新间隔文案（`5 分钟`） |
| &nbsp;&nbsp;`alert_sound` | bool | — | 否 | 告警音开关 |
| &nbsp;&nbsp;`unit_abbreviation` | bool | — | 否 | 金额缩写显示开关 |
| &nbsp;&nbsp;`privacy_mask` | bool | — | 否 | 隐私脱敏开关 |

**前端消费位置**：`src/views/workbench/SettingsView.vue` ← `getSettings()`

**空态与错误态**

- 任一列表为空：对应区块空态；`preferences` 缺失：偏好开关区按本地默认值渲染（本地默认与 mock 一致：`alert_sound`/`unit_abbreviation`/`privacy_mask`=true，`default_range`=`本月`）。偏好/阈值开关均可本地翻转，无写接口不落库。
- 可返回错误码：`10001` → 页级错误态 + 重试。

**mock key**：`workbench/settings/config`

---

## 15. 科技大屏快照 `GET /screen/snapshot`

- **契约锚点**：§14.1。大屏一站式加载快照，单端点供给整屏。
- **当前状态**：**已实施**（e6aeb52）——路由 `/screen` 已注册（`router/index.ts`），视图为 `src/views/screen/ScreenView.vue` + `src/components/screen/Scr*` 组件族 + `src/layouts/ScreenLayout.vue`；视觉基准 `archive/smart-hospital-cockpit/`，画布 1920×1080。
- **实现注记**：
  - 时钟：`ScrHeader` 以 `server_time` 为锚 + `setInterval` 本地走秒（卸载清理）；`new Date()`/`Date.now()` 仅用于走秒与 ISO 解析，为本节**白名单用法**（机械扫描豁免登记）。
  - 断线重试：顶部 error-bar 红条 + **手动**「重新连接」按钮（`ScreenView` 自管理三态，未复用 `useAsyncData`——大屏按本节豁免登记；`error-codes.md §4` 的自动重连倒计时为远期规格，当前实现以手动重试为准）。
  - 院名：`ScrHeader` 消费 `hospital/profile.name` + `english_name`（经 `getHospitalProfile()`，失败分别回退 `XX市人民医院` / `HOSPITAL EXECUTIVE COMMAND CENTER` 品牌兜底文案）。
  - 错误态：`ScreenView` 自管理三态（`useAsyncData` 豁免），错误经 `toApiError` 归一为 `ApiError{code,message,trace_id}` 并在错误条展示 code/trace_id。

**请求参数**：无

**响应字段**（`data`）

| 字段 | 类型 | 单位 | 可为null | 说明 |
| :--- | :--- | :--- | :--- | :--- |
| `server_time` | string | ISO 8601 | 否 | 屏显时钟源，恒 `2026-10-28T08:30:00+08:00` |
| `status` | object | — | 否 | 整屏运行态势 |
| &nbsp;&nbsp;`level` | string | — | 否 | 态势级枚举 `normal`/`busy`/`alert`（契约 §14.1 注9） |
| &nbsp;&nbsp;`text` | string | — | 否 | 态势文案（`运行平稳`） |
| &nbsp;&nbsp;`desc` | string | — | 否 | 态势描述 |
| &nbsp;&nbsp;`alert_open` | object | — | 否 | 未闭环告警计数 `{ urgent, major, minor }` |
| `kpis` | object[] | — | 否 | 屏顶 KPI 4 项 |
| &nbsp;&nbsp;`code` | string | — | 否 | 指标码（`OP_DAILY_VISITS`/`IP_IN_HOSP`/`BED_USE_RATE`/`SURG_DAILY_CNT`） |
| &nbsp;&nbsp;`name` | string | — | 否 | 指标名 |
| &nbsp;&nbsp;`value` | number | 见 `unit` | 否 | 当前值（日口径） |
| &nbsp;&nbsp;`unit` | string | — | 否 | `人`/`台`/`%` |
| &nbsp;&nbsp;`prev_value` | number | 见 `unit` | 否 | 前一日值 |
| &nbsp;&nbsp;`delta_pct` | number | % | 否 | 变动百分点 |
| &nbsp;&nbsp;`direction` | int | — | 否 | `1`/`-1`/`0` 涨跌方向 |
| &nbsp;&nbsp;`spark` | number[] | 见 `unit` | 否 | 近 7 日迷你序列（末点 = `value`） |
| &nbsp;&nbsp;`status` | string | — | 否 | `normal`/`warn` 卡片态 |
| `drg_quadrant` | object | — | 否 | DRG 盈亏 × CMI 四象限散点 |
| &nbsp;&nbsp;`period` | string | — | 否 | 统计窗（`d30`） |
| &nbsp;&nbsp;`period_label` | string | — | 可 | `period` 可读文案（如 `近30日`，§14.1 注9）；`ScrDrgQuadrant` 副标消费，缺省回退 `dNN`→`近N日` 推导 |
| &nbsp;&nbsp;`axis` | object | — | 否 | `{ x, y }` 轴名（`DRG盈亏(万元)`/`CMI`） |
| &nbsp;&nbsp;`split` | object | — | 否 | `{ x, y }` 象限分割线（`x=0, y=1.0`） |
| &nbsp;&nbsp;`points` | object[] | — | 否 | `{ dept_id, name, category, cmi, profit(万元), case_cnt, quadrant }` |
| `buildings` | object[] | — | 否 | 院区楼宇态势 4 栋 |
| &nbsp;&nbsp;`code` | string | — | 否 | 楼宇码（`mz`/`wk`/`jz`/`yj`） |
| &nbsp;&nbsp;`name` | string | — | 否 | 楼宇名 |
| &nbsp;&nbsp;`status` | string | — | 否 | `normal`/`busy`/`alert` |
| &nbsp;&nbsp;`badge` | string | — | 否 | 徽标文案 |
| &nbsp;&nbsp;`badge_level` | string | — | 否 | `info`/`warn`/`alert`/`ok` |
| &nbsp;&nbsp;`anchor` | object | — | 否 | `{ x, y }` 锚点坐标——**渲染后图像矩形内 %**（x/y ∈ 0–100，相对底图可见区域，非容器盒；§14.1 注7），`ScrCampusMap` pin 直用 |
| &nbsp;&nbsp;`metrics` | object | — | 否 | 楼宇级指标包，键随楼种（键集见本节末表） |
| &nbsp;&nbsp;`primary_metric` | object | — | 可 | `{ key, label, unit, max }` 主指标展示元数据（§14.1 注8），`ScrBuildingBars` 消费；缺席时该行降级为名称+badge，前端不自造量程 |
| `dept_ranking` | object[] | — | 否 | 科室效能榜 |
| &nbsp;&nbsp;`rank` | int | — | 否 | 名次 |
| &nbsp;&nbsp;`dept_id` | int | — | 否 | 科室 ID |
| &nbsp;&nbsp;`name` | string | — | 否 | 科室名 |
| &nbsp;&nbsp;`category` | string | — | 否 | `surg`/`med` |
| &nbsp;&nbsp;`cmi` | number | — | 否 | CMI |
| &nbsp;&nbsp;`surg_cnt` | int | 台 | 否 | 手术量 |
| &nbsp;&nbsp;`alos` | number | 天 | 否 | 平均住院日 |
| &nbsp;&nbsp;`profit` | number | 万元 | 否 | DRG 结余 |
| &nbsp;&nbsp;`eff_score` | number | 分 | 否 | 效能分（服务端按分布实算，契约 §14.1 注5） |
| `alerts` | object | — | 否 | 告警跑马灯 |
| &nbsp;&nbsp;`total_open` | int | — | 否 | 未闭环总数（与 `alert_open` 合计一致）；`ScrAlertFeed` 面板头 `head-extra` 徽标 `未闭环 N` 消费 |
| &nbsp;&nbsp;`list` | object[] | — | 否 | `{ id, level, title, dept, occurred_at(ISO) }` |
| `trends` | object | — | 否 | 屏底 7 日趋势 |
| &nbsp;&nbsp;`days` | int | — | 否 | 窗口天数 `7` |
| &nbsp;&nbsp;`dates` | string[] | — | 否 | `10-22`…`10-28` 短标签（契约占位，前端可格式化） |
| &nbsp;&nbsp;`series` | object | — | 否 | 键 = KPI `code`，值 = 7 日序列；与 `kpis[].spark` 同源 |

**`buildings[].metrics` 键集**（逐楼，契约 §14.1 示例）：

| `code` | `metrics` 键 |
| :--- | :--- |
| `mz` 门诊楼 | `today_visit`、`queue_avg_min` |
| `wk` 外科楼 | `bed_use_rate`、`bed_used`、`bed_open` |
| `jz` 急诊楼 | `obs_over6h`、`obs_cnt`、`obs_max_min` |
| `yj` 医技楼 | `device_run`、`device_alert` |

> **屏值事实化原则**（契约 §14.1 注6）：契约 JSON 字面量为形态示例，服务端出参允许 ±10% 采样容差；前端**不得**与示例字面值做等值断言，只保证"同一时刻 KPI 值 = spark 末点 = 楼宇徽标"的内部一致性渲染。

**前端消费位置**：`/screen` 大屏——`ScreenLayout`（画布/缩放）→ `ScreenView`（取数与三态）→ `ScrHeader`（院名 `hospital/profile.name`+`english_name`/时钟/态势）、`ScrKpiStrip`（kpis）、`ScrDrgQuadrant`（drg_quadrant，副标用 `period_label`）、`ScrCampusMap`（buildings，`anchor` 直渲 pin）、`ScrBuildingBars`（buildings，`primary_metric` 驱动指标名/单位/量程）、`ScrDeptRank`（dept_ranking）、`ScrAlertFeed`（alerts，`total_open` 渲面板头徽标）、`ScrTrendTabs`（trends）、`ScrPanel/ScrChart/scrTokens`（原语与取色）。

**空态与错误态**

- 子块缺失（如 `buildings=[]`）：对应屏区空态，不阻断整屏。
- `server_time` 缺失：屏显时钟回退 BASE_DATE 本地格式化。
- HTTP 5xx/断网：大屏进"断线重试"态——顶部红条 + 手动「重新连接」按钮（当前实现；`error-codes §4` 的自动重连倒计时为远期规格）。
- 可返回错误码：`10001`。

**mock key**：`screen/snapshot`（已注册，`mock/index.ts`）

---

## 16. 端点覆盖总表

| 端点 | mock key | 消费视图/组件 | 状态 |
| :--- | :--- | :--- | :--- |
| `GET /auth/profile` | `auth/profile` | `WorkbenchHeader.vue`（含角色切换下拉）+ 各业务页页头 `useSystemDate` | ✅ 已接入 |
| `GET /hospital/profile` | `hospital/profile` | `WorkbenchSidebar.vue` · `WorkbenchHero.vue` | ✅ 已接入 |
| `GET /workbench/home/kpis` | `workbench/home/kpis` | `WorkbenchKpiCards.vue` | ✅ 已接入 |
| `GET /workbench/home/trends` | `workbench/home/trends` | `TrendChartCard.vue` | ✅ 已接入 |
| `GET /workbench/home/top10` | `workbench/home/top10` | `DepartmentTop10Card.vue` | ✅ 已接入 |
| `GET /workbench/home/indicators` | `workbench/home/indicators` | `KeyIndicatorsCard.vue` | ✅ 已接入 |
| `GET /workbench/home/progress` | `workbench/home/progress` | `WorkProgressCard.vue`（`getHomeProgress`） | ✅ 已接入 |
| `GET /workbench/home/alerts` | `workbench/home/alerts` | `RiskAlertsCard.vue` | ✅ 已接入 |
| `GET /workbench/home/notices` | `workbench/home/notices` | `NoticesTodosCard.vue` | ✅ 已接入 |
| `GET /workbench/overview` | `workbench/overview` | `OverviewView.vue` | ✅ 已接入 |
| `GET /workbench/medical` | `workbench/medical` | `MedicalView.vue` | ✅ 已接入 |
| `GET /workbench/operations` | `workbench/operations` | `OperationsView.vue` | ✅ 已接入 |
| `GET /workbench/hr` | `workbench/hr` | `HrView.vue` | ✅ 已接入 |
| `GET /workbench/research` | `workbench/research` | `ResearchView.vue` | ✅ 已接入 |
| `GET /workbench/patient` | `workbench/patient` | `PatientView.vue` | ✅ 已接入 |
| `GET /workbench/quality` | `workbench/quality` | `QualityView.vue` | ✅ 已接入 |
| `GET /workbench/assets` | `workbench/assets` | `AssetsView.vue` | ✅ 已接入 |
| `GET /workbench/compare` | `workbench/compare` | `CompareView.vue` | ✅ 已接入 |
| `GET /workbench/topics` | `workbench/topics` | `TopicsView.vue` | ✅ 已接入 |
| `GET /workbench/settings/config` | `workbench/settings/config` | `SettingsView.vue` | ✅ 已接入 |
| `GET /screen/snapshot` | `screen/snapshot` | `views/screen/ScreenView.vue` + `components/screen/Scr*` | ✅ 已接入 |

合计 21 端点：**21/21 已接入**。

> **分段器（WbSeg）语义注记**：`research`/`patient`/`quality`/`assets` 四端点契约未声明 `range` 参数——这四页的 WbSeg 为**纯交互展示控件**，切换不产生取数（代码内已注释"仅保留视图交互状态"）。后端如为某端点补 range 参数，先走契约演进再接值。
>
> **本地渲染扩展注记**：`WbTableColumn.width?: string` 为前端原语的本地渲染扩展（契约 columns 仅下发 `key/title/align/num`，payload 从不下发 `width`）；视图本地构造列定义时可填，属组件层约定非契约字段。

---

## 17. 远期预留端点（契约 §15 — 前端不调用）

以下端点为后端落地/深层穿透预留，**当前前端不发起任何调用**，不建 mock key、不写取数函数。启用时须先走契约演进 → 补本文档对应节 → 再写代码。

| # | Method | Path | 用途 | 阶段 | 前端状态 |
| :- | :----- | :--- | :--- | :-- | :------- |
| R01 | GET | `/cases` | L4 病例列表（科室/病组/死因筛选，分页） | P2 | 不调用 |
| R02 | GET | `/cases/{id}` | L5 电子病历（脱敏事实） | P2 | 不调用 |
| R03 | GET | `/cases/{id}?unmask=1` | L5 实名解密调阅（二次验密） | P2 | 不调用 |
| R04 | POST | `/alerts/{id}/ack` | 告警认领 | P2 | 不调用 |
| R05 | POST | `/alerts/{id}/dispatch` | 告警一键督办派发 | P2 | 不调用 |
| R06 | POST | `/alerts/{id}/close` | 告警直接闭环关闭 | P2 | 不调用 |
| R07 | GET | `/todos` | 督办追踪工单列表（三点锚点，分页） | P2 | 不调用 |
| R08 | POST | `/todos/{id}/status` | 督办工单反馈与办结 | P2 | 不调用 |
| R09 | GET | `/campus/buildings/{code}` | 楼宇详情抽屉（大屏二级穿透） | P2 | 不调用 |
| R10 | GET | `/staff` | 组织人员下拉选择器 | P2 | 不调用 |
| R11 | POST | `/auth/login` | 正式 JWT 登录 | P3 | 不调用 |
| R12 | POST | `/auth/refresh` | Token 静默轮换 | P3 | 不调用 |
| R13 | POST | `/metrics/query` | ChatBI / 指标语义层查询 | P3 | 不调用 |
| R14 | GET/POST | `/sim/*` | 仿真时钟与故障注入 | P3 | 不调用 |
