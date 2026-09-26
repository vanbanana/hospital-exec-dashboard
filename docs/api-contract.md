# API 契约 — 院长查询与决策支持系统 (EDSS)

> **版本**：v2.0（双形态基线，替代 v1.1）  
> **制定日期**：2026-09-26  
> **基线状态**：面向"工作台优先（/workbench 12 视图）+ 科技大屏（/screen 辅助态势）"双形态架构。当前处于前端组件内 mock 向集中 `src/mock` + `src/api` 统一接口层演进阶段，后端（Go 单体）为远期目标态。  
> **演进纪律不变**：字段只增不删不改名、枚举只增不改语义；新需求先改本契约再写代码。

---

## 0. 版本演进与范围裁决声明

### 0.1 为什么升级到 v2.0？（范围裁决理由）
1. **形态重心转移**：原 `api-contract v1.1` 完全围绕“单一大屏（/screen）+ 五级下钻弹窗（L1~L5）”展开；但真实产品实践表明，院长与管理部门 90% 的日常决策发生于 **PC 浅色工作台**（高信息密度、多维交叉报表、全业务域监控），大屏更偏向指挥中心与会议汇报。系统已正式演进为**“/workbench 浅色工作台（12页为主）+ /screen 科技大屏（为辅）”**的双形态架构。
2. **落地阶段匹配**：前端已有 12 个完整的 Vue 工作台视图（`src/views/workbench/*.vue`）和 1 个大屏视图（`src/views/ScreenView.vue`），但数据分散硬编码于组件内部。v2.0 的首要任务是**收敛并定义这 13 个视图全部消费的标准化 API 契约**，使前端能零摩擦抽离出独立的 `src/api/` 模块与 Mock 拦截器。
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
     value: string | number           // 核心展示值，如 "12,300" 或 12300
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
   - 界面短日期（如 `"10-28"`、`"08:12"`）：后端 API 不直接下发短字符串，统一由前端按界面空间渲染格式化。
5. **图表/结构序列量纲**：所有趋势（trend）、构成（distribution / structure）、多序列图表响应中，必须显式下发 `unit` 字段或在节注声明量纲（如：收入构成 `unit: "%"`、科室份额 `unit: "万元"`、人员构成 `unit: "%"`、论文分布 `unit: "篇"`、能耗趋势 `unit: "万元"` 等）。
6. **色彩与视觉呈现解耦**：API 负载中严禁下发任何硬编码十六进制色值（如禁止出现十六进制颜色代码）。卡片与标签的视觉呈现统一使用 `tone` 语义色彩枚举（`primary`、`teal`、`green`、`amber`、`red`、`navy`），由前端样式系统与主题 Token 映射具体色值。
7. **错误码清单规范**：所有主体业务端点均在节尾明确标注可能返回的业务错误码；第 15 节预留端点清单同步补齐错误码对照列。

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
    "weekday": "星期一"
  }
  ```
  > **字段注**：`dept_id: null` 表示院级领导视角。在数据库存储中院级哨兵键使用 `0`，在 API 契约层统一对外序列化为 `null`。
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
      { "key": "outpatient", "label": "门急诊人次", "value": "12,300", "unit": "", "delta": "+3.6%", "dir": "up", "icon": "Stethoscope", "tone": "primary" },
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
        "current": [5400, 4600, 6800, 7000, 8500, 9000, 10800, 9700, 10500, 12300, 12200, 12000],
        "last": [4600, 3900, 5200, 5200, 6800, 7200, 9000, 9200, 8700, 10200, 10100, 9900]
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
    "max_val": 1450,
    "list": [
      { "rank": 1, "name": "心血管内科", "value": 1405 },
      { "rank": 2, "name": "骨科", "value": 1266 },
      { "rank": 3, "name": "呼吸与危重症医学科", "value": 1112 },
      { "rank": 4, "name": "普通外科", "value": 1032 },
      { "rank": 5, "name": "神经内科", "value": 901 },
      { "rank": 6, "name": "肿瘤科", "value": 829 },
      { "rank": 7, "name": "妇产科", "value": 804 },
      { "rank": 8, "name": "儿科", "value": 736 },
      { "rank": 9, "name": "消化内科", "value": 661 },
      { "rank": 10, "name": "泌尿外科", "value": 616 }
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
      { "id": 101, "level": "urgent", "title": "住院费用增幅高于行业均值", "occurred_at": "2026-10-28", "rule_code": "INPT_FEE_SURGE" },
      { "id": 102, "level": "urgent", "title": "部分科室床位使用率持续 > 95%", "occurred_at": "2026-10-27", "rule_code": "BED_OVER_95" },
      { "id": 103, "level": "major", "title": "医疗耗材库存周转天数上升", "occurred_at": "2026-10-26", "rule_code": "STOCK_TURN_SLOW" },
      { "id": 104, "level": "major", "title": "药品费用占比接近警戒阈值", "occurred_at": "2026-10-25", "rule_code": "DRUG_RATIO_WARN" },
      { "id": 105, "level": "minor", "title": "个别设备维保到期", "occurred_at": "2026-10-24", "rule_code": "DEVICE_MAINTAIN" }
    ]
  }
  ```
  > **字段注**：告警级别统一为英文枚举 `urgent | major | minor`；`occurred_at` 采用完整日期；`BED_OVER_95` 与 `DEVICE_MAINTAIN` 对齐 schema 预置种子，其余三条规则待 schema 种子补登。
