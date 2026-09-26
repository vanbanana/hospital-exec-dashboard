# API 契约（冻结基线 v1.1）— EDSS

> **本文件是前后端唯一接口事实来源。冻结规则：**
> 1. 字段只增不删、不改名、不改类型；2. 新能力只能加端点或在 `data` 内加可选字段；
> 3. 枚举值只增不改，前端遇未知枚举值必须降级处理不崩溃；4. 变更流程 = 改本文档 → 双方 review → 后端实现。**禁止先写代码后补文档。**
>
> **通用约定**
> - BaseURL `/api/v1`；包络见 `error-codes.md` §1（下文示例只写 `data`）；`ts`=真实服务器 unix 秒
> - 时刻字段 ISO8601 带时区；纯日期字段 `YYYY-MM-DD` 且命名 `*_date`；`admit_at` 类 `_at` 后缀保留给时刻
> - **金额一律元**（numeric 两位小数）；前端按展示需要换算万元。指标型数值（/metrics/* 与内嵌 metric 对象）按 metric_def.unit 给展示值（unit='%'→90.8，unit='万元'→830.5）
> - **原始率值**（`*_rate`/`_ratio` 出现在 metrics/payload 等裸字段时）= 0~1 小数
> - 分页 `?page&size`（size≤100）；排序统一 `by=<字段>&order=asc|desc`；`limit` 仅用于 topN 快照
> - 鉴权 `Authorization: Bearer <access>`（除 login/refresh/healthz）；可空字段在示例中显式标 `|null`
>- 命名约定：路径用全名（/departments），字段用缩写（dept_id）
- **DB列名→API字段名映射表**（防混淆）：`drill_route→drill`、`badge_text→badge`、`map_anchor→anchor`、`emr_json→emr`、`triage_level→triage`、`patient_masked→patient`、`building_code`（参数 `building` 吃 code，响应 `building` 是中文名、`building_code` 是编码）

---

## 0. 枚举附录（全篇引用，冻结值域）

| 枚举 | 取值 | 说明 |
| :--- | :--- | :--- |
| role | `admin`/`president`/`ops_director`/`viewer` | |
| dept.category | `med`/`surg`/`tech`/`nurse`/`adm` | 图例映射：med→内科、surg→外科、tech→医技、nurse+adm→其他 |
| dept.level | 1院区/2科室/3医疗组 | |
| alert.level | `urgent`/`major`/`minor` | |
| alert.status | `pending`/`processing`/`done`/`closed` | 查询用聚合值 `open`=pending+processing、`all` |
| todo.status | `open`/`doing`/`done`/`expired` | 状态机 open→doing→done；expired 系统置位 |
| building.status | `normal`/`busy`/`alert` | |
| badge_level | `info`/`ok`/`warn`/`alert` | 仅徽标颜色 |
| drill.type | `route`/`drawer`/`none` | 未知值→按 none 隐藏按钮；path 仅站内路由 |
| quadrant | 1左上/2右上/3左下/4右下 | split.x=盈亏0线，split.y=CMI均值线 |
| surg_level | 1~4 | |
| staff_type | `doc`/`nur`/`tec`/`adm` | |
| period | `d30`/`month` | ranking/quadrant 周期参数；**注意**：/metrics/trend 的 `period` 是另一枚举 `day`/`hour`（端点级值域，勿合并） |
| days | 7/14/30/90 | trend 天数 |
| flag（cases） | `all`/`loss`/`l4`/`death`/`readmit`/`spec` | |
| metric.direction | 1/-1/0 | 指标极性：越高越好/越低越好/中性 |
| kpi.status | `normal`/`warn`/`alert` | 后端按字典阈值算好 |
| screen.status.level | `normal`/`busy`/`alert` | 判定序：urgent>0→alert；else major>2→busy；else normal |

---

## 1. 认证域 /auth

### POST /auth/login
```json
{ "username": "president", "password": "******",
  "captcha_id": "(预留·可选)", "captcha_code": "(预留·可选)" }
→ {
  "access_token": "eyJ...", "refresh_token": "eyJ...", "expires_in": 7200,
  "user": { "id":2, "username":"president", "real_name":"王建国", "emp_no":"E0001",
            "role":"president", "dept_id":null } }
```
错误：20101 密码错 / 20102 停用 / **20104 连续失败锁定（5次/15min）** / 10002 缺参。

### POST /auth/refresh
```json
{ "refresh_token": "eyJ..." }
→ { "access_token": "...", "refresh_token": "...(轮换)", "expires_in": 7200 }
```
**轮换宽限**：旧 refresh_token 自轮换起 30s 内重放返回同一对新 token（多标签页并发安全）；超窗→20003。
错误：20002/20003。

### POST /auth/logout → `{ "ok": true }`（吊销 refresh）

### GET /auth/profile
```json
{ "id":2, "username":"president", "real_name":"王建国", "emp_no":"E0001",
  "role":"president", "dept_id":null,
  "permissions": ["screen:view","metric:view","drill:view","case:view","case:unmask",
                  "alert:view","alert:dispatch","todo:view"] }
```
`permissions` = role→perm 映射（冻结表见 §13）。

### POST /auth/password（**P2 预留，本期不实现**）
`{ "old_password", "new_password" }` → 20103 密码强度不足。

---

## 2. 医院基础 /hospital

### GET /hospital/profile
```json
{ "name":"市中心医院", "motto":"厚德 精医 仁爱 创新",
  "slogan":"人民至上 · 生命至上 · 精细管理 · 高质量发展",
  "level":"三级甲等", "campus":[{"code":"main","name":"本部"}] }
```

---

## 3. 大屏聚合 /screen

### GET /screen/snapshot ★首屏一次性加载
```json
{
  "server_time": "2026-09-18T08:30:00+08:00",
  "status": { "level":"alert", "text":"注意", "desc":"存在紧急告警待处理",
              "alert_open": { "urgent":1, "major":2, "minor":2 } },
  "kpis": [ /* 结构同 /metrics/today list 项 */ ],
  "drg_quadrant": { /* 结构同 /drg/quadrant data */ },
  "dept_ranking": [ /* 结构同 /departments/ranking list 项（top10） */ ],
  "alerts": { "total_open":5, "list":[ /* 结构同 /alerts list 项 top5 */ ] },
  "buildings": [ /* 结构同 /campus/buildings list */ ],
  "trends": { "days":7, "dates":["2026-09-12","..."],
              "series": { "OP_DAILY_VISITS":[...], "IP_IN_HOSP":[...],
                          "SURG_DAILY_CNT":[...], "BED_USE_RATE":[...] } }
}
```
- `server_time` = virtual_now（仿真模式）或真实 now（ETL 模式）；`ts`=真实时间，两者在 sim 倍速下不同属正常
- **snapshot 各节结构 = 对应单端点 list/内容快照**（分节刷新无缝复用同一类型）

### GET /screen/status（状态胶囊独立刷新，15s 级轻端点）
```json
{ "level":"alert", "text":"注意", "desc":"存在紧急告警待处理",
  "alert_open":{"urgent":1,"major":2,"minor":2}, "server_time":"..." }
