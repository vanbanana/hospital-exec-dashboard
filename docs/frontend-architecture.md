# 前端架构与交互规范（Frontend Architecture）— EDSS v2.2

> 版本：v2.2（双形态基线 —— `/workbench` 工作台 + `/screen` 大屏均已落地；`src/api/` + `src/mock/` 契约化数据层 21 端点全接入；设计令牌 tokens.css 统一治理）  
> 技术栈：Vue 3 + TypeScript + Vite + Vue Router 4 + ECharts 5 + Lucide Vue Next  
> 本文定位：**真实代码与工程结构的唯一事实源**。涵盖目录树、路由表、布局结构、设计系统（Token 与原语）、设计红线、数据链路、Mock 治理、错误反馈规范与大屏重建方向。代码与本文冲突时以本文为准修正代码；本文落后于代码时先改本文。

---

## 1. 系统形态与架构总览

**院长查询与决策支持系统（EDSS）** 为单一前端工程，双形态并存：

| 形态 | 路由入口 | 状态 | 视觉风格 | 目标场景 | 核心诉求 |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **管理工作台（主形态）** | `/workbench` | **现役** | 浅灰蓝医疗专业风（`#f0f5fc` 系） | 院长/院领导/主任日常桌面端办公 | 重"管"：多维筛选、下钻明细、运营监测、报表表格 |
| **指挥大屏（展示形态）** | `/screen` | **现役**（e6aeb52 建成）：`ScreenLayout` 画布 + `ScreenView` + 10 个 `Scr*` 组件，契约 §14 `screen/snapshot` 供给 | 深海蓝科技风 | 会议室大屏、指挥调度中心、大厅展示 | 重"看"：宏观态势、三维院区、风险轮播、指标跑马灯 |

数据链路总览（唯一取数路径，详见 §8；三条已登记例外见 §8.1 末）：

```
视图/卡片组件 onMounted|watch → useAsyncData(fetcher)（五态唯一入口）
  → src/api/{workbench,auth,screen}.ts 端点函数（getXxx(params)）
  → src/api/client.ts api<T>(key, params)
     ├─ VITE_USE_MOCK≠'0'（默认）→ src/mock/index.ts mockResolvers[key](params) → src/mock/<域>.ts
     └─ VITE_USE_MOCK='0' → vite proxy /api→:8080 → Go 后端 /api/v1/<key>（拆 ApiEnvelope）
```

工程约束与原则：
- **包管理纯正性**：一律使用 `npm`，`package-lock.json` 是唯一有效锁文件。
- **依赖白名单制**：仅启用 `vue3 + ts + vite + vue-router@4 + echarts + lucide-vue-next`。不引入 Element-Plus / Pinia / Axios，UI 原语由设计系统内生支撑；白名单外依赖引入前先确认。

---

## 2. 真实目录结构（Directory Structure）

仓库根级：

```
index.html                        # 中立壳：标题"XX市人民医院 · 院长决策支持系统"，无深色底/缩放容器
```

`src/`：

```
src/
├── App.vue                         # 顶层 Router 容器（router-view 根挂载）
├── main.ts                         # 应用入口：注册 Router，加载 index.css 与 workbench.css
├── api/                            # 数据访问层
│   ├── client.ts                   # api<T>(key, params) 统一取数入口（双轨）：默认查 mockResolvers
│   │                               #   注册表（120ms 模拟延迟 + 深拷贝隔离）；VITE_USE_MOCK=0 时经
│   │                               #   vite proxy 打 Go 后端 /api/v1/<key> 并拆 ApiEnvelope
│   ├── types.ts                    # API 契约类型镜像（api-contract v2.0 全量 snake_case，527 行含 §14 屏型）
│   ├── auth.ts                     # /auth/profile(?role=) + /hospital/profile 端点函数；getAuthProfile(role?) 透传 ?role=
│   ├── workbench.ts                # 工作台 18 个端点函数（§3 首页 ×7 + §4~§13 业务页 ×11）
│   ├── screen.ts                   # /screen/snapshot 端点函数
│   ├── useAsyncData.ts             # 取数五态 composable：{ data, loading, error, stale, reload } + ApiError（§10）
│   └── useSystemDate.ts            # 页头"数据截至"共享 system_date（auth/profile 单请求，chrome 级兜底基准日）
├── mock/                           # 契约形状 Mock 数据源（15 文件）
│   ├── index.ts                    # mockResolvers 端点注册表：key = 契约端点路径，21 条全量注册
│   │                               #   index.ts 内联 ENUM_DOMAIN+assertParams：枚举外值抛 Error{code:10001}（§1.4-1，错误态演练）
│   ├── labels.ts                   # delta_label 随 range 联动文案表（§1.3-3）
│   ├── auth.ts                     # 认证与医院上下文（auth/profile + hospital/profile）
│   ├── screen.ts                   # 大屏快照（§14.1：server_time/status/kpis/drg_quadrant/buildings/dept_ranking/alerts/trends）
│   ├── home.ts                     # 首页 7 端点数据包（kpis/trends/top10/indicators/progress/alerts/notices）
│   ├── overview.ts                 # 综合概览（含 range 参数分档数据）
│   ├── medical.ts                  # 医疗业务（tab × range 二维分档）
│   ├── operations.ts               # 运营管理（range 分档）
│   ├── hr.ts                       # 人力资源（range 分档）
│   ├── research.ts                 # 科研教学（无参）
│   ├── patient.ts                  # 患者服务（无参）
│   ├── quality.ts                  # 质量与安全（无参）
│   ├── assets.ts                   # 资产与后勤（无参）
│   ├── compare.ts                  # 对比分析（dim × range 二维分档）
│   ├── topics.ts                   # 专题分析（topic × range 二维分档）
│   └── settings.ts                 # 系统设置（无参）
├── layouts/                        # 布局架构层
│   ├── WorkbenchLayout.vue         # 工作台标准布局（左侧固定导航 + 右侧 Header 与滚动区）
│   └── ScreenLayout.vue            # 大屏布局：.screen-layout 作用域 + 1920×1080 画布缩放适配
├── router/                         # 路由配置
│   └── index.ts                    # 路由定义表（/ 重定向、/workbench 嵌套 12 子路由、/screen、子域 catch-all；根级无 catch-all）
├── styles/                         # 样式系统
│   ├── index.css                   # 全局 reset + body 基座（引入 tokens.css、盒模型重置、字体与 overflow）
│   ├── tokens.css                  # ★ 设计令牌唯一出处（design-tokens.md）：L0 原色 --p-*(:root)
│   │                               #   + L1 语义 --wb-*(.workbench-layout) / --scr-*(.screen-layout)
│   ├── workbench.css               # 工作台基元样式（.wb-*，取值全部 var(--wb-*)/var(--p-*)）
│   └── screen.css                  # 大屏基元样式（取值全部 var(--scr-*)）
├── components/                     # 组件层
│   ├── screen/                     # 大屏专属组件族（11 文件）
│   │   ├── ScrPanel.vue            # [原语] 玻璃面板容器（--scr-panel 底/描边/阴影）
│   │   ├── ScrChart.vue            # [原语] 大屏 ECharts 容器（dispose 配对）
│   │   ├── scrTokens.ts            # [原语] readScrPalette()：运行时 getComputedStyle 读 --scr-*/--p-*
│   │   ├── ScrHeader.vue           # 顶部横幅（院名/时钟/态势/未闭环计数）
│   │   ├── ScrKpiStrip.vue         # KPI 跑马灯 4 项（含 spark 迷你图）
│   │   ├── ScrDrgQuadrant.vue      # DRG 盈亏×CMI 四象限散点
│   │   ├── ScrCampusMap.vue        # 院区楼宇态势（4 栋 anchor 定位+徽标）
│   │   ├── ScrBuildingBars.vue     # 楼宇运行指标条（buildings.primary_metric 驱动，左列槽位）
│   │   ├── ScrDeptRank.vue         # 科室效能榜
│   │   ├── ScrAlertFeed.vue        # 告警跑马灯（纵向滚动）
│   │   └── ScrTrendTabs.vue        # 7 日趋势页签小图组
│   └── workbench/                  # 工作台专属组件库（20 文件）
│       ├── WbPageHead.vue          # [原语] 页面标题与操作区
│       ├── WbSeg.vue               # [原语] 分段选择器（Segmented Control）
│       ├── WbStatStrip.vue         # [原语] 紧凑指标条（Hairline 竖线分隔；items=[] 渲 WbEmpty）
│       ├── WbTable.vue             # [原语] 医疗业务数据表格（插槽支持；rows=[] 渲空态行）
│       ├── WbChart.vue             # [原语] ECharts 响应式容器（ResizeObserver 封装）
│       ├── chartPresets.ts         # [原语] 工作台统一图表主题、色板与轴预设
│       ├── WbEmpty.vue             # [原语] 空态占位（图标+文案，§10.1 empty）
│       ├── WbErrorPanel.vue        # [原语] 面板级错误态 + code/trace_id + 重试（§10.1 error/retry）
│       ├── WbSkeleton.vue          # [原语] 加载骨架占位（§10.1 loading）
│       ├── WbStaleTag.vue          # [原语] "数据未更新"角标 + 重试（§10.1 stale）
│       ├── WorkbenchHeader.vue     # 工作台顶部栏（系统名、搜索、铃铛、头像、日期）
│       ├── WorkbenchSidebar.vue    # 工作台左侧栏（品牌Logo、12项功能菜单、底纹院训）
│       ├── WorkbenchHero.vue       # 首页 Hero 横幅（标语阶梯、医院实景、毛笔书法）
│       ├── WorkbenchKpiCards.vue   # 首页 5 张核心 KPI 统计卡
│       ├── TrendChartCard.vue      # 首页医疗业务趋势折线图（4 Tab）
│       ├── DepartmentTop10Card.vue # 首页科室业务量 TOP10 进度卡
│       ├── KeyIndicatorsCard.vue   # 首页医院运营关键指标卡
│       ├── WorkProgressCard.vue    # 首页重点工作推进进度卡
│       ├── RiskAlertsCard.vue      # 首页风险预警等级卡
│       └── NoticesTodosCard.vue    # 首页通知与待办事项卡
├── views/                          # 页面视图层
│   ├── screen/
│   │   └── ScreenView.vue          # /screen 大屏视图（snapshot 取数 + 自管理三态，§15 豁免登记）
│   └── workbench/                  # 工作台 12 个业务页面
│       ├── HomeView.vue            # /workbench              首页工作台
│       ├── OverviewView.vue        # /workbench/overview     综合概览
│       ├── MedicalView.vue         # /workbench/medical      医疗业务
│       ├── OperationsView.vue      # /workbench/operations   运营管理
│       ├── HrView.vue              # /workbench/hr           人力资源
│       ├── ResearchView.vue        # /workbench/research     科研教学
│       ├── PatientView.vue         # /workbench/patient      患者服务
│       ├── QualityView.vue         # /workbench/quality      质量与安全
│       ├── AssetsView.vue          # /workbench/assets       资产与后勤
│       ├── CompareView.vue         # /workbench/compare      对比分析
│       ├── TopicsView.vue          # /workbench/topics       专题分析
│       └── SettingsView.vue        # /workbench/settings     系统设置
└── assets/                         # 静态资源
    ├── screen/                     # 大屏素材
    │   └── hospital_campus.jpg     # 院区写实等距渲染底图（ScrCampusMap 引用）
    └── workbench/                  # 工作台 AI 生成写实素材（严禁用 SVG 手搓）
        ├── hospital_logo.png       # 权威深海蓝月桂叶白十字官方院徽（WorkbenchSidebar 引用）
        ├── hero_building.png       # 现代门诊综合楼仰拍实景（带透明羽化渐变）
        ├── building_sketch.png     # 医院主楼正立面蓝图线描（侧栏底部半透明水印）
        ├── director_avatar.png     # 资深院长专业西装肖像（WorkbenchHeader 圆形头像）
        ├── slogan_col1.png         # 「人民至上」透明底真迹毛笔书法（WorkbenchHero）
        ├── slogan_col2.png         # 「生命至上」透明底真迹毛笔书法（WorkbenchHero）
        └── slogan_col3.png         # 「健康至上」透明底真迹毛笔书法（WorkbenchHero）
```

