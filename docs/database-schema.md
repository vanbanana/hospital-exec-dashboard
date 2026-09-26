# 数据库设计 — EDSS 运营决策大屏

> PostgreSQL 16 单实例，6 个 schema：`sys`（系统）/ `dim`（维度）/ `dwd`（明细事实）/ `dws`（日汇总）/ `ads`（应用集市）/ `sim`（仿真控制）。
> 迁移文件 `backend/migrations/*.sql` 为唯一事实来源；本文件为冻结的结构契约，改表必须走 migration + 同步本文档。
>
> **全局约定（修订 v1.1）**
> - 主键：`id bigint generated always as identity`（复合主键表单独注明）
> - 时间：时刻一律 `timestamptz`；日期一律 `date`
> - 金额：一律 `numeric(14,2)` 单位**元**，无例外（字典 unit=万元 的指标值存万元数值，见 §9）
> - 率值：列名含 `_rate`/`_ratio` 一律存 **0~1 小数**；API 指标值按字典 unit 给展示值（unit='%' → 90.8）
> - 可空外键/混合类型目标键统一 `varchar(64)`
> - 枚举值同时落 `sys.dict` 与 CHECK，应用层再校验一道

---

## 1. 分层定位与读写纪律

```
仿真器(Fact Producer)      未来真实ETL             派生流水线(双模式常驻)      API 只读
        │                      │                        │                    │
        ▼                      ▼                        ▼                    ▼
┌──────────┐ 逐例/逐时事实 ┌──────────┐   ┌──────────────────┐   ┌────────────────┐
│   DWD    │ ◄─────────── │ HIS/EMR  │   │ DayAgg → DWS/ADS  │   │  GET /api/v1    │
│ (明细层) │              │ /HRP CDC │   │ TodayKpi→ads.today│ ◄─┤  (默认读 dws/   │
└────┬─────┘              └──────────┘   │ AlertScan→alert   │   │   ads)          │
     │ 聚合SQL(两模式共用) ──────────────►│ _kpi/campus_status│   └────────────────┘
     ▼                                   └──────────────────┘
┌──────────┐
│   DWS    │ 院级/科室级/病组级 日·周期汇总
└──────────┘
```

**读纪律**：API 默认只读 `dws/ads/sys`。**白名单例外**：① realtime 今日指标（dwd 当日行累计）；② Level-5 病例穿透（dwd.drg_case）；③ 告警事实回溯（dwd.emergency_stay 等）。除此之外禁止 API 查 dwd。

**写纪律**：
- 仿真器只写 `dwd` 事实与 `sim` 控制表——**禁止直接写 dws/ads 数字**（剧本钩子也只能注入 dwd 事实行）。
- 派生流水线（DayAgg/TodayKpi/AlertScan，见 architecture.md）独占 `dws/ads` 写入，**模拟/真实两种模式都运行**——这是"切真实 ETL 后大屏不死"的关键。

---

## 2. sys — 系统域

### sys.user
| 列 | 类型 | 说明 |
| :--- | :--- | :--- |
| id | bigint PK | |
| username | varchar(32) UQ | 登录名 |
| password_hash | varchar(128) | bcrypt |
| real_name | varchar(32) | |
| emp_no | varchar(20) | 工号（水印用；种子=username） |
| role | varchar(20) | `admin`/`president`/`ops_director`/`viewer`，CHECK |
| dept_id | bigint FK→dim.department NULL | 院级账号为空 |
| status | smallint | 1 启用 0 停用 |
| last_login_at | timestamptz | |
| created_at / updated_at | timestamptz | |

种子：`admin/Admin@123`、`president/President@123`、`ops/Ops@123`、`viewer/Viewer@123`（仅本地演示，README 标注）。

### sys.audit_log
| id | user_id | username | action varchar(40) | target_type varchar(32) | target_id varchar(64) | detail jsonb | ip inet | created_at |
索引 `(created_at)`。写操作全量记录：登录、督办派发、告警 ack/close、规则启停、脱敏访问、sim 时钟操作。

