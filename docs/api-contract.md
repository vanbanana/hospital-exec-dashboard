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
  - 原 v1.1 中设计较重但当前组件未实际联动的能力（如：L5 病历底层结构化 JSON 与实名解密验密、工单派发/办理写操作、`/sim/*` 虚拟时钟与演示故障注入），统一归整至**第 14 节《远期预留端点清单》**，仅保留路由、请求方法与用途定义，不占用主体篇幅。

---

## 1. 契约通用约定与响应包络

### 1.1 统一包络规范（继承自 error-codes.md）
所有接口返回必须经由统一包络封装：

```json
{
  "code": 0,
  "message": "ok",
  "data": { ... },
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
  "list": [ ... ],
  "page": 1,
  "size": 20,
  "total": 137
}
```
查询参数统一：`?page=1&size=20`。

### 1.3 数值与单位规范（钉死口径）
1. **金额口径**：
   - 宏观分析与工作台统计（如医疗收入、结余）：单位统一为**万元**（保留 2 位小数）；
   - 明细费用与单例次均（如门诊次均、住院次均）：单位统一为**元**。
2. **比率与变化率（delta）**：
   - 带有单位 `%` 的展示字段（如床位使用率、药占比）：数值直接给展示浮点数（如 `92.1` 表示 `92.1%`）；
   - 环比/同比变动（`delta`）：返回格式化字符串（如 `"+3.6%"`、`"-0.3"`），便于前端直接渲染；
   - 极性方向（`dir`）：枚举 `'up'` | `'down'` | `'flat'`。
3. **指标条统一数据接口结构 (`WbStatItem`)**：
   ```ts
   interface WbStatItem {
     label: string      // 指标名称，如 "门急诊人次"
     value: string      // 核心展示值，如 "12,482"
     unit?: string      // 单位，如 "万元"、"天"、"%"
     delta?: string     // 环同比变动幅度，如 "+3.6%"
     dir?: 'up' | 'down' | 'flat' // 变动方向
     note?: string      // 备注文案，如 "目标 ≥1:1.25"、"当前实时"
   }
   ```

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
    "system_date": "2024-10-28",
    "weekday": "星期一"
  }
  ```

### 2.2 GET /hospital/profile
- **说明**：医院基本配置与院训文化。
- **Response `data`**：
  ```json
  {
    "name": "市中心医院",
    "english_name": "PEOPLE'S HOSPITAL",
    "level": "三级甲等综合医院",
    "motto": ["厚德", "精医", "仁爱", "创新"],
    "slogans": ["以数据洞察全局", "以科学决策引领医院高质量发展"],
    "pillars": ["人民至上", "生命至上", "健康至上"]
  }
  ```

---

## 3. 工作台首页 /workbench/home

对应页面：`src/views/workbench/HomeView.vue` 及对应 6 张子卡片。

### 3.1 GET /workbench/home/kpis
- **说明**：首页顶栏 5 大核心业务 KPI 卡片。
- **Response `data`**：
  ```json
  {
    "list": [
      { "key": "outpatient", "title": "门急诊人次", "value": "12,482", "unit": "", "change": "+3.6%", "is_positive": true, "bg_color": "#2563eb" },
      { "key": "inpatient", "title": "住院人次", "value": "3,920", "unit": "", "change": "+5.1%", "is_positive": true, "bg_color": "#3b82f6" },
      { "key": "surgery", "title": "手术台次", "value": "1,286", "unit": "", "change": "+4.8%", "is_positive": true, "bg_color": "#059669" },
      { "key": "revenue", "title": "医疗总收入", "value": "23,560", "unit": "万元", "change": "+2.9%", "is_positive": true, "bg_color": "#10b981", "is_currency": true },
      { "key": "staff", "title": "在岗职工", "value": "2,368", "unit": "", "change": "+0.4%", "is_positive": true, "bg_color": "#0891b2" }
    ]
  }
  ```

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
        "current": [2850, 2400, 3100, 3300, 3500, 3600, 3900, 4100, 3800, 3920, 3700, 3600],
        "last": [2600, 2100, 2800, 2900, 3100, 3200, 3400, 3500, 3300, 3400, 3200, 3100]
      },
      "手术台次": {
        "unit": "台",
        "current": [860, 720, 980, 1020, 1080, 1120, 1180, 1210, 1150, 1286, 1200, 1160],
        "last": [750, 650, 850, 900, 950, 980, 1020, 1050, 1000, 1100, 1050, 1000]
      },
      "医疗收入": {
        "unit": "万元",
        "current": [1420, 1280, 1720, 1850, 1980, 2060, 2210, 2150, 2080, 2356, 2260, 2180],
        "last": [1250, 1100, 1450, 1550, 1680, 1750, 1900, 1850, 1780, 2010, 1950, 1880]
      }
    }
  }
  ```

