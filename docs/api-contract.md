# API 契约 — 院长查询与决策支持系统 (EDSS)

> **版本**：v2.0（双形态基线，替代 v1.1）  
> **制定日期**：2026-09-26  
> **基线状态**：面向"工作台优先（/workbench 12 视图）+ 科技大屏（/screen 辅助态势）"双形态架构。当前处于前端组件内 mock 向集中 `src/mock` + `src/api` 统一接口层演进阶段，后端（Go 单体）为远期目标态。  
> **演进纪律不变**：字段只增不删不改名、枚举只增不改语义；新需求先改本契约再写代码。

---

## 0. 版本演进与范围裁决声明

### 0.1 为什么升级到 v2.0？（范围裁决理由）
1. **形态重心转移**：原 `api-contract v1.1` 完全围绕“单一大屏（/screen）+ 五级下钻弹窗（L1~L5）”展开；但真实产品实践表明，院长与管理部门 90% 的日常决策发生于 **PC 浅色工作台**（高信息密度、多维交叉报表、全业务域监控），大屏更偏向指挥中心与会议汇报。系统已正式演进为**“/workbench 浅色工作台（12页为主）+ /screen 科技大屏（为辅）”**的双形态架构。
2. **落地阶段匹配**：前端 12 个工作台视图（`src/views/workbench/*.vue`）已全部经 `src/api/` 端点函数 + `src/mock/` 注册表按本契约取数；大屏视图（`/screen`）正在按 `archive/smart-hospital-cockpit/` 视觉基准重建，旧过渡稿已删除。v2.0 契约持续约束两侧实现。
3. **认证与交互务实降级**：在纯演示与前端解耦阶段，强制要求 JWT 双 Token 轮换、黑名单拦截会产生大量非核心工程阻塞。v2.0 将认证降级为**“免密/可选角色切换”**的轻量模式，前端可通过下拉框切换院长、运营主任、科主任三种身份。

### 0.2 与原 v1.1 契约的关系（继承、重构与预留）
- **100% 继承的核心资产**：
  - 统一响应包络（Envelope）：`{ code, message, data, trace_id, ts }`；
  - 错误码注册表：严格沿用 `docs/error-codes.md`（1xxxx 通用、2xxxx 认证权限、3xxxx 业务）；
  - 枚举体系与单位换算纪律：金额规范（聚合层万元、明细层元）、率值规范（百分数或纯小数）。
- **重构扩充的主体内容**：
  - 依照 12 个真实工作台页面（首页、概览、医疗、运营、人力、科研、患者、质量、资产、对比、专题、设置）及科技大屏，建立对应域的 `GET` 端点，每个端点字段与前端组件的卡片、图表、表格完全对齐。
- **降维至预留清单的远期能力**：
  - 原 v1.1 中设计较重但当前组件未实际联动的能力（如：L5 病历底层结构化 JSON 与实名解密验密、工单派发/办理写操作、`/sim/*` 虚拟时钟与演示故障注入），统一归整至**第 15 节《远期预留端点清单》**，仅保留路由、请求方法与用途定义，不占用主体篇幅。

---

## 1. 契约通用约定与响应包络

### 1.1 统一包络规范（继承自 error-codes.md）
所有接口返回必须经由统一包络封装：

```json
{
  "code": 0,
  "message": "ok",
  "data": { },
  "trace_id": "req-7f8a9b0c1d2e",
  "ts": 1758153000
}
```

- `code`：业务状态码。`0` 表示成功；非 0 参照既有错误码规范。列表为空时仍返回 `code=0` 且 `data.list=[]`。
- `message`：人类可读的提示文案（中文）。
- `data`：实际业务负载。失败时为 `null` 或参数校验明细。
- `trace_id`：链路追踪 ID（Mock 阶段可由前端随机生成）。
- `ts`：服务端或 Mock 响应时间戳（Unix 秒）。

### 1.2 列表与分页包络
查询列表统一包含分页结构：
```json
{
  "list": [ ],
  "page": 1,
  "size": 20,
  "total": 137
}
```
查询参数统一：`?page=1&size=20`。

> **分页适用边界说明**：
> 分页结构仅用于真分页端点（如第 15 节预留清单中的 `R01 /cases`、`R07 /todos` 等）；工作台各业务域中的卡片式定长列表、固定前 N 名榜单、多维交叉汇总表等均不带分页字段。真分页端点请求单页容量限制为 `size <= 100`。

> **Query 参数通用约定**：参数出席即须合法：`?x=`（显式空串）按非法参数处理，返回 `10001`；参数缺席才取默认值。

### 1.3 数值与单位规范（钉死口径）
1. **金额口径**：
   - 宏观分析与工作台统计（如医疗收入、结余）：单位统一为**万元**（保留 2 位小数）；
   - 明细费用与单例次均（如门诊次均、住院次均）：单位统一为**元**。
2. **比率与变化率（delta）**：
   - 带有单位 `%` 的展示字段（如床位使用率、药占比）：数值直接给展示浮点数（如 `92.1` 表示 `92.1%`）；
   - 环比/同比变动（`delta`）：返回格式化字符串（如 `"+3.6%"`、`"-0.3"`），便于前端直接渲染；
   - 极性方向（`dir`）：严格三态枚举 `'up'` | `'down'` | `'flat'`。
3. **指标条统一数据接口结构 (`WbStatItem`)**：
   ```ts
   interface WbStatItem {
     label: string                    // 指标名称，如 "门急诊人次"
     value: string | number           // 核心展示值，如 "123,000" 或 12300
     unit?: string                    // 单位，如 "万元"、"天"、"%"
     delta?: string                   // 环同比变动幅度，如 "+3.6%"、"-0.3"、"+12项"
     delta_label?: string             // 变动文案说明，如 "较上月"、"同比"
     dir?: 'up' | 'down' | 'flat'      // 变动方向
     icon?: string                    // 语义图标名（Lucide 图标名，如 "Stethoscope"、"BedDouble"）
     tone?: 'primary' | 'teal' | 'green' | 'amber' | 'red' | 'navy' // 语义色枚举（禁止下发十六进制色值）
     note?: string                    // 备注文案，如 "目标 ≥1:1.25"、"当前实时"
   }
   ```

### 1.4 格式、命名与枚举扩展规范
1. **字段命名**：全契约与所有 JSON 负载一律使用 `snake_case`（全小写下划线命名），严禁出现 `camelCase`（驼峰命名），示例与字段声明均受此约束。实体标识使用 `code`（或 `id`），变动幅度统一为 `delta`，占比统一为 `share`，排序列条形占比统一为 `bar_pct`，业务指标与度量使用全称。
2. **告警级别枚举**：API 面统一使用英文枚举 `urgent` | `major` | `minor`（分别对应前端中文展示“高 / 中 / 低”），展示端由前端依据设计系统映射中文化；与底层数据库 schema 的 `alert_level` 字典完全同源。
3. **变动幅度 (delta) 格式**：统一返回 `+/-n%` 或 `+/-n<单位词>`（如 `"+3.6%"`、`"-0.3"`、`"+12项"`、`"-3分钟"`）或字面量 `"持平"`；变动方向 `dir` 为严格三态 `'up' | 'down' | 'flat'`。
4. **日期与时间格式**：
   - 标准日期：一律为 `YYYY-MM-DD`（如 `"2026-10-28"`）；
   - 时间戳：一律为 Unix 秒数（数值型）或 ISO 8601 标准字符串（如 `"2026-10-28T08:30:00+08:00"`）；
   - 跨度与日志展示时间：格式化为 `YYYY-MM-DD HH:mm`（如 `"2026-10-28 09:42"`）；
   - 界面短日期（如 `"10-28"`、`"08:12"`）：后端 API 不直接下发短字符串，统一由前端按界面空间渲染格式化；§14.1 `trends.dates` 的 `MM-DD` 序列为契约明示例外。
5. **图表/结构序列量纲**：所有趋势（trend）、构成（distribution / structure）、多序列图表响应中，必须显式下发 `unit` 字段或在节注声明量纲（如：收入构成 `unit: "%"`、科室份额 `unit: "万元"`、人员构成 `unit: "%"`、论文分布 `unit: "篇"`、能耗趋势 `unit: "万元"` 等）。
6. **色彩与视觉呈现解耦**：API 负载中严禁下发任何硬编码十六进制色值（如禁止出现十六进制颜色代码）。卡片与标签的视觉呈现统一使用 `tone` 语义色彩枚举（`primary`、`teal`、`green`、`amber`、`red`、`navy`），由前端样式系统与主题 Token 映射具体色值。
7. **错误码清单规范**：所有主体业务端点均在节尾明确标注可能返回的业务错误码；第 15 节预留端点清单同步补齐错误码对照列。
8. **示例字面量口径**：本文示例 JSON 的字面值为**形态示例**：端点真值以响应为准，统计口径随 `range`/锚月变化；示例与真值间按 ±10% 容差理解（§14.1 注6 精神的全文推广，原注保留）。

---

## 2. 演示级认证与上下文域 /auth & /hospital

### 2.1 GET /auth/profile
- **说明**：获取当前操作人身份与允许切换的模拟角色列表。演示模式无需 Bearer Token，支持直接通过 Query `?role=xxx` 切换上下文。
- **Query 参数**：
  - `role`（可选）：`president`（院长） | `ops_director`（运营办主任） | `dept_leader`（骨科主任）
- **Response `data`**：
  ```json
  {
    "user": {
      "id": 1,
      "username": "president",
      "real_name": "王建国",
      "title": "院长",
      "dept_id": null,
      "dept_name": "全院",
      "avatar": "/assets/workbench/director_avatar.png",
      "role": "president"
    },
    "available_roles": [
      { "role": "president", "name": "院长 (王建国)", "scope": "全院" },
      { "role": "ops_director", "name": "运营办主任 (李明)", "scope": "全院运营/质控" },
      { "role": "dept_leader", "name": "骨科主任 (刘主任)", "scope": "本科室" }
    ],
    "system_date": "2026-10-28",
    "weekday": "星期三"
  }
  ```
  > **字段注**：`dept_id: null` 表示院级领导视角。在数据库存储中院级哨兵键使用 `0`，在 API 契约层统一对外序列化为 `null`。
  > **演进注（P3 认证）**：本端点由会话中间件保护，无有效会话 → `20001`。`role` 参数演示期保留——出席时返回对应演示账号上下文（不校验会话身份，纯演示切换）；**缺席时返回当前会话用户**（原"缺省 president"语义调整为"会话用户"）。
- **可返回错误码**：`10001` (INVALID_PARAM), `20001` (UNAUTHORIZED)

### 2.2 GET /hospital/profile
- **说明**：医院基本配置与院训文化。
- **Response `data`**：
  ```json
  {
    "name": "XX市人民医院",
    "english_name": "PEOPLE'S HOSPITAL",
    "level": "三级甲等综合医院",
    "motto": ["厚德", "精医", "仁爱", "创新"],
    "slogans": ["以数据洞察全局", "以科学决策引领医院高质量发展"],
    "pillars": ["人民至上", "生命至上", "健康至上"]
  }
  ```
  > **字段注**：`name` 对齐视图与前端设计稿品牌展示；`english_name` 为品牌对外展示名，非逐字行政翻译。
- **可返回错误码**：`10001` (INVALID_PARAM)

### 2.3 POST /auth/login
- **说明**：账号口令登录，签发演示会话（Cookie `edss_sid`）。成功响应下发与 §2.1 同形上下文（`user` + `available_roles` + `system_date` + `weekday`），前端免二次拉取。
- **Request JSON**：

  | 字段 | 类型 | 必填 | 说明 |
  | :--- | :--- | :--- | :--- |
  | `username` | string | 是 | 登录名（`sys.user.username`） |
  | `password` | string | 是 | 明文口令，服务端 bcrypt 校验（演示口令仅本地用，见 `backend/README` 与种子注释） |
- **Response `data`**：与 §2.1 `data` 同形 `{ user, available_roles, system_date, weekday }`。
- **响应头**：`Set-Cookie: edss_sid=<会话令牌>; Path=/; HttpOnly; SameSite=Lax; Max-Age=43200`。生产 TLS 部署追加 `Secure`（后端配置项控制）；中间件同时接受 `Authorization: Bearer <令牌>`（供 curl/断言脚本，不进示例）。
- **可返回错误码**：`10001`（字段缺失/显式空串，`data.fields` 定位）、`10006`（请求体 JSON 非法）、`20101`（账号或口令错误）、`20102`（账号已停用）、`20104`（15 分钟内失败 ≥5 次锁定）
- **审计**：成功/失败均写 `sys.audit_log`（`action` = `login` / `login_fail`，username + ip）。

### 2.4 POST /auth/logout
- **说明**：吊销当前会话并清除 Cookie。**幂等**：无会话/会话已失效调用同样返回 `code=0`。
- **Request**：无 body；凭证取自 Cookie `edss_sid`。
- **Response `data`**：`null`
- **响应头**：`Set-Cookie: edss_sid=; Path=/; Max-Age=0`
- **可返回错误码**：无业务码（幂等成功）；系统错 `10000`。

---

## 3. 工作台首页 /workbench/home

对应页面：`src/views/workbench/HomeView.vue` 及对应 6 张子卡片。