> [!NOTE] 旧过渡大屏稿已拆除；/screen 已按真基准重建  
> 过渡大屏稿（根级 `src/components/` 下 8 个深色组件 + 旧 `src/views/ScreenView.vue`）已于 `e1ec65a` 整体拆除。/screen 现役实现见上方 `views/screen/`、`components/screen/`、`layouts/ScreenLayout.vue` 与 §12；真大屏视觉基准为只读参考工程 `archive/smart-hospital-cockpit/`。

---

## 3. 路由体系与导航表（Router Matrix）

### 3.1 路由架构设计
- 根路径 `/` 永久重定向到工作台主入口 `/workbench`。
- 工作台统一由 `WorkbenchLayout.vue` 承载，内部声明 `<router-view />` 承接所有子页面。
- 除首页 `HomeView` 直接导入外，其余 11 个业务 View 全部采用 `() => import(...)` 懒加载机制，实现物理分包；`/screen` 走 `ScreenLayout` 父路由 + 同步导入 `ScreenView`（裁决：懒加载与否记录——当前同步，整屏单 chunk，随多视图演进再议分包）。
- 导航栏 `WorkbenchSidebar.vue` 采用 `router-link` 的 `custom v-slot` 驱动高亮，完全基于 `isActive` 与 `isExactActive` 状态渲染激活效果。
- `/screen` 由 `layouts/ScreenLayout.vue` 承载（`.screen-layout` 令牌作用域 + 1920×1080 画布缩放，经 `provide('screen-adapt')` 注入适配模式与缩放系数供 `ScrHeader` 胶囊消费）。
- **已知缺口**：catch-all 仅声明在 `/workbench` children 内（`:pathMatch(.*)*` → 重定向 `/workbench`）；**根级无 catch-all**，访问未注册路径会渲染空白页（无组件匹配）。待补根级 404 或重定向，见 §13.2。
- **（P3 预案，随 auth epic 落码）登录态守卫**：`meta.public` 标记豁免路由（`/login`、`/screen` 大屏公开位）；`router.beforeEach` 对非 public 路由 `await currentProfile()` 校验会话，失败 → `/login?redirect=<fullPath>`；已登录访问 `/login` → 回 `/workbench`。会话态唯一事实源 `src/api/session.ts`（模块级单 Promise 缓存，`useSystemDate` 同形模式，不依赖 Pinia）。

### 3.2 完整路由定义表