```

---

## 4. 指标域 /metrics

### GET /metrics/today?codes=OP_DAILY_VISITS,IP_IN_HOSP,BED_USE_RATE,SURG_DAILY_CNT&dept_id=
```json
{ "server_time": "2026-09-18T08:35:00+08:00",
  "list": [ { "code":"OP_DAILY_VISITS", "name":"今日门急诊", "value":2845, "unit":"人",
              "prev_value":2664, "delta_pct":6.8, "direction":0,
              "spark":[2310,2450,2600,2501,2580,2664,2845], "status":"normal" } ] }
```
**口径钉死**：
- `prev_value` = **昨日同一 virtual_now 时刻**累计值（非昨日全天）
- `spark` = 近 7 日同时刻值，**末元素=当前 value**，长度恒 7
- `delta_pct` = (value−prev)/prev×100，保留 1 位小数；**prev 缺失或为 0 → delta_pct=null**
- `dept_id` 可选=科室口径（科室驾驶舱用）
错误：31001（data.unknown 列非法 code）/ 31004（口径正常无数据，data=null）。

### GET /metrics/trend?code=X&days=7&dept_id=&period=day
```json
{ "code":"OP_DAILY_VISITS","unit":"人","period":"day","days":7,
  "dates":["2026-09-12","..."],"values":[2450,2664,...] }
