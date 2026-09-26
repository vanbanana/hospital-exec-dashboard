# 前端架构与交互规范（Frontend Architecture）— EDSS v2.0

> 版本：v2.0（工作台全功能落地与双形态工程基线）  
> 技术栈：Vue 3 + TypeScript + Vite + Vue Router 4 + ECharts 5 + Lucide Vue Next  
> 本文定位：**真实代码与工程结构的事实源**。涵盖目录树、路由表、布局结构、设计系统（Token与原语）、设计红线、Mock数据治理与大屏整合方向。

---

## 1. 系统形态与架构总览

**院长查询与决策支持系统（EDSS）** 采用单一前端工程承载双形态：

| 形态 | 路由入口 | 视觉风格 | 目标场景 | 核心诉求 |
| :--- | :--- | :--- | :--- | :--- |
| **管理工作台（主形态）** | `/workbench` | 浅灰蓝医疗专业风（`#f0f5fc` 系） | 院长/院领导/主任日常桌面端办公 | 重"管"：多维筛选、下钻明细、运营监测、报表表格 |
| **指挥大屏（展示形态）** | `/screen` | 深海蓝科技风（`#021428` 系） | 会议室大屏、指挥调度中心、大厅展示 | 重"看"：宏观态势、三维院区、风险轮播、指标跑马灯 |

工程约束与原则：
- **包管理纯正性**：一律使用 `npm`，`package-lock.json` 是唯一有效锁文件。
- **依赖白名单制**：仅启用 `vue3 + ts + vite + vue-router@4 + echarts + lucide-vue-next`。不引入 Element-Plus，UI 原语由设计系统内生支撑。

---

## 2. 真实目录结构（Directory Structure）

```
src/
├── App.vue                         # 顶层 Router 容器（router-view 根挂载）
├── main.ts                         # 应用入口：注册 Router，加载 index.css 与 workbench.css
├── layouts/                        # 布局架构层
│   └── WorkbenchLayout.vue         # 工作台标准布局（左侧固定导航 + 右侧 Header 与滚动区）
├── router/                         # 路由配置
│   └── index.ts                    # 路由定义表（/ 重定向、/workbench 嵌套路由、/screen）
├── styles/                         # 样式系统
│   ├── index.css                   # 全局重置、深色大屏基础变量与过渡类
│   ├── variables.css               # 大屏变量体系 + 跨形态共享字体 Token（--font-family-base/number）
│   └── workbench.css               # 工作台设计令牌（--wb-*）与全局共享 CSS 基元
├── components/                     # 组件层
│   ├── workbench/                  # 工作台专属组件库
│   │   ├── WbPageHead.vue          # [原语] 页面标题与操作区
│   │   ├── WbSeg.vue               # [原语] 分段选择器（Segmented Control）
│   │   ├── WbStatStrip.vue         # [原语] 紧凑指标条（Hairline 竖线分隔）
│   │   ├── WbTable.vue             # [原语] 医疗业务数据表格（插槽支持）
│   │   ├── WbChart.vue             # [原语] ECharts 响应式容器（ResizeObserver 封装）
│   │   ├── chartPresets.ts         # [原语] 工作台统一图表主题、色板与轴预设
│   │   ├── WorkbenchHeader.vue     # 工作台顶部栏（系统名、搜索、铃铛、头像、日期）
│   │   ├── WorkbenchSidebar.vue    # 工作台左侧栏（品牌Logo、12项功能菜单、底纹院训）
│   │   ├── WorkbenchHero.vue       # 首页 Hero 横幅（标语阶梯、医院实景、毛笔书法）
│   │   ├── WorkbenchKpiCards.vue   # 首页 5 张核心 KPI 统计卡
│   │   ├── TrendChartCard.vue      # 首页医疗业务趋势折线图
│   │   ├── DepartmentTop10Card.vue # 首页科室业务量 TOP10 进度卡
│   │   ├── KeyIndicatorsCard.vue   # 首页医院运营关键指标卡
│   │   ├── WorkProgressCard.vue    # 首页重点工作推进进度卡
│   │   ├── RiskAlertsCard.vue      # 首页风险预警等级卡
│   │   └── NoticesTodosCard.vue    # 首页通知与待办事项卡
│   ├── CampusMap.vue               # [过渡大屏] 3D 院区建筑点位图
│   ├── DepartmentRanking.vue       # [过渡大屏] 科室运营排行
│   ├── DrgDipAnalysis.vue          # [过渡大屏] DRG/DIP 四象限散点图
│   ├── HeaderBanner.vue            # [过渡大屏] 顶部科技感标题与时钟
│   ├── KpiCards.vue                # [过渡大屏] 4 张深色关键卡片
│   ├── TrendCharts.vue             # [过渡大屏] 底部趋势图
│   ├── ValuePillars.vue            # [过渡大屏] 战略支柱装饰面板
│   └── WarningAlerts.vue           # [过渡大屏] 动态告警列表
├── views/                          # 页面视图层
│   ├── ScreenView.vue              # 过渡深色大屏视图（2048×1152 居中等比缩放）
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
├── assets/                         # 静态资源
│   ├── campus_3d.png               # 大屏 3D 院区图
│   ├── hospital_logo.svg           # 大屏顶部 HeaderBanner 引用矢量院徽
│   ├── hospital_logo.png           # 默认院徽（未引用孤儿资产，待清理）
│   └── workbench/                  # 工作台 AI 生成写实素材（严禁用 SVG 手搓）
│       ├── hospital_logo.png       # 权威深海蓝月桂叶白十字官方院徽（WorkbenchSidebar 引用）
│       ├── hero_building.png       # 现代门诊综合楼仰拍实景（带透明羽化渐变）
│       ├── building_sketch.png     # 医院主楼正立面蓝图线描（底栏半透明水印）
│       ├── director_avatar.png     # 资深院长专业西装肖像（圆形头像）
│       ├── slogan_col1.png         # 「人民至上」透明底真迹毛笔书法
│       ├── slogan_col2.png         # 「生命至上」透明底真迹毛笔书法
│       ├── slogan_col3.png         # 「健康至上」透明底真迹毛笔书法
│       └── calligraphy_slogan.png  # 历史单幅横版书法（未引用孤儿资产，待清理）
└── mock/                           # [目标演进] 集中契约 Mock 数据源（按节划分）
```