### sys.dict
| dict_type varchar(40) | dict_key varchar(40) | dict_label varchar(64) | sort int | extra jsonb |
PK(dict_type, dict_key)。枚举注册：`dept_category`/`alert_level`/`alert_status`/`todo_status`/`surgery_level`/`triage_level`/`building_func`/`ward_type`/`fee_cat`/`drill_type`/`badge_level`/`metric_category`。
`dict_type='hospital'` 承载机构信息（name/motto/slogan/level）——`/hospital/profile` 的数据源。

### sys.metric_def —— ★指标字典（"一数一源"核心）
| 列 | 类型 | 说明 |
| code | varchar(40) PK | 如 `OP_DAILY_VISITS` |
| name | varchar(64) | 今日门急诊人次 |
| unit | varchar(16) | 人 / % / 万元 / 天 / 分 |
| category | varchar(20) | `operation`/`quality`/`finance`/`insurance`/`hr` |
| formula | text | 口径说明（人读，含分子分母定义） |
| source_table | varchar(64) | 计算来源表 |
| direction | smallint | 1 越高越好 -1 越低越好 0 中性（涨跌红绿依据） |
| warn_low / warn_high | numeric NULL | 红绿灯阈值（按展示量纲：%=90 而非 0.9） |
| drill_route | jsonb NULL | `{"type":"route","path":"/metric/OP_DAILY_VISITS","label":"指标详情"}`，type 与契约 DrillCmd 一致 |
| owner | varchar(64) | 业务归口科室（白皮书"唯一归口"要求） |
| version | int NOT NULL DEFAULT 1 | 口径版本，公式变更 +1 不覆盖 |
| period | varchar(8) | `day`/`month`/`realtime`/`hour` |
| sort / enabled | | |

---

## 3. dim — 维度域（主数据 MDM）

### dim.campus（院区，多院区预留）
| code varchar(20) PK | name | sort | 种子 `main` 本部、`east` 东院区（预留） |

### dim.building
| code varchar(20) PK | name | func_type varchar(16)（`outpt`/`inpt`/`emerg`/`tech`/`adm`/`other`） | campus_code FK | map_anchor jsonb `{x,y}` 容器百分比 0~100 |
种子：门诊楼/外科楼/急诊楼/医技楼/住院部/停车场/行政楼。

### dim.department ★
| id | code varchar(20) UQ | name | category | parent_id NULL | level smallint 1~3 | campus_code FK | building_code FK NULL | leader_id FK→dim.staff NULL | eff_base numeric(4,3) | sort | active |
- `category`：`med`内科 / `surg`外科 / `tech`医技 / `nurse`医辅 / `adm`行政（大屏图例映射：med→内科、surg→外科、tech→医技、nurse+adm→其他）
- `level`：1 院区 2 科室 3 医疗组——树形支撑 L2→L3 下钻
- `building_code`：科室→楼宇映射（门诊楼 today_visit、ETL 期必需）
- `leader_id`：医疗组组长（`/departments/{id}/groups` 的 leader 字段）
- `eff_base`：仿真效率基线 0~1，真实环境 NULL
- 种子：~16 临床科室 + 4 医技 + 每临床科 2~3 医疗组

### dim.staff
| id | code UQ | name | dept_id FK | title | staff_type(`doc`/`nur`/`tec`/`adm`) | active |
索引 `(dept_id)`。种子 ~400 人。

### dim.drg_group ★
| code varchar(16) PK | name | adrg_code | mdc | rw numeric(8,4)（权重） | base_rate numeric(14,2)（基准费率·元） | pay_type `DRG`/`DIP` |
种子 ~60 组，含 IF15 腰椎融合术等白皮书示例。

### dim.ward（病区）
| code varchar(20) PK | name | dept_id FK | building_code FK | ward_type varchar(16)（`general`/`icu`/`obs`/`or` 手术室虚拟病区） | bed_open int |
- `ward_type='icu'` 是 ICU_USE_RATE 指标与 ICU 告警规则的识别依据（**必填**）
- `or`：手术室虚拟病区行使楼宇抽屉 `today.surg_*` 有 join 落点

### dim.device（P2 预留，MVP 种子 4 台）
| code PK | name | dtype(`CT`/`MRI`/`DSA`/`ROBOT`) | dept_id | building_code | value_yuan numeric(14,2) | active |