### 3.3 GET /workbench/home/top10
- **说明**：科室业务量 TOP10（按住院人次排行）。
- **Response `data`**：
  ```json
  {
    "metric_name": "住院人次",
    "max_val": 700,
    "list": [
      { "rank": 1, "name": "心血管内科", "value": 680 },
      { "rank": 2, "name": "骨科", "value": 612 },
      { "rank": 3, "name": "呼吸与危重症医学科", "value": 538 },
      { "rank": 4, "name": "普通外科", "value": 499 },
      { "rank": 5, "name": "神经内科", "value": 436 },
      { "rank": 6, "name": "肿瘤科", "value": 401 },
      { "rank": 7, "name": "妇产科", "value": 389 },
      { "rank": 8, "name": "儿科", "value": 356 },
      { "rank": 9, "name": "消化内科", "value": 320 },
      { "rank": 10, "name": "泌尿外科", "value": 298 }
    ]
  }
  ```

### 3.4 GET /workbench/home/indicators
- **说明**：医院运营关键效率与质量指标（首页右中卡片）。
- **Response `data`**：
  ```json
  {
    "list": [
      { "code": "ALOS", "name": "平均住院日", "value": "6.8", "unit": "天", "delta": "-0.3", "is_positive": false, "circle_bg": "#e9f0fe", "icon_color": "#2563eb", "icon": "CalendarDays" },
      { "code": "BED_USE_RATE", "name": "床位使用率", "value": "92.1", "unit": "%", "delta": "+1.2", "is_positive": true, "circle_bg": "#e9f0fe", "icon_color": "#2563eb", "icon": "BedDouble" },
      { "code": "DRUG_RATIO", "name": "药占比", "value": "28.4", "unit": "%", "delta": "-0.6", "is_positive": false, "circle_bg": "#e9f0fe", "icon_color": "#2563eb", "icon": "Pill" },
      { "code": "MATERIAL_RATIO", "name": "耗材占比", "value": "17.9", "unit": "%", "delta": "-0.4", "is_positive": false, "circle_bg": "#e5f6f3", "icon_color": "#0d9488", "icon": "Package" },
      { "code": "MED_SVC_RATIO", "name": "医疗服务收入占比", "value": "43.6", "unit": "%", "delta": "+0.8", "is_positive": true, "circle_bg": "#e8f6ee", "icon_color": "#059669", "icon": "HeartPulse" }
    ]
  }
  ```

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

### 3.6 GET /workbench/home/alerts
- **说明**：首页运营风险预警动态。
- **Response `data`**：
  ```json
  {
    "list": [
      { "id": 101, "level": "高", "text": "住院费用增幅高于行业均值", "date": "2024-10-28", "rule_code": "INPT_FEE_SURGE" },
      { "id": 102, "level": "高", "text": "部分科室床位使用率持续 > 95%", "date": "2024-10-27", "rule_code": "BED_OVERLOAD" },
      { "id": 103, "level": "中", "text": "医疗耗材库存周转天数上升", "date": "2024-10-26", "rule_code": "STOCK_TURN_SLOW" },
      { "id": 104, "level": "中", "text": "药品费用占比接近警戒阈值", "date": "2024-10-25", "rule_code": "DRUG_RATIO_WARN" },
      { "id": 105, "level": "低", "text": "个别设备维保到期", "date": "2024-10-24", "rule_code": "EQUIP_MAINT_DUE" }
    ]
  }
  ```

