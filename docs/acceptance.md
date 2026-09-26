# 验证与验收基线 — EDSS

> 版本：v1.1  
> 回答一个问题：**怎么证明代码符合契约？** 契约冻结的意义在于可机器核对——本文件定义三层验证 + P1 验收清单。

---

## 1. 三层验证体系

### L1 契约冒烟（`backend/test/contract_smoke`，CI 必跑）
对 `api-contract.md §13` 全部端点打一遍 httptest（不落库外部依赖，用 seed 库）：
- 每个响应断言：**包络四字段齐全**（code/message/data/trace_id/ts）、`code` 在错误码注册表内
- 关键端点断言 **data 必填字段**（契约示例 JSON 即 golden fixture，文档里的伪 JSON 注释需先剥离）
- 枚举字段断言值域（§0 附录表为事实源）
- 权限矩阵断言：4 个角色 × 关键端点的 allow/deny 符合 §12（20005/32004 必现）

### L2 数据自洽（`sim validate`，CI + 播种后必跑）
`database-schema.md §12` 全部 8 条，任一失败 = 播种失败。

### L3 页面级冒烟（人工/半自动 checklist，发布前跑）
见 §3 验收清单。

## 2. CI 最小门禁（三件套，不许跳过）

```bash
go vet ./... && go build ./...           # 后端静态检查+编译
npx vue-tsc -b && npm run build          # 前端类型检查+构建（npm 统一）
go run ./cmd/server -seed -validate      # 播种+8条自洽校验
```

PR 含契约改动（`[contract]` 标记）时额外跑 contract_smoke 全套。

## 3. P1 验收清单（"做完怎么算成"）

| # | 验收项 | 判据 |
| :- | :--- | :--- |
| 1 | 首屏 | /screen 2048 画布完整渲染 5 面板；1080p 缩放无黑边、无溢出 |
| 2 | 数据活性 | KPI 数值随 virtual_now 推进增长；趋势图末日=今日值 |
| 3 | 告警链 | /sim/alert-test 注入 → 15s 内面板出现 → 下钻可查 → 督办派发成功 → 行内变"处理中"+徽标消红 |
| 4 | 五级穿透 | 骨科→脊柱微创组→IF15→病例列表→病案详情，每级面包屑可回跳；直接 URL 打开 /case/{id} 面包屑正确重建 |
| 5 | 权限 | viewer 无督办按钮且 /cases 无 case_no；president 可 unmask（审计落 sys_audit_log） |
| 6 | 错误面 | 断网→红条重连；401→登录页；32001→科室页空态；无白屏 |
| 7 | 时钟 | POST /sim/clock 快进到 08:12 → 留观超时告警自然出现（剧本钩子） |
| 8 | 演示剧本 | simulation-plan §8 四步一次走通，无人工补数据 |
| 9 | 契约 | contract_smoke 全绿；types.ts 与 api-contract.md 版本号一致（v1.1） |
| 10 | 重置 | POST /sim/reset 后大屏回"开箱状态"（KPI 回 base_date 值、告警清空重播） |

## 4. 首个可交付 Vertical Slice（开工第 1 刀）

**目标**：最快看到端到端活数据的一条缝——
`migrations+seed → Go骨架(包络/errcode/JWT/healthz) → /screen/snapshot 返回真实聚合 → 前端 /screen 替换一个面板（KpiCards）接真数据`。
其余面板仍硬编码无妨——先验证管线，再横向铺开。

## 5. 联调协议

- **前端先写 types.ts**（契约镜像）→ 后端按 types 实现 DTO → 双向核对；
- 联调期后端可返回契约示例静态 JSON（`/screen/snapshot` 先硬编码）解锁前端开发，仿真器后补；
- 字段争议一律以 api-contract.md 为准，发现文档错 → 改文档升版本 → 再改代码。