```
`period`=`day`（默认，days∈{7,14,30,90}）/ `hour`（当日分时走势，返回 `times[]` 替代 `dates[]`，P2 启用字段先预留）。dates 不含今日时由调用方拼接 today_kpi。
错误：31002（days 越界）/31005（period 不支持）。

### GET /metrics/detail?code=CMI&period=d30&dept_id=
```json
{ "metric":{"code":"CMI","name":"病例组合指数","unit":"","direction":1,"formula":"..."},
  "summary":{"value":1.28,"delta_pct":3.2,"rank_in_depts":3},
  "trend":{"dates":[...],"values":[...]},
  "dept_breakdown":[{"dept_id":1,"name":"骨科","value":1.62,"share":0.09,"delta_pct":2.1}],
  "top_groups":[{"drg_code":"IF15","name":"腰椎融合术","value":2.31,"case_cnt":96}] }
```

### GET /metrics/dict?category=&keyword=&page=&size=
```json
{ "list":[{"code":"CMI","name":"病例组合指数","category":"operation","unit":"",
           "formula":"...","direction":1,"period":"month","owner":"医务处",
           "version":1,"enabled":true}],
  "page":1,"size":50,"total":25 }
```

### POST /metrics/query（**P3 预留·ChatBI DSL，本期 501 不实现**）
`{ "dsl": {...} }` —— 语义层查数预留端点，冻结规则同。

---

## 5. DRG/DIP /drg

### GET /drg/quadrant?period=d30&dept_id=
```json
{ "period":"d30",
  "axis":{"x":"DRG盈亏(万元)","y":"CMI"},
  "split":{"x":0,"y":1.0},
  "points":[
    {"dept_id":1,"name":"骨科","category":"surg",
     "cmi":1.62,"profit":8305000.00,"case_cnt":412,"quadrant":2} ],
  "quadrant_labels":{
    "1":{"text":"高CMI·低盈利","action":"结构优化"},
    "2":{"text":"高CMI·高盈利","action":"重点发展"},
    "3":{"text":"低CMI·低盈利","action":"需关注"},
    "4":{"text":"低CMI·高盈利","action":"提质增效"} } }
```
`profit` 单位**元**（展示层除 1e4 对应 X 轴"万元"刻度）。

### GET /drg/groups?dept_id=&quadrant=&period=d30&by=profit&order=desc&page=&size=
```json
{ "list":[{"drg_code":"IF15","name":"腰椎融合术","adrg":"IF1","rw":2.31,
            "case_cnt":96,"fee_avg":85230.00,"cost_avg":81000.00,"profit_avg":4230.00,
            "alos_avg":6.2,"material_ratio":0.41,"quadrant":2}],
  "page":1,"size":20,"total":38 }
```
`by` ∈ `profit`/`case_cnt`/`rw`/`fee_avg`/`alos_avg`。金额字段单位元；`material_ratio` 0~1。

---

## 6. 科室 /departments

### GET /departments/tree
```json
{ "list":[{"id":1,"code":"D001","name":"骨科","category":"surg","building_code":"wk",
            "children":[{"id":101,"code":"D001G1","name":"脊柱微创组"}]}] }
```

### GET /departments/ranking?period=d30&by=eff_score&order=desc&limit=&page=&size=
```json
{ "period":"d30",
  "list":[{"rank":1,"dept_id":1,"name":"骨科","category":"surg",
           "cmi":1.62,"surg_cnt":186,"alos":6.2,"profit":5120000.00,
           "eff_score":92.0,"eff_delta":1.3}],
  "page":1,"size":20,"total":20 }
```
`by` ∈ `eff_score`/`cmi`/`surg_cnt`/`alos`/`profit`。`limit`=topN 快捷（与分页互斥，大屏用 limit=10；排名页用分页）。`eff_delta`=较上一同长周期分差。

### GET /departments/{id}/cockpit（L2 科室驾驶舱）
```json
{ "dept":{"id":1,"name":"骨科","category":"surg","leader":{"id":201,"name":"刘明"}},
  "kpis":[ /* 同 /metrics/today list 项，dept_id 口径 */ ],
  "trend":{"dates":[...],"outpt":[...],"in_hosp":[...],"profit":[...]},
  "groups":[{"id":101,"name":"脊柱微创组","cmi":1.9,"profit":4120000.00,"case_cnt":88,"alos":5.9}],
  "drg_quadrant":{ /* 同 /drg/quadrant 结构，本科室 */ },
  "alerts":[ /* 本科室 open 告警，结构同 /alerts 项 */ ] }
```
错误：32001。

### GET /departments/{id}/groups（L3 医疗组）
```json
{ "list":[{"id":101,"name":"脊柱微创组","leader":{"id":201,"name":"刘明"},"staff_cnt":9,
           "cmi":1.9,"case_cnt":88,"profit":4120000.00,"alos":5.9}] }