### dim.date（2024-01-01~2027-12-31 预生成）
| date PK | year | month | day | week | weekday | is_weekend | is_holiday | holiday_name |

### dim.drug / dim.material：P2 再建（届时 migration 追加，本版不落表）

---

## 4. dwd — 明细事实层（仿真器/未来ETL 独占写入）

### dwd.outpatient_hourly（门急诊分时事实）
| stat_time timestamptz（**≤30min 粒度**） | dept_id | visit_cnt | reg_cnt | cancel_cnt int DEFAULT 0 | appt_cnt int DEFAULT 0 | emerg_flag bool | fee_total numeric(14,2) |
PK(stat_time, dept_id, emerg_flag)。`cancel_cnt`/`appt_cnt` 是 P2 退号率/预约率的落点列（先建先填0）。
索引 `(stat_time)`。

### dwd.inpatient_move（出入院事件）
| id | patient_masked varchar(32)（生成即脱敏 `P100234`） | dept_id | ward_code | event `admit`/`discharge`/`transfer` | event_time | los_days int NULL（出院时填） |
索引 `(event_time)`、`(dept_id,event_time)`、`(patient_masked,event_time)`。

### dwd.surgery_case（手术台次）
| id | case_no UQ | patient_masked | dept_id | ward_code（or 虚拟病区） | surg_level smallint CHECK 1~4 | status `sched`/`doing`/`done`/`pacu` | plan_start | actual_start NULL | actual_end NULL | room_no | date（=COALESCE(actual_start,plan_start)::date，一致性由生成器保证） |
索引 `(date)`、`(date,status)`、`(dept_id,date)`。

### dwd.bed_state_day（床位日态）
| date | ward_code | dept_id | bed_open | bed_used | borrow_in int DEFAULT 0 | borrow_out int DEFAULT 0 |
PK(date, ward_code)。
**借床口径（冻结）**：借入侧 `bed_used ≤ bed_open + borrow_in`；借出侧 `bed_used ≤ bed_open − borrow_out`；全院日粒度 `Σborrow_in = Σborrow_out`（跨行校验放 sim validate，不写跨表 CHECK）。
CHECK：`bed_used>=0 AND bed_used<=bed_open+borrow_in AND borrow_in>=0 AND borrow_out>=0`。
索引 `(ward_code,date)`。

### dwd.emergency_stay（急诊留观逐例）★
| id | patient_masked | arrive_at | leave_at NULL | stay_minutes int（**仅归档值**：observing 行不更新，实时时长=now−arrive_at） | status `observing`/`admitted`/`left` | triage_level smallint 1~4 | dept_id |
索引 `(status,arrive_at)`——60s 告警扫描热路径。
注：白皮书口径"留观>24h 预警"，本系统采用 **>6h**（晨会演示密度需要），为有意偏离，阈值在 alert_rule 可配。

### dwd.charge_day（费用日汇总）
| date | dept_id | fee_cat | out_fee numeric(14,2) | in_fee numeric(14,2) | insurance_fee numeric(14,2) NULL | self_fee numeric(14,2) NULL |
`fee_cat`：`drug`/`material`/`exam`/`treat`/`surg`/`bed`/`other`。PK(date,dept_id,fee_cat)。
insurance/self 两列含门诊口径，支撑 SELF_PAY_RATIO/INS_SETTLE。

### dwd.drg_case（病案首页/DRG结算病例）★L5 穿透终点
| 列 | 说明 |
| id PK / case_no UQ | |
| patient_masked | 脱敏姓名 `王**` |
| patient_name | **实名**（仿真期=NULL 或同 masked；真实期 ETL 写入，`?unmask=1` 的唯一数据源，service 层控制输出） |
| gender / age | |
| dept_id / group_id→dim.department | 科室/医疗组 |
| attending_id→dim.staff | 主治医生（doctor 字段来源） |
| drg_code FK | |
| admit_date date / discharge_date date | 纯日期 |
| los_days int | |
| total_fee / drug_fee / material_fee / exam_fee / surg_fee / other_fee | 费用分项（合计=total_fee） |
| insurance_pay / cost_total / profit（=insurance_pay−cost_total） | 结算与盈亏 |
| rw numeric(8,4) / surg_level smallint NULL / surg_date date NULL | ★surg_level=四级手术过滤列（flag=l4），preop_alos=surg_date−admit_date |
| death_flag / readmit15_flag / spec_flag bool | 死亡/15日再入院/特例单议候选 |
| emr_json jsonb NULL | 脱敏结构化病案（主诉/诊断/手术/关键医嘱），**仅 L5 展示载荷，不承担过滤**；ETL 期可 NULL→前端空态 |
索引 `(dept_id,discharge_date)`、`(drg_code)`、`(group_id,discharge_date)`、`(dept_id,surg_level)`、`(dept_id,discharge_date) WHERE profit<0`。