### 3.1 GET /workbench/home/kpis
- **说明**：首页顶栏 5 大核心业务 KPI 卡片。行结构并入 `WbStatItem` 规范，统一为当月业务量口径。
- **Response `data`**：
  ```json
  {
    "period": "本月",
    "list": [
      { "key": "outpatient", "label": "门急诊人次", "value": "123,000", "unit": "", "delta": "+3.6%", "dir": "up", "icon": "Stethoscope", "tone": "primary" },
      { "key": "inpatient", "label": "住院人次", "value": "8,120", "unit": "", "delta": "+5.1%", "dir": "up", "icon": "BedDouble", "tone": "primary" },
      { "key": "surgery", "label": "手术台次", "value": "1,286", "unit": "", "delta": "+4.8%", "dir": "up", "icon": "Scissors", "tone": "teal" },
      { "key": "revenue", "label": "医疗总收入", "value": "14,800", "unit": "万元", "delta": "+2.9%", "dir": "up", "icon": "Banknote", "tone": "green" },
      { "key": "staff", "label": "在岗职工", "value": "2,368", "unit": "", "delta": "+0.4%", "dir": "up", "icon": "Users", "tone": "navy" }
    ]
  }
  ```
  > **字段注**：`value` 采用当月（10月）最新业务量，与 §3.2 月度走势中的 10 月点位严格自洽。`is_currency` 已移除，金额量纲通过 `unit: "万元"` 显式声明；原十六进制色值已收敛为 `tone` 语义色彩。
- **可返回错误码**：`10001` (INVALID_PARAM)

### 3.2 GET /workbench/home/trends
- **说明**：医疗业务走势图（支持 4 个 Tab 切换，按月对比本期与上期）。
- **Response `data`**：
  ```json
  {
    "months": ["1月", "2月", "3月", "4月", "5月", "6月", "7月", "8月", "9月", "10月", "11月", "12月"],
    "series": {
      "门急诊人次": {
        "unit": "人次",
        "current": [54000, 46000, 68000, 70000, 85000, 90000, 108000, 97000, 105000, 123000, 122000, 120000],
        "last": [46000, 39000, 52000, 52000, 68000, 72000, 90000, 92000, 87000, 102000, 101000, 99000]
      },
      "住院人次": {
        "unit": "人次",
        "current": [5900, 4970, 6410, 6820, 7240, 7450, 8070, 8480, 7850, 8120, 7650, 7450],
        "last": [5380, 4340, 5800, 6000, 6410, 6620, 7030, 7240, 6820, 7030, 6620, 6410]
      },
      "手术台次": {
        "unit": "台",
        "current": [860, 720, 980, 1020, 1080, 1120, 1180, 1210, 1150, 1286, 1200, 1160],
        "last": [750, 650, 850, 900, 950, 980, 1020, 1050, 1000, 1100, 1050, 1000]
      },
      "医疗收入": {
        "unit": "万元",
        "current": [8950, 8060, 10800, 11650, 12450, 12980, 13940, 13550, 13080, 14800, 14240, 13720],
        "last": [7870, 6920, 9120, 9750, 10580, 11030, 11960, 11640, 11200, 12640, 12280, 11840]
      }
    }
  }
  ```
- **可返回错误码**：`10001` (INVALID_PARAM)

### 3.3 GET /workbench/home/top10
- **说明**：科室业务量 TOP10（按住院人次排行）。
- **Response `data`**：
  ```json
  {
    "metric_name": "住院人次",
    "max_val": 1300,
    "list": [
      { "rank": 1, "name": "心血管内科", "value": 1250 },
      { "rank": 2, "name": "骨科", "value": 1120 },
      { "rank": 3, "name": "呼吸与危重症医学科", "value": 990 },
      { "rank": 4, "name": "普通外科", "value": 920 },
      { "rank": 5, "name": "神经内科", "value": 800 },
      { "rank": 6, "name": "肿瘤科", "value": 735 },
      { "rank": 7, "name": "妇产科", "value": 715 },
      { "rank": 8, "name": "儿科", "value": 655 },
      { "rank": 9, "name": "消化内科", "value": 380 },
      { "rank": 10, "name": "泌尿外科", "value": 340 }
    ]
  }
  ```
- **可返回错误码**：`10001` (INVALID_PARAM)

### 3.4 GET /workbench/home/indicators
- **说明**：医院运营关键效率与质量指标（首页右中卡片）。
- **Response `data`**：
  ```json
  {
    "list": [
      { "code": "ALOS", "name": "平均住院日", "value": "6.8", "unit": "天", "delta": "-0.3", "dir": "down", "icon": "CalendarDays", "tone": "primary" },
      { "code": "BED_USE_RATE", "name": "床位使用率", "value": "92.1", "unit": "%", "delta": "+1.2", "dir": "up", "icon": "BedDouble", "tone": "primary" },
      { "code": "DRUG_RATIO", "name": "药占比", "value": "28.4", "unit": "%", "delta": "-0.6", "dir": "down", "icon": "Pill", "tone": "primary" },
      { "code": "MATERIAL_RATIO", "name": "耗材占比", "value": "17.9", "unit": "%", "delta": "-0.4", "dir": "down", "icon": "Package", "tone": "teal" },
      { "code": "MED_SVC_RATIO", "name": "医疗服务收入占比", "value": "43.6", "unit": "%", "delta": "+0.8", "dir": "up", "icon": "HeartPulse", "tone": "green" }
    ]
  }
  ```
  > **字段注**：极性方向统一为 `dir: 'up' | 'down' | 'flat'`；移除了原 `circle_bg` 与 `icon_color` 十六进制色值，由 `tone` 语义色彩驱动前端展示。
- **可返回错误码**：`10001` (INVALID_PARAM)

### 3.5 GET /workbench/home/progress
- **说明**：院级重点工作进度与督办项。
- **Response `data`**：
  ```json
  {
    "list": [
      { "id": 1, "name": "三甲复评准备", "progress": 75, "status": "进行中" },
      { "id": 2, "name": "DRG精细化管理", "progress": 60, "status": "进行中" },
      { "id": 3, "name": "智慧医院建设", "progress": 40, "status": "进行中" },
      { "id": 4, "name": "学科建设提升计划", "progress": 90, "status": "进行中" },
      { "id": 5, "name": "DIP支付方式改革", "progress": 30, "status": "待启动" }
    ]
  }
  ```
- **可返回错误码**：`10001` (INVALID_PARAM)

### 3.6 GET /workbench/home/alerts
- **说明**：首页运营风险预警动态。
- **Response `data`**：
  ```json
  {
    "list": [
      { "id": 201, "level": "urgent", "title": "住院费用增幅高于行业均值", "occurred_at": "2026-10-28", "rule_code": "INPT_FEE_SURGE", "alert_status": "pending" },
      { "id": 202, "level": "urgent", "title": "部分科室床位使用率持续 > 95%", "occurred_at": "2026-10-27", "rule_code": "BED_OVER_95", "alert_status": "pending" },
      { "id": 203, "level": "major", "title": "医疗耗材库存周转天数上升", "occurred_at": "2026-10-26", "rule_code": "STOCK_TURN_SLOW", "alert_status": "pending" },
      { "id": 204, "level": "major", "title": "药品费用占比接近警戒阈值", "occurred_at": "2026-10-25", "rule_code": "DRUG_RATIO_WARN", "alert_status": "pending" },
      { "id": 205, "level": "minor", "title": "个别设备维保到期", "occurred_at": "2026-10-24", "rule_code": "DEVICE_MAINTAIN", "alert_status": "pending" }
    ]
  }
  ```
  > **字段注**：告警级别统一为英文枚举 `urgent | major | minor`；`occurred_at` 采用完整日期；`BED_OVER_95` 与 `DEVICE_MAINTAIN` 对齐 schema 预置种子，其余三条规则待 schema 种子补登。
  > **`alert_status`（P3 新增，必填下发）**：`ads.alert_event.alert_status` 原值 `pending | processing | done | closed`——本端点打开集语义为 `IN ('pending','processing')`（§15.5 写后读注）；前端按该字段渲染行内操作集（`processing` 已认领行不再挂「认领」）。
- **可返回错误码**：`10001` (INVALID_PARAM)

### 3.7 GET /workbench/home/notices
- **说明**：行政通知与待办事项列表。
- **Response `data`**：
  ```json
  {
    "list": [
      { "id": 201, "text": "关于加强医疗质量安全管理的通知", "date": "2026-10-28", "urgent": true },
      { "id": 202, "text": "院务会会议材料（10月）", "date": "2026-10-27", "urgent": true },
      { "id": 203, "text": "请审阅2027年预算编制方案", "date": "2026-10-26", "urgent": true },
      { "id": 204, "text": "智慧医院二期建设进展汇报", "date": "2026-10-25", "urgent": false },
      { "id": 205, "text": "上级主管部门调研安排", "date": "2026-10-24", "urgent": false }
    ]
  }
  ```
- **可返回错误码**：`10001` (INVALID_PARAM)

---

## 4. 综合概览 /workbench/overview

对应页面：`src/views/workbench/OverviewView.vue`。

### 4.1 GET /workbench/overview
- **Query 参数**：`range` = `本月` | `本季` | `本年`（默认 `本年`）
- **Response `data`**：
  ```json
  {
    "range": "本年",
    "stats": [
      { "label": "门急诊人次", "value": "846,000", "delta": "+3.6%", "dir": "up" },
      { "label": "出院人数", "value": "71,310", "delta": "+5.1%", "dir": "up" },
      { "label": "手术台次", "value": "10,606", "delta": "+4.8%", "dir": "up" },
      { "label": "医疗收入", "value": "120,260", "unit": "万元", "delta": "+2.9%", "dir": "up" },
      { "label": "床位使用率", "value": "92.1", "unit": "%", "delta": "+1.2%", "dir": "up" },
      { "label": "平均住院日", "value": "6.8", "unit": "天", "delta": "-0.3", "dir": "down" }
    ],
    "scale_revenue_trend": {
      "months": ["1月", "2月", "3月", "4月", "5月", "6月", "7月", "8月", "9月", "10月", "11月", "12月"],
      "outpatient": [54000, 46000, 68000, 70000, 85000, 90000, 108000, 97000, 105000, 123000, 122000, 120000],
      "revenue": [8950, 8060, 10800, 11650, 12450, 12980, 13940, 13550, 13080, 14800, 14240, 13720],
      "units": { "outpatient": "人次", "revenue": "万元" }
    },
    "income_structure": {
      "unit": "%",
      "list": [
        { "name": "住院收入", "value": 71 },
        { "name": "门诊收入", "value": 25 },
        { "name": "其他收入", "value": 4 }
      ]
    },
    "dept_share_top8": {
      "metric": "住院收入（万元·本年）",
      "unit": "万元",
      "list": [
        { "name": "心血管内科", "value": 14826, "bar_pct": 100 },
        { "name": "骨科", "value": 13555, "bar_pct": 91 },
        { "name": "呼吸与危重症医学科", "value": 11381, "bar_pct": 77 },
        { "name": "普通外科", "value": 10637, "bar_pct": 72 },
        { "name": "神经内科", "value": 9636, "bar_pct": 65 },
        { "name": "肿瘤科", "value": 9559, "bar_pct": 64 },
        { "name": "妇产科", "value": 7705, "bar_pct": 52 },
        { "name": "儿科", "value": 6739, "bar_pct": 45 }
      ]
    },
    "live_inpatient": [
      { "label": "当前在院人数", "value": "1,846", "tone": "primary" },
      { "label": "今日入院人数", "value": "285", "tone": "teal" },
      { "label": "今日出院核准", "value": "272", "tone": "green" },
      { "label": "急诊在观人数", "value": "36", "tone": "amber" },
      { "label": "重症监护在科", "value": "22", "tone": "red" },
      { "label": "手术进行中", "value": "9", "tone": "navy" }
    ]
  }
  ```
  > **字段注**：
  > 1. `range="本年"` 下核心指标的 `value` 统一为本年 1~10 月累计值（门急诊 84.6 万、出院 7.13 万、手术 1.06 万、医疗收入 12.03 亿元），严格等于月度走势数组前 10 个月求和。
  > 2. `dept_share_top8` 明确度量为“住院收入（万元）”，`metric` 口径词随 `range` 实写（`本年`→“住院收入（万元·本年）”），`value` 为 `range` 累计口径纯数值型（方便前端计算），`bar_pct` 表示条形宽度归一化百分比（`val / max * 100`）。
  > 3. `live_inpatient` 项集与视图对齐为 6 项实时运营数据，十六进制色值改由 `tone` 语义色彩定义。
- **可返回错误码**：`10001` (INVALID_PARAM)

---

## 5. 医疗业务 /workbench/medical

对应页面：`src/views/workbench/MedicalView.vue`。支持两级维度：`tab`（门急诊/住院/手术）与 `range`（本月/本季/本年）。

### 5.1 GET /workbench/medical
- **Query 参数**：
  - `tab` = `门急诊` | `住院` | `手术`（默认 `门急诊`）
  - `range` = `本月` | `本季` | `本年`（默认 `本年`）
- **结构说明**：
  `stats`、`distribution`、`table` 结构与列集合随 `tab` 动态变化。
  > **跨 Tab 同键异义注**：`table.columns` 中 `avg` 列在 `门急诊` 与 `住院` tab 下表示“次均费用”（元），在 `手术` tab 下表示“平均手术时长”（分钟）。前端渲染按列元数据单位展示。
  > **stats 口径注**：`stats` 恒为**当月/当前口径**（如 `本月出院`、`在院人数`），不随 `range` 累计；`trend`/`distribution`/`table` 随 `range` 变化（`本年` 序列=1~10 月累计）。

