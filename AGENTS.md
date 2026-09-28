# AGENTS.md — 本项目工作方式

> 本文件描述在本项目工作的正确方式。`docs/` 是更高优先级事实源；发现本文件与 `docs/` 矛盾，或文档之间矛盾 → 停下报告，不自行裁决。

## 0. 项目本质

**院长查询与决策支持系统**（演示/作业项目），双形态、单一前端工程：

- **工作台 `/workbench`（主形态）**：浅色医疗专业风格的 Web 管理台，侧栏 11 个业务页 + 首页。院长/主任日常用，重"管"——筛选、下钻、督办、报表。
- **大屏 `/screen`（展示形态）**：深色科技风演示大屏，已按 `archive/smart-hospital-cockpit/` 视觉基准 + 契约 §14 建成（`ScreenLayout` + `ScreenView` + `Scr*` 组件族）。重"看"——宏观态势、告警跑马灯。

**数据供给单轨：前端经 `client.ts` → vite proxy/nginx 打 Go 真后端 `/api/v1/<key>`（39 端点已落地：读 21 + auth 2 + 写 8 + sim 5 + infra 3）——`src/mock/` 已整层摘除，禁止任何假数据兜底；`docs/api-contract.md` 是数据契约**——前端对着它做数据层，换数据源契约与页面不动。

### 0.1 设计资产定位（重要，别搞反）

| 资产 | 定位 |
| :--- | :--- |
| `archive/design/workbench-home.png` | 工作台首页**视觉参考图**——对风格、布局、密度用，不是像素核对唯一标准 |
| `archive/smart-hospital-cockpit/` | 大屏**视觉参考工程**——取其设计语言与交互形态，代码不并入主工程 |
| `src/` 现有前端代码 | **v0 参考实现**：由 AI 复刻+审查 agent 产出，供视觉对照与快速迭代用；**不视为工程基准**。后续重写/整改以 `docs/` 规范为准，发现其违反 §3.4 红线或工程规范时应修复而非照抄 |

**铁律**：`docs/` 规范 > 视觉参考 > 现有代码。三者冲突时按此序裁决（文档矛盾仍停下报告）。

## 1. 事实源顺序

| 优先级 | 文件 | 管什么 |
| :--- | :--- | :--- |
| 1 | `docs/api-contract.md` | 端点、字段名、枚举、单位、null、权限——代码里只出现契约内的端点与字段 |
| 2 | `docs/error-codes.md` | 响应包络、错误码、HTTP 映射 |
| 3 | `docs/frontend-architecture.md` | 路由、布局、设计系统（token/原语）、设计红线、数据纪律 |
| 4 | `docs/architecture.md` | 技术栈白名单、系统拓扑、分期路线 |
| 5 | `docs/simulation-plan.md` | 数据供给分层（组件内→契约层→仿真）、演示 runbook |
| 6 | `docs/acceptance.md` | 验收门禁 |
| 7 | `docs/database-schema.md` | 库表设计（**已实施**：58 表 hospital_edss；演进按"只加列/表/索引"纪律） |
| 8 | `docs/frontend-api.md` | 前端接口使用文档：每端点怎么调、字段怎么用、空错态怎么渲染 |
| 9 | `docs/design-tokens.md` | 设计令牌治理：颜色/字号/间距/圆角唯一出处，token 增改先过本文 |
| 10 | `backend/README.md` | 后端跑法、迁移/种子清单、断言脚本位置 |

## 2. 硬规则