### dwd.critical_value（危急值，P2）
| id | patient_masked | item | result_value varchar(64) | report_at | notice_at | close_at | status `open`/`closed` | dept_id |

### dwd.device_run_day（P2）
| date | device_code | run_hours | exam_cnt | positive_cnt | income | opex_total numeric(14,2)（折旧+维保+能耗+人力分摊） |
PK(date, device_code)。`opex_total` 为 ROI/保本点口径落点。

### dwd.hr_cost_month（P2 预留·人员支出占比指标落点）
| month char(7) | dept_id | staff_cost numeric(14,2) |

---

## 5. dws — 汇总层（派生流水线独占写入，两模式共用同一套聚合 SQL）

### dws.hospital_oper_day ★（院级运营日表）
| date | campus_code | outpt_cnt（门诊，**不含急诊**） | emerg_cnt（急诊） | reg_cnt | in_hosp_cnt | admit_cnt | discharge_cnt | surg_cnt | surg_l4_cnt | bed_open | bed_used | bed_use_rate(0~1) | alos | preop_alos | longstay_cnt | revenue | cost | profit（全院收支结余） | **drg_profit**（=Σdrg_case.profit，象限对账口径） | drug_fee | drug_ratio(0~1) | material_fee | material_per_100rev | insurance_settle | self_pay_ratio(0~1) | cmi | emerg_obs_over6h | critical_unclosed | satisfaction | updated_at |
PK(date, campus_code)。
口径钉死：`OP_DAILY_VISITS = outpt_cnt + emerg_cnt`；校验 #3 对账用 `drg_profit` 而非 `profit`。

### dws.dept_oper_day ★（科室·医疗组运营日表）
| date | dept_id | outpt_cnt | in_hosp_cnt | surg_cnt | surg_l4_cnt | alos | bed_use_rate | revenue | cost | profit | drg_profit | case_cnt int | cmi | material_per_100rev | eff_score numeric(5,2) |
PK(date, dept_id)。
**本表同时承载 level=2 科室行与 level=3 医疗组行**（dept_id 即 dim.department.id，组级行 group 指标同构）——`/departments/{id}/groups` 的 cmi/profit/case_cnt/alos 由此出。
注：daily cmi 仅供趋势参考（小科室日出院少噪声大），排名一律用 d30 快照。

### dws.drg_dept_period（病组×科室×周期盈亏，四象限源）
| period_type `month`/`d30` | period varchar(10)（month=`2026-09`；d30=`YYYY-MM-DD` 截止日） | dept_id | drg_code | case_cnt | rw_avg | cmi_equiv | total_profit | profit_avg | fee_avg | cost_avg | insure_avg | los_avg | material_ratio | quadrant smallint CHECK 1~4 |
PK(period_type, period, dept_id, drg_code)。

### dws.metric_value ★（通用指标长表）
| metric_code FK→sys.metric_def | date | **dept_id NOT NULL DEFAULT 0** | **group_id NOT NULL DEFAULT 0** | value numeric(18,4) | extra jsonb |
PK(metric_code, dept_id, group_id, date)。**哨兵约定：0=院级/无医疗组**（可空列进 PK 在 PG 不成立，故用 0 而非 NULL）。
值按 metric_def.unit 量纲存储（unit='万元'→存万元数值；unit='%'→存 90.8）。
索引 `(metric_code,dept_id,date)`。

---

## 6. ads — 应用集市（API 直读，派生流水线写入）