```

---

## 7. 病例穿透 /cases（L4→L5，默认脱敏）

### GET /cases?dept_id=&group_id=&drg_code=&period=d30&flag=&page=&size=
```json
{ "list":[{"id":9001,"case_no":"ZY20260812001","patient":"王**","gender":"M","age":58,
           "dept_id":1,"dept":"骨科","group_id":101,"group":"脊柱微创组",
           "drg_code":"IF15","drg_name":"腰椎融合术",
           "admit_date":"2026-08-02","discharge_date":"2026-08-09","los_days":7,
           "total_fee":85230.00,"profit":4230.00,"flags":["l4"]}],
  "page":1,"size":20,"total":96 }
```
**viewer 角色响应中不返回 `case_no`**（准标识符收敛）。

### GET /cases/{id}
```json
{ "id":9001,"case_no":"ZY20260812001","patient":"王**","gender":"M","age":58,
  "dept_id":1,"dept":"骨科","group_id":101,"group":"脊柱微创组",
  "attending":{"id":201,"name":"刘*"},
  "drg_code":"IF15","drg_name":"腰椎融合术","rw":2.31,"quadrant":2,
  "admit_date":"2026-08-02","discharge_date":"2026-08-09","los_days":7,
  "fee":{"total":85230.00,"drug":12040.00,"material":34900.00,"exam":9800.00,
         "surg":18200.00,"other":10290.00,"insurance_pay":89500.00,
         "cost_total":81000.00,"profit":4230.00},
  "emr":{"chief_complaint":"腰腿痛3年加重1周",
         "diagnosis":["腰椎管狭窄症","L4/5椎间盘突出"],
         "operations":[{"name":"腰椎后路减压融合内固定术","level":4,"date":"2026-08-04"}],
         "key_orders":[{"item":"PEEK椎间融合器","qty":1,"price":23800,"type":"material","insurance":"部分"}],
         "pathway_note":"临床路径内，耗材超DRG同组均值45%"},
  "masked":true }
```
- `?unmask=1` 仅 `case:unmask` 权限（admin+president），返回实名 `patient`/`attending.name` 并记审计；无权限→32004。仿真期 patient_name 为空时 unmask 返回同 masked 值（审计仍记）。
- `emr` 可为 null（ETL 期未结构化）→ 前端空态。
错误：32003。

---

## 8. 告警与督办 /alerts /todos

### GET /alerts?status=open&level=&dept_id=&building=&page=&size=
`status` ∈ `open`/`pending`/`processing`/`done`/`closed`/`all`；`building` 按 building_code 过滤
```json
{ "list":[{"id":51,"rule_code":"OBS_OVER_6H","level":"urgent",
           "title":"急诊留观超时（>6h）","dept_id":null,
           "building":"急诊楼","building_code":"jz",
           "occurred_at":"2026-09-18T08:12:00+08:00","status":"pending",
           "payload":{"count":3,"detail":"抢救室滞留3人，最长9h20m","evidence_ids":[8801,8802,8803]},
           "drill":{"type":"route","path":"/alerts/51","label":"查看留观明细"},
           "can_dispatch":true}],
  "page":1,"size":20,"total":5 }
```
`drill`：`type=route`→前端 router.push(path)；`drawer`→本屏抽屉加载；`none`/未知→按钮不渲染。path 仅站内路由。

### GET /alerts/{id}
```json
{ "id":51, "...":"同列表字段",
  "related":{"stay_list":[{"id":8801,"patient":"李**","stay_minutes":560,"triage":2}]},
  "todo":{"id":7,"status":"doing","assignee":"急诊科-张远","deadline":"2026-09-19T08:00:00+08:00"}|null }
```
错误：33001。

### POST /alerts/{id}/ack —— 认领
```json
{} → {"id":51,"status":"processing","ack_at":"..."}
```
错误：33002（并发抢单，data.current_status 回传最新态）。

### POST /alerts/{id}/dispatch ★"督办"按钮
```json
{ "assignee_id":310, "deadline":"2026-09-19T08:00:00+08:00", "note":"限14日内提交整改报告" }
→ { "todo_id":7, "alert_id":51, "status":"processing" }
```
错误：33002/33102（指派人非法）/33103（deadline 非法）/20005（无 dispatch 权限）。

### POST /alerts/{id}/close
```json
{ "comment":"已分流，指标复常" } → {"id":51,"status":"closed"}
```

### GET /todos?status=&assignee_id=&page=&size=
```json
{ "list":[{"id":7,"alert_id":51,"title":"急诊留观超时整改","level":"urgent",
           "assignee":{"id":310,"name":"张远","dept":"急诊科"},
           "dispatcher":"王建国","deadline":"2026-09-19T08:00:00+08:00",
           "status":"doing","note":"限14日内提交整改报告","result_note":null,
           "created_at":"2026-09-18T08:20:00+08:00",
           "progress":{"metric":"EMERG_OBS_OVER6H","baseline":9.3,"current":4.1,"target":6.0}|null}],
  "page":1,"size":20,"total":3 }