- **可返回错误码**：`10001` (INVALID_PARAM)

### 3.7 GET /workbench/home/notices
- **说明**：行政通知与待办事项列表。
- **Response `data`**：
  ```json
  {
    "list": [
      { "id": 201, "text": "关于加强医疗质量安全管理的通知", "date": "2026-10-28", "urgent": true },
      { "id": 202, "text": "院务会会议材料（10月）", "date": "2026-10-27", "urgent": true },
      { "id": 203, "text": "请审阅2025年预算编制方案", "date": "2026-10-26", "urgent": true },
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
      { "label": "门急诊人次", "value": "84,700", "delta": "+3.6%", "dir": "up" },
      { "label": "出院人数", "value": "71,310", "delta": "+5.1%", "dir": "up" },
      { "label": "手术台次", "value": "10,606", "delta": "+4.8%", "dir": "up" },
      { "label": "医疗收入", "value": "120,260", "unit": "万元", "delta": "+2.9%", "dir": "up" },
      { "label": "床位使用率", "value": "92.1", "unit": "%", "delta": "+1.2%", "dir": "up" },
      { "label": "平均住院日", "value": "6.8", "unit": "天", "delta": "-0.3", "dir": "down" }
    ],
    "scale_revenue_trend": {
      "months": ["1月", "2月", "3月", "4月", "5月", "6月", "7月", "8月", "9月", "10月", "11月", "12月"],
      "outpatient": [5400, 4600, 6800, 7000, 8500, 9000, 10800, 9700, 10500, 12300, 12200, 12000],
      "revenue": [8950, 8060, 10800, 11650, 12450, 12980, 13940, 13550, 13080, 14800, 14240, 13720]
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
      "metric": "住院收入（万元）",
      "unit": "万元",
      "list": [
        { "name": "心血管内科", "value": 2490, "bar_pct": 100 },
        { "name": "骨科", "value": 2310, "bar_pct": 93 },
        { "name": "呼吸与危重症医学科", "value": 2160, "bar_pct": 87 },
        { "name": "普通外科", "value": 1940, "bar_pct": 78 },
        { "name": "神经内科", "value": 1750, "bar_pct": 70 },
        { "name": "肿瘤科", "value": 1630, "bar_pct": 66 },
        { "name": "妇产科", "value": 1520, "bar_pct": 61 },
        { "name": "儿科", "value": 1310, "bar_pct": 53 }
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
  > 1. `range="本年"` 下核心指标的 `value` 统一为本年 1~10 月累计值（门急诊 8.47 万、出院 7.13 万、手术 1.06 万、医疗收入 12.03 亿元），严格等于月度走势数组前 10 个月求和。
  > 2. `dept_share_top8` 明确度量为“住院收入（万元）”，`value` 改为纯数值型（方便前端计算），`bar_pct` 表示条形宽度归一化百分比（`val / max * 100`）。
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

#### 示例 1：`tab=门急诊`
```json
{
  "tab": "门急诊",
  "range": "本年",
  "stats": [
    { "label": "门急诊总人次", "value": "12,482", "delta": "+3.6%", "dir": "up" },
    { "label": "普通门诊", "value": "8,236", "delta": "+2.1%", "dir": "up" },
    { "label": "专家门诊", "value": "3,114", "delta": "+6.4%", "dir": "up" },
    { "label": "急诊人次", "value": "1,132", "delta": "+4.2%", "dir": "up" },
    { "label": "次均费用", "value": "300", "unit": "元", "delta": "+1.8%", "dir": "up" },
    { "label": "平均候诊", "value": "18", "unit": "分钟", "delta": "-3分钟", "dir": "down" }
  ],
  "trend": {
    "title": "门急诊人次趋势",
    "name": "门急诊人次",
    "unit": "人次",
    "months": ["1月", "2月", "3月", "4月", "5月", "6月", "7月", "8月", "9月", "10月", "11月", "12月"],
    "values": [5400, 4600, 6800, 7000, 8500, 9000, 10800, 9700, 10500, 12300, 12200, 12000]
  },
  "distribution": {
    "title": "就诊高峰时段分布",
    "sub": "近 30 日分时段人次",
    "type": "bar",
    "unit": "人次",
    "categories": ["7时", "8时", "9时", "10时", "11时", "14时", "15时", "16时", "17时", "19时"],
    "values": [620, 1480, 1960, 1750, 1180, 1380, 1240, 960, 540, 380]
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
      { "dept": "心血管内科", "cnt": "1,286", "yoy": "+6.2%", "share": "10.3%", "avg": "352元", "drug": "26.1%" },
      { "dept": "呼吸与危重症医学科", "cnt": "1,158", "yoy": "+8.7%", "share": "9.3%", "avg": "318元", "drug": "31.2%" },
      { "dept": "消化内科", "cnt": "1,042", "yoy": "+4.1%", "share": "8.4%", "avg": "296元", "drug": "33.5%" },
      { "dept": "神经内科", "cnt": "968", "yoy": "+3.5%", "share": "7.8%", "avg": "342元", "drug": "29.8%" },
      { "dept": "内分泌科", "cnt": "826", "yoy": "+2.9%", "share": "6.6%", "avg": "274元", "drug": "35.4%" },
      { "dept": "儿科", "cnt": "792", "yoy": "-1.2%", "share": "6.3%", "avg": "198元", "drug": "22.6%" },
      { "dept": "骨科", "cnt": "716", "yoy": "+5.4%", "share": "5.7%", "avg": "412元", "drug": "18.9%" },
      { "dept": "皮肤科", "cnt": "654", "yoy": "+2.2%", "share": "5.2%", "avg": "186元", "drug": "41.3%" }
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
    { "label": "本月出院", "value": "8,120", "delta": "+5.1%", "dir": "up" },
    { "label": "床位使用率", "value": "92.1", "unit": "%", "delta": "+1.2%", "dir": "up" },
    { "label": "平均住院日", "value": "6.8", "unit": "天", "delta": "-0.3", "dir": "down" },
    { "label": "床位周转次数", "value": "4.0", "delta": "+0.2", "dir": "up" },
    { "label": "次均住院费用", "value": "13,000", "unit": "元", "delta": "+2.4%", "dir": "up" }
  ],
  "trend": {
    "title": "出院人数趋势",
    "name": "出院人数",
    "unit": "人次",
    "months": ["1月", "2月", "3月", "4月", "5月", "6月", "7月", "8月", "9月", "10月", "11月", "12月"],
    "values": [5900, 4970, 6410, 6820, 7240, 7450, 8070, 8480, 7850, 8120, 7650, 7450]
  },
  "distribution": {
    "title": "病区床位占用",
    "sub": "各病区开放床位占用率",
    "type": "bar",
    "unit": "%",
    "categories": ["内科", "外科", "妇产", "儿科", "ICU", "肿瘤", "康复"],
    "values": [94, 96, 82, 78, 98, 91, 68]
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
      { "dept": "心血管内科", "cnt": "1,405", "yoy": "+4.6%", "share": "17.3%", "avg": "12,400元", "drug": "24.8%" },
      { "dept": "骨科", "cnt": "1,266", "yoy": "+6.1%", "share": "15.6%", "avg": "15,860元", "drug": "12.4%" },
      { "dept": "呼吸与危重症医学科", "cnt": "1,112", "yoy": "+7.2%", "share": "13.7%", "avg": "11,280元", "drug": "32.6%" },
      { "dept": "普通外科", "cnt": "1,032", "yoy": "+3.8%", "share": "12.7%", "avg": "14,520元", "drug": "18.2%" },
      { "dept": "神经内科", "cnt": "901", "yoy": "+2.4%", "share": "11.1%", "avg": "9,680元", "drug": "36.4%" },
      { "dept": "肿瘤科", "cnt": "829", "yoy": "+5.9%", "share": "10.2%", "avg": "16,240元", "drug": "42.8%" },
      { "dept": "妇产科", "cnt": "804", "yoy": "-2.6%", "share": "9.9%", "avg": "7,460元", "drug": "15.6%" },
      { "dept": "儿科", "cnt": "736", "yoy": "+1.8%", "share": "9.1%", "avg": "4,280元", "drug": "26.4%" }
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
    { "label": "本月手术台次", "value": "1,286", "delta": "+4.8%", "dir": "up" },
    { "label": "三四级手术占比", "value": "58.6", "unit": "%", "delta": "+2.2%", "dir": "up" },
    { "label": "微创手术占比", "value": "42.3", "unit": "%", "delta": "+3.1%", "dir": "up" },
    { "label": "择期手术", "value": "1,048", "delta": "+5.2%", "dir": "up" },
    { "label": "急诊手术", "value": "238", "delta": "+3.1%", "dir": "up" },
    { "label": "手术间利用率", "value": "86.4", "unit": "%", "delta": "+1.6%", "dir": "up" }
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
    "values": [22, 37, 28, 13]
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
      { "dept": "骨科", "cnt": "286", "yoy": "+6.8%", "share": "22.2%", "avg": "42分钟", "drug": "8.6%" },
      { "dept": "普通外科", "cnt": "242", "yoy": "+5.4%", "share": "18.8%", "avg": "56分钟", "drug": "11.2%" },
      { "dept": "妇产科", "cnt": "186", "yoy": "-1.8%", "share": "14.5%", "avg": "38分钟", "drug": "9.4%" },
      { "dept": "神经外科", "cnt": "128", "yoy": "+7.6%", "share": "10.0%", "avg": "128分钟", "drug": "12.8%" },
      { "dept": "泌尿外科", "cnt": "116", "yoy": "+4.2%", "share": "9.0%", "avg": "52分钟", "drug": "10.6%" },
      { "dept": "心胸外科", "cnt": "98", "yoy": "+9.1%", "share": "7.6%", "avg": "145分钟", "drug": "14.2%" },
      { "dept": "耳鼻喉科", "cnt": "86", "yoy": "+2.4%", "share": "6.7%", "avg": "34分钟", "drug": "7.8%" },
      { "dept": "眼科", "cnt": "74", "yoy": "+1.6%", "share": "5.8%", "avg": "22分钟", "drug": "6.2%" }
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
        { "dept": "心血管内科", "income": "2,480", "cost": "2,310", "balance": "170", "margin": "6.9%", "drug_ratio": "24.8%", "mat_ratio": "18.2%" },
        { "dept": "骨科", "income": "2,180", "cost": "1,980", "balance": "200", "margin": "9.2%", "drug_ratio": "12.4%", "mat_ratio": "34.6%" },
        { "dept": "呼吸与危重症医学科", "income": "1,860", "cost": "1,790", "balance": "70", "margin": "3.8%", "drug_ratio": "32.6%", "mat_ratio": "8.4%" },
        { "dept": "普通外科", "income": "1,740", "cost": "1,620", "balance": "120", "margin": "6.9%", "drug_ratio": "18.2%", "mat_ratio": "22.1%" },
        { "dept": "神经内科", "income": "1,420", "cost": "1,380", "balance": "40", "margin": "2.8%", "drug_ratio": "36.4%", "mat_ratio": "6.2%" },
        { "dept": "肿瘤科", "income": "1,680", "cost": "1,610", "balance": "70", "margin": "4.2%", "drug_ratio": "42.8%", "mat_ratio": "9.1%" }
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
      "values": [12, 9, 7, 6, 4, 2, 2]
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
      "total": [168, 172, 198, 212, 196, 186],
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
      { "name": "年门急诊量（万人次）", "ours": "10.9", "region": "9.0", "bench": "12.8", "gap": "+1.9" },
      { "name": "年出院人数（万人）", "ours": "9.73", "region": "8.22", "bench": "11.58", "gap": "+1.51" },
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
        { "rank": 1, "dept": "心血管内科", "metric": "1,860", "bar_pct": 100, "yoy": "+6.2%", "outp": 1286, "inpt": 1405, "days": 9.2, "sat": 96.2 },
        { "rank": 2, "dept": "骨科", "metric": "1,724", "bar_pct": 93, "yoy": "+5.8%", "outp": 716, "inpt": 1266, "days": 8.6, "sat": 95.4 },
        { "rank": 3, "dept": "呼吸与危重症医学科", "metric": "1,615", "bar_pct": 87, "yoy": "+8.7%", "outp": 1158, "inpt": 1112, "days": 10.4, "sat": 94.8 },
        { "rank": 4, "dept": "普通外科", "metric": "1,480", "bar_pct": 80, "yoy": "+3.4%", "outp": 542, "inpt": 1032, "days": 7.8, "sat": 94.2 },
        { "rank": 5, "dept": "神经内科", "metric": "1,342", "bar_pct": 72, "yoy": "+4.1%", "outp": 968, "inpt": 901, "days": 11.2, "sat": 93.6 },
        { "rank": 6, "dept": "肿瘤科", "metric": "1,208", "bar_pct": 65, "yoy": "+5.9%", "outp": 412, "inpt": 829, "days": 12.6, "sat": 92.8 }
      ]
    }
  }
  ```
  > **字段注**：
  > 1. `radar` 重构为全院 6 大宏观决策能力维度（0–100 分），直接对比“本院”与“区域同级均值”，消除了单科室内指标量纲混杂的歧义。
  > 2. `benchmarks` 中的 `gap` 统一定义为 `= 本院 - 区域均值`；门急诊年业务量调整为万人口径，与全院累计量级对齐。
  > 3. `table` 补充 `rank` 排名列；`bar_pct` 表示条形宽度归一化百分比（`val / max * 100`）；`metric` 列标题随 `dim` 动态变换。
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
    { "label": "CMI 值", "value": "1.08", "delta": "+0.04", "dir": "up" },
    { "label": "入组率", "value": "98.5", "unit": "%", "delta": "+0.6%", "dir": "up" },
    { "label": "费用消耗指数", "value": "0.92", "delta": "-0.03", "dir": "down" },
    { "label": "时间消耗指数", "value": "0.95", "delta": "-0.02", "dir": "down" },
    { "label": "RW≥2 占比", "value": "10.2", "unit": "%", "delta": "+1.8%", "dir": "up" },
    { "label": "低风险组死亡率", "value": "0.02", "unit": "%", "delta": "持平", "dir": "flat" }
  ],
  "chart": {
    "title": "病组权重（RW）分布",
    "sub": "本月出院病例按 RW 分段（仅已入组病例）",
    "type": "bar",
    "unit": "例",
    "categories": ["<0.5", "0.5-1", "1-2", "2-5", "5-10", "≥10"],
    "values": [870, 3350, 3060, 662, 128, 37]
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
      { "dept": "神经外科", "cmi": "1.68", "cases": "294", "cost_idx": "1.02", "time_idx": "1.06", "rw2": "46.8%", "profit": "-12.8" },
      { "dept": "心血管内科", "cmi": "1.42", "cases": "1,360", "cost_idx": "0.96", "time_idx": "0.98", "rw2": "28.6%", "profit": "+86.4" },
      { "dept": "骨科", "cmi": "1.36", "cases": "1,232", "cost_idx": "0.88", "time_idx": "0.94", "rw2": "32.4%", "profit": "+124.6" },
      { "dept": "肿瘤科", "cmi": "1.24", "cases": "810", "cost_idx": "1.08", "time_idx": "1.02", "rw2": "26.4%", "profit": "-34.6" },
      { "dept": "普通外科", "cmi": "1.18", "cases": "1,005", "cost_idx": "0.86", "time_idx": "0.92", "rw2": "24.2%", "profit": "+98.2" },
      { "dept": "呼吸与危重症医学科", "cmi": "1.12", "cases": "1,083", "cost_idx": "0.94", "time_idx": "0.96", "rw2": "22.8%", "profit": "+42.8" },
      { "dept": "神经内科", "cmi": "0.94", "cases": "885", "cost_idx": "0.90", "time_idx": "0.98", "rw2": "12.6%", "profit": "+38.2" },
      { "dept": "儿科", "cmi": "0.68", "cases": "707", "cost_idx": "0.84", "time_idx": "0.88", "rw2": "4.2%", "profit": "+28.4" }
    ]
  }
}
```
> **字段注**：
> 1. `RW≥2 占比` 统计值修订为 `10.2%`，与下方病组权重柱状图中 `(662+128+37) / 8107` 的分段合计严格自洽。
> 2. 键名改为 `cost_idx` 与 `time_idx`（snake_case）；科室列表严格按 CMI 降序排列并补全视图 8 行数据。