### ads.alert_rule（告警规则）
| code PK | name | level `urgent`/`major`/`minor` | metric_code NULL | op `>`/`<`/`>=`/`<=` | threshold | scope `hospital`/`dept`/`building` | dedup_min | drill_route jsonb | source `rule`/`scenario` | enabled |
- `source='scenario'`：无事实表可扫的剧本型规则（药品库存低/设备待维护——P2 表未建），由场景注入器直接产 alert_event，规则扫描器跳过。
- **去重语义（冻结）**：去重键=`(rule_code,target_type,target_id)`；同键存在 open 态（pending/processing）事件时**不新建、仅刷新 payload**；`dedup_min` 仅在事件关闭后抑制再触发。
- 种子规则：OBS_OVER_6H(urgent,rule)、BED_OVER_95(major,rule)、SURG_TURN_OVER(major,rule)、ICU_USE_90(urgent,rule)、CRIT_UNCLOSED_30M(major,rule→P2 enabled=0)、DRUG_STOCK_LOW(minor,scenario)、DEVICE_MAINTAIN(minor,scenario)。

### ads.alert_event ★
| id | rule_code | level | title | dept_id NULL | building_code varchar(20) NULL | target_type varchar(32) | target_id varchar(64) | payload jsonb | drill_route jsonb | status `pending`/`processing`/`done`/`closed` | source `rule`/`scenario`/`test` | occurred_at | ack_at NULL | done_at NULL | closed_at NULL | close_note text NULL |
- `payload` 约定：`{"value":触发值, "evidence_ids":[事实行id], "stay_list":[快照]…}`——支撑 /alerts/{id}.related 与校验 #5 回溯；非事实来源事件（scenario/test 注入）统一带 `payload.stub=true` 作为校验豁免标记（`source` 字段区分来源）。
- 约束：open 态去重唯一索引 `UNIQUE(rule_code,target_type,target_id) WHERE status IN ('pending','processing')`。
- 索引 `(status,occurred_at desc)`、`(dept_id,status)`、`(building_code,status)`、`(rule_code,target_type,target_id,occurred_at)`。

### ads.todo_order（督办工单 PDCA）
| id | alert_id FK | title | assignee_id→staff | dispatcher_id→user | deadline | note text NULL（派发备注） | status `open`/`doing`/`done`/`expired` | result_note NULL | baseline_value numeric(18,4) NULL（派发时触发值快照） | target_value numeric(18,4) NULL（派发时阈值快照，防规则漂移） | metric_code NULL（复原指标） | escalated bool | created_at/updated_at |
- 状态机：`open→doing→done`；`expired` 由系统置位（deadline 过仍未 done）。
- `progress{metric,baseline,current,target}` = metric_code + baseline_value + 实时值 + target_value 组装。
- 索引 `(alert_id)`、`(assignee_id,status)`。

### ads.dept_rank_day（排名快照）
| date | period varchar(8) `d30` | dept_id | cmi | surg_cnt | alos | profit numeric(14,2) | eff_score | eff_delta numeric(5,2)（较前一周期分差） | rank_no |
UQ(date, period, dept_id)。

### ads.today_kpi（今日实时快照，Intraday 写）
| metric_code | **dept_id NOT NULL DEFAULT 0**（0=院级；科室驾驶舱 kpis 落点） | value | yesterday_same_time（昨日同时刻累计，prev_value 来源） | spark jsonb | updated_at |
PK(metric_code, dept_id)。

