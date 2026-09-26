# AGENTS.md — 本项目工作方式

> 本文件描述在本项目工作的正确方式。`docs/` 是更高优先级事实源；发现本文件与 `docs/` 矛盾，或文档之间矛盾 → 停下报告，不自行裁决。

## 0. 项目本质

医院运营决策大屏。前期全靠模拟数据；`docs/api-contract.md` 是冻结契约——前后端各自对着它实现，将来接真实 HIS/ETL **只换数据源，契约与前端不动**。每行代码都为"契约可落地"服务。

## 1. 事实源顺序

| 优先级 | 文件 | 管什么 |
| :--- | :--- | :--- |
| 1 | `docs/api-contract.md` | 端点、字段名、枚举、单位、null、权限——代码里只出现契约内的端点与字段 |
| 2 | `docs/error-codes.md` | 响应包络、错误码、HTTP 映射 |
| 3 | `docs/database-schema.md` | 表结构、约束、指标字典 |
| 4 | `docs/frontend-architecture.md` | Store 边界、路由、点击地图、反馈矩阵 |
| 5 | `docs/simulation-plan.md` | 时钟纪律、生成模型、ETL 切换、演示 runbook |
| 6 | `docs/architecture.md` / `docs/acceptance.md` | 技术栈白名单、验收门禁 |

## 2. 硬规则

1. **契约演进唯一方式**：新需求 → 先改 `api-contract.md`（加端点或加可选字段）→ 再写代码。已有路径/字段名/枚举值/语义保持原样。
2. **包管理一律 npm**：`package-lock.json` 是唯一锁文件。
3. **技术栈白名单制**：只用 `architecture.md §1` 打勾的栈；白名单外的库引入前先问用户。
4. **文件边界**：`output/`、设计稿图片只读；`src/components/*.vue` 视觉稿按 `frontend-architecture.md` 迁移表一次接管一个，接管前保持原样。
5. **密钥只写进 `.env`**（已在 `.gitignore`）。
6. **唯一时间源**：后端一律 `clock.Now(ctx)`，前端时钟读 `useAppStore` 偏移——仿真可复现靠这一条。
7. **commit**：每条信息说明"为什么"；`git status` 里每个文件都能对回用户指令。

## 3. 工作方式

### 3.1 写注释

注释写**不读代码就想不到的"为什么"**：业务规则出处、契约节号、非显然取舍。

- 正确示例：`// 院级汇总用 dept_id=0 哨兵键，见 database-schema §dws`
- 函数名已表达的内容不写注释；`TODO` 带责任人和依据：`// TODO(devin): P2 接 SSE，simulation-plan §7`
- 判断标准：注释全删后代码依然自解释 = 命名合格

### 3.2 完成定义（汇报照此格式）

"做完" = 五项全过：

1. 端点返回契约形状的**真实数据**
2. 实际发过请求并记录响应（curl / 测试 / 浏览器）
3. 空数据、null 字段、分页末页、无权限角色、非法参数——各试过一次
4. 重跑了相关既有检查
5. 汇报分三栏如实写：**过了什么 / 没过什么 / 没测什么**

分层验证：编译通过 → 能跑 → 符合契约 → 边界正确 → 未破坏既有功能。每向上一层都要重新验证。

### 3.3 数据缺失时的路径

契约即边界，缺失数据渲染空态组件：

| 情况 | 唯一路径 |
| :--- | :--- |
| API 失败 | panel 错误态 + 重试按钮（反馈矩阵），旧数据标 stale |
| 字段缺失/类型不符 | 修类型定义或后端响应，两侧对齐契约 |
| env/配置缺失 | 启动 fail-fast，打印缺失项名 |
| 未知错误码 | 兜底错误提示 + trace_id |
| 接口未实现 | 视觉稿占位数据在迁移时删到 grep 不到 |
| `drill.type` 未知 | 隐藏按钮（契约规定动作） |

### 3.4 改前端

- 动共享组件/`variables.css`/全局样式前：grep 全部消费方，逐个确认影响
- 色值/字号/间距一律取 `variables.css` token
- 修复限定作用域：scoped 选择器只覆盖目标面板
- 定位根因后改源头：样式问题改 token 或源选择器
- 组件迁移一次一个，按表走

### 3.5 执行指令

- 任务范围 = 用户字面意思；范围外文件保持原样（含格式、import 顺序）
- 范围模糊 → 先问再动手
- 收尾前：`git status` 逐文件对回指令

### 3.6 简单优先

- 选能满足当前需求的最简写法；一个函数能写完就一个函数
- 扩展点只用文档已设计的：双轨写侧、`drill.type`、可选字段、env 矩阵
- 第三次重复才抽象，两次以内直接重复
- 自检："删掉这段代码，当前需求还满足吗？" 满足 → 删

### 3.7 错误处理路径

- 后端：错误 → 错误码映射 → 统一包络；内部细节留服务端日志，客户端只收 code + trace_id
- 前端：接口错误 → http 拦截器 → 反馈矩阵；`try/catch` 只处理本地逻辑
- 每个 `catch` 有明确去向；每个 Promise 有 rejection 处理；goroutine 错误有回收处

## 4. 技术栈要点

### 后端（Go + Gin + GORM）

- 响应一律经包络 helper——它是唯一出口
- 多表写放事务；`ctx` 透传到 GORM/Redis
- 列表查询用 Preload/JOIN 一次取齐
- tick/批量写走事务；时钟跳变后清相关缓存

### 前端（Vue3 + TS + Pinia）

- `src/api/types.ts` 照抄契约 snake_case 字段名
- 数据流单向：组件 → store → api 模块 → axios
- 轮询：in-flight 去重 + `onUnmounted` 里清 `setInterval`；ECharts 卸载时 `dispose()`
- 金额渲染先读 `unit` 字段（raw=元，聚合按声明单位）
- count-up 等动效只在值真实变化时触发

### 数据库

- 顺序固定：`database-schema.md` → migration → 代码
- 已建表只加列/表/索引，旧列语义不动
- PK 全 NOT NULL；机构级/无组维度用哨兵 `0`

## 5. 交付门禁（结果写进汇报）

```bash
# 前端
npx vue-tsc -b && npm run build
# 后端（代码存在后）
go vet ./... && go build ./... && go test ./... -run Contract
# 数据自洽（代码存在后）
sim validate
# 机械自查（输出应为空）
grep -rn "time.Now\|as any\|@ts-ignore" --include="*.ts" --include="*.go" src/ cmd/ 2>/dev/null
# 契约对齐：端点覆盖率 100%，字段名 diff 为空
```

## 6. 拿不准时

1. 先查 `docs/`——90% 的问题已有答案
2. 文档空白或矛盾 → 报告选项给用户选
3. 少做 + 问，优先于多做 + 猜
