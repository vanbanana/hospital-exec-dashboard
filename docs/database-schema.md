# 数据库设计 — EDSS（v2.0 终装配版）

> **版本**：v2.0　**日期**：2026-10-28　**取代**：v1.1（全文重写）
> **状态**：设计与种子已装配至 `backend/migrations/` + `backend/seed/`（文件名序即执行序，见 `backend/README.md`）；经三轮独立审核收敛至 0 BLOCKER/0 MAJOR，干净库（PG15）全链 apply 与幂等重跑实证通过。
> **适用范围**：PostgreSQL 16（语法兼容验证至 PG15.15）；服务 `/workbench` 工作台与 `/screen` 大屏两套形态。

---

## 1. 六 schema 分层总览

```
写入方                     层          职责                          读取方
─────────────────────────────────────────────────────────────────────────
仿真器/未来ETL     ──►   dwd  明细事实（逐例/逐时/逐日事件行）
派生流水线(常驻)   ──►   dws  日/周期汇总（院级、科室级、病组级）
派生流水线(常驻)   ──►   ads  应用集市（页面直读快照/榜单/告警）
L1 系统域          ──►   sys  账号/字典/指标定义/通知/审计/数据源/偏好
L2 公共维度        ──►   dim  主维表（日期/院区/楼宇/科室/人员/病组/病区/设备…）
仿真控制           ──►   sim  虚拟时钟/作业日志/参数（生产可按 env 跳过）
```

**读写纪律**（与 architecture.md 派生流水线一致）：

- **API 默认只读 `dws/ads/sys`**；白名单例外：realtime 今日指标（dwd 当日累计）、Level-5 病例穿透（dwd.drg_case）、告警事实回溯。
- **仿真器只写 `dwd`+`sim`**，禁直写 dws/ads；dws/ads 由派生流水线独占写入——这是"切真实 ETL 后大屏不死"的关键。
- **依赖方向不可逆**：`sys → dim → dwd → dws → ads`（sim 旁挂末位）。种子相位装配见 §5。

## 2. 表总目录（57 表 × lane × 粒度 × 种子规模）

> 行数列为 lane 种子实测/规格值（BASE_DATE=2026-10-28，窗口 2025-01-01~2026-12-31）；"—"=空表/缓建。

### sys（7 表 · L1 sys-org）

| 表 | 粒度 | 种子行数 | 服务面 |
| :-- | :-- | :-- | :-- |
| sys.dict | dict_type×key | 310（69 类） | 全枚举值域 |
| sys.metric_def | 一指标一行 | 141（L1 91+L8hr 18+L8pat 32） | metric_code FK 正本、api_key/unit/direction |
| sys.user | 一账号一行 | 7（dept_id 回填 3） | 登录/角色/水印 |
| sys.notice | 一通知一行 | 5 | 工作台消息 |
| sys.data_source | 一来源一行 | 6 | ETL 登记 |
| sys.user_pref | 用户×键 | 5 | 个性化 |
| sys.audit_log | 事件行 | 0（框架） | 审计 |

### dim（12 表 · L2 dim-public + L8 补 2）

| 表 | 粒度 | 种子行数 | 锚点 |
| :-- | :-- | :-- | :-- |
| dim.date | 日 | 1,461（2024~2027） | 全域驱动表 |
| dim.campus | 院区 | 2 | main+east |
| dim.building | 楼 | 7 | 大屏浮标 map_anchor |
| dim.department | 科室/组 | 81 | id=0 院级哨兵+行政 12+科室 32+医疗组 36 |
| dim.dept_alias | 别名 | 18 | 契约/视图/archive 映射 |
| dim.staff | 员工 | 2,368 | 医 812/护 1,046/技 202/行政 308 |
| dim.drg_group | 病组 | 60 | RW 0.38~12.86，low20/mid21/midhigh10/high9 |
| dim.ward | 病区 | 31 | **Σbed_open=2,004** ↔ 在院 1,846÷92.1% |
| dim.device | 设备 | 68 | id PK+code UQ（实体组），全 active |
| dim.drug | 药品 | 0 | P1 缓建 DDL only |
| dim.material | 物资（L8e） | 24 | 库存预警明细键 |
| dim.discipline | 重点学科（L8b） | 4（3+哨兵） | leader_id 回填自 staff |

### dwd（18 表 · L3/L4/L8）