### ads.campus_status（楼宇浮标状态）
| building_code PK | status `normal`/`busy`/`alert` | badge_text | badge_level `info`/`ok`/`warn`/`alert` | metrics jsonb | updated_at |
- `badge_level` 仅驱动徽标颜色（info青/ok绿/warn黄/alert红），`status` 驱动楼态图标——两套语义各司其职。
- **`status` 推导规则（冻结）**：`alert`=该楼有 open 态 urgent 告警或核心指标越红线（急诊楼 obs_over6h>0、外科楼 bed_use_rate>0.95）；`busy`=有 major 告警或指标越黄线（bed_use_rate>0.85、queue_avg_min>30）；其余 `normal`。`badge_level` 由 TodayKpi 按同规则写（info=常规展示、ok=正向确认、warn=黄线、alert=红线）。
- `metrics` jsonb 各楼宇键集（冻结）：门诊楼 `{today_visit,queue_avg_min}`；外科楼 `{bed_use_rate,bed_used,bed_open}`；急诊楼 `{obs_cnt,obs_over6h,obs_max_min}`；医技楼 `{device_run,device_alert}`；住院部 `{bed_use_rate,bed_used,bed_open,in_hosp}`；非病区楼 `{}`。
- 楼宇抽屉数据（wards/today/devices）**由 API 现场聚合 dwd 当日行**（属 §1 白名单"今日 realtime 事实"例外），不冗余进 metrics。

---

## 7. sim — 仿真控制域（API 不暴露，仅 simulator/演示接口内部使用）

### sim.clock
| id=1 CHECK(id=1) | virtual_now timestamptz | speed numeric（1=实时） | paused bool | base_date date | updated_at |
所有"今日"语义=virtual_now。**更新必须用原子表达式** `virtual_now = virtual_now + ?*speed`；tick 与 POST /sim/clock 互斥（行锁）。

### sim.job_log
| id | job | virtual_date | started/finished | rows | status | err |

### sim.profile（仿真参数）
| key PK | val jsonb | 如 `outpt_daily_base`/`weekday_factor`/`dept_share`/`scenarios`（剧本钩子定义）。启动时校验关键 key 存在与 json 合法，缺 key 直接 panic 好于静默错。

---

## 8. 数据量与索引策略

| 表 | 演示量级 | 关键索引 |
| :--- | :--- | :--- |
| dwd.outpatient_hourly | 180d×48×20科≈173k | (stat_time) |
| dwd.drg_case | ~5.4k | (dept_id,discharge_date)/(drg_code)/(group_id,discharge_date)/(dept_id,surg_level) |
| dws.hospital_oper_day | 180 行 | PK(date,campus_code) |
| dws.dept_oper_day | 180×~80(科室+组)≈14k | PK(date,dept_id) |
| dws.drg_dept_period | 2期×20科×60组≈2.4k+ | PK |
| dws.metric_value | ~30指标×180d×(1+20)≈113k | PK+(metric_code,dept_id,date) |
| ads.alert_event | ~500 | 见 §6 |
分区：演示规模不启用；DWD 月分区与 TimescaleDB 同为未来真实化预案。ETL 期新增 `ods` schema（预留说明，不对齐白皮书五层字面但语义等价）。

---

## 9. 首批指标字典（sys.metric_def 种子）

| code | name | unit | dir | source | 大屏落点 |
| :--- | :--- | :--- | :--- | :--- | :--- |
| OP_DAILY_VISITS | 今日门急诊人次 | 人 | 0 | dwd.outpatient_hourly 累计（out+emerg） | KPI1+趋势 |
| IP_IN_HOSP | 在院患者数 | 人 | 0 | dwd.bed_state_day Σbed_used | KPI2+趋势 |
| BED_USE_RATE | 床位使用率 | % | 0(>95红) | dws | KPI3+趋势 |
| SURG_DAILY_CNT | 今日手术台次 | 台 | 1 | dwd.surgery_case | KPI4+趋势 |
| SURG_L4_RATIO | 四级手术占比 | % | 1 | 同上 | 详情 |
| ALOS | 平均住院日 | 天 | -1 | dws.dept_oper_day | 排名列 |
| CMI | 病例组合指数 | - | 1 | dws.drg_dept_period | 排名/象限Y |
| DRG_PROFIT | DRG结余 | 万元 | 1 | 同上 | 象限X |
| REVENUE_DAILY | 医疗收入 | 万元 | 1 | dws.hospital | 详情 |
| COST_RATIO_MATERIAL | 百元收入耗材费 | 元 | -1 | charge_day | 穿透示例 |
| DRUG_RATIO | 药占比 | % | -1 | charge_day | 详情 |
| EMERG_OBS_OVER6H | 留观超6h人数 | 人 | -1 | dwd.emergency_stay | 告警 |
| ICU_USE_RATE | ICU占床率 | % | -1(>90红) | bed_state_day+ward_type | 告警 |
| DEPT_EFF_SCORE | 科室运行效率分 | 分 | 1 | §10 公式 | 排名列 |
| SELF_PAY_RATIO | 自费比例 | % | -1 | charge_day.insurance/self | 详情 |
| INS_SETTLE | 医保结算额 | 万元 | 0 | dws.hospital | 详情 |
| ADMIT_CNT / DISCH_CNT | 入/出院人数 | 人 | 0 | inpatient_move | 详情 |
| PREOP_ALOS | 术前住院日 | 天 | -1 | surg_date−admit_date | 详情 |
| LONGSTAY_CNT | >30天超长住院 | 人 | -1 | dwd | 告警候选 |
| CRIT_UNCLOSED | 未闭环危急值 | 条 | -1 | critical_value(P2) | 告警候选 |
| REG_CANCEL_RATE | 退号率 | % | -1 | cancel_cnt(P2) | P2 |
| APPT_RATE | 预约就诊率 | % | 1 | appt_cnt(P2) | P2 |
| EQUIP_RUN_RATE | 设备开机率 | % | 1 | device_run_day(P2) | P2 |
| SATISFACTION | 满意度 | 分 | 1 | 仿真常量带噪(P2) | P2 |
| STAFF_COST_RATIO | 人员支出占比 | % | -1 | hr_cost_month(P2) | P2 |