1. **契约演进唯一方式**：新需求 → 先改 `api-contract.md`（加端点或加可选字段）→ 再写代码。已有路径/字段名/枚举值/语义保持原样。
1.1 **文档先行铁律**：任何结构性/接口性/样式性变动 → 先改对应 `docs/` 文档（frontend-api / frontend-architecture / design-tokens）→ 再写代码。文档没改就不允许写码；发现文档与现实矛盾 → 停下报告，先修文档。
2. **包管理一律 npm**：`package-lock.json` 是唯一锁文件。
3. **技术栈白名单制**：只用 `architecture.md §1` 打勾的栈；白名单外的库引入前先问用户。当前已装：`vue3 + ts + vite + vue-router@4 + echarts + lucide-vue-next`；**未装** pinia/element-plus——需要时先确认再装；axios 已定不引入（api 层用原生 fetch）。
4. **文件边界**：`archive/`（全部历史设计参考资产）只读；大屏唯一视觉基准为 `archive/smart-hospital-cockpit/`（旧 `src/components/` 大屏过渡稿已删除，勿再以任何历史稿为基准）。/screen 已建成，迭代按 `frontend-architecture.md` §12 与契约演进流程进行。
5. **密钥只写进 `.env`**（已在 `.gitignore`）。
6. **数据纪律**：视图数据一律经 `src/api/` 端点函数 → `client.ts` → 真后端 `/api/v1/<key>`（**单轨，无 mock**）；字段名对齐契约 snake_case，禁止视图内散落不可对回契约的字段、禁止任何假数据兜底（缺数据走五态空/错态）。目标形态 组件→store→api（Pinia），当前组件直连 api 为过渡态。
7. **commit**：每条信息说明"为什么"；`git status` 里每个文件都能对回用户指令。
8. **agy 产物原则**：AI 复刻 agent（agy/pixel 类）的产出是参考素材，代码工程性不保证——合并前按本文件标准审查，能用的用，不达标的重写。

## 3. 工作方式

### 3.1 写注释

注释写**不读代码就想不到的"为什么"**：业务规则出处、契约节号、非显然取舍。

- 正确示例：`// 院级汇总用 dept_id=0 哨兵键，见 database-schema §dws`
- 函数名已表达的内容不写注释；`TODO` 带责任人和依据：`// TODO(devin): P2 接 SSE，见 simulation-plan §7`
- 判断标准：注释全删后代码依然自解释 = 命名合格

### 3.2 完成定义（汇报照此格式）

"做完" = 五项全过：

1. 功能返回契约形状的**真实数据**（真后端响应；禁假数据兜底）
2. 实际验证过渲染/响应（截图 / curl / 测试）
3. 空数据、null 字段、分页末页、非法参数——各试过一次（有权限体系后加无权限角色）
4. 重跑了相关既有检查
5. 汇报分三栏如实写：**过了什么 / 没过什么 / 没测什么**

分层验证：编译通过 → 能跑 → 符合契约 → 边界正确 → 未破坏既有功能。每向上一层都要重新验证。

### 3.3 数据缺失时的路径

| 情况 | 唯一路径 |
| :--- | :--- |
| API 失败 | 面板/页面错误态 + 重试入口，旧数据标 stale |
| 字段缺失/类型不符 | 修类型定义或数据源，两侧对齐契约 |
| env/配置缺失 | 启动 fail-fast，打印缺失项名 |
| 未知错误码 | 兜底错误提示 + trace_id |
| 接口未实现 | 路由/区块不可达或显式"未接入"态；不造假数据 |
| 图表数据为空 | 画空坐标或空态组件，不报错不白屏 |

### 3.4 改前端（工作台）

- **设计系统唯一入口 `src/styles/workbench.css`**：色值/字号/间距/圆角一律取 `--wb-*` token，改样式先想"是不是 token 该加/改"
- **共享原语优先**：`WbPageHead / WbSeg / WbStatStrip / WbTable / WbChart` + `chartPresets`；新页面用原语拼，不从零写
- **设计红线（违反即返工）**：
  - 禁卡片套卡片、禁圆角矩形堆叠——分区用留白/hairline/表格/列表等手法
  - 禁"AI 感"风格：廉价渐变、滥用发光、风格混搭、不统一的图标/圆角
  - 写实/装饰图片素材用生图产出（png 存 `src/assets/`），不用 SVG 硬画照片感内容
  - 符合医院管理系统场景：专业、克制、高信息密度
- 动共享组件/`workbench.css`/全局样式前：grep 全部消费方，逐个确认影响
- 新页面标准流程：建 `src/views/workbench/XxxView.vue` → `src/router/index.ts` 注册 → WbPageHead + 原语拼装 → 无头截图自验（见 §5）