### 3.7 GET /workbench/home/notices
- **说明**：行政通知与待办事项列表。
- **Response `data`**：
  ```json
  {
    "list": [
      { "id": 201, "text": "关于加强医疗质量安全管理的通知", "date": "2024-10-28", "urgent": true },
      { "id": 202, "text": "院务会会议材料（10月）", "date": "2024-10-27", "urgent": true },
      { "id": 203, "text": "请审阅2025年预算编制方案", "date": "2024-10-26", "urgent": true },
      { "id": 204, "text": "智慧医院二期建设进展汇报", "date": "2024-10-25", "urgent": false },
      { "id": 205, "text": "上级主管部门调研安排", "date": "2024-10-24", "urgent": false }
    ]
  }
  ```

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
      { "label": "门急诊人次", "value": "12,482", "delta": "+3.6%", "dir": "up" },
      { "label": "出院人数", "value": "3,920", "delta": "+5.1%", "dir": "up" },
      { "label": "手术台次", "value": "1,286", "delta": "+4.8%", "dir": "up" },
      { "label": "医疗收入", "value": "23,560", "unit": "万元", "delta": "+2.9%", "dir": "up" },
      { "label": "床位使用率", "value": "92.1", "unit": "%", "delta": "+1.2%", "dir": "up" },
      { "label": "平均住院日", "value": "6.8", "unit": "天", "delta": "-0.3", "dir": "down" }
    ],
    "scale_revenue_trend": {
      "months": ["1月", "2月", "3月", "4月", "5月", "6月", "7月", "8月", "9月", "10月", "11月", "12月"],
      "outpatient": [5400, 4600, 6800, 7000, 8500, 9000, 10800, 9700, 10500, 12300, 12200, 12000],
      "revenue": [1420, 1280, 1720, 1850, 1980, 2060, 2210, 2150, 2080, 2356, 2260, 2180]
    },
    "income_structure": [
      { "name": "住院收入", "value": 54 },
      { "name": "门诊收入", "value": 38 },
      { "name": "其他收入", "value": 8 }
    ],
    "dept_share_top8": [
      { "name": "心血管内科", "value": "1,860", "pct": 92 },
      { "name": "骨科", "value": "1,724", "pct": 85 },
      { "name": "呼吸与危重症医学科", "value": "1,615", "pct": 80 },
      { "name": "普通外科", "value": "1,452", "pct": 72 },
      { "name": "神经内科", "value": "1,310", "pct": 65 },
      { "name": "肿瘤科", "value": "1,220", "pct": 60 },
      { "name": "妇产科", "value": "1,140", "pct": 56 },
      { "name": "儿科", "value": "980", "pct": 48 }
    ],
    "live_inpatient": [
      { "label": "当前在院人数", "value": "1,846", "color": "#2563eb" },
      { "label": "今日入院人数", "value": "142", "color": "#0d9488" },
      { "label": "今日出院核准", "value": "128", "color": "#059669" },
      { "label": "待分配床位", "value": "14", "color": "#d97706" },
      { "label": "空闲开放床位", "value": "158", "color": "#64748b" },
      { "label": "重症监护占用率", "value": "98%", "color": "#dc2626" }
    ]
  }
  ```

---

## 5. 医疗业务 /workbench/medical

对应页面：`src/views/workbench/MedicalView.vue`。支持两级维度：`bizTab`（门急诊/住院/手术）与 `range`（本月/本季/本年）。

### 5.1 GET /workbench/medical
- **Query 参数**：
  - `tab` = `门急诊` | `住院` | `手术`（默认 `门急诊`）
  - `range` = `本月` | `本季` | `本年`（默认 `本年`）
- **Response `data`（以 `tab=门急诊` 为例）**：
  ```json
  {
    "tab": "门急诊",
    "range": "本年",
    "stats": [
      { "label": "门急诊总人次", "value": "12,482", "delta": "+3.6%", "dir": "up" },
      { "label": "普通门诊", "value": "8,236", "delta": "+2.1%", "dir": "up" },
      { "label": "专家门诊", "value": "3,114", "delta": "+6.4%", "dir": "up" },
      { "label": "急诊人次", "value": "1,132", "delta": "+4.2%", "dir": "up" },
      { "label": "次均费用", "value": "286", "unit": "元", "delta": "+1.8%", "dir": "up" },
      { "label": "平均候诊", "value": "18", "unit": "分钟", "delta": "-3分钟", "dir": "down" }
    ],
    "trend": {
      "title": "门急诊人次趋势",
      "months": ["1月", "2月", "3月", "4月", "5月", "6月", "7月", "8月", "9月", "10月", "11月", "12月"],
      "values": [5400, 4600, 6800, 7000, 8500, 9000, 10800, 9700, 10500, 12300, 12200, 12000]
    },
    "distribution": {
      "title": "就诊高峰时段分布",
      "sub": "近 30 日分时段人次",
      "type": "bar",
      "categories": ["7时", "8时", "9时", "10时", "11时", "14时", "15时", "16时", "17时", "19时"],
      "values": [620, 1480, 1960, 1750, 1180, 1380, 1240, 960, 540, 380]
    },
    "table": {
      "columns": [
        { "key": "dept", "title": "科室" },
        { "key": "cnt", "title": "门急诊人次", "align": "right", "num": true },
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

---

## 6. 运营管理 /workbench/operations

对应页面：`src/views/workbench/OperationsView.vue`。

### 6.1 GET /workbench/operations
- **Query 参数**：`range` = `本月` | `本季` | `本年`
- **Response `data`**：
  ```json
  {
    "stats": [
      { "label": "医疗总收入", "value": "23,560", "unit": "万元", "delta": "+2.9%", "dir": "up" },
      { "label": "门诊收入", "value": "8,950", "unit": "万元", "delta": "+1.8%", "dir": "up" },
      { "label": "住院收入", "value": "12,720", "unit": "万元", "delta": "+3.6%", "dir": "up" },
      { "label": "收支结余率", "value": "4.2", "unit": "%", "delta": "+0.4%", "dir": "up" },
      { "label": "次均门诊费用", "value": "286", "unit": "元", "delta": "+1.8%", "dir": "up" },
      { "label": "次均住院费用", "value": "9,860", "unit": "元", "delta": "+2.4%", "dir": "up" }
    ],
    "revenue_trend": {
      "months": ["1月", "2月", "3月", "4月", "5月", "6月", "7月", "8月", "9月", "10月", "11月", "12月"],
      "income": [1420, 1280, 1720, 1850, 1980, 2060, 2210, 2150, 2080, 2356, 2260, 2180],
      "cost": [1360, 1230, 1640, 1770, 1890, 1970, 2110, 2060, 1990, 2250, 2160, 2080],
      "balance": [60, 50, 80, 80, 90, 90, 100, 90, 90, 106, 100, 100]
    },
    "cost_controls": [
      { "name": "药占比", "value": "28.4%", "target": "≤30%", "status": "达标", "pct": 71 },
      { "name": "百元医疗收入消耗卫生材料", "value": "17.9元", "target": "≤20元", "status": "达标", "pct": 60 },
      { "name": "管理费用率", "value": "7.8%", "target": "≤8%", "status": "达标", "pct": 65 },
      { "name": "百元医疗收入人员经费", "value": "32.5元", "target": "30~35元", "status": "合理", "pct": 65 }
    ],
    "dept_table": {
      "columns": [
        { "key": "dept", "title": "科室" },
        { "key": "income", "title": "收入（万元）", "align": "right", "num": true },
        { "key": "cost", "title": "成本（万元）", "align": "right", "num": true },
        { "key": "balance", "title": "结余（万元）", "align": "right", "num": true },
        { "key": "margin", "title": "结余率", "align": "right", "num": true },
        { "key": "drugRatio", "title": "药占比", "align": "right", "num": true },
        { "key": "matRatio", "title": "耗材比", "align": "right", "num": true }
      ],
      "rows": [
        { "dept": "心血管内科", "income": "2,480", "cost": "2,310", "balance": "170", "margin": "6.9%", "drugRatio": "24.8%", "matRatio": "18.2%" },
        { "dept": "骨科", "income": "2,180", "cost": "1,980", "balance": "200", "margin": "9.2%", "drugRatio": "12.4%", "matRatio": "34.6%" },
        { "dept": "呼吸与危重症医学科", "income": "1,860", "cost": "1,790", "balance": "70", "margin": "3.8%", "drugRatio": "32.6%", "matRatio": "8.4%" },
        { "dept": "普通外科", "income": "1,740", "cost": "1,620", "balance": "120", "margin": "6.9%", "drugRatio": "18.2%", "matRatio": "22.1%" },
        { "dept": "神经内科", "income": "1,420", "cost": "1,380", "balance": "40", "margin": "2.8%", "drugRatio": "36.4%", "matRatio": "6.2%" },
        { "dept": "肿瘤科", "income": "1,680", "cost": "1,610", "balance": "70", "margin": "4.2%", "drugRatio": "42.8%", "matRatio": "9.1%" }
      ]
    }
  }
  ```

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
      { "label": "高级职称占比", "value": "18.2", "unit": "%", "delta": "+0.6%", "dir": "up" },
      { "label": "人员经费占比", "value": "32.5", "unit": "%", "delta": "+1.1%", "dir": "up" }
    ],
    "structure": [
      { "name": "护理人员", "value": 44, "count": 1046 },
      { "name": "执业医师", "value": 34, "count": 812 },
      { "name": "行政后勤", "value": 13, "count": 308 },
      { "name": "医技人员", "value": 9, "count": 202 }
    ],
    "titles": {
      "categories": ["正高", "副高", "中级", "初级及以下"],
      "values": [128, 302, 946, 992]
    },
    "dept_staffing": {
      "columns": [
        { "key": "dept", "title": "科室" },
        { "key": "quota", "title": "定岗编制", "align": "right", "num": true },
        { "key": "actual", "title": "实际在岗", "align": "right", "num": true },
        { "key": "doctor", "title": "医师", "align": "right", "num": true },
        { "key": "nurse", "title": "护士", "align": "right", "num": true },
        { "key": "ratio", "title": "医护比", "align": "center" },
        { "key": "gap", "title": "缺口", "align": "right", "num": true },
        { "key": "status", "title": "状态", "align": "center" }
      ],
      "rows": [
        { "dept": "重症医学科", "quota": 68, "actual": 58, "doctor": 16, "nurse": 42, "ratio": "1:2.63", "gap": 10, "status": "紧缺" },
        { "dept": "急诊科", "quota": 86, "actual": 78, "doctor": 24, "nurse": 54, "ratio": "1:2.25", "gap": 8, "status": "紧张" },
        { "dept": "儿科", "quota": 64, "actual": 58, "doctor": 20, "nurse": 38, "ratio": "1:1.90", "gap": 6, "status": "紧张" },
        { "dept": "心血管内科", "quota": 92, "actual": 89, "doctor": 32, "nurse": 57, "ratio": "1:1.78", "gap": 3, "status": "充足" },
        { "dept": "骨科", "quota": 84, "actual": 81, "doctor": 28, "nurse": 53, "ratio": "1:1.89", "gap": 3, "status": "充足" }
      ]
    }
  }
  ```

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
      "years": ["2020", "2021", "2022", "2023", "2024"],
      "national": [4, 6, 8, 9, 12],
      "provincial": [12, 16, 20, 24, 30],
      "funds": [1200, 1680, 2240, 2940, 3480]
    },
    "paper_distribution": {
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
      { "label": "网约挂号率", "value": "88.6", "unit": "%", "delta": "+4.2%", "dir": "up" }
    ],
    "satisfaction_trend": {
      "months": ["5月", "6月", "7月", "8月", "9月", "10月"],
      "outpatient": [94.8, 95.2, 95.6, 95.8, 96.1, 96.4],
      "inpatient": [96.0, 96.2, 96.5, 96.8, 97.0, 97.2]
    },
    "channel_distribution": [
      { "name": "微信公众号", "value": 56 },
      { "name": "自助机", "value": 24 },
      { "name": "人工窗口", "value": 12 },
      { "name": "电话/网络", "value": 8 }
    ],
    "complaints_praises": {
      "columns": [
        { "key": "date", "title": "日期", "align": "center", "num": true },
        { "key": "type", "title": "类型", "align": "center" },
        { "key": "dept", "title": "涉及科室" },
        { "key": "content", "title": "反映内容" },
        { "key": "status", "title": "处理状态", "align": "center" },
        { "key": "score", "title": "回访评价", "align": "center" }
      ],
      "rows": [
        { "date": "10-27", "type": "表扬", "dept": "心血管内科", "content": "护士巡房细致入微，态度温和", "status": "已归档", "score": "非常满意" },
        { "date": "10-26", "type": "投诉", "dept": "超声科", "content": "叫号过慢，上午预约下午才做上", "status": "已整改", "score": "基本满意" },
        { "date": "10-25", "type": "投诉", "dept": "门诊药房", "content": "排队取药等候时间较长", "status": "处理中", "score": "待评价" }
      ]
    }
  }
  ```

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
      "months": ["5月", "6月", "7月", "8月", "9月", "10月"],
      "rates": [1.46, 1.40, 1.35, 1.32, 1.28, 1.24]
    },
    "adverse_events": {
      "categories": ["给药差错", "跌倒/坠床", "标本错误", "导管滑脱", "压疮", "其他"],
      "values": [12, 9, 6, 4, 3, 2]
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
        { "name": "首诊负责制度", "sample": 320, "pass": 318, "rate": "99.4%", "issues": "个别交接记录不及时" },
        { "name": "三级查房制度", "sample": 240, "pass": 234, "rate": "97.5%", "issues": "主任查房记录欠详实" },
        { "name": "疑难病例讨论制度", "sample": 60, "pass": 58, "rate": "96.7%", "issues": "讨论时限偶有延误" },
        { "name": "急危重患者抢救制度", "sample": 86, "pass": 86, "rate": "100.0%", "issues": "无" },
        { "name": "手术分级管理制度", "sample": 420, "pass": 416, "rate": "99.0%", "issues": "术者越级手术 1 例（急诊抢救）" }
      ]
    }
  }
  ```

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
      "months": ["5月", "6月", "7月", "8月", "9月", "10月"],
      "electricity": [112, 126, 142, 138, 120, 114],
      "water": [38, 42, 46, 44, 40, 38],
      "gas": [32, 28, 26, 28, 32, 34]
    },
    "stock_alerts": [
      { "name": "一次性使用输液器", "days": 46, "level": "高" },
      { "name": "骨科植入物（接骨板）", "days": 42, "level": "高" },
      { "name": "造影剂（碘海醇）", "days": 36, "level": "中" },
      { "name": "医用缝合线", "days": 34, "level": "中" },
      { "name": "中心静脉导管", "days": 31, "level": "中" },
      { "name": "无菌手术衣", "days": 29, "level": "中" }
    ],
    "large_equipments": {
      "columns": [
        { "key": "name", "title": "设备名称" },
        { "key": "dept", "title": "所属科室" },
        { "key": "count", "title": "台数", "align": "right", "num": true },
        { "key": "openRate", "title": "开机率", "align": "right" },
        { "key": "monthly", "title": "月均检查/治疗人次", "align": "right", "num": true },
        { "key": "income", "title": "月创收（万元）", "align": "right", "num": true },
        { "key": "roi", "title": "效益评价", "align": "center" }
      ],
      "rows": [
        { "name": "3.0T 核磁共振", "dept": "放射科", "count": 2, "openRate": "96.8%", "monthly": "2,860", "income": "486", "roi": "良好" },
        { "name": "256 排 CT", "dept": "放射科", "count": 2, "openRate": "94.6%", "monthly": "4,120", "income": "412", "roi": "良好" },
        { "name": "DSA 血管造影机", "dept": "介入中心", "count": 1, "openRate": "88.4%", "monthly": "380", "income": "296", "roi": "良好" },
        { "name": "直线加速器", "dept": "放疗科", "count": 1, "openRate": "91.2%", "monthly": "420", "income": "268", "roi": "良好" },
        { "name": "PET-CT", "dept": "核医学科", "count": 1, "openRate": "72.6%", "monthly": "186", "income": "158", "roi": "偏低" }
      ]
    }
  }
  ```

