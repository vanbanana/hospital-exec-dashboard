# 总体架构设计 — 院长查询与决策支持系统（EDSS）

> 版本：v2.1（后端落地翻页——双轨数据供给；v2.0 = 双形态改版基线，替代 v1.1 大屏单一形态基线）
> **核心约束：本项目无真实医院环境，全部数据为模拟口径（契约 mock 或种子库）。`api-contract.md` 是数据契约——前端只依赖契约形状，不区分数据来自 mock 还是真实后端。**

---

## 0. 产品定位与形态（v2.0 裁决）

对标真实产品（帆软"一库多端"、卫宁 WiNEX、东软 RealOne）：同一数据底座，两种渲染形态。

| 形态 | 路由 | 定位 | 受众/场景 |
| :--- | :--- | :--- | :--- |
| **工作台** | `/workbench/*`（主，`/` 重定向至此） | 浅色医疗专业 Web 管理台：筛选、对比、明细、督办、报表 | 院长/处长/科主任日常办公，近距离高密度 |
| **大屏** | `/screen`（已建成，e6aeb52） | 深色科技风演示屏：3D 院区、告警跑马灯、宏观 KPI；视觉基准 `archive/smart-hospital-cockpit/` | 运营中心/会议室/演示，远距离低交互 |

两形态**同一工程、同一数据契约、同一 mock/api 层**，仅表现层不同。顶栏预留模式切换入口。

## 1. 技术栈裁剪决策（对照实际 package.json）

| 组件 | 决策 | 状态/理由 |
| :--- | :--- | :--- |
| Vue3 + TS + Vite | ✅ | 已落地，前端基座 |
| Vue Router 4 | ✅ | 已装，双形态与 11 个子页路由必需 |
| ECharts 5 | ✅ | 已装，全部图表（chartPresets 统一主题） |
| lucide-vue-next | ✅ | 已装，线性图标唯一来源 |
| Pinia | ⚠️ 待装 | 数据层上 store 时需要；当前组件直连 api 为过渡态 |
| axios | ❌ 不引入 | api 层已用原生 fetch 落地（client.ts 自拆包络，实测工作正常），axios 不再需要 |
| Element Plus | ❌ 暂不引入 | 工作台用自研 `--wb-*` 设计体系（表格/表单已覆盖），引入会破坏视觉统一；确需复杂组件时先问用户 |
| Tailwind/样式框架 | ❌ 不引入 | 已有自研 token 体系 |
| Go + Gin + GORM + PG16 + Redis | ✅ 已落地（读侧） | `backend/` 读侧 21 端点 + 57 表 hospital_edss 库在跑；写侧督办闭环未做（契约 §15 预留）；Redis 未启用 |
| golang.org/x/crypto（bcrypt） | ✅ 审批已过 | 登录口令安全必需（契约 §2.3 `POST /auth/login` bcrypt 校验）；Go 官方扩展库，`go.mod` 现为 indirect → 使用时转直接依赖，非新增外部库；不引入第三方 auth/JWT 库 |

**当前真实栈**：前端 `Vue3 + TS + Vite + VueRouter + ECharts + lucide`（无 Pinia、无 axios）；后端 `backend/` Go + Gin + GORM + PG15/16（读侧已落地，写侧未做）。

## 2. 系统拓扑（现状）

```
浏览器 ── Vite dev(:5173)
  ├─ /workbench        工作台：WorkbenchLayout(侧栏+头部) + 12 个 view
  └─ /screen           大屏：ScreenLayout + ScreenView + Scr* 组件族（已建成；视觉基准 archive/smart-hospital-cockpit）

数据供给（双轨，client.ts 内 VITE_USE_MOCK 切换）：
  视图组件 ── src/api/*(端点函数) ── client.ts ──┬─ 默认：src/mock/*(注册表,契约形状)
                                                └─ VITE_USE_MOCK=0：vite proxy /api→:8080
                                                    Go 后端 /api/v1/<key> → PG hospital_edss
```

### 生产部署拓扑（远期，未实施）

```
浏览器 ── Nginx（/ 静态 + /api 反代）
   ├─ 前端 SPA（不变）
   └─ Go Backend（单体）：handler → service → repository → PG16(+Redis)
        写侧双轨制：Fact Producer(仿真器|ETL) → dwd；Derived Pipeline → dws/ads
```

保留原 v1.1 核心思想：**契约面与数据面分离**——后端可整体替换/后补，前端只认契约 JSON 形状。

## 3. 后端内部结构（读侧已落地，写侧未做）