```
`progress` 可空（非指标型告警）；三点锚点=派发快照+实时值。

### POST /todos/{id}/status
```json
{ "status":"done", "result_note":"已增设观察床位4张" }
→ { "id":7, "status":"done", "updated_at":"..." }
```
`status` 可写 `doing`/`done`。错误：33101/33104（已关闭）/20005（非指派人且非 admin）。

---

## 9. 院区楼宇 /campus

### GET /campus/buildings（中央院区浮标）
```json
{ "list":[
  {"code":"mz","name":"门诊楼","status":"normal","badge":"2310 人","badge_level":"info",
   "anchor":{"x":32,"y":58},"metrics":{"today_visit":2310,"queue_avg_min":18}},
  {"code":"wk","name":"外科楼","status":"busy","badge":"96% 负荷","badge_level":"warn",
   "anchor":{"x":50,"y":30},"metrics":{"bed_use_rate":0.96,"bed_used":192,"bed_open":200}},
  {"code":"jz","name":"急诊楼","status":"alert","badge":"留观超时","badge_level":"alert",
   "anchor":{"x":66,"y":42},"metrics":{"obs_over6h":3,"obs_cnt":11,"obs_max_min":560}},
  {"code":"yj","name":"医技楼","status":"normal","badge":"设备运行正常","badge_level":"ok",
   "anchor":{"x":60,"y":66},"metrics":{"device_run":12,"device_alert":0}} ] }
```
`anchor.x/y` = 容器宽高**百分比 0~100**。`metrics` 内 `*_rate` 为 0~1 原始率。非病区楼宇（停车场/行政楼）`metrics={}`，点击按装饰处理（前端约定见 frontend-architecture §5）。

### GET /campus/buildings/{code}（楼宇详情抽屉）
```json
{ "code":"wk","name":"外科楼",
  "wards":[{"code":"W08","name":"骨科一病区","dept_id":1,"bed_open":50,"bed_used":49,"borrow_in":2}],
  "today":{"surg_doing":6,"surg_done":30,"surg_wait":6},
  "devices":[{"code":"CT01","name":"CT-1","status":"run","queue":12}] }
```
`wards`/`today`/`devices` 按楼宇类型可为空数组。错误：34004。

---

## 10. 组织与人员 /staff（督办指派下拉）

### GET /staff?dept_id=&staff_type=&keyword=&page=&size=
```json
{ "list":[{"id":310,"name":"张远","dept":"急诊科","dept_id":9,"title":"主任医师","staff_type":"doc"}],
  "page":1,"size":50,"total":400 }