---

## 12. 对比分析 /workbench/compare

对应页面：`src/views/workbench/CompareView.vue`。支持维度切换：`dim` = `scale` | `efficiency` | `quality` | `benefit`。

### 12.1 GET /workbench/compare
- **Query 参数**：`dim` = `scale` | `efficiency` | `quality` | `benefit`（默认 `scale`）
- **Response `data`**：
  ```json
  {
    "dimension": "scale",
    "radar": {
      "indicators": [
        { "name": "门诊量", "max": 1500 },
        { "name": "出院量", "max": 800 },
        { "name": "手术量", "max": 300 },
        { "name": "床位占用", "max": 100 },
        { "name": "次均费用", "max": 15000 },
        { "name": "患者满意", "max": 100 }
      ],
      "series": [
        { "name": "心血管内科", "value": [1286, 680, 240, 94, 12400, 96.2] },
        { "name": "骨科", "value": [716, 612, 280, 96, 15860, 95.4] },
        { "name": "呼吸与危重症医学科", "value": [1158, 538, 110, 92, 11280, 94.8] }
      ]
    },
    "benchmarks": [
      { "name": "年门急诊量（万人次）", "ours": "142.6", "region": "118.4", "bench": "168.2", "gap": "+24.2" },
      { "name": "年出院人数（万人）", "ours": "4.28", "region": "3.62", "bench": "5.10", "gap": "+0.66" },
      { "name": "平均住院日（天）", "ours": "6.8", "region": "7.9", "bench": "6.2", "gap": "-1.1" },
      { "name": "三四级手术占比（%）", "ours": "58.6", "region": "48.2", "bench": "65.0", "gap": "+10.4" },
      { "name": "药占比（%）", "ours": "28.4", "region": "31.6", "bench": "25.0", "gap": "-3.2" },
      { "name": "CMI 值", "ours": "1.08", "region": "0.96", "bench": "1.22", "gap": "+0.12" }
    ],
    "table": {
      "columns": [
        { "key": "dept", "title": "科室" },
        { "key": "metric", "title": "当前指标" },
        { "key": "yoy", "title": "同比", "align": "right", "num": true },
        { "key": "outp", "title": "门诊人次", "align": "right", "num": true },
        { "key": "inpt", "title": "出院人数", "align": "right", "num": true },
        { "key": "days", "title": "平均住院日", "align": "right", "num": true },
        { "key": "sat", "title": "满意度", "align": "right", "num": true }
      ],
      "rows": [
        { "dept": "心血管内科", "metric": "1,286", "pct": 100, "yoy": "+6.2%", "outp": 1286, "inpt": 680, "days": 9.2, "sat": 96.2 },
        { "dept": "呼吸与危重症医学科", "metric": "1,158", "pct": 90, "yoy": "+8.7%", "outp": 1158, "inpt": 538, "days": 10.4, "sat": 94.8 },
        { "dept": "消化内科", "metric": "1,042", "pct": 81, "yoy": "+4.1%", "outp": 1042, "inpt": 320, "days": 7.2, "sat": 94.6 },
        { "dept": "骨科", "metric": "716", "pct": 56, "yoy": "+5.4%", "outp": 716, "inpt": 612, "days": 8.6, "sat": 95.4 }
      ]
    }
  }
  ```