| 路由路径 Path | 路由名称 Name | 视图组件 Component | 加载方式 | 业务口径与功能定位 |
| :--- | :--- | :--- | :--- | :--- |
| `/` | — | 重定向到 `/workbench` | 静态 | 默认根重定向着陆页 |
| `/workbench`（父） | — | `layouts/WorkbenchLayout.vue` | 布局承载 | 工作台框架容器（固定侧栏 + Header + 子路由视口） |
| `/workbench`（子） | `wb-home` | `views/workbench/HomeView.vue` | 同步加载 | `path: ''` 子路由。院长驾驶舱首页：KPI、趋势、TOP10、指标、预警、待办 |
| `/workbench/overview` | `wb-overview` | `views/workbench/OverviewView.vue` | 懒加载 | 综合概览：全院运营大盘、收入结构饼图、服务量构成、实时在院动态 |
| `/workbench/medical` | `wb-medical` | `views/workbench/MedicalView.vue` | 懒加载 | 医疗业务：门急诊/住院/手术三项细分、分时高峰、科室业务明细表 |
| `/workbench/operations` | `wb-operations` | `views/workbench/OperationsView.vue` | 懒加载 | 运营管理：月度收支趋势、百元医疗收入消耗费用红线、科室运营指标表 |
| `/workbench/hr` | `wb-hr` | `views/workbench/HrView.vue` | 懒加载 | 人力资源：岗位人员构成、职称结构分段、重点科室人员配置表 |
| `/workbench/research` | `wb-research` | `views/workbench/ResearchView.vue` | 懒加载 | 科研教学：立项课题经费、论文发表分级、重点学科建设进度 |
| `/workbench/patient` | `wb-patient` | `views/workbench/PatientView.vue` | 懒加载 | 患者服务：门急诊/住院满意度趋势、挂号渠道占比、投诉表扬记录台账 |
| `/workbench/quality` | `wb-quality` | `views/workbench/QualityView.vue` | 懒加载 | 质量与安全：院感发生率趋势、不良事件类型分布、8 项核心制度抽查合格率表 |
| `/workbench/assets` | `wb-assets` | `views/workbench/AssetsView.vue` | 懒加载 | 资产与后勤：月度能耗费用、物资库存预警、大型设备使用效益表 |
| `/workbench/compare` | `wb-compare` | `views/workbench/CompareView.vue` | 懒加载 | 对比分析：科室多维横向对比、与区域同级医院雷达对标、核心指标差距明细表 |
| `/workbench/topics` | `wb-topics` | `views/workbench/TopicsView.vue` | 懒加载 | 专题分析：DRG病组入组与CMI、医保基金监管、公立医院国考、门诊统筹专项 |
| `/workbench/settings` | `wb-settings` | `views/workbench/SettingsView.vue` | 懒加载 | 系统设置：HIS/EMR 数据源管理、指标预警阈值、用户与权限、5项系统偏好 |
| `/workbench/:pathMatch(.*)*` | — | 重定向到 `/workbench` | 静态 | 工作台子域 404 兜底回落（仅覆盖 `/workbench/*`） |
| `/login` | `login` | `views/LoginView.vue` | 懒加载 | （P3 预案）登录页：用户名/口令表单 → `POST /auth/login`（契约 §2.3）；`meta.public` 守卫豁免；`.auth-layout` 令牌作用域（design-tokens §6 R8） |
| `/screen`（父） | — | `layouts/ScreenLayout.vue` | 布局承载 | 大屏画布容器（viewport + 等比缩放 + `screen-adapt` provide） |
| `/screen`（子） | `screen` | `views/screen/ScreenView.vue` | 同步 | 院长驾驶舱大屏：snapshot 单端点 + 10 个 Scr* 组件 |

### 3.3 页面交互清单（点击地图）

当前全工程**无下钻、无行级跳转、无路由参数**——交互仅来自分段器、Tab、本地表单态，以及首页卡片「更多 >」页级导航。按代码实状清点：

| 区域 / 页面 | 交互元素 | 数据效果 |
| :--- | :--- | :--- |
| 侧栏 `WorkbenchSidebar` | 12 项 `router-link` 菜单 | 路由切换，`isActive`/`isExactActive` 驱动高亮 |
| 顶栏 `WorkbenchHeader` | 搜索框 / 铃铛 / 院长头像区 / 日期 | 日期与角色消费 `auth/profile`（system_date+weekday+title）；铃铛角标消费 `home/alerts` 计数；头像区点击展开角色下拉（`available_roles`，选中经 `?role=` 重取切上下文）；搜索仍为禁用静态展示 |
| 侧栏 `WorkbenchSidebar` | 品牌区 / 院训底纹 | 院名与英文名、座右铭消费 `hospital/profile` |
| 首页 `WorkbenchHero` | 标语阶梯 | `hospital/profile.slogans/pillars` 驱动 |
| 首页 `TrendChartCard` | 4 个趋势 Tab（门急诊人次 / 住院人次 / 手术台次 / 医疗收入） | 本地切换 `currentTab`，复用已取回的 `home/trends` 数据换序列 |
| 首页 5 张数据卡 | `更多 >` router-link（页级导航） | Top10→`/medical`、关键指标→`/overview`、风险预警→`/quality`、工作进度→`/topics`、通知待办→`/overview` |
| 综合概览 | `WbSeg` range（本月/本季/本年） | `watch` 触发 `getOverview(range)` 重取，参数生效 |
| 医疗业务 | `WbSeg` bizTab（门急诊/住院/手术）+ range | `watch` 触发 `getMedical(tab, range)` 重取，参数生效 |
| 运营管理 | `WbSeg` range | `getOperations(range)` 重取，参数生效 |
| 人力资源 | `WbSeg` range | `getHr(range)` 重取，参数生效 |
| 科研教学 | `WbSeg` range（本季/本年） | **仅 UI 态**：契约 §8.1 无 range 参数，无 `watch`，切换不取数 |
| 患者服务 | `WbSeg` range | **仅 UI 态**：契约 §9.1 无 range 参数，切换不取数 |
| 质量与安全 | `WbSeg` range | **仅 UI 态**：契约 §10.1 无 range 参数，无 `watch`，切换不取数 |
| 资产与后勤 | `WbSeg` range | **仅 UI 态**：契约 §11.1 无 range 参数，无 `watch`，切换不取数 |
| 对比分析 | `WbSeg` dim（业务量/收入/效率/质量）+ range | `watch` 触发 `getCompare(dim, range)`；中文选项映射为契约枚举（scale/benefit/efficiency/quality） |
| 专题分析 | 4 张专题卡点击（DRG/医保/国考/门诊统筹）+ `WbSeg` range | `watch` 触发 `getTopics(topic, range)` 重取 |
| 系统设置 | 阈值启用开关、5 项偏好下拉/开关 | **仅本地 `reactive` 态**：刷新即失；持久化端点已契约化（R15/R16，契约 §15.7/15.8），待 write epic 落码 |
| 各页 `WbTable` 行 | — | 无点击下钻；L4/L5 穿透属契约 §15 远期预留 |
| 大屏 `ScrHeader` | 全屏按钮 / 适配胶囊 | `requestFullscreen` 切换（拒绝静默）；点击胶囊切 contain/fill 适配（`screen-adapt` inject） |
| 大屏 `ScrAlertFeed` | 告警跑马灯 | CSS 纵向循环滚动，自动随 DOM 卸载 |
| 大屏 `ScreenView` | 断线重试条 | error 态顶部红条 + 手动「重新连接」重发 `getScreenSnapshot()` |

---

## 4. 布局体系（Layout Architecture）

工作台采用现代 Web 管理系统的二栏标准架构：

```
+------------------------------------------------------------------------------------+
|  [Sidebar 204px]  |  [Header 64px: Title | Search | Notice | User Profile | Date]   |
|                   +----------------------------------------------------------------+
|  Hospital Logo    |  [Scrollable View Container: padding 2px 16px 14px]            |
|  12 Nav Items     |                                                                |
|  (Active state)   |  <router-view />                                               |
|                   |                                                                |
|  Building Sketch  |  (Page Content: WbPageHead -> WbStatStrip -> Panels/Grids)     |
|  Hospital Motto   |                                                                |
+------------------------------------------------------------------------------------+
```

### 4.1 布局特性规范
1. **侧边栏（`WorkbenchSidebar.vue`）**：
   - 宽度固定 `204px`，背景为专用浅蓝底色 `--wb-sidebar-bg: #f1f6fd`，右侧描边 `1px solid --wb-border`。
   - 顶部品牌区展示官方圆形徽章（`38px`）及中英文院名（XX市人民医院）。
   - 导航项无固定高度（自动高度约 `37px`），间距 `2px`，内边距 `9px 12px`；激活项呈现 `--wb-accent` 纯色背景填充与 `rgba(37,99,235,0.25)` 柔和投影（非渐变）。
   - 底部定位建筑正立面线稿底纹（透明度 `0.7`），底端水平居中排布「厚德 精医 仁爱 创新」院训。