#### 示例 1：`tab=门急诊`
```json
{
  "tab": "门急诊",
  "range": "本年",
  "stats": [
    { "label": "门急诊总人次", "value": "123,443", "delta": "+20.5%", "delta_label": "较去年", "dir": "up" },
    { "label": "普通门诊", "value": "82,286", "delta": "+19.8%", "delta_label": "较去年", "dir": "up" },
    { "label": "专家门诊", "value": "29,842", "delta": "+22.5%", "delta_label": "较去年", "dir": "up" },
    { "label": "急诊人次", "value": "11,315", "delta": "+20.6%", "delta_label": "较去年", "dir": "up" },
    { "label": "次均费用", "value": "299", "unit": "元", "delta": "+0.1%", "delta_label": "较去年", "dir": "up" },
    { "label": "平均候诊", "value": "17.5", "unit": "分钟", "delta": "0.0分钟", "delta_label": "较去年", "dir": "flat" }
  ],
  "trend": {
    "title": "门急诊人次趋势",
    "name": "门急诊人次",
    "unit": "人次",
    "months": ["1月", "2月", "3月", "4月", "5月", "6月", "7月", "8月", "9月", "10月", "11月", "12月"],
    "values": [53896, 46037, 67829, 69861, 85253, 89777, 107966, 96920, 104798, 123443, 122208, 119591]
  },
  "distribution": {
    "title": "就诊高峰时段分布",
    "sub": "近 30 日分时段人次",
    "type": "bar",
    "unit": "人次",
    "categories": ["7时", "8时", "9时", "10时", "11时", "14时", "15时", "16时", "17时", "19时"],
    "values": [4686, 11923, 18014, 15702, 8077, 11076, 12807, 8286, 3396, 5197]
  },
  "table": {
    "columns": [
      { "key": "dept", "title": "科室" },
      { "key": "cnt", "title": "诊疗人次", "align": "right", "num": true },
      { "key": "yoy", "title": "同比", "align": "right", "num": true },
      { "key": "share", "title": "占比", "align": "right", "num": true },
      { "key": "avg", "title": "次均费用", "align": "right", "num": true },
      { "key": "drug", "title": "药占比", "align": "right", "num": true }
    ],
    "rows": [
      { "dept": "心血管内科", "cnt": "86,714", "yoy": "+19.7%", "share": "10.3%", "avg": "330元", "drug": "35.4%" },
      { "dept": "呼吸与危重症医学科", "cnt": "78,706", "yoy": "+20.9%", "share": "9.3%", "avg": "330元", "drug": "39.9%" },
      { "dept": "急诊科", "cnt": "77,837", "yoy": "+20.8%", "share": "9.2%", "avg": "0元", "drug": "0.0%" },
      { "dept": "消化内科", "cnt": "70,533", "yoy": "+20.0%", "share": "8.3%", "avg": "336元", "drug": "41.7%" },
      { "dept": "神经内科", "cnt": "65,760", "yoy": "+19.8%", "share": "7.8%", "avg": "327元", "drug": "38.8%" },
      { "dept": "内分泌科", "cnt": "56,114", "yoy": "+21.7%", "share": "6.6%", "avg": "333元", "drug": "44.0%" },
      { "dept": "儿科", "cnt": "53,522", "yoy": "+19.9%", "share": "6.3%", "avg": "317元", "drug": "29.4%" },
      { "dept": "骨科", "cnt": "48,865", "yoy": "+21.3%", "share": "5.8%", "avg": "327元", "drug": "26.0%" }
    ]
  }
}
```

#### 示例 2：`tab=住院`
```json
{
  "tab": "住院",
  "range": "本年",
  "stats": [
    { "label": "在院人数", "value": "1,846", "note": "当前实时" },
    { "label": "本月出院", "value": "8,109", "delta": "+16.1%", "delta_label": "较去年", "dir": "up" },
    { "label": "床位使用率", "value": "92.1", "unit": "%", "delta": "+1.6%", "delta_label": "较去年", "dir": "up" },
    { "label": "平均住院日", "value": "6.8", "unit": "天", "delta": "0.0", "delta_label": "较去年", "dir": "flat" },
    { "label": "床位周转次数", "value": "4.0", "delta": "+0.6", "delta_label": "较去年", "dir": "up" },
    { "label": "次均住院费用", "value": "13,701", "unit": "元", "delta": "0.0%", "delta_label": "较去年", "dir": "flat" }
  ],
  "trend": {
    "title": "出院人数趋势",
    "name": "出院人数",
    "unit": "人次",
    "months": ["1月", "2月", "3月", "4月", "5月", "6月", "7月", "8月", "9月", "10月", "11月", "12月"],
    "values": [5975, 4981, 6300, 6863, 7200, 7515, 8135, 8403, 7892, 8109, 7647, 7395]
  },
  "distribution": {
    "title": "病区床位占用",
    "sub": "各病区开放床位占用率",
    "type": "bar",
    "unit": "%",
    "categories": ["内科", "外科", "妇产", "儿科", "ICU", "肿瘤", "康复"],
    "values": [92, 92, 97, 86, 97, 93, 90]
  },
  "table": {
    "columns": [
      { "key": "dept", "title": "科室" },
      { "key": "cnt", "title": "出院人次", "align": "right", "num": true },
      { "key": "yoy", "title": "同比", "align": "right", "num": true },
      { "key": "share", "title": "占比", "align": "right", "num": true },
      { "key": "avg", "title": "次均费用", "align": "right", "num": true },
      { "key": "drug", "title": "药占比", "align": "right", "num": true }
    ],
    "rows": [
      { "dept": "心血管内科", "cnt": "11,097", "yoy": "+15.2%", "share": "15.5%", "avg": "13,361元", "drug": "27.3%" },
      { "dept": "骨科", "cnt": "9,645", "yoy": "+10.6%", "share": "13.5%", "avg": "14,054元", "drug": "13.1%" },
      { "dept": "呼吸与危重症医学科", "cnt": "8,662", "yoy": "+13.0%", "share": "12.1%", "avg": "13,140元", "drug": "32.4%" },
      { "dept": "普通外科", "cnt": "8,121", "yoy": "+13.8%", "share": "11.4%", "avg": "13,098元", "drug": "17.7%" },
      { "dept": "神经内科", "cnt": "7,074", "yoy": "+15.3%", "share": "9.9%", "avg": "13,621元", "drug": "36.7%" },
      { "dept": "肿瘤科", "cnt": "6,467", "yoy": "+13.7%", "share": "9.1%", "avg": "14,781元", "drug": "41.5%" },
      { "dept": "妇产科", "cnt": "6,287", "yoy": "+15.2%", "share": "8.8%", "avg": "12,256元", "drug": "19.6%" },
      { "dept": "儿科", "cnt": "5,791", "yoy": "+14.7%", "share": "8.1%", "avg": "11,637元", "drug": "22.9%" }
    ]
  }
}
```

#### 示例 3：`tab=手术`
```json
{
  "tab": "手术",
  "range": "本年",
  "stats": [
    { "label": "本月手术台次", "value": "1,286", "delta": "+16.9%", "delta_label": "较去年", "dir": "up" },
    { "label": "三四级手术占比", "value": "58.2", "unit": "%", "delta": "-0.3%", "delta_label": "较去年", "dir": "down" },
    { "label": "微创手术占比", "value": "42.3", "unit": "%", "delta": "-0.8%", "delta_label": "较去年", "dir": "down" },
    { "label": "择期手术", "value": "1,050", "delta": "+17.4%", "delta_label": "较去年", "dir": "up" },
    { "label": "急诊手术", "value": "236", "delta": "+14.6%", "delta_label": "较去年", "dir": "up" },
    { "label": "手术间利用率", "value": "80.1", "unit": "%", "delta": "+5.4%", "delta_label": "较去年", "dir": "up" }
  ],
  "trend": {
    "title": "手术台次趋势",
    "name": "手术台次",
    "unit": "台",
    "months": ["1月", "2月", "3月", "4月", "5月", "6月", "7月", "8月", "9月", "10月", "11月", "12月"],
    "values": [860, 720, 980, 1020, 1080, 1120, 1180, 1210, 1150, 1286, 1200, 1160]
  },
  "distribution": {
    "title": "手术分级构成",
    "sub": "本月手术级别分布",
    "type": "pie",
    "unit": "%",
    "categories": ["四级手术", "三级手术", "二级手术", "一级手术"],
    "values": [16, 40, 32, 12]
  },
  "table": {
    "columns": [
      { "key": "dept", "title": "科室" },
      { "key": "cnt", "title": "手术台次", "align": "right", "num": true },
      { "key": "yoy", "title": "同比", "align": "right", "num": true },
      { "key": "share", "title": "占比", "align": "right", "num": true },
      { "key": "avg", "title": "平均时长", "align": "right", "num": true },
      { "key": "drug", "title": "药占比", "align": "right", "num": true }
    ],
    "rows": [
      { "dept": "骨科", "cnt": "2,355", "yoy": "+14.8%", "share": "22.2%", "avg": "41分钟", "drug": "13.1%" },
      { "dept": "普通外科", "cnt": "1,995", "yoy": "+14.7%", "share": "18.8%", "avg": "56分钟", "drug": "17.7%" },
      { "dept": "妇产科", "cnt": "1,534", "yoy": "+14.6%", "share": "14.5%", "avg": "38分钟", "drug": "19.6%" },
      { "dept": "神经外科", "cnt": "1,056", "yoy": "+14.5%", "share": "10.0%", "avg": "130分钟", "drug": "14.9%" },
      { "dept": "泌尿外科", "cnt": "957", "yoy": "+14.7%", "share": "9.0%", "avg": "52分钟", "drug": "16.5%" },
      { "dept": "心胸外科", "cnt": "807", "yoy": "+14.5%", "share": "7.6%", "avg": "145分钟", "drug": "15.7%" },
      { "dept": "耳鼻喉科", "cnt": "710", "yoy": "+14.7%", "share": "6.7%", "avg": "34分钟", "drug": "15.7%" },
      { "dept": "眼科", "cnt": "611", "yoy": "+14.8%", "share": "5.8%", "avg": "22分钟", "drug": "13.7%" }
    ]
  }
}
```
- **可返回错误码**：`10001` (INVALID_PARAM)

---

## 6. 运营管理 /workbench/operations

对应页面：`src/views/workbench/OperationsView.vue`。

### 6.1 GET /workbench/operations
- **Query 参数**：`range` = `本月` | `本季` | `本年`
- **Response `data`**：
  ```json
  {
    "stats": [
      { "label": "医疗总收入", "value": "120,260", "unit": "万元", "delta": "+2.9%", "dir": "up" },
      { "label": "门诊收入", "value": "30,065", "unit": "万元", "delta": "+1.8%", "dir": "up" },
      { "label": "住院收入", "value": "85,385", "unit": "万元", "delta": "+3.6%", "dir": "up" },
      { "label": "收支结余率", "value": "4.2", "unit": "%", "delta": "+0.4%", "dir": "up" },
      { "label": "次均门诊费用", "value": "300", "unit": "元", "delta": "+1.8%", "dir": "up" },
      { "label": "次均住院费用", "value": "13,000", "unit": "元", "delta": "+2.4%", "dir": "up" }
    ],
    "revenue_trend": {
      "months": ["1月", "2月", "3月", "4月", "5月", "6月", "7月", "8月", "9月", "10月", "11月", "12月"],
      "income": [8950, 8060, 10800, 11650, 12450, 12980, 13940, 13550, 13080, 14800, 14240, 13720],
      "cost": [8574, 7721, 10346, 11161, 11927, 12435, 13359, 12981, 12531, 14178, 13642, 13144],
      "balance": [376, 339, 454, 489, 523, 545, 581, 569, 549, 622, 598, 576]
    },
    "cost_controls": [
      { "name": "药占比", "value": "28.4%", "target": "≤30%", "status": "达标", "pct": 71, "mark_pct": 75 },
      { "name": "耗占比", "value": "17.9%", "target": "≤20%", "status": "达标", "pct": 67, "mark_pct": 75 },
      { "name": "次均费用增幅", "value": "2.4%", "target": "≤8%", "status": "达标", "pct": 30, "mark_pct": 80 },
      { "name": "百元医疗收入消耗卫生材料", "value": "12.6元", "target": "≤15元", "status": "达标", "pct": 63, "mark_pct": 75 },
      { "name": "住院抗菌药物使用强度", "value": "38.2", "target": "≤40", "status": "达标", "pct": 76, "mark_pct": 80 },
      { "name": "门诊输液率", "value": "9.8%", "target": "≤8%", "status": "超标", "pct": 86, "mark_pct": 70 }
    ],
    "dept_table": {
      "columns": [
        { "key": "dept", "title": "科室" },
        { "key": "income", "title": "收入（万元）", "align": "right", "num": true },
        { "key": "cost", "title": "成本（万元）", "align": "right", "num": true },
        { "key": "balance", "title": "结余（万元）", "align": "right", "num": true },
        { "key": "margin", "title": "结余率", "align": "right", "num": true },
        { "key": "drug_ratio", "title": "药占比", "align": "right", "num": true },
        { "key": "mat_ratio", "title": "耗材比", "align": "right", "num": true }
      ],
      "rows": [
        { "dept": "心血管内科", "income": "19,270", "cost": "17,940", "balance": "1,330", "margin": "6.9%", "drug_ratio": "24.8%", "mat_ratio": "18.2%" },
        { "dept": "骨科", "income": "15,960", "cost": "14,490", "balance": "1,470", "margin": "9.2%", "drug_ratio": "12.4%", "mat_ratio": "34.6%" },
        { "dept": "呼吸与危重症医学科", "income": "15,070", "cost": "14,500", "balance": "570", "margin": "3.8%", "drug_ratio": "32.6%", "mat_ratio": "8.4%" },
        { "dept": "神经内科", "income": "13,270", "cost": "12,900", "balance": "370", "margin": "2.8%", "drug_ratio": "36.4%", "mat_ratio": "6.2%" },
        { "dept": "普通外科", "income": "12,620", "cost": "11,750", "balance": "870", "margin": "6.9%", "drug_ratio": "18.2%", "mat_ratio": "22.1%" },
        { "dept": "肿瘤科", "income": "11,680", "cost": "11,190", "balance": "490", "margin": "4.2%", "drug_ratio": "42.8%", "mat_ratio": "9.1%" }
      ]
    }
  }
  ```
  > **字段注**：
  > 1. `revenue_trend` 中的 `balance` 序列保留，结余率 `= balance / income * 100%` 可由前端直接推导渲染。
  > 2. `cost_controls` 扩展为 6 项精细化控费指标，`mark_pct` 表示红线警示阈值在进度条 0–100 刻度上的相对位置。
  > 3. `dept_table` 列键名全面统一为 `snake_case`（`drug_ratio`、`mat_ratio`）。
