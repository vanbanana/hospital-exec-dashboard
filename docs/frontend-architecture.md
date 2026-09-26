# 前端架构与交互上下文（Frontend ctx）— EDSS

> 版本：v1.1（契约冻结基线）
> Vue3 + TS + Vite + Pinia + VueRouter + ElementPlus + ECharts。
> 本文冻结：**路由表、Store 边界、每个可点元素的跳转与反馈**。组件视觉归设计线（output/ 文档），本文只管"数据从哪来、点了去哪、失败怎么报"。

---

## 1. 目录结构

```
src/
├── api/                    # ★ 契约层——文件与后端 handler 一一对应
│   ├── http.ts             #   axios 实例+拦截器（错误码矩阵见 error-codes.md §4）
│   ├── types.ts            #   契约 DTO 的 TS 镜像（与 api-contract.md 逐字段一致）
│   ├── auth.ts  screen.ts  metric.ts  drg.ts  dept.ts
│   ├── alert.ts  todo.ts   campus.ts  staff.ts  case.ts  sim.ts  hospital.ts
├── stores/                 # Pinia（见 §3）
├── router/                 # 路由表+守卫（见 §4）
├── views/                  # 路由页面
│   ├── ScreenView.vue          /screen 大屏
│   ├── LoginView.vue           /login
│   ├── MetricDetailView.vue    /metric/:code
│   ├── MetricDictView.vue      /metrics
│   ├── DeptRankingView.vue     /depts/ranking
│   ├── DeptCockpitView.vue     /dept/:id
│   ├── DeptGroupsView.vue      /dept/:id/groups
│   ├── DrgAnalysisView.vue     /drg
│   ├── DrgGroupsView.vue       /drg/groups
│   ├── CaseListView.vue        /cases
│   ├── CaseDetailView.vue      /case/:id
│   ├── AlertListView.vue       /alerts
│   ├── AlertDetailView.vue     /alerts/:id
│   ├── TodoListView.vue        /todos
│   └── ErrorView.vue           /403 /404
├── components/             # 大屏面板（设计线已有）+ 下钻页通用件
│   └── common/             #   PageState(loading/empty/error)、MetricCard、DrillBreadcrumb、LevelTag
├── composables/            # usePolling(fn,ms)、useScale、useWatermark、useCountUp
├── directives/             # v-permission
└── utils/                  # format(万元/百分比)、enum-maps(level→颜色/文案)
```

---

## 2. HTTP 层（http.ts 契约）

```ts
// 拦截器职责（实现一次，全局生效）：
// req:  Bearer token 注入
// resp: 拆包络 → code===0 resolve(data)；否则按错误码矩阵分发
//   20002 → refresh 单例队列重放；20001/20003 → auth.logout()→/login
//   20004 → /403；10002 → 抛 FormError(fields)；其余 → ElMessage + 抛 ApiError(code,traceId)
// 约定：api 函数全部返回 data 本体，页面只见数据不见包络；
//   trace_id 由后端生成，前端仅随报错日志/用户反馈渠道上送（无专用反馈端点）
// 超时：请求 timeout=10s；超时计入 sectionError（防"在飞未完成永久跳轮"）
export function get<T>(url: string, params?: object): Promise<T>
```

**环境**：dev `vite proxy /api→localhost:8080`；prod nginx 同源反代。**禁止硬编码 baseURL 域名**，统一 `import.meta.env.VITE_API_BASE`（默认 `/api/v1`）。

---

## 3. Pinia Store 边界