| 表 | lane | 粒度 | 种子行数/规模 |
| :-- | :-- | :-- | :-- |
| dwd.outpatient_hourly | L3 | 30min×科室×门/急诊 | ~40 万 |
| dwd.reg_channel_day | L3 | 日×渠道 | 窗口×5 |
| dwd.inpatient_move | L3 | 入/出/转事件行 | 年出院量级 ×~2.4 事件 |
| dwd.bed_state_day | L3 | 日×病区快照 | 31×730≈2.3 万 |
| dwd.emergency_stay | L3 | 留观事件行 | 月 ~30+ |
| dwd.charge_day | L3 | 日×科室×fee_cat(7) | 费用**唯一真源** |
| dwd.insurance_settle_day | L3 | 日×科室×险种×业务 | 5 险种×2 biz |
| dwd.surgery_case | L4 | 一台手术一行 | **24,266** |
| dwd.drg_case | L4 | 一例出院一行 | **103,934**（14 月窗，R3 裁决） |
| dwd.critical_value | L8d | 一危急值一行 | 24 月规格（锚月 109/110） |
| dwd.infection_case | L8d | 一院感例一行 | 率驱动（锚月 ≈101） |
| dwd.adverse_event | L8d | 一不良事件一行 | 锚月 36/百床 1.95 |
| dwd.feedback_event | L8c | 一投诉/表扬一行 | 锚月 24/86+样例 |
| dwd.hr_cost_month | L8a | 月×科室 | 24×44≈1,056 |
| dwd.research_project | L8b | 一课题一行 | 在研 186/新立 42 等 |
| dwd.device_run_day | L8e | 日×设备 | 68×730≈5.0 万 |
| dwd.material_stock_day | L8e | 日×物资 | 24×730≈1.8 万 |
| dwd.logistics_order | L8e | 一工单一行 | 锚月 156（完结 92%） |

### dws（9 表 · L5 + L6/L8 自有表）

| 表 | lane | 粒度 | 规模 |
| :-- | :-- | :-- | :-- |
| dws.hospital_oper_day | L5 | 日×院级 | 730 |
| dws.dept_oper_day | L5 | 日×科室（含医疗组） | ~2.9 万 |
| dws.drg_dept_period | L5 | 期×科室×病组 | ~6.5k |
| dws.metric_value | L5 表，L5+L8 供稿 | 期×码(×科室/病组) | ~7k + L8 供稿 535 |
| dws.benchmark_peer | L6 | 期×指标 | ≤6（ours 派生） |
| dws.exam_indicator | L6 | 期×指标 | 23 |
| dws.quality_rule_audit | L8d | 期×制度 | 8×24=192 |
| dws.energy_month | L8e | 月×分项 | 3×24=72 |
| dws.research_paper_period | L8b | 年×分区×学科 | 三年谱系 |

### ads（8 表 · L6/L7）

| 表 | lane | 粒度 | 规模 |
| :-- | :-- | :-- | :-- |
| ads.dept_rank_day | L6 | 日×期×科室 | ~20（d30 快照） |
| ads.work_item | L6 | 一事项一行 | 5 |
| ads.radar_score | L6 | 期×维度 | 6 维双序列 |
| ads.today_kpi | L7 | 快照行 | 11（院级 4+楼宇归口 7，dwd 派生） |
| ads.campus_status | L7 | 楼宇快照 | 4 栋 metrics jsonb（0~1 规范化） |
| ads.alert_rule | L7 | 一规则一行 | 13（11 rule+2 scenario） |
| ads.alert_event | L7 | 一事件一行 | open 5+历史 |
| ads.todo_order | L7 | 督办行 | 0（空表预案） |

### sim（3 表 · L9，env 可跳）

| 表 | 粒度 | 种子 |
| :-- | :-- | :-- |
| sim.clock | 单行 | virtual_now=2026-10-28 09:00+08 |
| sim.job_log | 作业日志 | 骨架数行 |
| sim.profile | 参数键值 | 含 outpt_daily_base=4200 |

## 3. 核心约定（生产级硬规则）

| 主题 | 裁决 |
| :-- | :-- |
| 金额 | 一律 `numeric(14,2)` 单位**元**；万元/亿元只在 API/展示层换算 |
| 率值 | 一律存 **0~1** `numeric(7,4)`（含 `campus_status.metrics`——无例外）；满意度为 0~100 分制 |
| 时间 | 时刻 `timestamptz`；日期 `date`；周期二元组 `period_type`+`period_start`（废 char(7)） |
| 主键 | `id bigint generated always as identity`；大事实表 PK 含时间键；编码组表 code 为主键，实体组 id PK+code UQ |
| 哨兵 | `dim.department id=0` 实体哨兵行承接"院级"聚合；API 序列化 `dept_id=0→null`；事件归属缺失=`NULL`（与聚合哨兵并存） |
| 外键 | `sys.user.dept_id→dim.department(id)` 后挂迁移 **0113 `fk_user_department` + `ON DELETE RESTRICT`**（防账号静默升格院级）；事实层 dept FK 默认 NO ACTION |
| 枚举 | `sys.dict` 注册 + 列 CHECK **同 migration 双写**；69 个 dict_type 冻结 |
| 指标 | `metric_code` 全列 FK→`sys.metric_def`；direction=好坏极性（升好 1/降好 -1/中性 0），涨跌符号走 delta 列；page-only 字段（icon/tone）不落库 |
| 命名 | PK `pk_<表>` / FK `fk_<子>_<父>` / UQ `uq_<表>_<列>` / IDX `idx_<表>_<列>` / CK `ck_<表>_<列>` |
| 基准日 | **BASE_DATE=2026-10-28（周三）**；种子窗 2025-01-01~2026-12-31；`dim.date` 预生成 2024~2027 |
| 年累计 | `range=本年` 月粒度指标=趋势数组 **Jan–Oct 全月求和**（锚月整月计入，不做 ≤BASE_DATE 截断） |
| 种子 | 确定性（md5/setseed 派生，禁裸 `random()`/`now()`）+ 幂等（ON CONFLICT/键域 DELETE）；规模偏差 <±10% 须标注 |
| 屏值 | 契约字面仅形态示例；**屏显数值为事实层实算，±10% 容差**（v2.2 §6.7） |