- **可返回错误码**：`10001` (INVALID_PARAM)

---

## 7. 人力资源 /workbench/hr

对应页面：`src/views/workbench/HrView.vue`。

### 7.1 GET /workbench/hr
- **Query 参数**：`range` = `本月` | `本季` | `本年`
- **Response `data`**：
  ```json
  {
    "stats": [
      { "label": "在岗职工", "value": "2,368", "delta": "+0.4%", "dir": "up" },
      { "label": "执业医师", "value": "812", "delta": "+1.8%", "dir": "up" },
      { "label": "注册护士", "value": "1,046", "delta": "+2.2%", "dir": "up" },
      { "label": "医护比", "value": "1 : 1.29", "note": "目标 ≥1:1.25" },
      { "label": "高级职称占比", "value": "12.0", "unit": "%", "delta": "+0.6%", "dir": "up" },
      { "label": "人员经费占比", "value": "32.5", "unit": "%", "delta": "+1.1%", "dir": "up" }
    ],
    "structure": {
      "unit": "%",
      "list": [
        { "name": "护理人员", "value": 44, "count": 1046 },
        { "name": "执业医师", "value": 34, "count": 812 },
        { "name": "行政后勤", "value": 13, "count": 308 },
        { "name": "医技人员", "value": 9, "count": 202 }
      ]
    },
    "titles": {
      "unit": "人",
      "categories": ["医师", "护理", "医技", "行政后勤"],
      "series": [
        { "name": "正高", "values": [42, 6, 4, 0] },
        { "name": "副高", "values": [128, 68, 22, 14] },
        { "name": "中级", "values": [312, 368, 84, 62] },
        { "name": "初级及以下", "values": [330, 604, 92, 232] }
      ]
    },
    "dept_staffing": {
      "columns": [
        { "key": "dept", "title": "科室" },
        { "key": "quota", "title": "编制数", "align": "right", "num": true },
        { "key": "actual", "title": "在岗数", "align": "right", "num": true },
        { "key": "doctor", "title": "医师", "align": "right", "num": true },
        { "key": "nurse", "title": "护士", "align": "right", "num": true },
        { "key": "ratio", "title": "医护比", "align": "center" },
        { "key": "gap", "title": "缺口", "align": "right", "num": true },
        { "key": "status", "title": "配置状态", "align": "center" }
      ],
      "rows": [
        { "dept": "重症医学科", "quota": 68, "actual": 58, "doctor": 16, "nurse": 42, "ratio": "1:2.63", "gap": 10, "status": "紧缺" },
        { "dept": "急诊科", "quota": 86, "actual": 78, "doctor": 24, "nurse": 54, "ratio": "1:2.25", "gap": 8, "status": "紧张" },
        { "dept": "儿科", "quota": 64, "actual": 58, "doctor": 20, "nurse": 38, "ratio": "1:1.90", "gap": 6, "status": "紧张" },
        { "dept": "心血管内科", "quota": 92, "actual": 89, "doctor": 32, "nurse": 57, "ratio": "1:1.78", "gap": 3, "status": "充足" },
        { "dept": "骨科", "quota": 84, "actual": 81, "doctor": 28, "nurse": 53, "ratio": "1:1.89", "gap": 3, "status": "充足" },
        { "dept": "呼吸与危重症医学科", "quota": 76, "actual": 72, "doctor": 24, "nurse": 48, "ratio": "1:2.00", "gap": 4, "status": "充足" },
        { "dept": "麻醉科", "quota": 42, "actual": 36, "doctor": 30, "nurse": 6, "ratio": "—", "gap": 6, "status": "紧张" },
        { "dept": "康复医学科", "quota": 38, "actual": 34, "doctor": 10, "nurse": 24, "ratio": "1:2.40", "gap": 4, "status": "充足" }
      ]
    }
  }
  ```
  > **字段注**：
  > 1. `titles` 重构为岗位×职称的完整矩阵结构，各列合计与医院全岗人员总数完全自洽。
  > 2. `dept_staffing` 补齐视图全量 8 行科室定岗编制数据，各列字段名统一。
- **可返回错误码**：`10001` (INVALID_PARAM)

---

## 8. 科研教学 /workbench/research

对应页面：`src/views/workbench/ResearchView.vue`。

### 8.1 GET /workbench/research
- **Response `data`**：
  ```json
  {
    "stats": [
      { "label": "在研课题", "value": "186", "unit": "项", "delta": "+12项", "dir": "up" },
      { "label": "年度新立项", "value": "42", "unit": "项", "delta": "+6项", "dir": "up" },
      { "label": "科研经费", "value": "3,480", "unit": "万元", "delta": "+18.2%", "dir": "up" },
      { "label": "SCI 论文", "value": "98", "unit": "篇", "delta": "+14篇", "dir": "up" },
      { "label": "住培学员", "value": "312", "unit": "人", "note": "首次结业率 96.2%" },
      { "label": "继教覆盖率", "value": "98.4", "unit": "%", "delta": "+0.8%", "dir": "up" }
    ],
    "project_trend": {
      "unit": "万元",
      "years": ["2021", "2022", "2023", "2024", "2025"],
      "national": [4, 6, 8, 9, 12],
      "provincial": [12, 16, 20, 24, 30],
      "funds": [1200, 1680, 2240, 2940, 3480]
    },
    "paper_distribution": {
      "unit": "篇",
      "categories": ["一区（Top）", "二区", "三区", "四区", "中文核心"],
      "values": [14, 28, 36, 20, 68]
    },
    "disciplines": {
      "columns": [
        { "key": "name", "title": "学科名称" },
        { "key": "level", "title": "级别", "align": "center" },
        { "key": "leader", "title": "学科带头人" },
        { "key": "projects", "title": "在研课题", "align": "right", "num": true },
        { "key": "funds", "title": "科研经费（万元）", "align": "right", "num": true },
        { "key": "papers", "title": "年度论文", "align": "right", "num": true },
        { "key": "transfer", "title": "成果转化（万元）", "align": "right", "num": true }
      ],
      "rows": [
        { "name": "心血管病学", "level": "国家临床重点", "leader": "张伟 教授", "projects": 28, "funds": "820", "papers": 22, "transfer": "150" },
        { "name": "骨外科学", "level": "省级重点专科", "leader": "李强 教授", "projects": 22, "funds": "540", "papers": 16, "transfer": "80" },
        { "name": "呼吸病学", "level": "省级重点专科", "leader": "王军 教授", "projects": 18, "funds": "460", "papers": 14, "transfer": "45" }
      ]
    }
  }
  ```
  > **字段注**：`disciplines` 统计粒度为重点学科级口径（非末级临床科室）；`funds` 字段名严格保持复数规范。
- **可返回错误码**：`10001` (INVALID_PARAM)

---

## 9. 患者服务 /workbench/patient

对应页面：`src/views/workbench/PatientView.vue`。

### 9.1 GET /workbench/patient
- **Response `data`**：
  ```json
  {
    "stats": [
      { "label": "门诊满意度", "value": "96.4", "unit": "%", "delta": "+0.8%", "dir": "up" },
      { "label": "住院满意度", "value": "97.2", "unit": "%", "delta": "+0.4%", "dir": "up" },
      { "label": "本月投诉", "value": "24", "unit": "件", "delta": "-6件", "dir": "down" },
      { "label": "本月表扬", "value": "86", "unit": "件", "delta": "+12件", "dir": "up" },
      { "label": "平均候诊", "value": "18", "unit": "分钟", "delta": "-3分钟", "dir": "down" },
      { "label": "网约挂号率", "value": "82.0", "unit": "%", "delta": "+4.2%", "dir": "up" }
    ],
    "satisfaction_trend": {
      "unit": "%",
      "months": ["5月", "6月", "7月", "8月", "9月", "10月"],
      "outpatient": [94.8, 95.2, 95.6, 95.8, 96.1, 96.4],
      "inpatient": [96.0, 96.2, 96.5, 96.8, 97.0, 97.2]
    },
    "channel_distribution": {
      "unit": "%",
      "list": [
        { "name": "微信小程序", "value": 38 },
        { "name": "自助机", "value": 24 },
        { "name": "人工窗口", "value": 18 },
        { "name": "官方APP", "value": 14 },
        { "name": "电话预约", "value": 6 }
      ]
    },
    "complaints_praises": {
      "columns": [
        { "key": "date", "title": "日期", "align": "center" },
        { "key": "type", "title": "类型", "align": "center" },
        { "key": "dept", "title": "涉及科室" },
        { "key": "channel", "title": "渠道" },
        { "key": "content", "title": "反映内容" },
        { "key": "status", "title": "处理状态", "align": "center" },
        { "key": "score", "title": "回访评价", "align": "center" }
      ],
      "rows": [
        { "date": "2026-10-27", "type": "表扬", "dept": "急诊科", "channel": "12345热线", "content": "急诊科医护人员深夜救治及时，家属致谢", "status": "已办结", "score": "非常满意" },
        { "date": "2026-10-26", "type": "投诉", "dept": "门诊部", "channel": "现场意见箱", "content": "门诊缴费窗口排队时间过长（高峰时段）", "status": "处理中", "score": "待评价" },
        { "date": "2026-10-24", "type": "投诉", "dept": "护理部", "channel": "电话", "content": "住院部陪护床管理不规范", "status": "已整改", "score": "基本满意" },
        { "date": "2026-10-23", "type": "表扬", "dept": "骨科", "channel": "小程序", "content": "骨科王主任术后随访细致", "status": "已归档", "score": "非常满意" },
        { "date": "2026-10-22", "type": "投诉", "dept": "放射科", "channel": "现场", "content": "放射科取报告自助机故障", "status": "已办结", "score": "满意" },
        { "date": "2026-10-20", "type": "投诉", "dept": "后勤保障部", "channel": "电话", "content": "停车场出口排队拥堵", "status": "待核实", "score": "待评价" }
      ]
    }
  }
  ```
  > **字段注**：
  > 1. `channel_distribution` 对齐视图 5 类预约服务渠道分布，显式声明 `unit: "%"`。
  > 2. `complaints_praises` 列集合并了来源渠道与回访评价，日期使用 `YYYY-MM-DD` 规范，状态统一采用五态枚举：`待核实 | 处理中 | 已整改 | 已办结 | 已归档`。
- **可返回错误码**：`10001` (INVALID_PARAM)

---

## 10. 质量与安全 /workbench/quality

对应页面：`src/views/workbench/QualityView.vue`。

### 10.1 GET /workbench/quality
- **Response `data`**：
  ```json
  {
    "stats": [
      { "label": "甲级病案率", "value": "98.6", "unit": "%", "delta": "+0.4%", "dir": "up" },
      { "label": "院感发生率", "value": "1.24", "unit": "%", "delta": "-0.18%", "dir": "down" },
      { "label": "危急值处理及时率", "value": "99.1", "unit": "%", "delta": "+0.3%", "dir": "up" },
      { "label": "不良事件上报", "value": "36", "unit": "起", "note": "百床 1.95 起" },
      { "label": "I类切口感染率", "value": "0.38", "unit": "%", "delta": "-0.06%", "dir": "down" },
      { "label": "抗菌药物使用强度", "value": "36.2", "unit": "DDDs", "delta": "-2.1", "dir": "down" }
    ],
    "infection_trend": {
      "unit": "%",
      "target": 2.0,
      "months": ["5月", "6月", "7月", "8月", "9月", "10月"],
      "rates": [2.2, 2.0, 2.1, 1.9, 1.9, 1.8]
    },
    "adverse_events": {
      "unit": "起",
      "categories": ["跌倒/坠床", "用药错误", "管路滑脱", "院内压疮", "手术相关", "输血相关", "其他"],
      "values": [11, 8, 6, 5, 3, 2, 1]
    },
    "rules_compliance": {
      "columns": [
        { "key": "name", "title": "制度名称" },
        { "key": "sample", "title": "抽检例数", "align": "right", "num": true },
        { "key": "pass", "title": "合格例数", "align": "right", "num": true },
        { "key": "rate", "title": "执行合规率", "align": "right", "num": true },
        { "key": "issues", "title": "主要问题" }
      ],
      "rows": [
        { "name": "首诊负责制", "sample": 280, "pass": 270, "rate": "96.4%", "issues": "个别首诊病历书写延迟" },
        { "name": "三级查房制度", "sample": 260, "pass": 240, "rate": "92.3%", "issues": "主任查房记录欠详实" },
        { "name": "会诊制度", "sample": 240, "pass": 230, "rate": "95.8%", "issues": "常规会诊偶有超时" },
        { "name": "危急值报告制度", "sample": 280, "pass": 276, "rate": "98.6%", "issues": "闭环确认偶有遗漏" },
        { "name": "手术安全核查制度", "sample": 220, "pass": 218, "rate": "99.1%", "issues": "三方核查签字不全 2 例" },
        { "name": "病历书写规范", "sample": 300, "pass": 266, "rate": "88.6%", "issues": "24小时出入院记录欠完整" },
        { "name": "抗菌药物分级管理", "sample": 260, "pass": 237, "rate": "91.2%", "issues": "特殊级抗菌药越权使用 3 例" },
        { "name": "值班交接班制度", "sample": 280, "pass": 264, "rate": "94.2%", "issues": "床旁交接偶无双人签字" }
      ]
    }
  }
  ```
  > **字段注**：
  > 1. `infection_trend` 包含 `target: 2.0` 控制线，月度率值与视图波动走势一致（展示出从越线到受控的运营改进剧情）。
  > 2. `adverse_events` 改为视图 7 类分类体系，单位统一为“起”。
  > 3. `rules_compliance` 覆盖医院 8 项十八项核心制度，`sample` 与 `pass` 例数严格满足 `rate = pass / sample * 100%`。