**已落地**（`backend/`，详见 `backend/README.md`）：Go 单体 `cmd/server` + `internal/{config,envelope,middleware,clock,router,handler,repo}`——薄查询层 `handler → repo → 预聚合表（dws/ads/dwd）→ 契约 JSON`，读侧 21 端点对接契约 §2–§14；57 表 `hospital_edss` 库（六 schema，迁移+种子见 `database-schema.md` §5）；`sim.clock.virtual_now` 为唯一时间源；包络由 `envelope` 包统一出口。

**未实施**（v1.1 设计保留，按需启用）：写侧 Fact/Derived 双轨（Fact Producer/仿真器 → dwd；Derived Pipeline → dws/ads）、告警引擎、督办写闭环（契约 §15 R04–R08）、Redis。

## 4. 分期路线图（v2.0 实际路线）

| 期 | 内容 | 状态 |
| :- | :--- | :--- |
| P0 | 工作台 12 页 v0 参考实现（agy 复刻+审查产出）+ 设计体系（`--wb-*` token + Wb 原语） | ✅ 已落地 |
| P0.5 | **前端规范化重写**：按 frontend-architecture v2.0 整改 v0 代码；抽 `src/mock/` 集中 mock（字段对齐契约） | ✅ 已落地 |
| P0.6 | **规范验收与令牌统一**：设计令牌（tokens.css）+ 文档先行机制 + /screen 按 cockpit 基准重建 | ✅ 已落地（e6aeb52） |
| P1 | store 层落地（组件→store→api）；督办/预警写操作闭环 | ◐ 组件直连 api 过渡态；写闭环已随 P3-EW 落地 |
| P2 | 最小后端跑通契约端点；督办/预警写操作闭环 | ✅ 已完成（读侧 21 端点 + 写侧 8 端点真 SQL） |
| P3 | 认证会话/RBAC/写侧生命周期/仿真控制面/运维部署件（原 v1.1 裁剪后 P3 范围；五级下钻·病案脱敏归 P3.1 远期） | ✅ 已落地（EA 会话+RBAC、EW 写侧、ES sim、EO 运维） |

## 5. 安全与合规（演示级）

- **认证（P3-EA 已落地）**：`POST /auth/login`/`logout`（契约 §2.3–2.4）= PG 会话表 `sys.user_session` + `edss_sid` HttpOnly Cookie（生产追加 `Secure`）；口令 bcrypt（x/crypto，§1 已批）；登录防爆破 5 次/15min → `20104`（`sys.audit_log` 计数）。`?role=` 双轨语义：读侧保留演示切换（契约 §2.1 注），写侧异名切换限 `admin`/`president` 会话（契约 §15 闸注）。
- **RBAC（端点级，已生效）**：`/workbench/settings/config` 读限 `admin`/`president`（`20004`），§15 写面按角色矩阵放行管理域三角色（`20005`），`/sim/*` 全限 `admin`；数据域 RBAC（`dept_leader` 本科室过滤已实现于工单域闸）与实名脱敏属 P3.1 远期。
- **CORS/TLS**：dev（vite proxy 同源 `/api`→:8080）与 prod（静态托管 + 反代同源）均不实现 CORS 中间件；TLS 在生产反代（Nginx）终结，Go 后端保 HTTP，本地不强制。
- 密钥一律 `.env`；演示截图/录屏场景注意不展示真实敏感信息

## 6. 部署

- 当前：`npm run dev`（:5173）本地开发预览；真链路 `VITE_USE_MOCK=0`（需 `backend/` Go 服务 :8080 + PG hospital_edss，见 `backend/README.md`）
- 演示：`npm run build` + 静态托管即可（mock 轨纯前端无依赖）
- 后端生产部署（远期）：恢复 v1.1 的 docker-compose 方案（db+redis+backend+web）

**端口归一（P3 登记）**：

dev 形态（本机）：

| 端口 | 用途 | 必开 | 备注 |
| :--- | :--- | :--- | :--- |
| 5173 | vite dev 唯一 canonical（mock 与真链路同端口） | ✅ | 5174/5175 = 占用时 vite 自动递增漂移，非受配端口 |
| 8080 | Go API | 真链路时 | `PORT` env |
| 5432 | 本地 PG | 真链路时 | brew postgresql@15/16 |
| — | vite proxy `/api`→`localhost:8080` | — | target 硬编码于 `vite.config.ts` |

prod 形态（静态托管 + 反代，远期）：

| 端口 | 用途 | 暴露面 |
| :--- | :--- | :--- |
| 80/443 | 反代（Nginx）：`/` 静态 SPA + `/api` 反代后端；TLS 终结 | 公网唯一入口 |
| 8080 | backend | 内网；可选 `127.0.0.1:8080` 调试透出 |
| 5432 | postgres | 仅内网，不 publish |