2. **顶部栏（`WorkbenchHeader.vue`）**：
   - 高度固定 `64px`，顶层悬浮对齐，右侧排布圆角药丸搜索输入框（`320px` 宽）、消息提醒铃铛（红色未读角标 = `home/alerts` 未闭环计数）、院长个人信息展示区（头像 + `auth/profile.title` 角色称谓；头像下拉为远期项）以及标准中文日期。
   - 日期消费 `auth/profile.system_date+weekday`（契约 §2.1 下发 `2026-10-28/星期三`）；取数失败回退演示基准日 `BASE_DATE=2026-10-28`（周三）本地格式化。
3. **滚动工作区（`WorkbenchLayout.vue .workbench-scroll`）**：
   - 采用弹性自适应高度 `flex: 1; min-height: 0; overflow-y: auto;`。
   - 统一页面级外边距与纵向节奏：`padding: 2px 16px 14px;`。
   - 自定义 `6px` 极简半透明滚动条，保障视觉纯净度。

---

## 5. 设计系统规范（Design System）

设计系统主入口为 `src/styles/tokens.css`（唯一令牌出处，`docs/design-tokens.md` **已生效**，见 §11）：L0 原色 `--p-*` 定义于 `:root`，L1 语义 `--wb-*`/`--scr-*` 分别挂在 `.workbench-layout`/`.screen-layout` 作用域；`workbench.css`/`screen.css` 仅含基元样式（取值一律 `var()`），公共 UI 原语用 `.wb-*`、大屏用 `.scr-*`/`Scr*` 前缀隔离。

### 5.1 Token 清单速查（**登记总表以 `design-tokens.md` §3-§5 为唯一权威**；本节为消费速查）

#### 工作台语义令牌（tokens.css `.workbench-layout`，取值 = `var(--p-*)`）
```css
--wb-bg / --wb-surface / --wb-sidebar-bg   /* 页面底 / 面板底 / 侧栏底 */
--wb-border / --wb-hairline / --wb-input-border / --wb-hover-bg   /* 描边与分隔 */
--wb-navy / --wb-primary / --wb-accent / --wb-accent-soft          /* 品牌蓝系 */
--wb-text-1..4                              /* 正文→失效 四级灰 */
--wb-up / --wb-down / --wb-green / --wb-teal / --wb-amber / --wb-red /* 信号色 */
--wb-tag-{green,red,amber,teal,blue,gray}-bg  /* tag/badge 浅底族 */
--wb-th-bg / --wb-bar-track / --wb-seg-bg / --wb-switch-off / --wb-scrollbar /* 组件件 */
--wb-shadow-{card,hover,accent,raised}      /* 阴影族 */
--wb-chart-{text,axis,grid,axis-line,green,amber,blue-1..4}      /* 图表语义锚（chartPresets 对照） */
--wb-rank-1..3                              /* 奖牌色 */
--wb-radius-{card,inner,tag,sm,pill} / --wb-gap / --wb-pad-{x,y}  /* 几何 */
--wb-fs-{2xs..hero} / --wb-fw-{normal..bold} / --wb-lh-{solid..loose} / --wb-ls-{sm..2xl} /* 排版 */
--wb-space-1..5 / --wb-opacity-{muted,dimmed} / --wb-z-{raised,sticky} / --wb-dur-{fast,normal} /* 覆盖维 */
--wb-sidebar-w / --wb-header-h / --wb-scrollbar-w               /* 布局度量 */
```

#### 大屏语义令牌（tokens.css `.screen-layout`）
```css
--scr-bg / --scr-panel / --scr-border / --scr-border-glow      /* 底与描边 */
--scr-accent / --scr-accent-bright / --scr-text-1..4           /* 强调与文本 */
--scr-up / --scr-down / --scr-warn                            /* 信号色 */
--scr-radius-{card,tag,badge,pill} / --scr-shadow-panel       /* 几何与阴影 */
--scr-fs-{axis,xxs,xs,sm,md,title,num} / --scr-fw-{normal..bold} / --scr-lh-{tight,normal} / --scr-ls-{xs..xl} /* 排版 */
--scr-space-1..10 / --scr-opacity-{sub,img} / --scr-z-{pin,overlay} / --scr-dur-{fast,normal} /* 覆盖维 */
--scr-chart-{axis,grid,mark,area-top,area-bottom} / --scr-tooltip-bg /* 图表语义（scrTokens 出口） */
--scr-canvas-w:1920px / --scr-canvas-h:1080px                 /* 画布基准（ScreenLayout 经 readScrCanvas 消费） */
```

#### 原色层（tokens.css `:root`，消费经 `var(--p-*)` 或 `rgb(from …)` 配方）
`--p-slate-*` / `--p-blue-*` / `--p-navy-900` / `--p-ink-{800,900,950}` / `--p-cyan-{400,500}` / `--p-{red,amber,green,teal}-*` / `--p-{green,red,amber,teal,blue}-bg` / `--p-white` / `--p-font-{base,number}`

#### 字体阶梯规范（Typography Scale，字号一律取 `--wb-fs-*`/`--scr-fs-*`）
| 阶梯层级 | token | 典型应用场景 |
| :--- | :--- | :--- |
| Hero 标语 | `--wb-fs-hero` 24px | 首页横幅核心口号 |
| 核心指标大数 | `--wb-fs-num` 22px / `--scr-fs-19` 19px | KPI 数值、屏顶大数 |
| 页面大标题 | `--wb-fs-xl` 18px / `--scr-fs-title` 20px | 页标题、屏标题 |
| 面板区块标题 | `--wb-fs-lg` 15px | 卡片头部标题 |
| 正文/菜单/表单 | `--wb-fs-md` 13px / `--scr-fs-md` 13px | 表格、导航 |
| 辅助说明/副标题 | `--wb-fs-sm` 12px | 单位、表头 |
| 状态标签/轴标 | `--wb-fs-xs` 11px / `--scr-fs-sm` 11px / `--scr-fs-axis` 9px | 胶囊签、ECharts 轴 |
| 微备注 | `--wb-fs-2xs` 10px / `--scr-fs-xs` 10px / `--scr-fs-xxs` 8px | 图例、密集小图 |

---

## 6. 共享原语组件库（Shared Primitives）

工作台杜绝从零堆砌样式，页面由原语组装拼装。**工作台原语 9 件**（`WbPageHead`/`WbSeg`/`WbStatStrip`/`WbTable`/`WbChart`+`chartPresets`/`WbEmpty`/`WbErrorPanel`/`WbSkeleton`/`WbStaleTag`）；**大屏原语 3 件**（`ScrPanel`/`ScrChart`/`scrTokens.readScrPalette`），两域令牌隔离、互不消费。以下按域列示（原 5 件核心原语详述保留）：

### 6.1 `WbPageHead.vue` — 统一页头
- **定位**：页面最顶部的标准化标题栏。
- **Props**：
  - `title: string`（必填，页面主标题，如"医疗业务"）
  - `sub?: string`（选填，数据范围与统计口径说明）
- **Slots**：
  - `default`：右侧操作插槽，通常放置时间范围分段器 `WbSeg`、条件过滤下拉或刷新按钮。