- **可返回错误码**：`10001` (INVALID_PARAM)

---

## 11. 资产与后勤 /workbench/assets

对应页面：`src/views/workbench/AssetsView.vue`。

### 11.1 GET /workbench/assets
- **Response `data`**：
  ```json
  {
    "stats": [
      { "label": "固定资产总额", "value": "12.6", "unit": "亿元", "delta": "+3.2%", "dir": "up" },
      { "label": "大型设备", "value": "68", "unit": "台", "note": "单价 ≥100 万" },
      { "label": "设备开机率", "value": "94.2", "unit": "%", "delta": "+1.2%", "dir": "up" },
      { "label": "库存周转天数", "value": "28", "unit": "天", "delta": "+3天", "dir": "up" },
      { "label": "本月能耗费用", "value": "186", "unit": "万元", "delta": "-2.4%", "dir": "down" },
      { "label": "后勤工单", "value": "156", "unit": "单", "note": "完结率 92%" }
    ],
    "energy_trend": {
      "unit": "万元",
      "months": ["5月", "6月", "7月", "8月", "9月", "10月"],
      "total": [182, 196, 214, 210, 192, 186],
      "electricity": [112, 126, 142, 138, 120, 114],
      "water": [38, 42, 46, 44, 40, 38],
      "gas": [32, 28, 26, 28, 32, 34]
    },
    "stock_alerts": [
      { "name": "一次性使用输液器", "days": 46, "level": "urgent" },
      { "name": "骨科植入物（接骨板）", "days": 42, "level": "urgent" },
      { "name": "造影剂（碘海醇）", "days": 36, "level": "major" },
      { "name": "医用缝合线", "days": 34, "level": "major" },
      { "name": "中心静脉导管", "days": 31, "level": "major" },
      { "name": "无菌手术衣", "days": 29, "level": "major" }
    ],
    "large_equipments": {
      "columns": [
        { "key": "name", "title": "设备名称" },
        { "key": "dept", "title": "所属科室" },
        { "key": "count", "title": "台数", "align": "right", "num": true },
        { "key": "open_rate", "title": "开机率", "align": "right" },
        { "key": "monthly", "title": "月均检查/治疗人次", "align": "right", "num": true },
        { "key": "income", "title": "月创收（万元）", "align": "right", "num": true },
        { "key": "roi", "title": "效益评价", "align": "center" }
      ],
      "rows": [
        { "name": "3.0T 核磁共振", "dept": "放射科", "count": 2, "open_rate": 96.8, "monthly": "2,860", "income": "486", "roi": "良好" },
        { "name": "256 排 CT", "dept": "放射科", "count": 2, "open_rate": 94.6, "monthly": "4,120", "income": "412", "roi": "良好" },
        { "name": "DSA 血管造影机", "dept": "介入中心", "count": 1, "open_rate": 88.4, "monthly": "380", "income": "296", "roi": "良好" },
        { "name": "直线加速器", "dept": "放疗科", "count": 1, "open_rate": 91.2, "monthly": "420", "income": "268", "roi": "良好" },
        { "name": "PET-CT", "dept": "核医学科", "count": 1, "open_rate": 72.6, "monthly": "186", "income": "158", "roi": "偏低" },
        { "name": "高清电子胃肠镜", "dept": "内镜中心", "count": 6, "open_rate": 89.8, "monthly": "1,640", "income": "226", "roi": "一般" },
        { "name": "体外冲击波碎石机", "dept": "泌尿外科", "count": 1, "open_rate": 64.2, "monthly": "92", "income": "46", "roi": "偏低" }
      ]
    }
  }
  ```
  > **字段注**：
  > 1. `energy_trend` 包含 `total` 总能耗序列（万元），分项与总计相互自洽。
  > 2. `stock_alerts` 中的 `days` 明确为“库存可用天数”，`level` 统一采用英文枚举。
  > 3. `large_equipments` 键名改为 `open_rate`，数值下发纯浮点数（如 `96.8`），补全视图 7 台重点大型医疗设备明细。
- **可返回错误码**：`10001` (INVALID_PARAM)

---

## 12. 对比分析 /workbench/compare

对应页面：`src/views/workbench/CompareView.vue`。

### 12.1 GET /workbench/compare
- **Query 参数**：
  - `dim` = `scale` | `benefit` | `efficiency` | `quality`（默认 `scale`）
  - `range` = `本月` | `本季` | `本年`（默认 `本月`）
- **维度枚举与 UI 标签映射表**：
  | `dim` 枚举 | UI 对应名称 | 默认核心度量 | 单位 |
  | :--- | :--- | :--- | :--- |
  | `scale` | 业务量 | 业务量当量 | 当量/人次 |
  | `benefit` | 收入 | 医疗收入 | 万元 |
  | `efficiency` | 效率 | 床位周转次数 | 次 |
  | `quality` | 质量 | 质量综合评分 | 分 |

- **Response `data`（以 `dim=scale` 为例）**：
  ```json
  {
    "dimension": "scale",
    "range": "本月",
    "radar": {
      "indicators": [
        { "name": "业务规模", "max": 100 },
        { "name": "收入能力", "max": 100 },
        { "name": "运营效率", "max": 100 },
        { "name": "医疗质量", "max": 100 },
        { "name": "患者满意", "max": 100 },
        { "name": "科研教学", "max": 100 }
      ],
      "series": [
        { "name": "本院", "value": [86, 82, 78, 88, 90, 74] },
        { "name": "区域同级均值", "value": [72, 70, 68, 76, 78, 58] }
      ]
    },
    "benchmarks": [
      { "name": "年门急诊量（万人次）", "ours": "108.8", "region": "90.0", "bench": "128.0", "gap": "+18.8" },
      { "name": "年出院人数（万人）", "ours": "8.64", "region": "8.22", "bench": "11.58", "gap": "+0.42" },
      { "name": "平均住院日（天）", "ours": "6.8", "region": "7.9", "bench": "6.2", "gap": "-1.1" },
      { "name": "三四级手术占比（%）", "ours": "58.6", "region": "48.2", "bench": "65.0", "gap": "+10.4" },
      { "name": "药占比（%）", "ours": "28.4", "region": "31.6", "bench": "25.0", "gap": "-3.2" },
      { "name": "CMI 值", "ours": "1.08", "region": "0.96", "bench": "1.22", "gap": "+0.12" }
    ],
    "table": {
      "columns": [
        { "key": "rank", "title": "排名", "align": "center" },
        { "key": "dept", "title": "科室" },
        { "key": "metric", "title": "业务量当量" },
        { "key": "yoy", "title": "同比", "align": "right", "num": true },
        { "key": "outp", "title": "门诊人次", "align": "right", "num": true },
        { "key": "inpt", "title": "出院人次", "align": "right", "num": true },
        { "key": "days", "title": "平均住院日", "align": "right", "num": true },
        { "key": "sat", "title": "满意度", "align": "right", "num": true }
      ],
      "rows": [
        { "rank": 1, "dept": "心血管内科", "metric": "25,360", "bar_pct": 100, "yoy": "+6.2%", "outp": 12860, "inpt": 1250, "days": 9.2, "sat": 96.2 },
        { "rank": 2, "dept": "呼吸与危重症医学科", "metric": "21,480", "bar_pct": 85, "yoy": "+8.7%", "outp": 11580, "inpt": 990, "days": 10.4, "sat": 94.8 },
        { "rank": 3, "dept": "骨科", "metric": "18,360", "bar_pct": 72, "yoy": "+5.8%", "outp": 7160, "inpt": 1120, "days": 8.6, "sat": 95.4 },
        { "rank": 4, "dept": "神经内科", "metric": "17,680", "bar_pct": 70, "yoy": "+4.1%", "outp": 9680, "inpt": 800, "days": 11.2, "sat": 93.6 },
        { "rank": 5, "dept": "普通外科", "metric": "15,280", "bar_pct": 60, "yoy": "+3.4%", "outp": 6080, "inpt": 920, "days": 7.8, "sat": 94.2 },
        { "rank": 6, "dept": "肿瘤科", "metric": "11,800", "bar_pct": 47, "yoy": "+5.9%", "outp": 4450, "inpt": 735, "days": 12.6, "sat": 92.8 }
      ]
    }
  }
  ```
  > **字段注**：
  > 1. `radar` 重构为全院 6 大宏观决策能力维度（0–100 分），直接对比“本院”与“区域同级均值”，消除了单科室内指标量纲混杂的歧义。
  > 2. `benchmarks` 中的 `gap` 统一定义为 `= 本院 - 区域均值`；门急诊年业务量调整为万人口径，与全院累计量级对齐。
  > 3. `table` 补充 `rank` 排名列；`bar_pct` 表示条形宽度归一化百分比（`val / max * 100`）；`metric` 列标题随 `dim` 动态变换。
  > 4. `metric`（业务量当量）派生公式冻结为 `outp + inpt × 10`（门诊人次 + 出院人次×10 权重），`outp`/`inpt` 与 §5.1 科室表及 §3.3 TOP10 同口径同源，服务端按事实层实算。
- **可返回错误码**：`10001` (INVALID_PARAM)

---

## 13. 专题分析与设置 /workbench/topics & /workbench/settings

### 13.1 GET /workbench/topics
- **Query 参数**：
  - `topic` = `drg`（DRG付费） | `insurance`（医保基金） | `exam`（三级国考） | `outp_fund`（门诊统筹）
  - `range` = `本月` | `本季` | `本年`（默认 `本年`）

#### 示例 1：`topic=drg`
```json
{
  "topic": "drg",
  "range": "本年",
  "stats": [
    { "label": "CMI 值", "value": "1.09", "delta": "持平", "delta_label": "较上月", "dir": "flat" },
    { "label": "入组率", "value": "98.5", "unit": "%", "delta": "+0.3%", "delta_label": "较上月", "dir": "up" },
    { "label": "费用消耗指数", "value": "0.66", "delta": "+0.01", "delta_label": "较上月", "dir": "up" },
    { "label": "时间消耗指数", "value": "0.97", "delta": "-0.01", "delta_label": "较上月", "dir": "down" },
    { "label": "RW≥2 占比", "value": "10.0", "unit": "%", "delta": "+0.1%", "delta_label": "较上月", "dir": "up" },
    { "label": "低风险组死亡率", "value": "0.03", "unit": "%", "delta": "持平", "delta_label": "较上月", "dir": "flat" }
  ],
  "chart": {
    "title": "病组权重（RW）分布",
    "sub": "本年出院病例按 RW 分段（仅已入组病例）",
    "type": "bar",
    "unit": "例",
    "categories": ["<0.5", "0.5-1", "1-2", "2-5", "5-10", "≥10"],
    "values": [9927, 38841, 31037, 6995, 1413, 418]
  },
  "table": {
    "title": "科室 DRG 核心指标",
    "sub": "按 CMI 降序排列",
    "columns": [
      { "key": "dept", "title": "科室" },
      { "key": "cmi", "title": "CMI", "align": "right", "num": true },
      { "key": "cases", "title": "入组病例", "align": "right", "num": true },
      { "key": "cost_idx", "title": "费用消耗指数", "align": "right", "num": true },
      { "key": "time_idx", "title": "时间消耗指数", "align": "right", "num": true },
      { "key": "rw2", "title": "RW≥2 占比", "align": "right", "num": true },
      { "key": "profit", "title": "DRG 结余（万元）", "align": "right", "num": true }
    ],
    "rows": [
      { "dept": "神经外科", "cmi": "1.68", "cases": "3,133", "cost_idx": "0.65", "time_idx": "1.50", "rw2": "20.4%", "profit": "-12.8" },
      { "dept": "心血管内科", "cmi": "1.42", "cases": "14,447", "cost_idx": "0.59", "time_idx": "0.96", "rw2": "12.5%", "profit": "+86.4" },
      { "dept": "骨科", "cmi": "1.36", "cases": "13,059", "cost_idx": "0.73", "time_idx": "1.13", "rw2": "15.1%", "profit": "+124.6" },
      { "dept": "肿瘤科", "cmi": "1.24", "cases": "8,611", "cost_idx": "0.74", "time_idx": "1.19", "rw2": "12.3%", "profit": "-34.6" },
      { "dept": "普通外科", "cmi": "1.18", "cases": "10,659", "cost_idx": "0.74", "time_idx": "0.92", "rw2": "11.7%", "profit": "+98.2" },
      { "dept": "呼吸与危重症医学科", "cmi": "1.12", "cases": "11,491", "cost_idx": "0.64", "time_idx": "1.07", "rw2": "10.6%", "profit": "+42.8" },
      { "dept": "神经内科", "cmi": "0.94", "cases": "9,387", "cost_idx": "0.64", "time_idx": "1.15", "rw2": "6.2%", "profit": "+38.2" },
      { "dept": "儿科", "cmi": "0.68", "cases": "7,513", "cost_idx": "0.40", "time_idx": "0.60", "rw2": "2.1%", "profit": "+28.4" }
    ]
  }
}
```
> **字段注**：
> 1. `RW≥2 占比` 统计值与下方病组权重柱状图中 `(6995+1413+418) / 88631` 的分段合计严格自洽；`chart.sub`/`table.sub` 口径词随 `range` 实写（`本年`→“本年…”）。
> 2. 键名改为 `cost_idx` 与 `time_idx`（snake_case）；科室列表严格按 CMI 降序排列并补全视图 8 行数据；`cmi`/`profit` 为 §14.1 注10 的冻结事实列，不随 `range` 缩放。