## 4. 关键勾稽锚点表（目标 vs lane 实测，R3 轮）

| 锚点 | 目标（scale-decision v2.2） | lane 实测 | 判定 |
| :-- | :-- | :-- | :-- |
| 月出院（2026-10） | 8,120 | L3 **8,117**；L4 科室字面 8,478（+4.4%⊆带） | ✅ |
| 在院患者 | 1,846 | 床态 Σ=1,846；move 净存 1,875（+1.6%） | ✅ Little：8,120×6.8÷30≈1,841 |
| 床位 | 使用率 0.921 / 开放 ~2,004 | ward Σbed_open=2,004 精确 | ✅ |
| 月门急诊（E9×10） | 123,000（急诊 ~11,300） | L3 **123,350~123,443** | ✅ |
| 今日门急诊（10-28） | ~4,200 | **4,437**（+5.6%，确定性抖动上限） | ✅ |
| 年累计（Jan–Oct） | 出院 71,310 / 门急诊 846,000 / 收入 120,260 万 / 手术 10,606 | 门急诊实测 845,780（-0.14%） | ✅ |
| 月医疗总收入 | 14,800 万 | **14,800.0 万精确**（门诊 3,690.0/住院 10,508.0/其他 602.0=4.07%） | ✅ |
| 门诊费勾稽 | hourly.fee_total≡charge_day.out_fee | Σ3,690.0 万、次均 299.1 元、日偏差 max 0.048% | ✅ |
| 次均费用 | 住院 13,000 / 门诊 300 | 住院实测 12,430（-4.4%⊆勾稽余量） | ✅ |
| 结余 | 10月 622 万 / 率 4.2% | 成本合成系数收敛 [0.9307,0.9997] | ✅ |
| 医保基金月结算 | 9,860 万 | ≈住院收入×93.6% 自洽 | ✅ |
| 手术 | 月 1,286 / 日 ~45 | 1,286 精确；全年 24,266 | ✅ |
| ALOS / CMI | 6.8 / 1.08±0.02 | 6.8 / **1.0870** | ✅ |
| DRG | 入组率 98.5%；RW 六段 870/3350/3060/662/128/37 | drg_case 103,934；RW 实测 942/3652/2915/681/128/34（±10% 盒内）；RW≥2=10.2% | ✅ |
| 低风险死亡率 | ≤0.024% | 0.021%（16/75,107） | ✅ |
| 科室出院 TOP10 | ip_sh：1250/1120/990/920/800/735/715/655/380/340+尾~215 | 实测 TOP8=7,202、尾 214 | ✅ ±10% |
| 大屏 KPI | 4,200 / 1,846 / 0.921 / 45 | today_kpi 自 dwd 派生复现 | ✅ ±10% |
| compare ours | 门急诊 **108.8 万**（全年 Σ1,088,000）/ 出院 8.64 万（Σ86,410） | 派生实算；契约字面 109.0/9.73 为近似 | ✅ |
| 人力 | 2,368（医 812/护 1,046/技 202/行政 308）；高职 12.0% | staff 矩阵严格锚定；经费占比 32.5%（10 月 46,078,500 元） | ✅ |
| 科研 | 在研 186/新立 42(+6)/经费 3,480 万/SCI 98 | 逐年精确 | ✅ |
| 患者 | 投诉 24/表扬 86/满意度 96.4/97.2 | 精确 | ✅ |
| 质安 | 危急值 99.1%/院感 1.24%/不良 36/百床 1.95/切口 0.38% | 0.9909、1.245%、36、1.9502、随分母自适应 | ✅ |
| 资产 | 设备 68/开机率 94.2%/库存 28 天/能耗 186 万/工单 156·92% | 0.9420、28.0、Σ186 万、0.9231 | ✅ |