## 10. eff_score 口径（冻结版，version=1）

```
eff_score = 100 * ( 0.30*norm(cmi) + 0.25*norm(surg_cnt) + 0.20*(1-norm(alos)) + 0.15*bed_use_rate + 0.10*norm(profit) )
```
`norm()`=全科 min-max 归一；排名取 `ads.dept_rank_day.eff_score`。公式变更 → metric_def.version+1，不改接口。

## 11. MVP 外模块对账（白皮书 14 模块 → 落点）

| 白皮书模块 | 本期状态 |
| 4.1 全景驾驶舱 / 4.5 DRG盈亏 / 4.3 床位 | ✅ MVP 全量 |
| 4.4 质控（危急值/核心制度/死亡率） | ⚠️ 表已建(critical_value/死亡标记)，告警规则 P2 启用 |
| 4.2 门急诊效能（退号/预约/分时峰谷） | ⚠️ 列已落(cancel/appt)，指标 P2 |
| 4.6 全成本四级核算 / 4.10 人员支出 | ⚠️ hr_cost_month 预留列，明细成本表 P2 |
| 4.7 药事（基药/DDDs/创新药剔除） | ❌ P2 建 dim.drug + 规则 |
| 4.8 耗材 SPD/UDI | ❌ P2 建 dim.material + 追溯表 |
| 4.9 设备 ROI | ⚠️ device_run_day 已含 opex_total，P2 启用 |
| 4.11 科研教学 / 4.12 满意度NLP / 4.13 医共体 / 4.14 多院区 | ❌ P3（campus/院区字段已预留） |
| 特例单议 | ✅ spec_flag 已建，申报工具 P2 |
| ChatBI/What-If/月报 | ❌ P3 |

## 12. 自洽性校验（sim validate，播种后必跑）

1. Σbed_state_day.bed_used = dws.in_hosp_cnt（±0）；Σborrow_in=Σborrow_out；**逐行**借出侧 `bed_used ≤ bed_open − borrow_out`
2. KPI 屏值 = outpatient_hourly 当日累计（±1，30min 粒度内）
3. 四象限 profit 合计 ≈ dws.drg_profit 同期（±2%）
4. ranking cmi/alos/surg 与 dws.dept_oper_day d30 均值一致（±5%）
5. 每条 `source='rule'` alert_event 可回溯 payload.evidence_ids 事实行（`payload.stub=true` 的 scenario/test 注入事件豁免）
6. trend 末日值 = today_kpi.yesterday_same_time 同日值（趋势含今日时以 today_kpi.value 为准）
7. Σ(drg_case.total_fee) ≤ Σ(charge_day.in_fee)（DRG 病例是住院费用子集）
8. drg_case 费用分项合计 = total_fee（±0.01）