#### 示例 2：`topic=insurance`
```json
{
  "topic": "insurance",
  "range": "本年",
  "stats": [
    { "label": "医保结算人次", "value": "8,462", "delta": "+4.2%", "dir": "up" },
    { "label": "医保基金支付", "value": "9,860", "unit": "万元", "delta": "+3.8%", "dir": "up" },
    { "label": "基金结余率", "value": "6.8", "unit": "%", "delta": "+0.4%", "dir": "up" },
    { "label": "拒付/扣款率", "value": "0.8", "unit": "%", "delta": "-0.2%", "dir": "down" },
    { "label": "次均医保费用", "value": "11,652", "unit": "元", "delta": "+1.6%", "dir": "up" },
    { "label": "异地就医结算", "value": "486", "unit": "人次", "delta": "+12.4%", "dir": "up" }
  ],
  "chart": {
    "title": "医保基金月度支付",
    "sub": "近 6 个月（万元）",
    "type": "line",
    "unit": "万元",
    "months": ["5月", "6月", "7月", "8月", "9月", "10月"],
    "values": [8860, 9150, 9620, 9840, 9560, 9860]
  },
  "table": {
    "title": "分险种结算情况",
    "sub": "本月",
    "columns": [
      { "key": "type", "title": "险种" },
      { "key": "cases", "title": "结算人次", "align": "right", "num": true },
      { "key": "fund", "title": "基金支付（万元）", "align": "right", "num": true },
      { "key": "self", "title": "个人自付（万元）", "align": "right", "num": true },
      { "key": "ratio", "title": "报销比例", "align": "right", "num": true },
      { "key": "status", "title": "运行状态", "align": "center" }
    ],
    "rows": [
      { "type": "职工医保", "cases": "4,286", "fund": "5,680", "self": "1,420", "ratio": "80.0%", "status": "平稳" },
      { "type": "居民医保", "cases": "3,246", "fund": "3,420", "self": "1,486", "ratio": "69.7%", "status": "平稳" },
      { "type": "生育保险", "cases": "486", "fund": "420", "self": "128", "ratio": "76.6%", "status": "平稳" },
      { "type": "大病保险", "cases": "286", "fund": "286", "self": "86", "ratio": "76.9%", "status": "关注" },
      { "type": "医疗救助", "cases": "158", "fund": "54", "self": "12", "ratio": "81.8%", "status": "平稳" }
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
    { "label": "国考预估得分", "value": "786", "unit": "分", "delta": "+18分", "dir": "up" },
    { "label": "指标达标率", "value": "82.4", "unit": "%", "delta": "+3.6%", "dir": "up" },
    { "label": "医疗质量得分率", "value": "86.2", "unit": "%", "delta": "+2.4%", "dir": "up" },
    { "label": "运营效率得分率", "value": "78.6", "unit": "%", "delta": "+4.2%", "dir": "up" },
    { "label": "持续发展得分率", "value": "74.8", "unit": "%", "delta": "+1.8%", "dir": "up" },
    { "label": "满意度得分率", "value": "91.2", "unit": "%", "delta": "+0.6%", "dir": "up" }
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
      { "name": "每床日收入（剔除药耗）", "full": 30, "score": "72%", "trend": "↑", "owner": "财务部" },
      { "name": "人员支出占业务支出比重", "full": 30, "score": "64%", "trend": "→", "owner": "人力资源部" },
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
    { "label": "门诊统筹结算人次", "value": "6,248", "delta": "+18.6%", "dir": "up" },
    { "label": "统筹基金支付", "value": "486", "unit": "万元", "delta": "+22.4%", "dir": "up" },
    { "label": "人均统筹费用", "value": "778", "unit": "元", "delta": "+3.2%", "dir": "up" },
    { "label": "个人账户支出", "value": "326", "unit": "万元", "delta": "-4.6%", "dir": "down" },
    { "label": "慢特病结算", "value": "1,846", "unit": "人次", "delta": "+8.4%", "dir": "up" },
    { "label": "处方外流率", "value": "12.4", "unit": "%", "delta": "+2.8%", "dir": "up" }
  ],
  "chart": {
    "title": "门诊统筹基金月度支出",
    "sub": "近 6 个月（万元）",
    "type": "line",
    "unit": "万元",
    "months": ["5月", "6月", "7月", "8月", "9月", "10月"],
    "values": [342, 386, 412, 438, 456, 486]
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
      { "dept": "内分泌科", "cases": "986", "fund": "86.4", "avg": "88", "chronic": "68.4%" },
      { "dept": "心血管内科", "cases": "912", "fund": "92.6", "avg": "102", "chronic": "62.8%" },
      { "dept": "神经内科", "cases": "684", "fund": "62.8", "avg": "92", "chronic": "54.2%" },
      { "dept": "呼吸与危重症医学科", "cases": "596", "fund": "58.4", "avg": "98", "chronic": "42.6%" },
      { "dept": "消化内科", "cases": "512", "fund": "44.2", "avg": "86", "chronic": "38.4%" },
      { "dept": "中医科", "cases": "468", "fund": "38.6", "avg": "82", "chronic": "46.8%" }
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
      { "name": "床位使用率", "rule": "连续 3 日 > 95%", "level": "urgent", "enabled": true },
      { "name": "药占比", "rule": "> 30%", "level": "major", "enabled": true },
      { "name": "耗占比", "rule": "> 20%", "level": "major", "enabled": true },
      { "name": "住院费用增幅", "rule": "同比 > 8%", "level": "urgent", "enabled": true },
      { "name": "库存周转天数", "rule": "> 35 天", "level": "minor", "enabled": true },
      { "name": "危急值超时率", "rule": "及时率 < 95%", "level": "urgent", "enabled": true },
      { "name": "设备开机率", "rule": "< 60%", "level": "minor", "enabled": false }
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
- **可返回错误码**：`10001` (INVALID_PARAM)

---

## 14. 辅助形态：科技大屏快照 /screen/snapshot

对应页面：`src/views/ScreenView.vue` 及根目录 `src/components/*.vue`。

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
      { "code": "OP_DAILY_VISITS", "name": "今日门急诊", "value": 420, "unit": "人", "prev_value": 395, "delta_pct": 6.3, "direction": 1, "spark": [380, 395, 410, 390, 405, 395, 420], "status": "normal" },
      { "code": "IP_IN_HOSP", "name": "在院患者", "value": 1846, "unit": "人", "prev_value": 1820, "delta_pct": 1.4, "direction": 1, "spark": [1780, 1800, 1810, 1825, 1830, 1820, 1846], "status": "normal" },
      { "code": "BED_USE_RATE", "name": "床位使用率", "value": 92.1, "unit": "%", "prev_value": 90.8, "delta_pct": 1.4, "direction": 1, "spark": [88.5, 89.2, 90.1, 91.0, 91.5, 90.8, 92.1], "status": "warn" },
      { "code": "SURG_DAILY_CNT", "name": "今日手术", "value": 45, "unit": "台", "prev_value": 42, "delta_pct": 7.1, "direction": 1, "spark": [38, 40, 42, 39, 41, 42, 45], "status": "normal" }
    ],
    "drg_quadrant": {
      "period": "d30",
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
      { "code": "mz", "name": "门诊楼", "status": "normal", "badge": "420 人", "badge_level": "info", "anchor": { "x": 32, "y": 58 }, "metrics": { "today_visit": 420, "queue_avg_min": 18 } },
      { "code": "wk", "name": "外科楼", "status": "busy", "badge": "96% 负荷", "badge_level": "warn", "anchor": { "x": 50, "y": 30 }, "metrics": { "bed_use_rate": 96.0, "bed_used": 192, "bed_open": 200 } },
      { "code": "jz", "name": "急诊楼", "status": "alert", "badge": "留观超时", "badge_level": "alert", "anchor": { "x": 66, "y": 42 }, "metrics": { "obs_over6h": 3, "obs_cnt": 11, "obs_max_min": 560 } },
      { "code": "yj", "name": "医技楼", "status": "normal", "badge": "设备正常", "badge_level": "ok", "anchor": { "x": 60, "y": 66 }, "metrics": { "device_run": 12, "device_alert": 0 } }
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
        "OP_DAILY_VISITS": [380, 395, 410, 390, 405, 395, 420],
        "IP_IN_HOSP": [1780, 1800, 1810, 1825, 1830, 1820, 1846],
        "SURG_DAILY_CNT": [38, 40, 42, 39, 41, 42, 45],
        "BED_USE_RATE": [88.5, 89.2, 90.1, 91.0, 91.5, 90.8, 92.1]
      }
    }
  }
  ```
  > **字段注**：
  > 1. `server_time` 统一使用基准日 `"2026-10-28T08:30:00+08:00"`，`dates` 序列对齐为 `10-22 ~ 10-28`；演示基准日 `BASE_DATE=2026-10-28`（周三工作日），KPI/月累计均锚定 10 月。
  > 2. 日业务量量级与工作台月累计完全自洽：门急诊日均约 420 人次（月累计约 12,300），手术日均约 45 台（月累计约 1,286）。
  > 3. `profit` 统一为万元单位浮点数值（如 `124.6` 万元）；`bed_use_rate` 统一为展示百分比口径（`96.0`）；未闭环告警数 `alert_open.urgent = 1`，与告警列表首条紧急事件一致。
  > 4. 告警时间字段使用 `occurred_at` ISO 格式。
  > 5. `dept_ranking.eff_score` 为展示示意值（归一公式见 §10 注），API 出参以服务端按当前分布实算为准；`rank` 序与 `cmi/profit` 事实列一致即可。
- **可返回错误码**：`10001` (INVALID_PARAM)

---

## 15. 远期预留端点清单（Reserved Endpoints Checklist）

以下端点源自 v1.1 深度决策架构设计，属于**“远期真实业务演进与后端落地项”**。在当前前端 Mock/API 解耦阶段，前端不发起真实调用，保留此清单以备未来后端开发与深层穿透扩展：

| # | Method | Path | 用途与定位 | 规划阶段 | 错误码 | 说明 |
| :- | :----- | :--- | :--------- | :------ | :----- | :--- |
| R01 | GET | `/cases` | L4 病例列表（按科室/病组/死因筛选） | P2 | 10001, 10002, 30001 | 用于从 DRG 病组穿透至具体病例集合，带分页参数 |
| R02 | GET | `/cases/{id}` | L5 电子病历（脱敏事实） | P2 | 10001, 30001, 30002 | 默认患者姓名身份证脱敏（`张**`） |
| R03 | GET | `/cases/{id}?unmask=1` | L5 实名解密调阅 | P2 | 10001, 20002, 32006 | 需二次验密（验密口令错误码 32006 已在 error-codes.md 注册）并记录审计日志 |
| R04 | POST | `/alerts/{id}/ack` | 告警认领 | P2 | 10001, 31001, 31004 | 告警状态变为 `processing` |
| R05 | POST | `/alerts/{id}/dispatch` | 告警一键督办派发 | P2 | 10001, 31002, 31004 | 生成 Todo 工单，指定承办人与截止期 |
| R06 | POST | `/alerts/{id}/close` | 告警直接闭环关闭 | P2 | 10001, 31003, 31004 | 填写办结理由与改善说明 |
| R07 | GET | `/todos` | 督办追踪工单列表 | P2 | 10001, 10002 | 包含整改前/当前/目标值三点锚点，带分页参数 |
| R08 | POST | `/todos/{id}/status` | 督办工单反馈与办结 | P2 | 10001, 31005 | 承办科室主任提交整改举措并申请验收 |
| R09 | GET | `/campus/buildings/{code}`| 楼宇详情抽屉（病区/设备） | P2 | 10001, 30001 | 大屏点击外科楼/急诊楼拉出二级抽屉 |
| R10 | GET | `/staff` | 组织人员下拉选择器 | P2 | 10001 | 督办派发时根据科室联想责任人 |
| R11 | POST| `/auth/login` | 正式 JWT 登录 | P3 | 10001, 20001, 20002 | 真实 Go 后端上线时启用 |
| R12 | POST| `/auth/refresh` | Token 静默轮换 | P3 | 10001, 20003, 20004 | 双 Token 并发安全轮换 |
| R13 | POST| `/metrics/query` | ChatBI / 指标语义层查询 | P3 | 10001, 30001 | 大模型 NLQ to DSL 智能问数接口 |
| R14 | GET/POST | `/sim/*` | 仿真时钟与故障注入 | P3 | 10001, 10002 | 演示控制接口（时钟加速、重置、注入告警） |

---

## 16. 前端 Mock 实施指引（Next Action）

在前端工程中落地 v2.0 契约的推荐目录组织：
```
src/
├── api/                   # API 请求定义（TypeScript）
│   ├── types.ts           # 镜像本契约中的所有接口类型
│   ├── auth.ts            # /auth/*, /hospital/*
│   ├── workbench.ts       # /workbench/home/*, /workbench/overview, /workbench/medical ...
│   └── screen.ts          # /screen/snapshot
├── mock/                  # 本地 Mock 数据集（可随时被真实 HTTP 拦截替换）
│   ├── index.ts           # Mock 拦截开关（通过 VITE_USE_MOCK 控制）
│   ├── home.json          # 首页 KPI、趋势、TOP10
│   ├── overview.json      # 概览页数据
│   ├── medical.json       # 医疗业务多维数据
│   └── ...                # 其他各模块静态数据包
```

**实施要诀**：
1. **表格列定义服务端化**：`table.*.columns` 由后端契约统一返回，供前端 `WbTable` 原语直接渲染；视图组件抽离数据层时，可全面移除本地硬编码的 `cols` 定义。
2. **角色切换支持**：`user.dept_id`、`available_roles` 等字段专为演示期角色无缝切换（院长/运营主任/科主任）预留，前端通过全局状态驱动页面视角联动。
3. **视觉提示解耦**：`icon`（Lucide 图标名）与 `tone`（语义色彩枚举）为演示期展示提示字段，前端依据统一样式系统（`src/styles/workbench.css`）映射对应样式，彻底消除散落的十六进制硬编码。
4. **平滑演进路线**：组件中通过 `onMounted` 调用 `api.getOverview()` 等标准化函数赋值，将来无论是纯前端静态演示、接入轻量 Mock 服务、还是上线正式 Go 单体后端，前端视图组件均无需修改一行业务渲染逻辑！