**勾稽恒等式**（建库验收断言用）：在院≈出院×ALOS÷30；门诊收入=人次×300；住院收入≈出院×13,000；RW≥2%=(662+128+37)/8,107=10.2%；年累计=趋势数组 Jan–Oct Σ；屏 KPI=dwd 当日派生 ±10%。

## 5. 迁移与种子装配

### 5.1 迁移（`backend/migrations/`，59 文件）

| 序号段 | 内容 |
| :-- | :-- |
| `0000` | **bootstrap**：六 schema `CREATE SCHEMA IF NOT EXISTS` 唯一属主 + pgcrypto 预留（lane 文件头 IF NOT EXISTS 仅防御性兜底） |
| `0001~0007` | sys 7 表 |
| `0101~0112` | dim 12 表（0109 device=实体组 id PK） |
| `0113` | `sys.user.dept_id→dim.department(id)` 延迟 FK（RESTRICT，须在 dim 后） |
| `0201~0218` | dwd 18 事实表 |
| `0301~0309` | dws 9 表（含 L6 benchmark_peer/exam_indicator、L8 quality_rule_audit/energy_month/research_paper_period） |
| `0401~0408` | ads 8 表（含 0408 todo_order 空表预案） |
| `0501~0503` | sim 3 表（末批，env 可跳） |

命名 `NNNN_<schema>_<对象>.sql` 全局单调；一文件一对象；dict 行与 CHECK 同文件。

### 5.2 种子装配（`backend/seed/`，正本=`seed-manifest.md`）

DDL 全链先 apply，种子**按相位不按 lane 文件边界**（clean-DB 实测断链收口：L5 引用的 metric_def 曾埋在 newdom 尾部 seed 里报 FK 违规）：

```
Ⅰa 定义：seed/1001_sys_defs.sql（dict+metric_def 全行）→ seed/1002_l8_defs.sql（L8 两域供稿并编）
Ⅰb 维度：seed/1100_dim_public.sql（date→org→staff→clinical 全维）
Ⅱ.pre：seed/1150_sys_deferred.sql（user.dept_id 回填+环 FK 收口）
Ⅱ  事实：seed/2010_dwd_flow → 2020_dwd_clinical → 2030_l8_hr → 2031_l8_pat_qual → 2032_l8_supply
Ⅲa 聚合：seed/3001_dws_agg.sql（hospital_oper_day/dept_oper_day/drg_dept_period/metric_value，全 dwd 派生）
Ⅲb 集市：seed/3020_ads_workbench → 3030_ads_screen
Ⅳ  仿真：seed/5001_sim.sql（env 可跳）
```

铁律：`INSERT INTO sys.metric_def`/`sys.dict` 集中在 Ⅰa 文件（lane 文件内防御性 ON CONFLICT 供稿段幂等无害）；user 回填必在 department 之后；L8 事实先于 L5 聚合（dws 读 dwd.critical_value）。理想态 26 文件相位拆分正本见 `/tmp/modeling/schema/seed-manifest.md`。

## 6. 遗留 open-items（交接清单）

| 项 | 内容 | 状态 |
| :-- | :-- | :-- |
| O-E4 | `dept_rank_day` eff_score 实算值 vs 契约字面（骨科 96.10 vs 94.2）——序已回锚（骨科1/心内2），契约 §14.1 注6 已声明屏值事实化±10% | ✅ R3 已消解 |
| O-E7 | 高职占比：契约已改 12.0%（=284/2,368 实算） | ✅ 已消解 |
| O-E8 | 住培/继教/转化率、医保结算明细、benchmark region/bench 为 manual 占位（无库内真源） | 演示期接受 |
| 契约残留（R3 遗留） | scale_revenue_trend×10+unit、compare 派生值、stats 当月口径注、weekday 修正——**全部已修**（commit 9f6e1e5） | ✅ 已消解 |
| 缓建项 | `sim` 三表 env 可跳；`dim.drug`、`sys.audit_log`、`ads.todo_order` 空表 | 按计划 |
| 口径注记 | L5 成本/结余为合成口径（系数收敛 4.2%）待真实成本源；drg_case 窗口裁 14 月（103,934 行）；`research disciplines.funds` 走 metric_value 口径禁用 Σproject | 已登记，非阻塞 |
| 文档微痕 | 个别 lane README/注释残留 `8,110`/`847,000` 旧字样（数值断言不受影响） | 清扫项 |

---

> 附：建模流水线全部过程资产在 `/tmp/modeling/`：`conventions.md`（公约）、`schema/plan.md`（总账+DAG）、`schema/seed-manifest.md`（种子相位装配正本）、`escalations.md`（33 条裁决/门禁台账）、`scale-decision.md`（规模裁决书 v2.2）、各 lane `README/columns/open-items`。