- **用法示例**（页头"数据截至"不写死日期，经 `useSystemDate` 消费 `auth/profile.system_date`）：
```html
<WbPageHead title="医疗业务" :sub="`门急诊 · 住院 · 手术明细分析 · 数据截至 ${systemDate}`">
  <WbSeg v-model="bizTab" :options="['门急诊', '住院', '手术']" />
  <WbSeg v-model="range" :options="['本月', '本季', '本年']" />
</WbPageHead>
```
```ts
const systemDate = useSystemDate()
// 渲染为 "门急诊 · 住院 · 手术明细分析 · 数据截至 {system_date}"；取数失败回退演示基准日
```

### 6.2 `WbSeg.vue` — 医疗风分段控制器
- **定位**：克制、紧凑的胶囊切换控件，替代原生 tabs。
- **Props**：
  - `options: string[]`（必填，选项文本数组）
  - `modelValue: string`（必填，当前选中值）
- **Emits**：
  - `update:modelValue(value: string)`
- **用法示例**：
```html
<WbSeg v-model="range" :options="['本月', '本季', '本年']" />
```

### 6.3 `WbStatStrip.vue` — 紧凑指标条
- **定位**：单层面板横排 4~6 个关键指标，通过 `::before` 细微竖向发丝线（Hairline）分隔，**杜绝卡片并排与嵌套**。
- **Props**：
  - `items: WbStatItem[]`（必填，契约 §1.3-3 类型——组件已收敛为从 `src/api/types` 导入，单一事实源）
- **渲染约定**：`delta`/`note` 二选一展示；`delta_label`（契约可选字段，mock 已按口径下发）缺失时兜底「较上月」；`dir` 三态驱动箭头与涨跌色。

### 6.4 `WbTable.vue` — 业务数据表格
- **定位**：高信息密度、浅底色表头、支持单元格自定义插槽的高性能表格。
- **Props**：
  - `columns: WbTableColumn[]`（列定义：`{ key, title, width?, align?, num? }`）
  - `rows: Record<string, unknown>[]`（数据源数组）
  - `rowKey?: string`（行唯一标识，默认使用数组索引）
- **类型双声明说明（已知差异）**：`WbTableColumn` 与 `rows` 类型在契约层与组件层各声明一份——
  - 契约层 `src/api/types.ts`：`WbTableData { columns: WbTableColumn[]; rows: WbTableRow[] }`，其中 `WbTableRow = Record<string, string | number>`；
  - 组件层 `WbTable.vue`：本地 `WbTableColumn` 接口 + `rows: Record<string, unknown>[]`（更宽的行类型）。
  - 二者赋值兼容（契约行是组件行的子集），运行时无冲突，但属重复声明，待收敛为统一引用契约类型。
- **Slots**：
  - `#cell-{key}="{ row, value }"`：指定列插槽，用于渲染 `.wb-tag` 或特定徽标。
- **用法示例**：
```html
<WbTable :columns="tableCols" :rows="tableRows" row-key="dept">
  <template #cell-status="{ value }">
    <span class="wb-tag" :class="value === '达标' ? 'is-green' : 'is-red'">{{ value }}</span>
  </template>
</WbTable>
```

### 6.5 `WbChart.vue` 与 `chartPresets.ts` — ECharts 响应式封装
- **`WbChart.vue`**：
  - 自动绑定 `ResizeObserver`，当容器栅格尺寸变化时自动 `chart.resize()`。
  - 监听 `option` 深度更新并以 `{ notMerge: true }` 安全重绘。
  - 组件销毁生命周期内完整执行 `observer.disconnect()` 与 `chart.dispose()`，杜绝内存泄漏。
- **`chartPresets.ts` 共享配置库**：
  - `wbPalette`：官方调色板（Primary `#2563eb`、Teal `#0d9488`、Amber `#f59e0b`、Green `#10b981` 等）。
  - `wbDonutColors`：环形图推荐配色序列。
  - `wbCategoryAxis(data, extra)`：预设好灰蓝刻度线与 11px 字号的 X 轴工厂函数。
  - `wbValueAxis(extra)`：预设好细分隔线 #eef3f9、无轴线的 Y 轴工厂函数（ECharts 默认实线）。
  - `wbTooltip(trigger)`：预设 96% 高透明度纯白浮层、细腻阴影与精准文本样式的 Tooltip。
  - `wbGrid(extra)`：微调边界的图表定位坐标。
  - `wbAreaGradient(color)`：平滑面积渐变生成器。

---

### 6.6 反馈态原语（§10 五态渲染专用）

| 原语 | 覆盖态 | 行为 |
| :--- | :--- | :--- |
| `WbSkeleton.vue` | loading | 骨架条脉冲占位（`rows` 可配），flex 撑满宿主区块 |
| `WbErrorPanel.vue` | error + retry | 错误文案 + `code`/`trace_id` 元信息 + 重试按钮（`@retry`），`loading` 时按钮置"加载中" |
| `WbEmpty.vue` | empty | 图标 + `text` 文案（默认"暂无数据"）；`WbTable` rows=[]、`WbStatStrip` items=[] 已内置 |
| `WbStaleTag.vue` | stale + retry | "数据未更新"角标 + 重试入口（`@retry`），旧数据保留时挂于页头操作区/卡片列表首行 |

视图统一用法：`useAsyncData(fetcher)` → `data===null` 时渲面板级 error/skeleton/empty 门，非空渲内容 + `stale` 时挂 `WbStaleTag`；取数列表/表格空集合局部渲 `WbEmpty`/表格空态行。

---

## 7. 设计红线与工程戒律（Design Redlines）

在进行工作台页面构建或迭代时，必须严格执行以下红线，**违反即重构**：

1. **绝对禁止卡片套卡片（No Card-in-Card Nesting）**：
   - 页面第一级已使用 `.wb-panel` 纯白卡片，面板内部**绝对禁止再套一层带背景与圆角的矩形卡片**。
   - 面板内部如需多栏分区，必须使用留白（Padding）、细发丝线（`.wb-split`、`--wb-hairline`）、表格（`WbTable`）或列表行（`.wb-list-row`）进行视觉划分。
2. **绝对禁止圆角矩形无序堆叠（No Rounded-Rectangle Stacking）**：
   - 避免满屏圆角块造成的视觉钝化与“玩具感”。所有微型标签必须遵循 `--wb-radius-tag: 4px`，输入框使用 `--wb-radius-inner: 6px`，面板使用 `--wb-radius-card: 10px`。
3. **绝对禁止“AI 感”混搭与廉价渐变（No AI-Slop Visual Styles）**：
   - 禁止在 Web 工作台界面滥用暗黑荧光霓虹描边、高饱和度彩虹色渐变、发光投影（Glow Effect）。侧栏导航激活项的微投影（`rgba(37,99,235,0.25)`）属于白名单视觉规范豁免，除此以外页面主体面板禁止滥用发光与弥散大投影。
   - 图标一律使用 `lucide-vue-next` 的线性极简风格（`stroke-width="1.8~2.0"`），禁止不同粗细、不同圆角图标混杂。
4. **写实与装饰素材严格采用生成资产（Assets Must Be Real Images）**：
   - 建筑实景、权威院徽、历史院训底纹、人物肖像等写实/装饰性内容，必须使用图像生成工具生成高质量 PNG，存放于 `src/assets/workbench/` 并以 `import` 方式引用。
   - **严禁使用 SVG 代码手绘硬凑照片感大楼、假 3D 建筑或复杂人物**。
5. **高度符合公立医院院长决策场景（Hospital Executive Context）**：
   - 整体视觉必须沉稳、克制、严谨、高信息密度。
   - 涨跌幅红绿色严格绑定中国医疗与金融管理惯例：升/超标用红（`--wb-up`），降/达标用绿（`--wb-down`）。

---

## 8. 数据链路与 Mock 治理（Data Layer）

### 8.1 取数链路（现状）

全工程**唯一**取数路径，11 个业务视图 + 首页 7 张数据卡片全部经此链路取数（HomeView 自身不取数，由各卡片独立调用），组件内无散落的契约形状数据块：

