# 总体架构设计 — 院长查询与决策支持系统（EDSS）

> 版本：v2.0（双形态改版基线，替代 v1.1 大屏单一形态基线）
> **核心约束：本项目无真实医院环境，全部数据为模拟数据。`api-contract.md` 是数据契约——前端只依赖契约形状，永不知道数据来自 mock 还是真实后端。**

---

## 0. 产品定位与形态（v2.0 裁决）

对标真实产品（帆软"一库多端"、卫宁 WiNEX、东软 RealOne）：同一数据底座，两种渲染形态。

| 形态 | 路由 | 定位 | 受众/场景 |
| :--- | :--- | :--- | :--- |
| **工作台** | `/workbench/*`（主，`/` 重定向至此） | 浅色医疗专业 Web 管理台：筛选、对比、明细、督办、报表 | 院长/处长/科主任日常办公，近距离高密度 |
| **大屏** | `/screen`（重建中） | 深色科技风演示屏：3D 院区、告警跑马灯、宏观 KPI；视觉基准 `archive/smart-hospital-cockpit/` | 运营中心/会议室/演示，远距离低交互 |

两形态**同一工程、同一数据契约、同一 mock/api 层**，仅表现层不同。顶栏预留模式切换入口。

## 1. 技术栈裁剪决策（对照实际 package.json）

| 组件 | 决策 | 状态/理由 |
| :--- | :--- | :--- |
| Vue3 + TS + Vite | ✅ | 已落地，前端基座 |
| Vue Router 4 | ✅ | 已装，双形态与 11 个子页路由必需 |
| ECharts 5 | ✅ | 已装，全部图表（chartPresets 统一主题） |
| lucide-vue-next | ✅ | 已装，线性图标唯一来源 |
| Pinia | ⚠️ 待装 | 数据层上 store 时需要；现在 mock 直读 |
| axios | ⚠️ 待装 | 接 api/mock 层时需要 |
| Element Plus | ❌ 暂不引入 | 工作台用自研 `--wb-*` 设计体系（表格/表单已覆盖），引入会破坏视觉统一；确需复杂组件时先问用户 |
| Tailwind/样式框架 | ❌ 不引入 | 已有自研 token 体系 |
| Go + Gin + GORM + PG16 + Redis | 📋 目标态（未实施） | 远期真实后端候选；动工前复核——演示期很可能"前端 mock → vite mock plugin/轻量 node mock"就够 |

**当前真实栈**：`Vue3 + TS + Vite + VueRouter + ECharts + lucide`（无后端、无 Pinia、无 axios）。

## 2. 系统拓扑（现状）

```
浏览器 ── Vite dev(:5173)
  ├─ /workbench        工作台：WorkbenchLayout(侧栏+头部) + 12 个 view
  └─ /screen           大屏：重建中（视觉基准 archive/smart-hospital-cockpit；旧过渡稿已删）

数据供给（当前全部前端内）：
  视图组件 ── src/api/*(端点函数) ── client.ts ── src/mock/*(注册表,契约形状)
  目标形态：视图 → store/composable → src/api/* → http(VITE_USE_MOCK 切换)
                          └────── 未来可换成 /api/v1 真后端 ──────┘
```

### 目标拓扑（远期，未实施）

```
浏览器 ── Nginx（/ 静态 + /api 反代）
   ├─ 前端 SPA（不变）
   └─ Go Backend（单体）：handler → service → repository → PG16(+Redis)
        写侧双轨制：Fact Producer(仿真器|ETL) → dwd；Derived Pipeline → dws/ads
```

保留原 v1.1 核心思想：**契约面与数据面分离**——后端可整体替换/后补，前端只认契约 JSON 形状。

## 3. 后端内部结构（目标态，未实施）

原 v1.1 的 Go 单体分层（handler/service/repository + simulator + jobs + 六 schema PG）保留为**目标设计**，详见 v1.1 文档与本目录 `database-schema.md`。**动工前复核**：演示规模很可能不需要全量落地——按 api-contract v2.0 的落地范围做最小实现即可；原设计的 Fact/Derived 双轨、虚拟时钟、告警引擎作为可选项保留。

## 4. 分期路线图（v2.0 实际路线）

| 期 | 内容 | 状态 |
| :- | :--- | :--- |
| P0 | 工作台 12 页 v0 参考实现（agy 复刻+审查产出）+ 设计体系（`--wb-*` token + Wb 原语） | ✅ 已落地 |
| P0.5 | **前端规范化重写**：按 frontend-architecture v2.0 整改 v0 代码；抽 `src/mock/` 集中 mock（字段对齐契约） | ✅ 已落地 |
| P0.6 | **规范验收与令牌统一**：设计令牌（tokens.css）+ 文档先行机制 + /screen 按 cockpit 基准重建 | ⬜ 当前 |
| P1 | store 层落地（组件→store→api）；督办/预警写操作闭环 | ⬜ |
| P2 | 最小后端（或 vite mock server）跑通契约端点；督办/预警写操作闭环 | ⬜ |
| P3 | 五级下钻/病案脱敏/角色权限/仿真时钟（原 v1.1 全量范围，按需裁剪） | ⬜ |

## 5. 安全与合规（演示级）

- 演示期**不做登录/鉴权**（头部"院长"角色为静态展示）；权限/RBAC/脱敏属 P3 远期范围
- 密钥一律 `.env`；演示截图/录屏场景注意不展示真实敏感信息

## 6. 部署

- 当前：`npm run dev`（:5173）本地开发预览
- 演示：`npm run build` + 静态托管即可（纯前端无依赖）
- 后端启用后：恢复 v1.1 的 docker-compose 方案（db+redis+backend+web）