---

## 3. 路由体系与导航表（Router Matrix）

### 3.1 路由架构设计
- 根路径 `/` 永久重定向到工作台主入口 `/workbench`。
- 工作台统一由 `WorkbenchLayout.vue` 承载，内部声明 `<router-view />` 承接所有子页面。
- 除首页 `HomeView` 直接导入外，其余 11 个业务 View 全部采用 `() => import(...)` 懒加载机制，实现物理分包。
- 导航栏 `WorkbenchSidebar.vue` 采用 `router-link` 的 `custom v-slot` 驱动高亮，完全基于 `isActive` 与 `isExactActive` 状态渲染激活效果。

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
| `/workbench/:pathMatch(.*)*` | — | 重定向到 `/workbench` | 静态 | 404 兜底回落 |
| `/screen` | `Screen` | `views/ScreenView.vue` | 同步加载 | 深海蓝过渡大屏（2048×1152 居中等比自适应缩放） |

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
   - 高度固定 `64px`，顶层悬浮对齐，右侧排布圆角药丸搜索输入框（`320px` 宽）、消息提醒铃铛（带红色未读角标）、院长个人信息展示区（包含头像、角色称谓与折叠角标，当前为静态展示，无交互下拉菜单）以及标准中文日期（演示期硬编码为 `2024年10月28日 星期一`）。
3. **滚动工作区（`WorkbenchLayout.vue .workbench-scroll`）**：
   - 采用弹性自适应高度 `flex: 1; min-height: 0; overflow-y: auto;`。
   - 统一页面级外边距与纵向节奏：`padding: 2px 16px 14px;`。
   - 自定义 `6px` 极简半透明滚动条，保障视觉纯净度。

---

## 5. 设计系统规范（Design System v2.0）

设计系统主入口为 `src/styles/workbench.css`。CSS 变量 Token 定义限定于 `.workbench-layout` 作用域下，杜绝与大屏深色样式冲突；公共 UI 原语与工具类采用 `.wb-*` 统一前缀进行全局命名隔离。