#### 示例 2：`topic=insurance`
```json
{
  "topic": "insurance",
  "range": "本年",
  "stats": [
    { "label": "医保结算人次", "value": "90,155", "delta": "+32.9%", "delta_label": "较上年", "dir": "up" },
    { "label": "医保基金支付", "value": "98,756", "unit": "万元", "delta": "+46.1%", "delta_label": "较上年", "dir": "up" },
    { "label": "基金结余率", "value": "6.8", "unit": "%", "delta": "+0.4%", "delta_label": "较上年", "dir": "up" },
    { "label": "拒付/扣款率", "value": "0.8", "unit": "%", "delta": "持平", "delta_label": "较上年", "dir": "flat" },
    { "label": "次均医保费用", "value": "10,954", "unit": "元", "delta": "+10.0%", "delta_label": "较上年", "dir": "up" },
    { "label": "异地就医结算", "value": "5,175", "unit": "人次", "delta": "+33.1%", "delta_label": "较上年", "dir": "up" }
  ],
  "chart": {
    "title": "医保基金月度支付",
    "sub": "近 6 个月（万元）",
    "type": "line",
    "unit": "万元",
    "months": ["5月", "6月", "7月", "8月", "9月", "10月"],
    "values": [8295, 8648, 9288, 9028, 8715, 9861]
  },
  "table": {
    "title": "分险种结算情况",
    "sub": "本年",
    "columns": [
      { "key": "type", "title": "险种" },
      { "key": "cases", "title": "结算人次", "align": "right", "num": true },
      { "key": "fund", "title": "基金支付（万元）", "align": "right", "num": true },
      { "key": "self", "title": "个人自付（万元）", "align": "right", "num": true },
      { "key": "ratio", "title": "报销比例", "align": "right", "num": true },
      { "key": "status", "title": "运行状态", "align": "center" }
    ],
    "rows": [
      { "type": "职工医保", "cases": "45,653", "fund": "56,888", "self": "14,224", "ratio": "80.0%", "status": "平稳" },
      { "type": "居民医保", "cases": "34,580", "fund": "34,255", "self": "14,886", "ratio": "69.7%", "status": "平稳" },
      { "type": "生育保险", "cases": "5,185", "fund": "4,207", "self": "1,283", "ratio": "76.6%", "status": "平稳" },
      { "type": "大病保险", "cases": "3,053", "fund": "2,864", "self": "863", "ratio": "76.8%", "status": "关注" },
      { "type": "医疗救助", "cases": "1,684", "fund": "543", "self": "119", "ratio": "82.0%", "status": "平稳" }
    ]
  }
}
```

#### 示例 3：`topic=exam`
```json
{
  "topic": "exam",
  "range": "本年",
  "stats": [
    { "label": "国考预估得分", "value": "786", "unit": "分", "delta": "+18分", "delta_label": "较上年", "dir": "up" },
    { "label": "指标达标率", "value": "82.4", "unit": "%", "delta": "+3.6%", "delta_label": "较上年", "dir": "up" },
    { "label": "医疗质量得分率", "value": "86.2", "unit": "%", "delta": "+2.4%", "delta_label": "较上年", "dir": "up" },
    { "label": "运营效率得分率", "value": "78.6", "unit": "%", "delta": "+4.2%", "delta_label": "较上年", "dir": "up" },
    { "label": "持续发展得分率", "value": "74.8", "unit": "%", "delta": "+1.8%", "delta_label": "较上年", "dir": "up" },
    { "label": "满意度得分率", "value": "91.2", "unit": "%", "delta": "+0.6%", "delta_label": "较上年", "dir": "up" }
  ],
  "chart": {
    "title": "近 6 个月指标达标率",
    "sub": "已监测指标达标占比",
    "type": "line",
    "unit": "%",
    "months": ["5月", "6月", "7月", "8月", "9月", "10月"],
    "values": [74.2, 76.8, 78.4, 79.6, 81.2, 82.4]
  },
  "table": {
    "title": "关键国考指标",
    "sub": "得分率偏低的重点项",
    "columns": [
      { "key": "name", "title": "指标名称" },
      { "key": "full", "title": "分值", "align": "right", "num": true },
      { "key": "score", "title": "得分率", "align": "right", "num": true },
      { "key": "trend", "title": "趋势", "align": "center" },
      { "key": "owner", "title": "责任部门" }
    ],
    "rows": [
      { "name": "出院患者四级手术比例", "full": 40, "score": "68%", "trend": "↑", "owner": "医务部" },
      { "name": "人员支出占业务支出比重", "full": 30, "score": "64%", "trend": "→", "owner": "人力资源部" },
      { "name": "每床日收入（剔除药耗）", "full": 30, "score": "72%", "trend": "↑", "owner": "财务部" },
      { "name": "万元收入能耗支出", "full": 20, "score": "76%", "trend": "↑", "owner": "后勤保障部" },
      { "name": "医护比", "full": 20, "score": "82%", "trend": "↑", "owner": "人力资源部" },
      { "name": "住院患者满意度", "full": 20, "score": "95%", "trend": "→", "owner": "护理部" }
    ]
  }
}
```

#### 示例 4：`topic=outp_fund`
```json
{
  "topic": "outp_fund",
  "range": "本年",
  "stats": [
    { "label": "门诊统筹结算人次", "value": "61,644", "delta": "+22.0%", "delta_label": "较上年", "dir": "up" },
    { "label": "统筹基金支付", "value": "4,783", "unit": "万元", "delta": "+22.6%", "delta_label": "较上年", "dir": "up" },
    { "label": "人均统筹费用", "value": "776", "unit": "元", "delta": "+0.5%", "delta_label": "较上年", "dir": "up" },
    { "label": "个人账户支出", "value": "3,210", "unit": "万元", "delta": "+22.5%", "delta_label": "较上年", "dir": "up" },
    { "label": "慢特病结算", "value": "18,080", "unit": "人次", "delta": "+27.6%", "delta_label": "较上年", "dir": "up" },
    { "label": "处方外流率", "value": "12.4", "unit": "%", "delta": "+2.8%", "delta_label": "较上年", "dir": "up" }
  ],
  "chart": {
    "title": "门诊统筹基金月度支出",
    "sub": "近 6 个月（万元）",
    "type": "line",
    "unit": "万元",
    "months": ["5月", "6月", "7月", "8月", "9月", "10月"],
    "values": [342, 387, 412, 438, 456, 488]
  },
  "table": {
    "title": "科室门诊统筹使用",
    "sub": "按统筹支付额排序",
    "columns": [
      { "key": "dept", "title": "科室" },
      { "key": "cases", "title": "结算人次", "align": "right", "num": true },
      { "key": "fund", "title": "统筹支付（万元）", "align": "right", "num": true },
      { "key": "avg", "title": "人均费用（元）", "align": "right", "num": true },
      { "key": "chronic", "title": "慢特病占比", "align": "right", "num": true }
    ],
    "rows": [
      { "dept": "内分泌科", "cases": "10,304", "fund": "804.1", "avg": "780", "chronic": "49.9%" },
      { "dept": "心血管内科", "cases": "9,579", "fund": "745.7", "avg": "778", "chronic": "45.7%" },
      { "dept": "神经内科", "cases": "7,157", "fund": "556.8", "avg": "778", "chronic": "37.0%" },
      { "dept": "呼吸与危重症医学科", "cases": "6,236", "fund": "486.4", "avg": "780", "chronic": "28.1%" },
      { "dept": "消化内科", "cases": "5,354", "fund": "417.9", "avg": "780", "chronic": "22.9%" },
      { "dept": "中医科", "cases": "4,893", "fund": "381.4", "avg": "780", "chronic": "32.6%" }
    ]
  }
}
```
- **可返回错误码**：`10001` (INVALID_PARAM)

### 13.2 GET /workbench/settings/config
- **说明**：设置页面的数据源连接状态、预警阈值、权限用户与系统偏好。
- **Response `data`**：
  ```json
  {
    "data_sources": [
      { "name": "HIS 门诊收费系统", "type": "业务库 · 准实时", "status": "已连接", "sync": "2026-10-28 09:42" },
      { "name": "HIS 住院管理系统", "type": "业务库 · 准实时", "status": "已连接", "sync": "2026-10-28 09:42" },
      { "name": "EMR 电子病历", "type": "业务库 · 小时级", "status": "已连接", "sync": "2026-10-28 09:00" },
      { "name": "LIS 检验系统", "type": "业务库 · 小时级", "status": "已连接", "sync": "2026-10-28 09:05" },
      { "name": "HRP 人财物系统", "type": "业务库 · 日终批", "status": "已连接", "sync": "2026-10-28 06:30" },
      { "name": "医保结算接口", "type": "局端接口 · 日终批", "status": "异常", "sync": "2026-10-27 23:58" }
    ],
    "thresholds": [
      { "code": "BED_OVER_95", "name": "床位使用率", "rule": "连续 3 日 > 95%", "level": "urgent", "enabled": true },
      { "code": "DRUG_RATIO_WARN", "name": "药占比", "rule": "> 30%", "level": "major", "enabled": true },
      { "code": "MAT_OVER_20", "name": "耗占比", "rule": "> 20%", "level": "major", "enabled": true },
      { "code": "INPT_FEE_SURGE", "name": "住院费用增幅", "rule": "同比 > 8%", "level": "urgent", "enabled": true },
      { "code": "STOCK_TURN_SLOW", "name": "库存周转天数", "rule": "> 35 天", "level": "minor", "enabled": true },
      { "code": "CRIT_TIMEOUT_95", "name": "危急值超时率", "rule": "及时率 < 95%", "level": "urgent", "enabled": true },
      { "code": "EQUIP_RUN_LOW", "name": "设备开机率", "rule": "< 60%", "level": "minor", "enabled": false }
    ],
    "users": [
      { "name": "system_admin", "role": "管理员", "scope": "全部", "login": "2026-10-28 09:12", "status": "启用" },
      { "name": "院长", "role": "院领导", "scope": "全院", "login": "2026-10-28 08:46", "status": "启用" },
      { "name": "分管副院长·医疗", "role": "院领导", "scope": "全院", "login": "2026-10-27 17:32", "status": "启用" },
      { "name": "医务部主任", "role": "部门负责人", "scope": "医疗业务", "login": "2026-10-28 08:58", "status": "启用" },
      { "name": "财务部主任", "role": "部门负责人", "scope": "运营财务", "login": "2026-10-28 09:05", "status": "启用" },
      { "name": "骨科主任", "role": "科室主任", "scope": "骨科", "login": "2026-10-28 08:30", "status": "启用" }
    ],
    "preferences": {
      "default_range": "本月",
      "refresh_interval": "5 分钟",
      "alert_sound": true,
      "unit_abbreviation": true,
      "privacy_mask": true
    }
  }
  ```
  > **字段注**：
  > 1. `thresholds` 中的 `level` 统一使用英文枚举 `urgent | major | minor`。
  > 2. `sync` 和 `login` 日期时间统一为 `YYYY-MM-DD HH:mm` 规范。
  > 3. `users` 中保留“骨科主任”以与演示系统三级角色故事闭环。
  > 4. `thresholds[].code` 为规则寻址键（`ads.alert_rule.code`），即 R15 写回端点（§15.7）的路径参数。
- **可返回错误码**：`10001` (INVALID_PARAM)

---

## 14. 辅助形态：科技大屏快照 /screen/snapshot

对应页面：`/screen` 大屏（重建中，视觉基准 `archive/smart-hospital-cockpit/`，旧过渡组件已删除）。