---

## 13. 专题分析与设置 /workbench/topics & /workbench/settings

### 13.1 GET /workbench/topics
- **Query 参数**：
  - `topic` = `drg`（DRG付费） | `insurance`（医保基金） | `exam`（三级国考） | `outpFund`（门诊统筹）
  - `range` = `本月` | `本季` | `本年`
- **Response `data`（以 `topic=drg` 为例）**：
  ```json
  {
    "topic": "drg",
    "range": "本年",
    "stats": [
      { "label": "CMI 值", "value": "1.08", "delta": "+0.04", "dir": "up" },
      { "label": "入组率", "value": "98.5", "unit": "%", "delta": "+0.6%", "dir": "up" },
      { "label": "费用消耗指数", "value": "0.92", "delta": "-0.03", "dir": "down" },
      { "label": "时间消耗指数", "value": "0.95", "delta": "-0.02", "dir": "down" },
      { "label": "RW≥2 占比", "value": "21.4", "unit": "%", "delta": "+1.8%", "dir": "up" },
      { "label": "低风险组死亡率", "value": "0.02", "unit": "%", "delta": "持平", "dir": "flat" }
    ],
    "chart": {
      "title": "病组权重（RW）分布",
      "sub": "本月出院病例按 RW 分段",
      "type": "bar",
      "categories": ["<0.5", "0.5-1", "1-2", "2-5", "5-10", "≥10"],
      "values": [420, 1620, 1480, 320, 62, 18]
    },
    "table": {
      "title": "科室 DRG 核心指标",
      "sub": "按 CMI 排序",
      "columns": [
        { "key": "dept", "title": "科室" },
        { "key": "cmi", "title": "CMI", "align": "right", "num": true },
        { "key": "cases", "title": "入组病例", "align": "right", "num": true },
        { "key": "costIdx", "title": "费用消耗指数", "align": "right", "num": true },
        { "key": "timeIdx", "title": "时间消耗指数", "align": "right", "num": true },
        { "key": "rw2", "title": "RW≥2 占比", "align": "right", "num": true },
        { "key": "profit", "title": "DRG 结余（万元）", "align": "right", "num": true }
      ],
      "rows": [
        { "dept": "神经外科", "cmi": "1.68", "cases": "142", "costIdx": "1.02", "timeIdx": "1.06", "rw2": "46.8%", "profit": "-12.8" },
        { "dept": "心血管内科", "cmi": "1.42", "cases": "658", "costIdx": "0.96", "timeIdx": "0.98", "rw2": "28.6%", "profit": "+86.4" },
        { "dept": "骨科", "cmi": "1.36", "cases": "596", "costIdx": "0.88", "timeIdx": "0.94", "rw2": "32.4%", "profit": "+124.6" },
        { "dept": "肿瘤科", "cmi": "1.24", "cases": "392", "costIdx": "1.08", "timeIdx": "1.02", "rw2": "26.4%", "profit": "-34.6" },
        { "dept": "普通外科", "cmi": "1.18", "cases": "486", "costIdx": "0.86", "timeIdx": "0.92", "rw2": "24.2%", "profit": "+98.2" }
      ]
    }
  }
  ```