```
视图/卡片 onMounted|watch → useAsyncData(fetcher)（工作台域唯一入口）
  → api/{workbench,auth,screen}.ts 端点函数（如 getOverview(range)、getAuthProfile()、getScreenSnapshot()）
  → api/client.ts api<T>(key, params)
     ├─ VITE_USE_MOCK≠'0'（默认）→ mock/index.ts mockResolvers[key](params)   // key = 契约端点路径，如 'workbench/overview'
     │    → mock/<域>.ts 返回契约形状数据
     └─ VITE_USE_MOCK='0' → vite proxy /api→:8080 → Go 后端 /api/v1/<key>（拆 ApiEnvelope）
```

`client.ts` 行为要点：
- mock 轨：`key` 未注册 → 抛 `Error("[api] 未注册的端点: <key>")`；每次调用固定 `120ms` 模拟延迟；返回值为深拷贝（隔离 mock 模块单例，防消费方原地修改污染后续请求）。
- 真后端轨（`VITE_USE_MOCK=0`）：经 `fetch` 打 `/api/v1/<key>`（vite proxy → :8080），拆 `ApiEnvelope`——`code!==0` 抛带数值 `code`/`fields`/`trace_id` 的 Error，HTTP 层失败（无包络）抛 `[api] http N`。
- `api()` 成功路径直返 `data` 负载，视图对数据来源无感。

**已登记例外**（三条，不走 useAsyncData）：
- `ScreenView` 整屏自管理 loading/error/data 三态（frontend-api §15 豁免登记；顶部红条手动重连）。
- `WorkbenchHeader`/`WorkbenchSidebar`/`WorkbenchHero` 的 `auth/profile`、`hospital/profile`、`home/alerts` 计数取数：`onMounted` 内 `await` + `.catch(() => null/0)` 兜底展示——chrome 级数据失败静默降级，不进面板五态。
- 各业务视图页头"数据截至"：`useSystemDate()` 消费 `auth/profile.system_date`（模块级共享单次请求，9 个页头复用；顶栏 WorkbenchHeader 走自有 `getAuthProfile()` chrome 例外），失败静默回退演示基准日 `2026-10-28`；同属 chrome 级降级。

### 8.2 现有 12 页面数据区块清单

| 页面名称 | 路由路径 | 端点（mock key） | 数据区块 1 | 数据区块 2 | 数据区块 3 | 数据区块 4 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **首页** | `/workbench` | `workbench/home/*`（×7） | 5 张顶层 KPI 指标卡（门急诊/住院/手术/医疗总收入/在岗职工） | 业务趋势双折线图（门急诊人次/住院人次/手术台次/医疗收入 4 Tab 切换） | 科室业务量 TOP10 水平条形进度卡 | 底部运营关键指标 / 重点工作进度 / 风险预警 / 通知与待办四联卡片 |
| **综合概览** | `/workbench/overview` | `workbench/overview` | 6 项全院核心指标条（门急诊/出院/手术/收入/床位/住院日） | 业务规模与收入双轴趋势图（门急诊柱 × 医疗收入折线） | 收入结构环形占比图（医疗/药品/耗材/检查化验 + 图例列表） | 科室服务量构成 TOP8 进度列表 + 实时在院动态列表 |
| **医疗业务** | `/workbench/medical` | `workbench/medical` | 门急诊/住院/手术 3 Tab 动态联动指标条（各 6 项核心指标） | 近 12 个月规模趋势平滑面积折线图（随 Tab 切换人次/台数） | 业务特征分布图（门急诊分时高峰柱 / 住院重点病种柱 / 手术分级环形） | 科室医疗业务明细表（WbTable，按当前 Tab 口径排序展示） |
| **运营管理** | `/workbench/operations` | `workbench/operations` | 6 项收支与费用指标条（医疗总收入/门诊/住院/结余率/次均费用） | 月度收支趋势双轴图（医疗收入柱 × 医疗成本虚线 × 收支结余率折线右轴，近 12 个月） | 费用控制监测（药耗比、次均费用等 4 项指标对标红线值进度条列表） | 科室运营指标表格（WbTable，收入/结余率/药占比/耗材占比/达标状态） |
| **人力资源** | `/workbench/hr` | `workbench/hr` | 6 项人力资源指标条（在岗职工/执业医师/护士/医护比/高职占比/人员经费） | 人员构成环形占比图（按岗位类别 + 结构明细列表） | 职称结构堆叠柱状图（categories 岗位轴分段梯队） | 重点科室人员配置表（WbTable，编制 vs 在岗、床人比、缺口预警） |
| **科研教学** | `/workbench/research` | `workbench/research` | 6 项科教指标条（在研课题/新立项/科研经费/SCI论文/住培/继教率） | 近 5 年立项课题与科研经费双轴图（国家级/省部级堆叠柱 × 经费折线） | 论文分区构成柱状图（一区 Top~四区 / 中文核心） | 重点学科建设进展表（WbTable，学科级别/带头人/课题/经费/进展） |
| **患者服务** | `/workbench/patient` | `workbench/patient` | 6 项患者服务指标条（门诊/住院满意度、投诉/表扬件数、候诊时长、网约率） | 满意度趋势近 6 个月双折线走势图（门诊 vs 住院） | 挂号渠道分布环形占比图（微信小程序/自助机/人工窗口等） | 投诉与表扬记录台账表（WbTable，日期/科室/类型/诉求/状态） |
| **质量与安全** | `/workbench/quality` | `workbench/quality` | 6 项质量安全指标条（甲级病案率/院感率/危急值及时率/不良事件/切口感染/抗生素强度） | 院感发生率趋势单折线 + markLine 目标控制线（`infection_trend.rates` 单序列，契约 §10.1） | 不良事件类型分布水平条形图（跌倒/用药/管路等按频次排序） | 医疗核心制度执行监测表（WbTable，8 项核心制度抽查合格率与环比） |
| **资产与后勤** | `/workbench/assets` | `workbench/assets` | 6 项资产后勤指标条（固定资产总额/大型设备/开机率/库存周转/能耗/工单） | 月度能耗合计面积主线 + 电/水/气三条分项细线（近 6 个月） | 物资库存预警列表（周转天数偏长品类与警戒级别标注） | 大型设备使用效益表（WbTable，CT/MRI/DSA 等机时/人次/收入/评级） |
| **对比分析** | `/workbench/compare` | `workbench/compare` | 科室横向对比表（WbTable，业务量/收入/效率/质量 4 维度分段器切换，内嵌水平条形） | 与区域同级医院对标雷达图（6 维度综合评分：本院 vs 区域均值） | 核心指标对标明细表（WbTable，本院值/区域均值/标杆值/差距差额） | —（本页无顶部 WbStatStrip 指标条，亦无柱状图） |
| **专题分析** | `/workbench/topics` | `workbench/topics` | 4 类专题动态切换专属 5 项指标条（DRG / 医保 / 国考 / 门诊统筹） | 专题趋势与分布分析图（DRG入组率线图 / 医保支出线图 / 国考完成度柱图 / 门诊统筹人次线图） | 专题明细数据监测表（WbTable，重点病组DRG / 险种基金 / 国考核心指标 / 常见慢病统筹） | 4 类专题卡片导航选择器（DRG付费 / 医保基金 / 三级国考 / 门诊统筹） |
| **系统设置** | `/workbench/settings` | `workbench/settings/config` | 数据源管理表格（WbTable，6 项系统对接状态——HIS/LIS/PACS/EMR/HRP/医保结算接口，含异常行） | 指标预警阈值配置表（WbTable，7 项指标预警阈值与启用开关） | 用户与权限管理表格（WbTable，用户账号、角色标签、科室授权与启用状态） | 5 项系统偏好表单设置（默认时间范围、数据刷新频率、预警声音、单位缩写、敏感脱敏） |
| **工作台 chrome** | 布局件 | `auth/profile` · `hospital/profile` | 顶栏日期/角色称谓（auth）+ 铃铛未闭环计数（home/alerts） | 侧栏院名/英文名/座右铭（hospital） | Hero 标语阶梯（hospital.slogans/pillars） | — |
| **大屏** | `/screen` | `screen/snapshot` | ScrHeader 时钟/态势/未闭环告警 + ScrKpiStrip 4 项 KPI | ScrDrgQuadrant 象限散点 + ScrCampusMap 四栋楼宇 | ScrDeptRank 效能榜 + ScrAlertFeed 告警跑马灯 | ScrTrendTabs 7 日趋势页签小图组 |