### 14.1 GET /screen/snapshot
- **说明**：科技大屏一站式加载快照。继承并升级原结构，一次性供给大屏态势展示渲染。
- **Response `data`**：
  ```json
  {
    "server_time": "2026-10-28T08:30:00+08:00",
    "status": {
      "level": "normal",
      "text": "运行平稳",
      "desc": "医院整体运行正常",
      "alert_open": { "urgent": 1, "major": 2, "minor": 2 }
    },
    "kpis": [
      { "code": "OP_DAILY_VISITS", "name": "今日门急诊", "value": 4200, "unit": "人", "prev_value": 3950, "delta_pct": 6.3, "direction": 1, "spark": [3800, 3950, 4100, 3900, 4050, 3950, 4200], "status": "normal" },
      { "code": "IP_IN_HOSP", "name": "在院患者", "value": 1846, "unit": "人", "prev_value": 1820, "delta_pct": 1.4, "direction": 1, "spark": [1780, 1800, 1810, 1825, 1830, 1820, 1846], "status": "normal" },
      { "code": "BED_USE_RATE", "name": "床位使用率", "value": 92.1, "unit": "%", "prev_value": 90.8, "delta_pct": 1.4, "direction": 1, "spark": [88.5, 89.2, 90.1, 91.0, 91.5, 90.8, 92.1], "status": "warn" },
      { "code": "SURG_DAILY_CNT", "name": "今日手术", "value": 45, "unit": "台", "prev_value": 42, "delta_pct": 7.1, "direction": 1, "spark": [38, 40, 42, 39, 41, 42, 45], "status": "normal" }
    ],
    "drg_quadrant": {
      "period": "d30",
      "period_label": "近30日",
      "axis": { "x": "DRG盈亏(万元)", "y": "CMI" },
      "split": { "x": 0, "y": 1.0 },
      "points": [
        { "dept_id": 1, "name": "骨科", "category": "surg", "cmi": 1.36, "profit": 124.6, "case_cnt": 1232, "quadrant": 2 },
        { "dept_id": 2, "name": "心血管内科", "category": "med", "cmi": 1.42, "profit": 86.4, "case_cnt": 1360, "quadrant": 2 },
        { "dept_id": 3, "name": "肿瘤科", "category": "med", "cmi": 1.24, "profit": -34.6, "case_cnt": 810, "quadrant": 1 },
        { "dept_id": 4, "name": "神经外科", "category": "surg", "cmi": 1.68, "profit": -12.8, "case_cnt": 294, "quadrant": 1 },
        { "dept_id": 5, "name": "儿科", "category": "med", "cmi": 0.68, "profit": 28.4, "case_cnt": 707, "quadrant": 4 }
      ]
    },
    "buildings": [
      { "code": "mz", "name": "门诊楼", "status": "normal", "badge": "4,200 人", "badge_level": "info", "anchor": { "x": 24.0, "y": 36.2 }, "metrics": { "today_visit": 4200, "queue_avg_min": 18 }, "primary_metric": { "key": "queue_avg_min", "label": "候诊均时", "unit": "分", "max": 60 } },
      { "code": "wk", "name": "外科楼", "status": "busy", "badge": "96% 负荷", "badge_level": "warn", "anchor": { "x": 51.0, "y": 23.7 }, "metrics": { "bed_use_rate": 96.0, "bed_used": 192, "bed_open": 200 }, "primary_metric": { "key": "bed_use_rate", "label": "床位使用率", "unit": "%", "max": 100 } },
      { "code": "jz", "name": "急诊楼", "status": "alert", "badge": "留观超时", "badge_level": "alert", "anchor": { "x": 71.8, "y": 42.4 }, "metrics": { "obs_over6h": 3, "obs_cnt": 11, "obs_max_min": 560 }, "primary_metric": { "key": "obs_over6h", "label": "留观超时", "unit": "起", "max": 10 } },
      { "code": "yj", "name": "医技楼", "status": "normal", "badge": "设备正常", "badge_level": "ok", "anchor": { "x": 57.1, "y": 39.1 }, "metrics": { "device_run": 12, "device_alert": 0 }, "primary_metric": { "key": "device_run", "label": "设备运行", "unit": "台", "max": 12 } }
    ],
    "dept_ranking": [
      { "rank": 1, "dept_id": 1, "name": "骨科", "category": "surg", "cmi": 1.36, "surg_cnt": 280, "alos": 8.6, "profit": 124.6, "eff_score": 94.2 },
      { "rank": 2, "dept_id": 2, "name": "心血管内科", "category": "med", "cmi": 1.42, "surg_cnt": 240, "alos": 9.2, "profit": 86.4, "eff_score": 92.8 }
    ],
    "alerts": {
      "total_open": 5,
      "list": [
        { "id": 51, "level": "urgent", "title": "急诊留观超时（>6h）", "dept": "急诊科", "occurred_at": "2026-10-28T08:12:00+08:00" },
        { "id": 52, "level": "major", "title": "外科楼重症监护床位达98%", "dept": "重症医学科", "occurred_at": "2026-10-28T08:20:00+08:00" }
      ]
    },
    "trends": {
      "days": 7,
      "dates": ["10-22", "10-23", "10-24", "10-25", "10-26", "10-27", "10-28"],
      "series": {
        "OP_DAILY_VISITS": [3800, 3950, 4100, 3900, 4050, 3950, 4200],
        "IP_IN_HOSP": [1780, 1800, 1810, 1825, 1830, 1820, 1846],
        "SURG_DAILY_CNT": [38, 40, 42, 39, 41, 42, 45],
        "BED_USE_RATE": [88.5, 89.2, 90.1, 91.0, 91.5, 90.8, 92.1]
      }
    }
  }
  ```
  > **字段注**：
  > 1. `server_time` 统一使用基准日 `"2026-10-28T08:30:00+08:00"`，`dates` 序列对齐为 `10-22 ~ 10-28`；演示基准日 `BASE_DATE=2026-10-28`（周三工作日），KPI/月累计均锚定 10 月。
  > 2. 日业务量量级与工作台月累计完全自洽：门急诊日均约 4,200 人次（月累计约 123,000），手术日均约 45 台（月累计约 1,286）。
  > 3. `profit` 统一为万元单位浮点数值（如 `124.6` 万元）；`bed_use_rate` 统一为展示百分比口径（`96.0`）；未闭环告警数 `alert_open.urgent = 1`，与告警列表首条紧急事件一致。
  > 4. 告警时间字段使用 `occurred_at` ISO 格式。
  > 5. `dept_ranking.eff_score` 为展示示意值（归一公式见 §10 注），API 出参以服务端按当前分布实算为准；`rank` 序与 `cmi/profit` 事实列一致即可。
  > 6. **屏值事实化原则**：`kpis[].value/prev_value/spark`、`buildings[].badge/metrics`、趋势 `dates/series` 等屏显数值一律由当前事实层（dwd/dws）按基准日实算得出，契约 JSON 中的字面量为**形态示例**，服务端出参允许 ±10% 采样容差；判定依据为"同一时刻 KPI 值 = spark 末点 = 楼宇徽标 = 事实层当日值"的内部一致性，而非与示例字面逐一相等。
  > 7. `buildings[].anchor` 为**渲染后图像矩形**内的百分比坐标（x/y ∈ 0–100，相对院区底图可见区域，非容器盒）；示例值为当前底图校准值，换底图需随图重校。
  > 8. `buildings[].primary_metric` 为楼宇主指标的**展示元数据**（`key` 指向 `metrics` 内键、`label` 中文名、`unit` 展示单位、`max` 归一量程上限）；契约缺该字段时前端不得自造展示口径（演示期 mock 必发）。
  > 9. `drg_quadrant.period_label` 为 `period` 的可读展示文案（如 `d30`→`近30日`）；`status.level` 枚举 `normal|busy|alert`。
  > 10. `dept_ranking`/`drg_quadrant.points` 中科室的 `cmi/profit` 事实列必须与 §13.1 冻结表一致（如 神经内科 cmi=0.94/profit=+38.2、普通外科 cmi=1.18/profit=+98.2），扩排行亦不得偏离冻结值。
  > 11. `dept_id`/`building_code` 等 id 语义以 `dim.department`/`dim.building` 注册表为准，mock 与 backend 须同源；示例中的 id 字面为形态示例。
- **可返回错误码**：`10001` (INVALID_PARAM)

---

## 15. 远期预留端点清单（Reserved Endpoints Checklist）

以下端点源自 v1.1 深度决策架构设计，属于**“远期真实业务演进与后端落地项”**。在当前前端 Mock/API 解耦阶段，前端不发起真实调用，保留此清单以备未来后端开发与深层穿透扩展：

> **操作人传输约定（演示期）**：本清单写端点（R04–R08、R15、R16）的操作人一律经 Query `?role=<username>` 显式传输——缺席取 `president`，出席须为合法演示账号（非法 → `10001`），写入 `ack_by`/`dispatcher_id`/`sys.audit_log` 等操作人列。会话机制（§2.3）落地后改由会话中间件解析操作人并按端点角色矩阵校验 `20001`/`20004`/`20005`，届时 `?role=` 语义回归 §2.1 演示切换注。

| # | Method | Path | 用途与定位 | 规划阶段 | 错误码 | 说明 |
| :- | :----- | :--- | :--------- | :------ | :----- | :--- |
| R01 | GET | `/cases` | L4 病例列表（按科室/病组/死因筛选） | P2 | 10001, 10002, 30001 | 用于从 DRG 病组穿透至具体病例集合，带分页参数 |
| R02 | GET | `/cases/{id}` | L5 电子病历（脱敏事实） | P2 | 10001, 30001, 30002 | 默认患者姓名身份证脱敏（`张**`） |
| R03 | GET | `/cases/{id}?unmask=1` | L5 实名解密调阅 | P2 | 10001, 20002, 32006 | 需二次验密（验密口令错误码 32006 已在 error-codes.md 注册）并记录审计日志 |
| R04 | POST | `/alerts/{id}/ack` | 告警认领 | P2 | 10001, 33001, 33002 | 告警状态变为 `processing`；展开见 §15.1 |
| R05 | POST | `/alerts/{id}/dispatch` | 告警一键督办派发 | P2 | 10001, 10002, 33001, 33002, 33102, 33103 | 生成 Todo 工单，指定承办人与截止期；展开见 §15.2 |
| R06 | POST | `/alerts/{id}/close` | 告警直接闭环关闭 | P2 | 10001, 10002, 33001, 33002 | 填写办结理由与改善说明；展开见 §15.3 |
| R07 | GET | `/todos` | 督办追踪工单列表 | P2 | 10001, 10002 | 包含整改前/当前/目标值三点锚点，带分页参数；展开见 §15.4 |
| R08 | POST | `/todos/{id}/status` | 督办工单反馈与办结 | P2 | 10001, 10002, 20005, 33101, 33104 | 承办科室主任提交整改举措并申请验收；展开见 §15.5 |
| R09 | GET | `/campus/buildings/{code}`| 楼宇详情抽屉（病区/设备） | P2 | 10001, 30001 | 大屏点击外科楼/急诊楼拉出二级抽屉 |
| R10 | GET | `/staff` | 组织人员下拉选择器 | P2 | 10001 | 督办派发时根据科室联想责任人；展开见 §15.6 |
| R11 | POST| `/auth/login` | 会话登录（Cookie Session） | P3 | 10001, 10006, 20001, 20101, 20102, 20104 | **已展开为正式小节 → §2.3**（凭证机制 = PG 会话表 + HttpOnly Cookie，非 JWT） |
| R12 | POST| `/auth/refresh` | Token 静默轮换 | P3 | 10001, 20003, 20004 | **保留远期**：Bearer/refresh 轮换路线备选；当前凭证为会话 Cookie（§2.3），本端点不实施 |
| R13 | POST| `/metrics/query` | ChatBI / 指标语义层查询 | P3 | 10001, 30001 | 大模型 NLQ to DSL 智能问数接口 |
| R14 | GET/POST | `/sim/*` | 仿真时钟与故障注入 | P3 | 10001, 10002, 35002, 35003 | **已展开为正式节 → §16**（档 A：时钟控制面） |
| R15 | POST | `/workbench/settings/rules/{code}` | 预警阈值启停写回 | P3 | 10001, 10003, 10006, 20005 | 设置页阈值表开关持久化（`ads.alert_rule.enabled`）；展开见 §15.7 |
| R16 | PUT | `/workbench/settings/preferences` | 系统偏好写回 | P3 | 10001, 10002, 10006 | 设置页 5 项偏好表单持久化（`sys.user_pref` upsert）；展开见 §15.8 |

> **错误码注**：R01/R02/R09/R13 引用的 `30001`/`30002` 定义见 `error-codes.md` §3「通用业务 30xxx」段；R04–R08 的 `33xxx` 系列定义见同文「告警与督办」段（§15 早期版本误挂 `310xx` 指标域码，本次对账修正）。

### 15.1 R04 `POST /alerts/{id}/ack` — 告警认领
- **说明**：将告警从 `pending` 推进到 `processing`（认领）。操作人经 `?role=` 传输（见本节头部约定）。
- **路径参数**：`id`（int，必填，`ads.alert_event.id`）
- **Request JSON**：`{}`（无字段）
- **Response `data`**：
  ```json
  { "id": 12, "alert_status": "processing", "ack_at": "2026-10-28T09:12:00+08:00", "ack_by": 1 }
  ```
- **可返回错误码**：`10001`（id 非数 / `?role=` 非法）、`33001`（告警不存在）、`33002`（已非 `pending`，`data.current_status` 回传最新态——重复认领同此码，天然幂等）
- **语义注**：单事务 `FOR UPDATE` 锁行 → 校验 `alert_status='pending'` → `UPDATE`（`ack_at` 取虚拟时钟 `virtual_now`、`ack_by` 取操作人 id）→ `sys.audit_log` 写 `alert_ack`。

### 15.2 R05 `POST /alerts/{id}/dispatch` — 告警督办派发
- **说明**：告警一键派发为督办工单（`ads.todo_order`）；`pending` 告警连带自动认领（→`processing`）。
- **路径参数**：`id`（int，必填）
- **Request JSON**：

  | 字段 | 类型 | 必填 | 说明 |
  | :--- | :--- | :--- | :--- |
  | `assignee_id` | int | 是 | 承办人（`dim.staff.id`，须在职；科室关系校验见 `33102`） |
  | `deadline` | string | 是 | 截止时间，ISO 8601（须晚于 `virtual_now`） |
  | `title` | string | 否 | 工单标题，缺省=告警标题 |
  | `note` | string | 否 | 派发备注 |
- **Response `data`**：
  ```json
  { "todo_id": 7, "alert_id": 12, "alert_status": "processing", "assignee_id": 118, "deadline": "2026-10-30T17:00:00+08:00" }
  ```
- **可返回错误码**：`10001`、`10002`（字段缺失/格式非法，`data.fields` 定位）、`33001`（告警不存在）、`33002`（已 `done`/`closed`/已有打开工单，`data.current_status`+`data.todo_id` 回传）、`33102`（承办人非在职或非本科室）、`33103`（deadline 不晚于当前时间）
- **幂等**：`ads.todo_order` 以部分唯一索引 `(alert_id, alert_occurred_at) WHERE todo_status IN ('open','doing')` 保证"一告警一打开工单"，撞键 → `33002`。
- **语义注**：单事务——锁告警行校验状态 → INSERT todo（`baseline_value`/`target_value`/`metric_code` 承接告警三点锚点）→ `pending` 时连带 `ack` 回填 → 审计 `todo_dispatch`。

### 15.3 R06 `POST /alerts/{id}/close` — 告警直接闭环
- **说明**：不派工单直接办结关闭，须填办结理由。
- **路径参数**：`id`（int，必填）
- **Request JSON**：

  | 字段 | 类型 | 必填 | 说明 |
  | :--- | :--- | :--- | :--- |
  | `close_note` | string | 是 | 办结理由/改善说明（空串 → `10002`） |