### 5.1 CSS 变量 Token 清单（真实代码映射）

#### 色彩令牌（Color Tokens）
```css
--wb-bg: #f0f5fc;            /* 页面主背景（浅灰蓝） */
--wb-surface: #ffffff;       /* 面板卡片底色（纯白） */
--wb-sidebar-bg: #f1f6fd;    /* 侧边栏专属底色 */
--wb-border: #e4ecf7;        /* 面板外描边 */
--wb-hairline: #edf2f9;      /* 面板内细微水平/竖向分割线 */
--wb-input-border: #d6e2f0;  /* 表单与输入框边框 */
--wb-hover-bg: #f4f8fe;      /* 表格行 hover / 浅色底纹 */

--wb-navy: #0b1f47;          /* 系统主标题、重点大数字、关键高亮文字 */
--wb-primary: #1d4ed8;       /* 交互强调色（链接悬浮、选中项文字） */
--wb-accent: #2563eb;        /* 品牌核心主色（按钮填充、图表主线） */
--wb-accent-soft: #eaf1fe;   /* 强调色浅色背景衬底 */

--wb-text-1: #1e293b;        /* 正文主文本色（深蓝灰） */
--wb-text-2: #475569;        /* 次级文本、指标描述 */
--wb-text-3: #64748b;        /* 辅助说明、轴标、时间戳 */
--wb-text-4: #94a3b8;        /* 失效/占位符文本 */

--wb-up: #ef4444;            /* 环比上升/告警高危（红） */
--wb-down: #059669;          /* 环比下降/正向好转（绿） */
--wb-green: #059669;         /* 达标状态、安全标识 */
--wb-teal: #0d9488;          /* 医疗健康辅助色 */
--wb-amber: #d97706;         /* 重点关注、中度预警 */
--wb-red: #ef4444;           /* 高危异常、重要待办 */
```

#### 跨形态共享字体令牌（定义于 variables.css :root）
```css
--font-family-base: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "PingFang SC", "Hiragino Sans GB", "Microsoft YaHei", sans-serif;
--font-family-number: "DIN Alternate", -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
```

#### 间距、圆角与阴影令牌（Metric & Geometry Tokens）
```css
--wb-radius-card: 10px;      /* 面板外层主圆角 */
--wb-radius-inner: 6px;      /* 内部容器、表头端角 */
--wb-radius-tag: 4px;        /* 状态胶囊标签圆角 */
--wb-gap: 12px;              /* 栅格全局统一间距 */
--wb-pad-x: 16px;            /* 面板内部水平内边距 */
--wb-pad-y: 14px;            /* 面板内部垂直内边距 */
--wb-shadow-card: 0 1px 3px rgba(15, 23, 42, 0.04); /* 面板超轻量弥散阴影 */
```

#### 字体阶梯规范（Typography Scale）
| 阶梯层级 | 字号 | 字重 | 样式来源 | 典型应用场景 |
| :--- | :--- | :--- | :--- | :--- |
| **Hero 标语** | 24px - 26px | 700 Bold | `slogan-line`（`WorkbenchHero.vue` Scoped 类） | 首页横幅核心口号 |
| **核心指标大数** | 22px - 25px | 700 Bold | `.wb-stat-value`, `.wb-num`（`workbench.css` 全局基元类） | KPI 卡片数值、统计大指标 |
| **页面大标题** | 18px | 700 Bold | `.wb-page-title`（`workbench.css` 全局基元类） | 各二级页顶栏主标题 |
| **面板区块标题** | 15px | 700 Bold | `.wb-panel-title`（`workbench.css` 全局基元类） | 卡片头部标题（带竖直 Accent 装饰线） |
| **正文/菜单/表单**| 13px - 14px | 500 Medium | `.wb-table`（全局基元类）, `.nav-item`（`WorkbenchSidebar.vue` Scoped 类） | 表格单元格、侧栏导航、正文说明 |
| **辅助说明/副标题**| 12px | 400 Regular | `.wb-panel-sub`, `th`（全局基元类） | 图表单位、表头列名、次级说明 |
| **状态标签/微备注**| 11px | 500 Medium | `.wb-tag`（全局基元类）, `axisLabel`（`chartPresets.ts` 常量） | 胶囊状态签、ECharts 坐标轴刻度 |