### 8.3 Mock 数据集中治理纪律（现行）

1. **统一集中目录**：Mock 数据一律放 `src/mock/`，按业务域一域一文件（当前 14 域 15 文件 + `index.ts` 注册表 21 key；auth/screen 为共享上下文域非页面域）。
2. **命名强行对齐契约**：Mock 数据对象的属性名称**必须全量使用 snake_case**，与 `docs/api-contract.md` 字段完全一致（如 `dept_name`、`bed_use_rate`、`case_cnt`）。禁止在视图与 mock 中使用私有或随意的驼峰命名。
3. **注册表唯一入口**：每个端点在 `mock/index.ts` 的 `mockResolvers` 注册一行，`key` 必须与契约端点路径**字面一致**；新增端点缺注册即触发 `[api] 未注册的端点` 运行时错误。
4. **四位一体改单**：新增/变更端点 = `api-contract.md`（先改契约）→ `types.ts` 类型 → `mock/<域>.ts` 数据 + `index.ts` 注册 → `api/workbench.ts` 端点函数，四层缺一即断链。
5. **零成本对接后端（已兑现）**：`client.ts` 内 `VITE_USE_MOCK` 双轨开关已落地——`=0` 经 vite proxy 打 Go 后端 `/api/v1/<key>` 并拆 `ApiEnvelope`，视图、端点函数、mock 注册表一行未改。

### 8.4 写路径与有状态 mock（P3 契约预案）

契约 §15 R04–R08/R15/R16 写端点与 §2.3–2.4 会话端点已定义，落码时数据链路按本节演进：

1. **api() 写形**：`api<T>(key, params?, opts?: { method?: 'GET'|'POST'|'PUT', body? })`——GET 签名不变（21 端点零回归）；写路径同包络拆解。`fetch` 显式 `credentials:'same-origin'` 携带 `edss_sid` Cookie。mock 轨以 `method:key` 复合键注册写 resolver。
2. **401 拦截**：`env.code ∈ {20001,20002,20003}` → `clearSession()` + `location.assign('/login?redirect=…')` 硬跳转（`client.ts` 不 import router，防依赖环）。
3. **写后读**：调用方 `useAsyncData.reload()` 局部重取受影响区块；不做跨组件失效广播（Pinia 落地再议）。
4. **有状态 mock 域（首个状态源）**：写流引入 `src/mock/alertflow.ts`——模块态 Map 存告警状态机 + todos 数组；`workbench/home/alerts` resolver 改由该源派生打开集，实现 mock 轨写后读一致（ack/dispatch 不政变开数，close/todo done 后减一）。页面刷新即重置 = 演示可接受行为（restart→seed 语义对齐真后端）。`auth` 域 mock 同步引入会话旗标（`auth/login` 置位、`auth/logout` 清除、无旗标 `auth/profile` 抛 `code=20001`）。
5. **操作人传输**：演示期写端点函数自动拼 `?role=<当前演示角色>`（`api/auth.ts` 模块级 ref 存当前角色，Header 角色下拉切换写回；契约 §15 头部约定）。
6. **写操作反馈**：`33002`/`33104` 冲突类 → 警告提示 + 相关区块局部刷新；`10002` → 表单内联错（`data.fields` 逐字段红标，不弹全局消息）；`20004`/`20005` → 警告提示 + 停留。全局提示走 token 化轻量 toast 等价物（error-codes §4 矩阵的 ElMessage 语义，登记后落码）。

---

## 9. 新增页面标准开发流程（Standard Playbook）

开发者新增业务分析页面时，必须严格执行以下标准八步，禁止随意发挥：

```
[步骤 1: 创建视图]
创建 src/views/workbench/XxxView.vue（先建空骨架）

[步骤 2: 契约与类型]
确认 api-contract.md 已定义该页端点与字段（未定义则先改契约），
在 src/api/types.ts 中补 XxxResp 镜像类型（snake_case 照抄契约）

[步骤 3: mock 域文件]
新建 src/mock/xxx.ts 造契约形状数据；
在 src/mock/index.ts 的 mockResolvers 注册 key（key = 契约端点路径）

[步骤 4: 端点函数]
在 src/api/workbench.ts 增加端点函数：
export function getXxx(range: RangeKey = '本年') {
  return api<XxxResp>('workbench/xxx', { range })
}

[步骤 5: 注册路由]
在 src/router/index.ts 的 /workbench children 数组中追加懒加载路由

[步骤 6: 挂载导航]
在 src/components/workbench/WorkbenchSidebar.vue 的 menuItems 数组中添加导航菜单与 Lucide 图标

[步骤 7: 规范拼装]
视图内 onMounted/watch 调端点函数取数（try/catch 与五态反馈按 §10 规范实现），
使用共享原语组装界面：
<WbPageHead> -> <WbStatStrip> -> 面板栅格（.wb-grid-2-1 等） -> <WbChart> / <WbTable>

[步骤 8: 交付门禁验证]
运行构建检查与无头截屏对比（必须与 acceptance.md 门禁一致）：
npx vue-tsc -b && npm run build
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless \
  --screenshot=/tmp/shot.png --window-size=1568,880 --hide-scrollbars \
  http://localhost:5173/workbench/<新路由>
```

---

## 10. 错误处理与反馈矩阵（Error Handling & Feedback）

> **规范源**：`docs/error-codes.md` §4「前端统一处理矩阵」——真后端轨下由 `client.ts` 拆包络统一实现 code → 行为映射；本节约束的是**视图/组件层的渲染状态规范**。

### 10.1 五态规范

每个取数区块（页面、面板、卡片、指标条）必须覆盖五种界面状态：

| 状态 | 定义 | 渲染要求 |
| :--- | :--- | :--- |
| **loading** | 请求已发出未返回 | 区块骨架屏或占位，不闪现空数据尖峰 |
| **error** | 请求 reject / 业务 code 非 0 | 面板级错误态 + **显式重试入口**；展示 code 与 trace_id（包络启用后） |
| **empty** | 请求成功但数据为空（含 `code=31004` resolve(null) 场景） | 图表画空坐标轴或空态组件；表格空态行；**不报错、不白屏** |
| **stale** | 刷新失败但存在旧数据 | 保留旧数据渲染，区块角标 stale/「数据未更新」提示 |
| **retry** | error/stale 后的恢复路径 | 重试按钮重发同一请求；成功后回到正常态 |

### 10.2 实现现状（✅ 已实现 — composable + 反馈原语落地）