### 3.5 执行指令

- 任务范围 = 用户字面意思；范围外文件保持原样（含格式、import 顺序）
- 范围模糊 → 先问再动手
- **并行 agent 一律走 herdr**：`herdr tab create` / `herdr pane split` 在当前工作区开 pane 后 `herdr pane send-text` 下发任务、`herdr pane read` / `wait-output` 收报告——双向可观测；**禁用 subagent 工具、禁开原生 Terminal 窗口**（无读回通道，曾致 fix-wb 断连 27 分钟不可见）
- agent 任务书落盘 `/tmp` 后 send 路径，避免终端转义；完工的 pane/tab 及时 `herdr pane/tab close` 清场
- 收尾前：`git status` 逐文件对回指令

### 3.6 简单优先

- 选能满足当前需求的最简写法；一个函数能写完就一个函数
- 扩展点只用文档已设计的：契约可选字段、预留端点、env 矩阵
- 第三次重复才抽象，两次以内直接重复
- 自检："删掉这段代码，当前需求还满足吗？" 满足 → 删

### 3.7 错误处理路径

- 后端：错误 → 错误码映射 → 统一包络；内部细节留服务端日志，客户端只收 code + trace_id
- 前端：接口错误 → http 拦截器 → 统一处理矩阵（error-codes §4）；`try/catch` 只处理本地逻辑
- 每个 `catch` 有明确去向；每个 Promise 有 rejection 处理

## 4. 技术栈要点

### 前端（Vue3 + TS + Vite + VueRouter + ECharts + lucide）

- `src/api/types.ts` 照抄契约 snake_case 字段名
- 数据流单向：组件 → store → api 模块 → http（当前组件直连 api 封装函数）
- 轮询/定时器：`onUnmounted` 里清理；ECharts 卸载时 `dispose()`（`WbChart` 已封装，优先复用）
- 金额/比率渲染先读单位声明
- count-up 等动效只在值真实变化时触发

### 后端（已落地）

- `backend/`：`cmd/server` + `internal/{config,envelope,middleware,clock,router,handler,repo}`；薄查询层 handler→repo→预聚合表（dws/ads/dwd）；39 端点已落地（读 21 + auth 2 + 写 8 + sim 5 + infra 3 根挂），会话/RBAC 生效中
- 响应一律经包络 helper；多表写放事务；唯一时间源 `clock`（`sim.clock.virtual_now`）；包络 `ts` 为传输墙钟字段，豁免业务时钟纪律
- 跑法见 `backend/README.md`（`go run ./cmd/server` :8080；前端 `VITE_USE_MOCK=0 npm run dev` 即真链路）

### 数据库（已实施，58 表 hospital_edss）

- `docs/database-schema.md` 为设计文档；演进按"已建表只加列/表/索引"纪律执行
- 灌库与种子幂等/确定性纪律见 `backend/README.md`

## 5. 交付门禁（结果写进汇报）

```bash
# 前端
npx vue-tsc -b && npm run build

# 页面自验（无头截图，1568×880）
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless \
  --screenshot=/tmp/shot.png --window-size=1568,880 --hide-scrollbars \
  http://localhost:5173/workbench/<路由>

# 后端（在 backend/ 目录跑）
cd backend && go vet ./... && go build ./... && go test -count=1 ./...

# 机械自查（time.Now 豁免清单=传输/运维层墙钟:envelope.go 包络 ts、requestlog.go 延迟计时、
# write_alert.go failData ts(包络冻结故本地实现)、cmd/migrate/main.go 迁移耗时统计;
# clock.go 注释里的"time.Now"字样为文档串,非调用——除此五处命中即违例）
grep -rn "time.Now\|as any\|@ts-ignore" --include="*.ts" --include="*.go" src/ backend/ 2>/dev/null
```

## 6. 拿不准时

1. 先查 `docs/`——90% 的问题已有答案
2. 文档空白或矛盾 → 报告选项给用户选
3. 少做 + 问，优先于多做 + 猜