> [!NOTE] 共享基元未 Token 化字面量说明  
> 共享基元层存在少量未 Token 化的字面色（如表头底色 `#f8fafd`、状态标签底色系 `#e8f6ee`/`#feecec`/`#fdf3e3`/`#eef2f7`、分段控制器底色 `#eef3fa`、开关未激活态 `#cbd5e1`、进度条底色 `#f1f5f9`），已列入 P0.5 阶段 Token 化整改计划，在验收中基元内部样式予以豁免。

---

## 6. 共享原语组件库（Shared Primitives）

工作台杜绝从零堆砌样式，所有页面必须由以下 5 个共享原语组装拼装：

### 6.1 `WbPageHead.vue` — 统一页头
- **定位**：页面最顶部的标准化标题栏。
- **Props**：
  - `title: string`（必填，页面主标题，如"医疗业务"）
  - `sub?: string`（选填，数据范围与统计口径说明）
- **Slots**：
  - `default`：右侧操作插槽，通常放置时间范围分段器 `WbSeg`、条件过滤下拉或刷新按钮。
- **用法示例**：
```html
<WbPageHead title="医疗业务" sub="门急诊 · 住院 · 手术明细分析 · 数据截至 2024-10-28">
  <WbSeg v-model="bizTab" :options="['门急诊', '住院', '手术']" />
  <WbSeg v-model="range" :options="['本月', '本季', '本年']" />
</WbPageHead>
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
  - `items: WbStatItem[]`（必填）
- **接口类型**：
```ts
export interface WbStatItem {
  label: string            // 指标名称，如"门急诊总人次"
  value: string | number   // 格式化后的数值，如"12,482"
  unit?: string            // 单位，如"人次"、"万元"、"%"
  delta?: string           // 环比浮动量，如"+3.6%"
  dir?: 'up' | 'down' | 'flat' // 浮动方向，决定红/绿/灰箭头上色
  deltaLabel?: string      // 浮动描述标签，缺省默认"较上月"
  note?: string            // 无浮动时的替代说明文本
  icon?: string            // 图标标识（展示提示，可选）
  tone?: 'default' | 'warn' | 'alarm' // 表现层色调倾向（展示提示，可选）
}
```

### 6.4 `WbTable.vue` — 业务数据表格
- **定位**：高信息密度、浅底色表头、支持单元格自定义插槽的高性能表格。
- **Props**：
  - `columns: WbTableColumn[]`（列定义：`{ key, title, width?, align?, num? }`）
  - `rows: Record<string, unknown>[]`（数据源数组）
  - `rowKey?: string`（行唯一标识，默认使用数组索引）
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

## 8. 数据现状盘点与 Mock 治理纪律

### 8.1 现有 12 页面数据区块清单（全组件硬编码现状）

| 页面名称 | 路由路径 | 数据区块 1 | 数据区块 2 | 数据区块 3 | 数据区块 4 |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **首页** | `/workbench` | 5 张顶层 KPI 指标卡（门急诊/出院/手术/收入/床位率） | 业务趋势双折线图（支持门急诊/出院/手术/收入 4 Tab 切换） | 科室业务量 TOP10 水平条形进度卡 | 底部运营关键指标 / 重点工作进度 / 风险预警 / 通知与待办四联卡片 |
| **综合概览** | `/workbench/overview` | 6 项全院核心指标条（门急诊/出院/手术/收入/床位/住院日） | 业务规模与收入双轴趋势图（门急诊柱 × 医疗收入折线） | 收入结构环形占比图（医疗/药品/耗材/检查化验 + 图例列表） | 科室服务量构成 TOP8 进度列表 + 实时在院动态列表（5分钟刷新） |
| **医疗业务** | `/workbench/medical` | 门急诊/住院/手术 3 Tab 动态联动指标条（各 6 项核心指标） | 近 12 个月规模趋势平滑面积折线图（随 Tab 切换人次/台数） | 业务特征分布图（门急诊分时高峰柱 / 住院重点病种柱 / 手术分级环形） | 科室医疗业务明细表（WbTable，按当前 Tab 口径排序展示） |
| **运营管理** | `/workbench/operations`| 6 项收支与费用指标条（医疗总收入/门诊/住院/结余率/次均费用） | 月度收支趋势双轴图（12 个月医疗收入柱 × 收支结余率折线） | 费用控制监测（药耗比、次均费用等 4 项指标对标红线值进度条列表） | 科室运营指标表格（WbTable，收入/结余率/药占比/耗材占比/达标状态） |
| **人力资源** | `/workbench/hr` | 6 项人力资源指标条（在岗职工/执业医师/护士/医护比/高职占比/人员经费） | 人员构成环形占比图（按岗位类别 + 结构明细列表） | 职称结构堆叠柱状图（医师/护理/医技分段梯队） | 重点科室人员配置表（WbTable，编制 vs 在岗、床人比、缺口预警） |
| **科研教学** | `/workbench/research` | 6 项科教指标条（在研课题/新立项/科研经费/SCI论文/住培/继教率） | 近 5 年立项课题与科研经费双轴图（课题数柱 × 经费折线） | 近 5 年论文发表分级堆叠柱状图（SCI / 中文核心 / 统计源期刊） | 重点学科建设进展表（WbTable，学科级别/带头人/课题/经费/进展） |
| **患者服务** | `/workbench/patient` | 6 项患者服务指标条（门诊/住院满意度、投诉/表扬件数、候诊时长、网约率） | 满意度趋势近 6 个月双折线走势图（门诊 vs 住院） | 挂号渠道分布环形占比图（微信小程序/自助机/人工窗口等） | 投诉与表扬记录台账表（WbTable，日期/科室/类型/诉求/状态） |
| **质量与安全** | `/workbench/quality` | 6 项质量安全指标条（甲级病案率/院感率/危急值及时率/不良事件/切口感染/抗生素强度） | 院感发生率趋势平滑双折线图（院感发生率 + I类切口感染率） | 不良事件类型分布水平条形图（跌倒/用药/管路等按频次排序） | 医疗核心制度执行监测表（WbTable，8 项核心制度抽查合格率与环比） |
| **资产与后勤** | `/workbench/assets` | 6 项资产后勤指标条（固定资产总额/大型设备/开机率/库存周转/能耗/工单） | 月度能耗费用平滑折线面积图（近 6 个月趋势） | 物资库存预警列表（周转天数偏长品类与警戒级别标注） | 大型设备使用效益表（WbTable，CT/MRI/DSA 等机时/人次/收入/评级） |
| **对比分析** | `/workbench/compare` | 科室横向对比表（WbTable，业务量/收入/效率/质量 4 维度分段器切换，内嵌水平条形） | 与区域同级医院对标雷达图（6 维度综合评分：本院 vs 区域均值） | 核心指标对标明细表（WbTable，本院值/区域均值/差距差额） | —（本页无顶部 WbStatStrip 指标条，亦无柱状图） |
| **专题分析** | `/workbench/topics` | 4 类专题动态切换专属 5 项指标条（DRG / 医保 / 国考 / 门诊统筹） | 专题趋势与分布分析图（DRG入组率线图 / 医保支出线图 / 国考完成度柱图 / 门诊统筹人次线图） | 专题明细数据监测表（WbTable，重点病组DRG / 险种基金 / 国考核心指标 / 常见慢病统筹） | 4 类专题卡片导航选择器（DRG付费 / 医保基金 / 三级国考 / 门诊统筹） |
| **系统设置** | `/workbench/settings` | 数据源管理表格（WbTable，HIS/LIS/PACS/EMR/HRP 对接状态、延迟与同步时间） | 指标预警阈值配置表（WbTable，5 项指标预警阈值与启用开关） | 用户与权限管理表格（WbTable，用户账号、角色标签、科室授权与启用状态） | 5 项系统偏好表单设置（默认时间范围、数据刷新频率、预警声音、单位缩写、敏感脱敏） |

### 8.2 Mock 数据集中治理纪律
1. **统一抽离目录**：当前分散在各 Vue 组件 `<script setup>` 中的 Mock 数据，后续统一迁移至 `src/mock/` 目录，按业务域分文件拆解（如 `src/mock/medical.ts`、`src/mock/overview.ts` 等）。
2. **命名强行对齐契约**：Mock 数据对象的属性名称**必须全量使用 snake_case**，与 `docs/api-contract.md` 字段完全一致（如 `dept_name`、`bed_use_rate`、`case_cnt`）。禁止在视图中使用私有或随意的驼峰命名。
3. **零成本对接后端**：未来接入 Pinia Store 或真实 Axios 接口时，只需在 Store 中将数据源由 `src/mock/` 切换至 API 请求，组件内部的字段引用保持一行不改。

---

## 9. 新增页面标准开发流程（Standard Playbook）

开发者新增业务分析页面时，必须严格执行以下标准五步，禁止随意发挥：

```
[步骤 1: 创建视图]
创建 src/views/workbench/XxxView.vue