### 13.2 GET /workbench/settings/config
- **说明**：设置页面的数据源连接状态、预警阈值、权限用户与系统偏好。
- **Response `data`**：
  ```json
  {
    "data_sources": [
      { "name": "HIS 门诊收费系统", "type": "业务库 · 准实时", "status": "已连接", "sync": "10-28 09:42" },
      { "name": "HIS 住院管理系统", "type": "业务库 · 准实时", "status": "已连接", "sync": "10-28 09:42" },
      { "name": "EMR 电子病历", "type": "业务库 · 小时级", "status": "已连接", "sync": "10-28 09:00" },
      { "name": "LIS 检验系统", "type": "业务库 · 小时级", "status": "已连接", "sync": "10-28 09:05" },
      { "name": "HRP 人财物系统", "type": "业务库 · 日终批", "status": "已连接", "sync": "10-28 06:30" },
      { "name": "医保结算接口", "type": "局端接口 · 日终批", "status": "异常", "sync": "10-27 23:58" }
    ],
    "thresholds": [
      { "name": "床位使用率", "rule": "连续 3 日 > 95%", "level": "高", "enabled": true },
      { "name": "药占比", "rule": "> 30%", "level": "中", "enabled": true },
      { "name": "耗占比", "rule": "> 20%", "level": "中", "enabled": true },
      { "name": "住院费用增幅", "rule": "同比 > 8%", "level": "高", "enabled": true },
      { "name": "库存周转天数", "rule": "> 35 天", "level": "低", "enabled": true },
      { "name": "危急值超时率", "rule": "及时率 < 95%", "level": "高", "enabled": true },
      { "name": "设备开机率", "rule": "< 60%", "level": "低", "enabled": false }
    ],
    "users": [
      { "name": "system_admin", "role": "管理员", "scope": "全部", "login": "10-28 09:12", "status": "启用" },
      { "name": "院长", "role": "院领导", "scope": "全院", "login": "10-28 08:46", "status": "启用" },
      { "name": "分管副院长·医疗", "role": "院领导", "scope": "全院", "login": "10-27 17:32", "status": "启用" },
      { "name": "医务部主任", "role": "部门负责人", "scope": "医疗业务", "login": "10-28 08:58", "status": "启用" },
      { "name": "财务部主任", "role": "部门负责人", "scope": "运营财务", "login": "10-28 09:05", "status": "启用" },
      { "name": "骨科主任", "role": "科室主任", "scope": "骨科", "login": "10-28 08:30", "status": "启用" }
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

---

## 14. 辅助形态：科技大屏快照 /screen/snapshot

对应页面：`src/views/ScreenView.vue` 及根目录 `src/components/*.vue`。

### 14.1 GET /screen/snapshot
- **说明**：科技大屏一站式加载快照。继承 v1.1 结构，一次性供给大屏 7 大组件渲染。
- **Response `data`**：
  ```json
  {
    "server_time": "2026-09-18T08:30:00+08:00",
    "status": {
      "level": "normal",
      "text": "运行平稳",
      "desc": "医院整体运行正常",
      "alert_open": { "urgent": 0, "major": 2, "minor": 3 }
    },
    "kpis": [
      { "code": "OP_DAILY_VISITS", "name": "今日门急诊", "value": 2845, "unit": "人", "prev_value": 2664, "delta_pct": 6.8, "direction": 1, "spark": [2310, 2450, 2600, 2501, 2580, 2664, 2845], "status": "normal" },
      { "code": "IP_IN_HOSP", "name": "在院患者", "value": 1846, "unit": "人", "prev_value": 1820, "delta_pct": 1.4, "direction": 1, "spark": [1780, 1800, 1810, 1825, 1830, 1820, 1846], "status": "normal" },
      { "code": "BED_USE_RATE", "name": "床位使用率", "value": 92.1, "unit": "%", "prev_value": 90.8, "delta_pct": 1.4, "direction": 1, "spark": [88.5, 89.2, 90.1, 91.0, 91.5, 90.8, 92.1], "status": "warn" },
      { "code": "SURG_DAILY_CNT", "name": "今日手术", "value": 142, "unit": "台", "prev_value": 136, "delta_pct": 4.4, "direction": 1, "spark": [120, 125, 130, 128, 134, 136, 142], "status": "normal" }
    ],
    "drg_quadrant": {
      "period": "d30",
      "axis": { "x": "DRG盈亏(万元)", "y": "CMI" },
      "split": { "x": 0, "y": 1.0 },
      "points": [
        { "dept_id": 1, "name": "骨科", "category": "surg", "cmi": 1.36, "profit": 1246000.0, "case_cnt": 596, "quadrant": 2 },
        { "dept_id": 2, "name": "心血管内科", "category": "med", "cmi": 1.42, "profit": 864000.0, "case_cnt": 658, "quadrant": 2 },
        { "dept_id": 3, "name": "肿瘤科", "category": "med", "cmi": 1.24, "profit": -346000.0, "case_cnt": 392, "quadrant": 1 },
        { "dept_id": 4, "name": "神经外科", "category": "surg", "cmi": 1.68, "profit": -128000.0, "case_cnt": 142, "quadrant": 1 },
        { "dept_id": 5, "name": "儿科", "category": "med", "cmi": 0.68, "profit": 284000.0, "case_cnt": 342, "quadrant": 4 }
      ]
    },
    "buildings": [
      { "code": "mz", "name": "门诊楼", "status": "normal", "badge": "2310 人", "badge_level": "info", "anchor": { "x": 32, "y": 58 }, "metrics": { "today_visit": 2310, "queue_avg_min": 18 } },
      { "code": "wk", "name": "外科楼", "status": "busy", "badge": "96% 负荷", "badge_level": "warn", "anchor": { "x": 50, "y": 30 }, "metrics": { "bed_use_rate": 0.96, "bed_used": 192, "bed_open": 200 } },
      { "code": "jz", "name": "急诊楼", "status": "alert", "badge": "留观超时", "badge_level": "alert", "anchor": { "x": 66, "y": 42 }, "metrics": { "obs_over6h": 3, "obs_cnt": 11, "obs_max_min": 560 } },
      { "code": "yj", "name": "医技楼", "status": "normal", "badge": "设备正常", "badge_level": "ok", "anchor": { "x": 60, "y": 66 }, "metrics": { "device_run": 12, "device_alert": 0 } }
    ],
    "dept_ranking": [
      { "rank": 1, "dept_id": 1, "name": "骨科", "category": "surg", "cmi": 1.36, "surg_cnt": 280, "alos": 8.6, "profit": 1246000.0, "eff_score": 94.2 },
      { "rank": 2, "dept_id": 2, "name": "心血管内科", "category": "med", "cmi": 1.42, "surg_cnt": 240, "alos": 9.2, "profit": 864000.0, "eff_score": 92.8 }
    ],
    "alerts": {
      "total_open": 5,
      "list": [
        { "id": 51, "level": "urgent", "title": "急诊留观超时（>6h）", "dept": "急诊科", "time": "08:12" },
        { "id": 52, "level": "major", "title": "外科楼重症监护床位达98%", "dept": "重症医学科", "time": "08:20" }
      ]
    },
    "trends": {
      "days": 7,
      "dates": ["09-12", "09-13", "09-14", "09-15", "09-16", "09-17", "09-18"],
      "series": {
        "OP_DAILY_VISITS": [2310, 2450, 2600, 2501, 2580, 2664, 2845],
        "IP_IN_HOSP": [1780, 1800, 1810, 1825, 1830, 1820, 1846],
        "SURG_DAILY_CNT": [120, 125, 130, 128, 134, 136, 142],
        "BED_USE_RATE": [88.5, 89.2, 90.1, 91.0, 91.5, 90.8, 92.1]
      }
    }
  }
  ```

---

## 15. 远期预留端点清单（Reserved Endpoints Checklist）

以下端点源自 v1.1 架构设计，属于**“远期真实业务演进与后端落地项”**。在当前前端 Mock/API 解耦阶段，前端不发起真实调用，保留此清单以备未来后端开发与深层穿透扩展：

| # | Method | Path | 用途与定位 | 规划阶段 | 说明 |
| :- | :----- | :--- | :--------- | :------ | :--- |
| R01 | GET | `/cases` | L4 病例列表（按科室/病组/死因筛选） | P2 | 用于从 DRG 病组穿透至具体病例集合 |
| R02 | GET | `/cases/{id}` | L5 电子病历（脱敏事实） | P2 | 默认患者姓名身份证脱敏（`张**`） |
| R03 | GET | `/cases/{id}?unmask=1` | L5 实名解密调阅 | P2 | 需输入二次验密口令，记录审计日志 |
| R04 | POST | `/alerts/{id}/ack` | 告警认领 | P2 | 告警状态变为 `processing` |
| R05 | POST | `/alerts/{id}/dispatch` | 告警一键督办派发 | P2 | 生成 Todo 工单，指定承办人与截止期 |
| R06 | POST | `/alerts/{id}/close` | 告警直接闭环关闭 | P2 | 填写办结理由 |
| R07 | GET | `/todos` | 督办追踪工单列表 | P2 | 包含整改前/当前/目标值三点锚点 |
| R08 | POST | `/todos/{id}/status` | 督办工单反馈与办结 | P2 | 承办科室主任提交整改举措 |
| R09 | GET | `/campus/buildings/{code}`| 楼宇详情抽屉（病区/设备） | P2 | 大屏点击外科楼/急诊楼拉出二级抽屉 |
| R10 | GET | `/staff` | 组织人员下拉选择器 | P2 | 督办派发时根据科室联想责任人 |
| R11 | POST| `/auth/login` | 正式 JWT 登录 | P3 | 真实 Go 后端上线时启用 |
| R12 | POST| `/auth/refresh` | Token 静默轮换 | P3 | 双 Token 并发安全轮换 |
| R13 | POST| `/metrics/query` | ChatBI / 指标语义层查询 | P3 | 大模型 NLQ to DSL 智能问数接口 |
| R14 | GET/POST | `/sim/*` | 仿真时钟与故障注入 | P3 | 演示控制接口（时钟加速、重置、注入告警） |

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
1. `src/views/workbench/*.vue` 中原先写在 `const stats = [...]` 等内部的数据全量抽出迁移到 `src/mock/*.json` 中；
2. 组件中通过 `onMounted` 调用 `api.getOverview()` 等标准化函数给 `ref` 赋值；
3. 将来无论是纯前端演示、接入轻量 Node 服务、还是上线 Go 单体后端，前端视图组件均无需修改一行业务渲染逻辑！