```

---

## 11. 运维与仿真控制（/sim 仅 ENV=dev|sim 注册；生产不注册→NoRoute 10003）

### GET /healthz（**包络外**，探活裸读）
```json
{ "status":"ok","db":"up","redis":"up","version":"1.0.0","virtual_now":"..." }
```

| 端点 | 说明 |
| :--- | :--- |
| GET /sim/clock | `{ "virtual_now":"...","speed":1,"paused":false }` |
| POST /sim/clock | `{ "virtual_now":"...","speed":60,"paused":false }` → 原子更新+清热缓存；bounds=[base_date, 播种末日+1]，越界 35002 |
| POST /sim/run-day | `{ "date":"2026-09-19" }` 幂等（当日 delete+insert 或全 PK upsert）；进行中→35003 |
| POST /sim/alert-test | `{ "rule_code":"OBS_OVER_6H" }` 注入演示告警（source=test，payload.stub=true 豁免标记） |
| POST /sim/reset | 演示重置：清事实+告警+工单+审计 → 重跑 seed → clock 回 base_date（幂等，进行中→35003） |

---

## 12. 权限矩阵（冻结）

perm 清单：`screen:view` `metric:view` `drill:view` `case:view` `case:unmask` `alert:view` `alert:dispatch` `todo:view` `sim:ops`

| 端点域 | 所需 perm | admin | president | ops_director | viewer |
| :--- | :--- | :-: | :-: | :-: | :-: |
| /screen/* /metrics/* /drg/* /departments/* /campus/* /hospital/profile | screen:view | ✓ | ✓ | ✓ | ✓ |
| /alerts GET（含{id}） | alert:view | ✓ | ✓ | ✓ | ✓ |
| /alerts ack/dispatch/close | alert:dispatch | ✓ | ✓ | ✓ | ✗→20005 |
| /todos GET | todo:view | ✓ | ✓ | ✓ | ✓ |
| /todos POST status | 工单指派人或admin | ✓ | ✓(仅本人为指派人时) | ✓(仅本人为指派人时) | ✗→20005 |
| /cases GET（不含case_no） | case:view | ✓ | ✓ | ✓ | ✓(无case_no) |
| /cases/{id} | case:view | ✓ | ✓ | ✓ | ✓(无case_no) |
| /cases/{id}?unmask=1 | case:unmask | ✓ | ✓ | ✗→32004 | ✗→32004 |
| /sim/* | sim:ops | ✓ | ✗ | ✗ | ✗ |
| /auth/profile /staff /departments/tree /metrics/dict | 登录即可 | ✓ | ✓ | ✓ | ✓ |

**实现注意**：Gin ≥1.7 支持静态段 `/departments/ranking` 与参数段 `/departments/:id` 同层注册（静态优先）；Vue Router 4 同理静态段优先匹配——前后端路由树均无需特殊排序，但须在 Gin ≥1.7 上运行。

---

## 13. 端点总表（实现核对清单）

| # | Method | Path | 面板/页面 | P |
| :- | :----- | :--- | :--------- | :- |
| 1 | POST | /auth/login | 登录 | P1 |
| 2 | POST | /auth/refresh | 静默续期 | P1 |
| 3 | POST | /auth/logout | 登出 | P1 |
| 4 | GET | /auth/profile | 会话恢复 | P1 |
| 5 | POST | /auth/password | 改密(预留) | P2 |
| 6 | GET | /hospital/profile | Header | P1 |
| 7 | GET | /screen/snapshot | 大屏首屏 | P1 |
| 8 | GET | /screen/status | 胶囊刷新 | P1 |
| 9 | GET | /metrics/today | KPI卡/科室kpis | P1 |
| 10 | GET | /metrics/trend | 底部趋势/详情图 | P1 |
| 11 | GET | /metrics/detail | 指标详情页 | P2 |
| 12 | GET | /metrics/dict | 指标字典页 | P2 |
| 13 | POST | /metrics/query | ChatBI(预留) | P3 |
| 14 | GET | /drg/quadrant | 四象限 | P1 |
| 15 | GET | /drg/groups | 病组列表L4 | P1 |
| 16 | GET | /departments/tree | 下钻/筛选 | P1 |
| 17 | GET | /departments/ranking | 排名topN/排名页 | P1 |
| 18 | GET | /departments/{id}/cockpit | 科室页L2 | P1 |
| 19 | GET | /departments/{id}/groups | 医疗组L3 | P1 |
| 20 | GET | /cases | 病例列表L4 | P1 |
| 21 | GET | /cases/{id} | 病案L5 | P1 |
| 22 | GET | /alerts | 预警面板/列表页 | P1 |
| 23 | GET | /alerts/{id} | 告警详情 | P1 |
| 24 | POST | /alerts/{id}/ack | 认领 | P1 |
| 25 | POST | /alerts/{id}/dispatch | 督办按钮 | P1 |
| 26 | POST | /alerts/{id}/close | 关闭 | P1 |
| 27 | GET | /todos | 督办追踪页 | P2 |
| 28 | POST | /todos/{id}/status | 工单反馈 | P2 |
| 29 | GET | /campus/buildings | 院区浮标 | P1 |
| 30 | GET | /campus/buildings/{code} | 楼宇抽屉 | P1 |
| 31 | GET | /staff | 指派下拉 | P1 |
| 32-35 | GET/POST | /sim/* | 仿真控制(dev) | P1 |
| 36 | GET | /healthz | 探活 | P1 |

**SSE（P2 预留）**：`GET /stream` → `event: alert`/`kpi`；本期一律轮询（snapshot 30s、alerts/status 15s）。