[步骤 2: 注册路由]
在 src/router/index.ts 的 /workbench children 数组中追加懒加载路由

[步骤 3: 挂载导航]
在 src/components/workbench/WorkbenchSidebar.vue 的 menuItems 数组中添加导航菜单与 Lucide 图标

[步骤 4: 规范拼装]
使用共享原语组装界面：
<WbPageHead> -> <WbStatStrip> -> 面板栅格（.wb-grid-2-1 等） -> <WbChart> / <WbTable>

[步骤 5: 交付门禁验证]
运行构建检查与无头截屏对比（必须与 acceptance.md 门禁一致）：
npx vue-tsc -b && npm run build
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless \
  --screenshot=/tmp/shot.png --window-size=1568,880 --hide-scrollbars \
  http://localhost:5173/workbench/<新路由>
```

---

## 10. 大屏侧说明与整合规划（Big-Screen Cockpit）

### 10.1 现状与过渡定位
- 当前工程中的 `src/views/ScreenView.vue` 以及根下 `src/components/*.vue` 为**过渡旧稿**。
- 其采用固定 `2048×1152` 坐标系与组件内联 scale 等比缩放实现（未抽 composable），承载深蓝色旧版综合监控画面，供既有演示备用，在正式重构前保持原样。

### 10.2 目标形态：`smart-hospital-cockpit/`
本仓库根目录下的 `smart-hospital-cockpit/` 为大屏专属的**设计参考工程**，确立了下一代指挥大屏的视觉语言与模块形态：
- **安防态势（`SecurityView.vue`）**：CCTV 实时视频流抓拍、重点区域红外报警、院区巡更动态。
- **综合态势（`OverviewView.vue`）**：立体多层建筑空间堆叠切片、全院实时客流热力。
- **院感防控（`EpidemicControlView.vue`）**：三维疾病画像光球、发热门诊流调预警、聚集性感染风险态势。
- **智慧后勤（`LogisticsView.vue`）**：后勤设备物联机房、能耗管网拓扑、智慧电梯与被服流转监控。

### 10.3 整合实施路线
1. **解耦设计资产**：提取 `smart-hospital-cockpit/public/assets/` 中的高精模型渲染素材并规整到主工程。
2. **样式隔离**：大屏所有科技风样式收敛至专属命名空间（如 `.screen-cockpit-root`），严禁污染工作台。
3. **路由重构**：将过渡版 `ScreenView.vue` 平滑升级为下一代智慧医院数字孪生驾驶舱，统一在 `/screen` 路由下运行。

---

## 11. 下一步演进路线（Evolution Roadmap）

1. **接口与契约层（API Layer）**：
   - 建立 `src/api/types.ts`，逐行镜像 `docs/api-contract.md` 契约结构。
   - 建立 `src/api/http.ts`，基于 Axios 封装统一包络拆解、全局超时与错误码矩阵映射。
2. **状态管理层（Store Layer）**：
   - 引入 Pinia，按业务域建立 `useAuthStore`、`useWorkbenchStore`、`useScreenStore` 与 `useAlertStore`。
   - 页面由直读本地状态演进为调用 Store Action。
3. **从静态 Mock 迈向仿真联动**：
   - 依据 `docs/simulation-plan.md`，对接后端的 Virtual Clock 虚拟时钟与场景注入器，支持动态警报与快进演算演示。