- **Response `data`**：
  ```json
  { "id": 12, "alert_status": "closed", "closed_at": "2026-10-28T09:40:00+08:00" }
  ```
- **可返回错误码**：`10002`（`close_note` 缺失/空串）、`33001`（告警不存在）、`33002`（已 `closed`；**存在打开工单**时亦拒，`data.current_status='todo_open'`——打开工单须先办结，不得跨越关闭）
- **语义注**：单事务锁行 → `UPDATE alert_status='closed', closed_at, close_note` → 审计 `alert_close`；重复关闭 → `33002`（幂等语义=已被处理）。

### 15.4 R07 `GET /todos` — 督办工单列表
- **说明**：督办追踪工单分页列表（`ads.todo_order`；与资产页"后勤工单"`dwd.logistics_order` 属不同域，勿混口径）。
- **Query 参数**：`page`（默认 1）、`size`（默认 20，≤100）、`status`（可选 `open|doing|done|expired`）、`assignee_id`（可选 int）
- **Response `data`**（分页包络 §1.2）：
  ```json
  { "list": [
    { "id": 7, "alert_id": 12, "title": "急诊留观超时整改",
      "assignee_id": 118, "assignee_name": "周婷", "dept_name": "急诊科",
      "deadline": "2026-10-30 17:00", "todo_status": "doing", "status_label": "办理中",
      "baseline_value": 4.2, "current_value": 3.1, "target_value": 2.0,
      "metric_code": "OBS_OVER_2H", "note": "限期三日", "result_note": null,
      "created_at": "2026-10-28 09:20" } ],
    "page": 1, "size": 20, "total": 5 }
  ```
- **字段注**：
  1. `current_value` 实时组装：`metric_code` 命中 `ads.today_kpi`（realtime 指标）取实时值，否则取 `dws.metric_value` 最新期值；无指标行 → `null`（三点锚点 = 整改前/当前/目标）。
  2. `expired` 为**存储值**：每次请求先惰性清扫 `deadline < virtual_now` 的 `open|doing` 单 → `expired`，再出参（无后台作业的确定性语义）。
  3. `deadline`/`created_at` 按 §1.4 `YYYY-MM-DD HH:mm`；`status_label` 由 `sys.dict(todo_status)` 文案渲染。
- **可返回错误码**：`10001`（page/size/status/assignee 非法）、`10002`

### 15.5 R08 `POST /todos/{id}/status` — 工单反馈与办结
- **说明**：承办人反馈工单状态；`report` 办结时同事务回填源告警 `done`。
- **路径参数**：`id`（int，必填，`ads.todo_order.id`）
- **Request JSON**：

  | 字段 | 类型 | 必填 | 说明 |
  | :--- | :--- | :--- | :--- |
  | `action` | string | 是 | `accept`（open→doing 接单）/ `report`（doing→done 办结申请验收） |
  | `result_note` | string | 条件必填 | `action=report` 时必填（整改举措/办结说明；库 CHECK 强制非空） |
- **Response `data`**：
  ```json
  { "id": 7, "todo_status": "done", "alert_id": 12, "alert_status": "done" }
  ```
- **可返回错误码**：`10001`、`10002`（action 非法/`result_note` 缺）、`20005`（`dept_leader` 仅可办本科室工单——以 `sys.user.dept_id` 比对承办人 `dim.staff.dept_id`）、`33101`（工单不存在）、`33104`（`done`/`expired` 禁变更，`data.current_status` 回传）
- **语义注**：`report` 为双表单事务——工单 `done`（`result_note` 必填落库）+ 源告警 `alert_status='done'`（`done_at` 回填）；审计 `todo_status`（`detail` 记 from→to）。
- **写后读一致性**：`home/alerts` 计数、`screen` 告警块实时派生 `alert_status IN ('pending','processing')`——ack/dispatch 不政变开数（仍在打开集），close/todo done 后自动减一；工单读面即本端点，**不回流** `home/progress`（`ads.work_item` 为行政重点工作域，不同物）。

### 15.6 R10 `GET /staff` — 承办人联想选择器
- **说明**：督办派发时按科室联想责任人（在职人员 `dim.staff.active`）。
- **Query 参数**：`dept_id`（可选 int；缺席返回全院在职人员，按负责人优先排序）
- **Response `data`**：
  ```json
  { "list": [
    { "id": 118, "code": "E0128", "name": "周婷", "title": "副主任医师",
      "dept_id": 5, "dept_name": "急诊科", "is_leader": true } ] }
  ```
- **字段注**：`is_leader` = `dim.department.leader_id = staff.id`（科室负责人优先联想）；排序 `is_leader DESC, id`。
- **可返回错误码**：`10001`（`dept_id` 非数）

### 15.7 R15 `POST /workbench/settings/rules/{code}` — 预警阈值启停写回
- **说明**：切换 `ads.alert_rule` 单条规则启停（`enabled`），对应设置页阈值表开关（`§13.2 thresholds[].code` 寻址）。
- **路径参数**：`code`（string，必填，`ads.alert_rule.code`，须为 `source='rule'` 行）
- **Request JSON**：

  | 字段 | 类型 | 必填 | 说明 |
  | :--- | :--- | :--- | :--- |
  | `enabled` | bool | 是 | 目标启停态 |
- **Response `data`**：
  ```json
  { "code": "BED_OVER_95", "enabled": false }
  ```
- **可返回错误码**：`10001`（`?role=` 非法）、`10003`（规则 code 不存在或非 `rule` 源行）、`10006`、`20005`（角色不足——写面限管理域角色 `admin`/`president`/`ops_director`）
- **语义注**：`UPDATE ... SET enabled, updated_at=virtual_now`；审计 `rule_toggle`。

### 15.8 R16 `PUT /workbench/settings/preferences` — 系统偏好写回
- **说明**：当前操作人的偏好 KV 部分更新（`sys.user_pref` upsert），对应设置页 5 项偏好表单。
- **Request JSON**（与 §13.2 `preferences` 出参同形，全部可选但至少一项）：

  | 字段 | 类型 | 说明 |
  | :--- | :--- | :--- |
  | `default_range` | string | `本月`/`本季`/`本年`（入库换算 `month`/`quarter`/`year`） |
  | `refresh_interval` | string | `5 分钟`/`15 分钟`/`30 分钟`（入库换算秒数 `300`/`900`/`1800`） |
  | `alert_sound` | bool | 预警声音 |
  | `unit_abbreviation` | bool | 单位缩写 |
  | `privacy_mask` | bool | 敏感脱敏 |
- **Response `data`**：与 §13.2 `preferences` 同形（回写后的完整偏好集）
- **可返回错误码**：`10001`（body 空对象/未知键/`?role=` 非法）、`10002`（枚举值越界，`data.fields` 定位）、`10006`
- **语义注**：逐键 `INSERT ... ON CONFLICT (user_id, pref_key) DO UPDATE`（`updated_at=virtual_now`）；审计 `pref_save`。

---

## 16. 仿真控制面 /sim/*（P3 档 A）

仿真时钟与演示控制的契约面。**环境门控**：仅 `SIM_ENABLED` 开启时注册路由；关闭（生产形态）时 `/sim/*` 一律未注册 → `NoRoute` → `10003`（error-codes §3 35xxx 段注）。操作人校验（admin 限定）待会话机制（§2.3）落地后生效，本期不解析 `?role=`。

统一前缀 `/api/v1/sim`，包络同 §1。`virtual_now`/`updated_at`/`started_at` 等时刻字段按 §1.4 ISO 8601 字符串；`weekday` 中文星期；**ads 快照层（today_kpi/campus_status/alert/dept_rank）跨日后维持"最近派生切面"冻结语义**（档 A 不触发派生重跑）。

### 16.1 GET /sim/clock
- **说明**：当前虚拟时钟状态与种子余量。
- **Response `data`**：
  ```json
  {
    "virtual_now": "2026-10-28T09:00:00+08:00",
    "base_date": "2026-10-28",
    "seed_end": "2026-12-31",
    "speed": 1,
    "paused": false,
    "weekday": "星期三",
    "updated_at": "2026-10-28T09:00:00+08:00"
  }
  ```
- **字段注**：`seed_end` 为 tick 上界事实源（`sim.profile.seed_end` 键；缺省回退 `SELECT MAX(date) FROM dwd.charge_day`）；`updated_at` 为墙钟审计字段（同包络 `ts` 豁免逻辑）；`speed`/`paused` 为远期 auto-runner 预留列，手动 tick 不读取。
- **可返回错误码**：`10000`

### 16.2 POST /sim/tick
- **说明**：虚拟时钟前移 N 分钟。**非幂等**——重复提交=重复推进。
- **Request JSON**：

  | 字段 | 类型 | 必填 | 说明 |
  | :--- | :--- | :--- | :--- |
  | `minutes` | int | 是 | `≥1`；且 `virtual_now + minutes` 不越 `seed_end + 1 天`，越界 → `35002` |
- **Response `data`**：
  ```json
  {
    "virtual_now_before": "2026-10-28T09:00:00+08:00",
    "virtual_now": "2026-10-28T10:00:00+08:00",
    "advanced_minutes": 60,
    "crossed_day": false,
    "job_id": 12
  }
  ```
- **语义注**：单事务 `SELECT…FOR UPDATE` 行锁 → 界校验 → `UPDATE sim.clock` → `INSERT sim.job_log('SimTick')`；并发 tick 由行锁串行，`job_log` 存在 `running` 行 → `35003`。`paused` 不阻塞手动 tick（其为 auto-runner 标志）。
- **可返回错误码**：`10001`（minutes 缺/非整/`<1`）、`10006`、`35002`（越上界）、`35003`（批次进行中）、`10000`

### 16.3 POST /sim/reset
- **说明**：时钟复位至 `base_date 09:00`（`speed=1, paused=false`）。**幂等**。
- **Request JSON**：`{}` 或 `{ "scope": "clock" }`；`scope` 枚举 `clock|full`，`full`（全量重灌）本期未开放 → `35002`。
- **Response `data`**：
  ```json
  { "scope": "clock", "virtual_now": "2026-10-28T09:00:00+08:00", "job_id": 13 }
  ```
- **可返回错误码**：`10001`、`10006`、`35002`、`35003`、`10000`

### 16.4 GET /sim/jobs
- **说明**：仿真作业台账（`sim.job_log`），分页。
- **Query 参数**：`page`（默认 1）、`size`（默认 20）、`job`（精确匹配过滤）、`status`（`running|success|failed`）
- **Response `data`**（分页包络 §1.2）：
  ```json
  { "list": [
    { "id": 13, "job": "SimReset", "virtual_date": "2026-10-28",
      "started_at": "2026-10-28T09:00:00+08:00", "finished_at": "2026-10-28T09:00:01+08:00",
      "rows_cnt": 0, "job_status": "success", "err": null } ],
    "page": 1, "size": 20, "total": 13 }
  ```
- **字段注**：按 `started_at DESC`；空集 `code=0, list=[]`。
- **可返回错误码**：`10001`（参数非法）、`10000`

### 16.5 POST /sim/clock — 时钟定点跳转
- **说明**：直接设定虚拟时钟（演示剧本"切回晨会起点"等定点需求）；与 tick 同为非幂等。
- **Request JSON**（全部可选，至少一项）：

  | 字段 | 类型 | 说明 |
  | :--- | :--- | :--- |
  | `virtual_now` | string | ISO 8601 目标时刻，界校验同 tick（越界 → `35002`） |
  | `speed` | int | `1–1000`（预留列，本期无消费方） |
  | `paused` | bool | （预留列） |
- **Response `data`**：
  ```json
  { "virtual_now": "2026-10-28T07:55:00+08:00", "job_id": 14 }
  ```
- **可返回错误码**：`10001`（无有效字段）、`10006`、`35002`、`35003`、`10000`

---

## 17. 前端 Mock 实施指引（Next Action）

在前端工程中落地 v2.0 契约的推荐目录组织：
```
src/
├── api/                   # API 请求定义（TypeScript）
│   ├── types.ts           # 镜像本契约中的所有接口类型（已就位）
│   ├── client.ts          # 统一解析层：mock 注册表查取，VITE_USE_MOCK 开关位预留 http 切换（已就位）
│   ├── auth.ts            # /auth/*, /hospital/*（已就位）
│   ├── workbench.ts       # /workbench/*（已就位）
│   └── screen.ts          # /screen/snapshot（已就位）
├── mock/                  # 本地 Mock 数据集（可随时被真实 HTTP 拦截替换）
│   ├── index.ts           # mockResolvers 注册表：key=契约端点路径（已就位）
│   ├── home.ts overview.ts medical.ts operations.ts hr.ts research.ts
│   ├── patient.ts quality.ts assets.ts compare.ts topics.ts settings.ts
│   └── screen.ts          # 大屏快照 mock（已就位）
```

**实施要诀**：
1. **表格列定义服务端化**：`table.*.columns` 由后端契约统一返回，供前端 `WbTable` 原语直接渲染；视图组件抽离数据层时，可全面移除本地硬编码的 `cols` 定义。
2. **角色切换支持**：`user.dept_id`、`available_roles` 等字段专为演示期角色无缝切换（院长/运营主任/科主任）预留，前端通过全局状态驱动页面视角联动。
3. **视觉提示解耦**：`icon`（Lucide 图标名）与 `tone`（语义色彩枚举）为演示期展示提示字段，前端依据统一样式系统（`src/styles/workbench.css`）映射对应样式，彻底消除散落的十六进制硬编码。
4. **平滑演进路线**：组件中通过 `onMounted` 调用 `api.getOverview()` 等标准化函数赋值，将来无论是纯前端静态演示、接入轻量 Mock 服务、还是上线正式 Go 单体后端，前端视图组件均无需修改一行业务渲染逻辑！