- **统一封装**：`src/api/useAsyncData.ts::useAsyncData<T>(fetcher)` 返回 `{ data, loading, error, stale, reload }`；`reload()` 内部全捕获**永不 reject**，`onMounted`/`watch`/重试按钮共用其为唯一触发入口；序号闸保证并发重取仅最后一次写态。错误经 `toApiError` 归一化为 `ApiError{ code, message, trace_id }`（error-codes §1 失败包络形状；mock 期 `code=10000`、`trace_id=local-N` 本地序号）。
- **反馈原语**：`WbSkeleton`（loading 占位）、`WbErrorPanel`（错误文案 + code/trace_id + 重试）、`WbEmpty`（空态）、`WbStaleTag`（stale 角标 + 重试），全部 `--wb-*` token 消费；`WbTable` 内置 rows=[] 空态行，`WbStatStrip` 内置 items=[] 空态。
- **接线范围**：首页 7 卡片 + 11 业务视图全部改经 `useAsyncData`；页面/卡片 `data===null` 渲面板级 error/skeleton/empty，`stale` 时页头操作区或列表首行挂 `WbStaleTag`，列表区块空集合局部 `WbEmpty`。图表空数据沿用"画空坐标轴"（`?? []` 兜底）。
- **全局兜底**：`main.ts` 挂 `app.config.errorHandler` 与 `window unhandledrejection`——console 留痕 + `preventDefault` 防裸崩，不吞错。
- **真后端轨下**：`client.ts` 拆包络按 `error-codes.md` §4 矩阵产出 `ApiError`（`code`/`fields`/`trace_id` 透传），视图五态渲染零改动；`api()` 签名与 mock 行为不变。
- **写操作反馈（P3 契约预案）**：写端点错误码按 error-codes §4 矩阵——`33002`/`33104` 冲突类 → 警告提示+相关区块局部刷新；`10002` → 表单内联错（fields 逐字段红标，不弹全局消息）；`20101` → 登录页表单内联；`20104` → 锁定提示+15min 倒计时展示；`20004`/`20005` → 警告提示+停留当前页（无独立 /403 页，面板错误态等价）；表单提交中 loading 复用 `useAsyncData.loading` 或提交按钮本地态。

---

## 11. 设计令牌治理（Design Token Governance）

> **治理专文**：`docs/design-tokens.md`（**已生效**）。分层模型/命名法/治理规则 R1-R7/白名单/门禁命令以专文为准；本文 §5 清单仅作速查。

已落地要点：
1. **统一出处**：`src/styles/tokens.css` = L0 原色 `--p-*`(:root) + L1 语义 `--wb-*(.workbench-layout)`/`--scr-*(.screen-layout)`；`variables.css` 已删除。
2. **收敛成果**：r0 审计 570 散落声明点全量收编——tokens.css 外色值/字号/间距/圆角字面量 0 命中（美术稿白名单除外）。
3. **图表同源**：wb=`chartPresets.ts` 静态表（行内注释标 token）、scr=`scrTokens.ts::readScrPalette()` 运行时读取。

---

## 12. 大屏实现（Big-Screen Implementation，e6aeb52 建成）

> 本节原为"重建规划"。`/screen` 已于 e6aeb52 建成，以下为**建成现状**记录；后续迭代按正常演进流程走（契约先行）。

### 12.1 建成物
- **布局/画布**：`src/layouts/ScreenLayout.vue` —— `.screen-layout` 作用域 + 1920×1080 画布 + 等比缩放适配（resize 监听配对清理）。
- **视图**：`src/views/screen/ScreenView.vue` —— `getScreenSnapshot()` 取数，自管理 loading/error/data 三态（顶部 error-bar + 手动重连，§15 豁免 useAsyncData 登记）。
- **组件族** `src/components/screen/`：`ScrHeader`（院名/时钟/态势/未闭环告警计数，`setInterval` 走秒卸载清理）、`ScrKpiStrip`、`ScrDrgQuadrant`、`ScrCampusMap`、`ScrBuildingBars`（楼宇运行指标条）、`ScrDeptRank`、`ScrAlertFeed`、`ScrTrendTabs`；原语 `ScrPanel`/`ScrChart`/`scrTokens.ts`。
- **样式**：`src/styles/screen.css` 基元 + `--scr-*` 语义令牌（tokens.css `.screen-layout` 块）；ECharts 经 `scrTokens.readScrPalette()` 运行时取色。
- **数据层**：`api/screen.ts::getScreenSnapshot()` + `mock/screen.ts` + `mockResolvers['screen/snapshot']`；锚点自洽（`KPI.value=spark末点` 全量成立；badge 锚定仅限门急诊—门诊楼口径，其余 KPI 非楼级锚定——外科楼 `96% 负荷` 为楼级口径；alert_open 合计=total_open、BASE_DATE=2026-10-28 周三）。

### 12.2 视觉基准与偏离说明
- **基准**：`archive/smart-hospital-cockpit/`（只读参考，未并入代码）。
- **P07 复刻裁决（撤销旧偏离）**：布局改为与基准一致的**院区图垫底 + 浮层面板**（`cover` 满幅 + `.ui-overlay` 叠压），原"规整三栏栅格"偏离作废——用户要求按设计稿 1:1。逆向规格书 `/tmp/screen-spec/spec.md`（外部工作区），差距清单 `/tmp/screen-spec/gap.md`。
- **保留的偏离**：院区底图继续用写实等距渲染图（`_blue` 霓虹夜景版属设计红线禁的荧光风，但 `object-fit` 改 `cover`+暗角对齐基准氛围）；无顶部多视图 tab（契约单快照单视图），中央改态势胶囊+未闭环告警计数。
- **数据→槽位映射**（契约 §14.1 六组数据对基准骨架）：KPI ribbon=4 项 kpi 卡｜左列=「业务趋势」(trends 四序列 tab 切线)+「楼宇运行」(buildings 指标进度条)｜底行=「DRG盈亏×CMI 四象限」(724 宽)+「科室效能榜」(dept_ranking 表)+「实时告警」(alerts 跑马灯)｜中央=院区图+4 楼宇 pin。

### 12.3 演进预留
- 多视图分屏（安防/院感/后勤等 cockpit 形态）如启用 → 先走契约演进（§14 加端点或分屏字段），再按 §9 流程实施。

---

## 13. 演进路线（Evolution Roadmap）

### 13.1 已完成（落地事实）
- **契约类型镜像**：`src/api/types.ts`（527 行）逐节镜像 `api-contract.md` v2.0（含 §14 屏型），全量 snake_case。
- **端点函数层**：`api/workbench.ts` 18 + `api/auth.ts` 2 + `api/screen.ts` 1，**21/21 契约端点全接入**。
- **mock 解析层**：`api/client.ts` + `mock/` 15 文件，`index.ts` 注册表 21 key 全量注册。
- **http 层（双轨）**：`VITE_USE_MOCK=0` 经 vite proxy 接 Go 后端 `/api/v1/<key>`，包络拆解与错误码映射已按 `error-codes.md` §4 落地（HTTP 客户端=原生 fetch，无新依赖，白名单未突破）。
- **视图迁移**：11 业务视图 + 首页 7 卡 + `/screen` 全屏，组件内契约形状数据块清零。
- **五态反馈**：`useAsyncData` + 4 反馈原语 + `main.ts` 全局兜底（§10.2）。
- **大屏建成**：e6aeb52，见 §12。
- **设计令牌**：tokens.css 三层模型落地，散值收敛 0 命中（§11）。
- **壳/资产/类型**：index.html 中立壳、根级孤儿资产清理、`delta_label` 单源、`WbTable` 类型收敛——均已销。

### 13.2 P1 待办（缺陷与缺口）
- **路由缺口**：根级无 catch-all，未知路径渲染空白（§3.1；`/screen` 本身已注册）。

### 13.3 P2 演进项
- **状态管理层（Store Layer）**：引入 Pinia，按业务域建立 `useAuthStore`、`useWorkbenchStore`、`useAlertStore`。**目标形态为 组件 → store → api 单向流**；当前"组件直连 api"为过渡形态，store 落地后页面改为调 Action 取数（时钟偏移亦归 store，AGENTS §2-6）。
- **设置页持久化**：`settings/config` 现为本地展示（开关可点击翻转但无写接口）；契约演进增写端点后接。
- **从静态 Mock 迈向仿真联动**：依据 `docs/simulation-plan.md`，对接后端的 Virtual Clock 虚拟时钟与场景注入器，支持动态警报与快进演算演示。