| Store | 状态 | 动作 | 消费方 |
| :--- | :--- | :--- | :--- |
| `useAuthStore` | user, token, permissions | login/logout/refresh/hasPerm | 守卫、指派按钮、水印 |
| `useScreenStore` | sections 数据映射、loading、**sectionError: Record<name,ApiError\|null>**、**sectionUpdateAt: Record<name,number>** | `loadSnapshot()`、`refreshSection(name)`（映射表见 §3.1）；**分档轮询：status=15s，其余=30s** | ScreenView 非告警面板 + **Header 状态胶囊** |
| `useAlertStore` | list, totalOpen, filters, detail | fetch/ack/dispatch/close，15s 轮询 | **预警面板、楼宇徽标、/alerts（告警列表数据的唯一消费方）** |
| `useDrillStore` | crumbStack[{label,path,params}] | push/pop/reset/**rebuildFromEntity**（直接 URL 进入时由当前页实体反推面包屑，依赖契约 dept_id/group_id 字段） | DrillBreadcrumb |
| `useMetricStore` | dict cache, detail cache | dict 一次性加载、detail 按 code 缓存 5min | /metrics、/metric/:code |
| `useAppStore` | globalLoading、hospitalProfile、watermarkText、serverTimeOffset、clockSpeed | profile 加载、水印、服务器时钟偏移（对齐 virtual_now） | HeaderBanner、App 根组件 |

**纪律**：组件只调 store 动作，不直接 import api/*（纯展示纯容器组件可例外传入 props）。**store 内不弹消息**——错误由 http 层统一弹，store 只写 sectionError 供面板画"数据过期"角标。
**单一消费方规则**：预警面板只读 `useAlertStore`（15s 轮询为准）；snapshot.alerts 仅首屏冷启动填充告警 store，之后不再消费。**联动规则**：告警 mutation（ack/dispatch/close）成功后同步调 `screenStore.refreshSection('buildings'|'status')`，楼宇徽标与胶囊即时消红，不等轮询。

### 3.1 refreshSection → 端点映射（冻结）

| section | 端点 |
| :--- | :--- |
| status | GET /screen/status |
| kpis | GET /metrics/today |
| drg | GET /drg/quadrant |
| ranking | GET /departments/ranking?limit=10 |
| buildings | GET /campus/buildings |
| trends | GET /metrics/trend ×4 |
| alerts | （由 useAlertStore 自刷，不经 screenStore） |

section 名与 snapshot 键名映射：`status→status`、`kpis→kpis`、`drg→drg_quadrant`、`ranking→dept_ranking`、`buildings→buildings`、`trends→trends`。
`appStore.clockSpeed` 仅在 sim 模式由 snapshot 可选字段 `clock.speed` 供给，prod 恒 1。

---

## 4. 路由表与守卫

```ts
{ path: '/login',   meta: { public: true } }
{ path: '/',        redirect: '/screen' }
{ path: '/screen',  meta: { perm: 'screen:view', layout: 'blank' } }
{ path: '/metric/:code',   meta: { perm: 'screen:view', title: '指标详情' } }
{ path: '/metrics',        meta: { perm: 'screen:view', title: '指标字典' } }
{ path: '/drg',            meta: { perm: 'screen:view', title: 'DRG/DIP分析' } }
{ path: '/drg/groups',     meta: { perm: 'screen:view', title: '病组列表' } }   // query: dept_id,quadrant
{ path: '/depts/ranking',  meta: { perm: 'screen:view', title: '科室排名' } }   // 独立前缀 /depts，天然避让 /dept/:id
{ path: '/dept/:id',       meta: { perm: 'screen:view', title: '科室驾驶舱' } }
{ path: '/dept/:id/groups',meta: { perm: 'screen:view', title: '医疗组' } }
{ path: '/cases',          meta: { perm: 'case:view',  title: '病例列表' } }   // query: dept_id,drg_code,flag
{ path: '/case/:id',       meta: { perm: 'case:view',  title: '病案详情' } }
{ path: '/alerts',         meta: { perm: 'alert:view', title: '预警与待办' } }
{ path: '/alerts/:id',     meta: { perm: 'alert:view', title: '告警详情' } }
{ path: '/todos',          meta: { perm: 'todo:view', title: '督办工单' } }
{ path: '/403', '/404', meta: { public: true } }
{ path: '/:pathMatch(.*)*', redirect: '/404' }
```

**守卫**：无 token→/login?redirect=to.fullPath；有 token 无 user→先 profile 恢复；`meta.perm` 不满足→/403；**已登录访问 /login → redirect=/screen**。**登录成功后读取 `route.query.redirect` 跳回原页，缺省 /screen**。大屏与下钻页共享 session；大屏用 `layout:'blank'`（无侧边栏），下钻页用管理台布局（顶栏+面包屑+返回大屏悬浮钮）。perm 名与契约 §12 perm 清单一一对应。
**部署注意**：history 模式需 nginx `try_files $uri /index.html` 回退。

---

## 5. ★ 大屏点击→跳转地图（逐一对应设计稿）

| 屏上元素 | 命中域 | 目标/反馈 |
| :--- | :--- | :--- |
| Header 状态胶囊"运行平稳" | 整个胶囊 | → `/alerts?status=open` |
| KPI 卡片（4张） | **整卡可点**（>与卡体同域） | → `/metric/{code}`（卡内 code：OP_DAILY_VISITS/IP_IN_HOSP/BED_USE_RATE/SURG_DAILY_CNT） |
| "＞全部指标" | 链接 | → `/metrics` |
| DRG 面板"＞查看详情" | 链接 | → `/drg` |
| DRG 散点（科室点） | 数据点 | → `/dept/{dept_id}`（L1→L2） |
| DRG 图例（内科/外科/医技/**其他** 4 类） | 图例项 | 面板内筛选高亮（**不跳转**；"其他"=nurse+adm 类科室） |
| 楼宇浮标本体（门诊/外科/急诊/医技/**住院部**等病区楼） | 浮标 | 右侧 `el-drawer` 楼宇详情（GET /campus/buildings/{code}）；抽屉内"查看病区"→ `/dept/{wards[].dept_id}` |
| 楼宇徽标（如"留观超时"） | 徽标 | → `/alerts?building={code}&status=open` |
| 非病区楼宇（停车场/行政楼，func_type∈`other`/`adm` 且 metrics={}） | — | **装饰层不响应**（pointer-events:none；**住院部 func_type=inpt 属病区楼，可点**） |
| 地面导览标/指北针/院区底图 | — | 装饰层 `pointer-events:none` |
| 战略支柱 ValuePillars ×4 | — | **装饰不响应**（去掉 hover 上浮误导；如需链接 P2 再定） |
| 科室排名行 | 整行 | → `/dept/{dept_id}`（表头不可排序——排序只在排名页） |
| "＞更多排名" | 链接 | → `/depts/ranking` |
| 预警行本体（非按钮区） | 行 | → `/alerts/{id}`（同"下钻"route 行为） |
| 预警行"下钻"按钮 | 按钮 | **执行 `alert.drill`**：`route`→router.push(path)；`drawer`→本屏抽屉加载 `/alerts/{id}`；`none`/未知→不渲染 |
| 预警行"督办"按钮 | 按钮（v-permission=alert:dispatch） | `el-dialog`（assignee=GET /staff?dept_id+keyword 搜索、deadline、note）→ POST dispatch → 成功：行内→"处理中"+ElNotification；33002→刷新行+warning |
| "＞全部预警" | 链接 | → `/alerts` |
| 底部趋势图（4张） | 图区 | → `/metric/{code}` 对应指标详情 |

**文案统一**：按钮固定为"**下钻 / 督办**"（参考稿口径；组件内"下发"字样统一改为"下钻"，不存在第三个动作）。

### 5.1 下钻页内部点击地图（L2→L5）

| 页面 | 元素 | 目标 |
| :--- | :--- | :--- |
| /dept/:id 科室驾驶舱 | 医疗组行 | → `/dept/{group_id}`（组=level3 dept，复用同一 cockpit 页面结构） |
| /dept/:id | "病组盈亏"区某病组 | → `/drg/groups?dept_id={id}` 该科病组列表 |
| /dept/:id/groups 医疗组 | 组行 | → `/drg/groups?dept_id={group_id}` |
| /drg/groups 病组列表 | 病组行 | → `/cases?dept_id=&drg_code={code}` |
| /cases 病例列表 | 病例行 | → `/case/{id}` |
| /case/:id 病案详情 | "实名调阅"开关（v-permission=case:unmask） | 二次确认弹窗 → GET ?unmask=1 → 展示实名+水印加深 |
| /alerts/:id 告警详情 | "认领"按钮（status=pending） | POST ack → 行内变 processing |
| /alerts/:id | "关闭"按钮（处理完成） | 弹窗填 comment → POST close |
| /alerts/:id | 关联留观行/病例行 | → 对应事实列表（stay 明细抽屉或 /case/{id}） |
| /todos 工单页 | "反馈"按钮（仅指派人或 admin） | 弹窗 status+result_note → POST status |
| 全部下钻页 | DrillBreadcrumb 任一级 | 跳回对应层（drillStore.rebuildFromEntity 支撑直接 URL 进入） |

---

## 6. 反馈规范（用户可感知行为统一）

| 场景 | 规范 |
| :--- | :--- |
| 面板加载 | 骨架屏/面板内 spinner；**不整屏 loading**（大屏分面板自治） |
| 面板数据过期 | 右上角"更新于 HH:mm"变灰 + ⚠ 角标（sectionError[name] 置位），数据不清空 |
| 面板接口失败 | 面板内 error 态"加载失败 [重试]"，不弹全局消息（轮询类静默重试；手动点击类才 ElMessage） |
| 大屏断线 | 顶部细红条"连接中断，重连中 Xs"，指数退避 5s→30s；断线期间轮询挂起；恢复后绿条"已恢复"2s 消失+全量补刷 |
| 轮询并发 | usePolling 用 setTimeout 链（非 setInterval）；在飞请求未完成则跳过本轮；手动刷新与在飞轮询去重；`document.hidden` 暂停、回前台立即补刷一轮 |
| 操作类成功 | ElNotification.success（右上角，2.5s）；状态行内即时更新+`refreshSection` 联动，不等轮询 |
| 操作类失败 | ElMessage.error(message)；409 冲突类额外刷新该实体 |
| 弹窗提交中 | 确认按钮 loading + 禁关闭；10002 的 `fields` 逐项映射到 el-form-item error |
| 楼宇抽屉 | 打开即骨架屏加载；失败显示重试按钮 |
| 空数据 | PageState empty"暂无数据"+icon；图表画空坐标不报错 |
| 按钮防重 | 点击即 loading 至响应结束；10005 附加 3s 冷却 |
| 权限不足 | 按钮 `v-permission` 隐藏（非禁用）；直达 URL 被守卫拦到 /403 |
| 数字动效 | KPI 用 useCountUp 滚动；**仅 value 变化时重滚动**（轮询同值不闪）；涨跌徽标按 `direction` 上色（1→↑绿↓红；-1→↑红↓绿；0→中性蓝） |
| 时钟 | Header 时间 = server_time + 本地偏移每秒自增；sim speed>1 时按 `clock.speed` 倍速自增（P2 可接受漂移） |

---

## 7. 大屏缩放方案（冻结）

2048×1152 设计坐标系（恰 16:9），`useScale`：`transform: scale(min(vw/2048, vh/1152))` 居中；1080p 屏 scale=0.9375 **无黑边**（黑边仅出现在非 16:9 屏）。**所有组件按设计稿绝对像素写，不做响应式**。ECharts `resize` 挂 scale 变化。
**字号下限**：设计稿最小 13px（1080p 有效≈12px）；低于此值（如现有 11px 轴标/徽标）需设计线复核可读性，会议室距离场景慎用 11px。

---

## 8. 类型镜像（types.ts 摘录，与契约同义）

```ts
interface ApiResp<T> { code: number; message: string; data: T; trace_id: string; ts: number }
interface Page<T> { list: T[]; page: number; size: number; total: number }
interface Kpi { code: string; name: string; value: number; unit: string;
  prev_value: number|null; delta_pct: number|null; direction: -1|0|1;
  spark: number[]; status: 'normal'|'warn'|'alert' }
interface DrillCmd { type: 'route'|'drawer'|'none'; path?: string; label?: string }
interface AlertItem { id: number; rule_code: string; level: 'urgent'|'major'|'minor';
  title: string; dept_id: number|null; building: string|null; building_code: string|null;
  occurred_at: string;
  status: 'pending'|'processing'|'done'|'closed'; payload: Record<string,any>;
  drill: DrillCmd; can_dispatch: boolean }
// …其余逐字段对齐 api-contract.md
```

**生成物建议**：`types.ts` 头注释"手工镜像 api-contract.md v1.1，改动需同步"；后期可换 openapi-typescript 生成（预留）。

---

## 9. 依赖清单与工程落地（当前 package.json 缺口）

| 包 | 状态 | 用途 |
| vue / echarts / lucide-vue-next | ✅ 已装 | lucide 用于下钻页图标；大屏沿用现有手绘 SVG 图标风格 |
| vue-router@4 | ⬜ 待装 | 路由 |
| pinia | ⬜ 待装 | store |
| axios | ⬜ 待装 | http 层 |
| element-plus | ⬜ 待装 | 下钻页全量；**大屏仅白名单** Drawer/Dialog/Select/DatePicker/Form/Message/Notification |
| sass | ⬜ 待装 | EP 主题变量定制可选 |
| dayjs | ⬜ 待装 | 时间格式化 |

```bash
npm i vue-router@4 pinia axios element-plus dayjs
npm i -D unplugin-vue-components unplugin-auto-import sass
# 包管理器统一 npm（仓库已有 package-lock.json），不引入 pnpm/yarn
```

**工程落地清单**：
- EP 按需引入：`unplugin-vue-components` 自动按需+样式；大屏 bundle 只解析白名单组件。
- ECharts 按需注册：`echarts/core` + ScatterChart/LineChart + Grid/Tooltip/Legend + CanvasRenderer；自定义主题 `edss-dark` 在 `useChart` composable 内幂等注册。
- `vite.config.ts` 需补 `server.proxy['/api']→http://localhost:8080`（当前文件只有 vue 插件与别名）。
- 路由懒加载：`() => import('@/views/XxxView.vue')`；大屏与下钻页自然分包。
- token 存储：localStorage（双 token）；演示项目接受 XSS 折衷，prod 可升级 httpOnly cookie（契约不变）。挂墙大屏注意 refresh 14d 过期需重登——演示前检查单含"确认 session"。
- 路由 history 模式 + nginx `try_files $uri /index.html`。
- **数字字体内嵌**：设计稿指定 "DIN Alternate"（macOS 字体，Windows 演示机会静默 fallback）——内嵌可替代字体（Oswald/Barlow 等）作 `--font-family-number` 首选。
- **浏览器基线**：Chrome/Edge ≥ 109（Vue3+ECharts modern）；kiosk 场景用 F11 全屏或 `--kiosk` 启动参数。
- **小屏降级**：viewport <1200px 打开 /screen 时显示引导层"请在大屏或 PC 宽屏访问"（不强行渲染 scale≈0.2 的不可读画面）。
- **登录页**：仅 ENV≠prod 时渲染 4 个种子角色一键登录按钮（演示刚需；prod 不渲染）。
- **水印作用域**：登录人 emp_no 全屏浮水印——**含大屏本体**（防拍屏恰是大屏场景刚需）。
- **ErrorView**：/403="无权限访问"+返回按钮；/404="页面不存在"+回大屏。
- **导出入口**：P1 不支持报表导出（浏览器截图兜底），归 P3 月度报告。

## 10. 现有组件迁移表（设计线 → 数据线的接驳点）

| 组件 | 现状 | 改造点 |
| :--- | :--- | :--- |
| KpiCards.vue | 硬编码 4 卡 | `v-for` 绑 store.kpis（code/name/value/unit/delta_pct/spark[]）；涨跌着色按 `direction` 换 `.text-up/.text-down` 硬编码；spark[]→path 生成；整卡 click→/metric/:code |
| HeaderBanner.vue | 硬编码时间/胶囊 | 时钟=appStore.serverTimeOffset 每秒自增；status.level→enum-maps 色/文案/desc；胶囊 click→/alerts |
| CampusMap.vue | 手绘浮标 | buildings[].anchor(%)驱动浮标定位；badge_level→徽标色；浮标/徽标点击分流（§5）；装饰元素 pointer-events:none |
| WarningAlerts.vue | 硬编码 | 行/按钮按 §5 地图；"下发"→"下钻"文案统一；drill.type 驱动按钮；can_dispatch+v-permission 控督办钮 |
| DepartmentRanking.vue | 待建 | 行 click→/dept/:id；表头排序仅排名页开放（屏上不排） |
| DrgDipAnalysis.vue | **手绘 SVG** | **需重写为 ECharts 散点**（点击/图例筛选/resize 依赖 ECharts 能力）——文档承认此返工量 |
| TrendCharts.vue | **手绘 SVG** | **需重写为 ECharts 折线**（同上面板×4 循环） |
| ValuePillars.vue | 装饰 | 定性装饰层：去 hover 误导，pointer-events:none |

## 11. 与模拟数据的衔接（前端视角）

- 前端**永远不知道**数据真假；演示节奏由后端 virtual clock 控制。
- 大屏轮询节奏：snapshot 30s / alerts 15s；页面隐藏（document.hidden）暂停轮询省电。
- 需要"演示剧情"（如快进产生告警）→ 后端 /sim 接口，前端不提供入口（演示者走 API/小工具页 P2）。
