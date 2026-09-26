-- ============================================================================
-- L5 dws-agg — 汇总层 DDL（序号 0301~0304）
-- 事实源：conventions.md v1.0 + schema/plan.md + database-schema.md v1.1 §5
-- 依赖：dim.campus / dim.department（含 id=0 哨兵）/ dim.drg_group / sys.metric_def
-- 通用约定：金额 numeric(14,2) 单位元；率值 numeric(7,4) 存 0~1；
--          周期一律 period_type + period_start(date) 二元组；
--          dept_id=0 / group_id=0 为院级/无组哨兵（FK 由 dim.department id=0 行保证）。
-- 写纪律：本层四表由派生流水线独占写入（演示期=本种子），仿真器/ETL 禁直写。
-- ============================================================================

CREATE SCHEMA IF NOT EXISTS dws;   -- M1 防线：本文件是首个使用 dws schema 的迁移（0301 起）

-- ----------------------------------------------------------------------------
-- file: migrations/0301_dws_hospital_oper_day.sql   lane: L5   verdict: 继承
-- contract: api-contract §3.1/§3.2/§3.4/§4.1/§6.1/§14.1
-- partition: 不列入分区预案（日汇总表，演示+生产量级均小）；如需归档按年冷备
-- ----------------------------------------------------------------------------
CREATE TABLE dws.hospital_oper_day (
  date                date          NOT NULL,              -- 统计日（自然日）
  campus_code         varchar(20)   NOT NULL,              -- 院区（演示期仅 main）
  outpt_cnt           int           NOT NULL DEFAULT 0,    -- 门诊人次（不含急诊）
  emerg_cnt           int           NOT NULL DEFAULT 0,    -- 急诊人次
  reg_cnt             int           NOT NULL DEFAULT 0,    -- 挂号人次
  in_hosp_cnt         int           NOT NULL DEFAULT 0,    -- 当日在院人数（=Σbed_used）
  admit_cnt           int           NOT NULL DEFAULT 0,    -- 当日入院人数
  discharge_cnt       int           NOT NULL DEFAULT 0,    -- 当日出院人数
  surg_cnt            int           NOT NULL DEFAULT 0,    -- 手术台次（status<>'sched'）
  surg_l4_cnt         int           NOT NULL DEFAULT 0,    -- 四级手术台次
  bed_open            int           NOT NULL DEFAULT 0,    -- 开放床位（Σ病区）
  bed_used            int           NOT NULL DEFAULT 0,    -- 占用床位（Σ病区，含借床净额）
  bed_use_rate        numeric(7,4)  NOT NULL DEFAULT 0,    -- 床位使用率 0~1（借床可>1，护栏2）
  alos                numeric(6,2)  NULL,                  -- 平均住院日·天（当日无出院=NULL）
  preop_alos          numeric(6,2)  NULL,                  -- 术前住院日·天（当日无手术病例=NULL）
  longstay_cnt        int           NOT NULL DEFAULT 0,    -- 当日出院中 los>30 人数
  revenue             numeric(14,2) NOT NULL DEFAULT 0,    -- 医疗收入·元（=Σcharge_day out+in）
  cost                numeric(14,2) NOT NULL DEFAULT 0,    -- 医疗成本·元（演示期合成口径，见 README O-成本）
  profit              numeric(14,2) NOT NULL DEFAULT 0,    -- 收支结余·元 = revenue−cost（可负，不加 CHECK）
  drg_profit          numeric(14,2) NOT NULL DEFAULT 0,    -- DRG结余·元 =Σdrg_case.profit（可负）
  drug_fee            numeric(14,2) NOT NULL DEFAULT 0,    -- 药品费·元
  drug_ratio          numeric(7,4)  NOT NULL DEFAULT 0,    -- 药占比 0~1
  material_fee        numeric(14,2) NOT NULL DEFAULT 0,    -- 卫生材料费·元
  material_per_100rev numeric(8,2)  NOT NULL DEFAULT 0,    -- 百元医疗收入消耗卫生材料·元（口径B剔药：mat/(rev−drug)×100）
  insurance_settle    numeric(14,2) NOT NULL DEFAULT 0,    -- 医保结算额·元（=Σcharge_day.insurance_fee）
  self_pay_ratio      numeric(7,4)  NOT NULL DEFAULT 0,    -- 自费比例 0~1 = self/(ins+self)
  cmi                 numeric(8,4)  NULL,                  -- 当日 CMI（无入组病例=NULL；小样本噪声大仅参考）
  emerg_obs_over6h    int           NOT NULL DEFAULT 0,    -- 当日到诊且留观>6h 人数
  critical_unclosed   int           NOT NULL DEFAULT 0,    -- 当日报出且未闭环危急值条数
  satisfaction        numeric(6,2)  NULL,                  -- 综合满意度·0~100 分（采集型，演示期仿真常量带噪）
  updated_at          timestamptz   NOT NULL,              -- 派生流水线写入时刻（种子=BASE_DATE 常量）
  CONSTRAINT pk_hospital_oper_day PRIMARY KEY (date, campus_code),
  CONSTRAINT fk_hospital_oper_day_campus FOREIGN KEY (campus_code) REFERENCES dim.campus(code),
  CONSTRAINT ck_hod_counts CHECK (
    outpt_cnt>=0 AND emerg_cnt>=0 AND reg_cnt>=0 AND in_hosp_cnt>=0 AND admit_cnt>=0
    AND discharge_cnt>=0 AND surg_cnt>=0 AND surg_l4_cnt>=0 AND bed_open>=0 AND bed_used>=0
    AND longstay_cnt>=0 AND emerg_obs_over6h>=0 AND critical_unclosed>=0 AND surg_l4_cnt<=surg_cnt),
  CONSTRAINT ck_hod_rates CHECK (
    bed_use_rate>=0 AND bed_use_rate<=2 AND drug_ratio>=0 AND drug_ratio<=2 AND self_pay_ratio>=0 AND self_pay_ratio<=2),
  CONSTRAINT ck_hod_amt_nonneg CHECK (
    revenue>=0 AND cost>=0 AND drug_fee>=0 AND material_fee>=0 AND insurance_settle>=0 AND material_per_100rev>=0),
  CONSTRAINT ck_hod_satisfaction CHECK (satisfaction IS NULL OR (satisfaction>=0 AND satisfaction<=100)),
  CONSTRAINT ck_hod_alos CHECK (alos IS NULL OR alos>=0),
  CONSTRAINT ck_hod_preop_alos CHECK (preop_alos IS NULL OR preop_alos>=0),
  CONSTRAINT ck_hod_cmi CHECK (cmi IS NULL OR cmi>=0)
);
COMMENT ON TABLE  dws.hospital_oper_day IS '院级运营日表：契约宏观指标主源（§3/§4/§6/§14）。OP_DAILY_VISITS=outpt_cnt+emerg_cnt（口径钉死）；对账用 drg_profit 非 profit';
COMMENT ON COLUMN dws.hospital_oper_day.cost IS '演示期=revenue×科室成本系数合成（无成本事实表）；真实期接 HRP 全成本后改聚合（open-item #3）';
COMMENT ON COLUMN dws.hospital_oper_day.material_per_100rev IS '口径B：材料费/(医疗收入−药品费)×100，单位元/百元（契约 §6.1 cost_controls）';
COMMENT ON COLUMN dws.hospital_oper_day.satisfaction IS '院级综合满意度（分值 0~100，API 按契约出参 unit=% 值不变）；门/住分项走 metric_value SAT_*_SCORE';

-- ----------------------------------------------------------------------------
-- file: migrations/0302_dws_dept_oper_day.sql   lane: L5   verdict: 继承（+1列改造，见 open-items #1）
-- contract: api-contract §3.3 top10 / §5.1 三 tab 科室表 / §12.1 compare inpt/sat / §14.1 dept_ranking 底数
-- partition: 不列入分区预案（日汇总表）
-- ----------------------------------------------------------------------------
CREATE TABLE dws.dept_oper_day (
  date                date          NOT NULL,              -- 统计日
  dept_id             bigint        NOT NULL,              -- dim.department.id：level=2 科室行与 level=3 医疗组行并存
  outpt_cnt           int           NULL,                  -- 诊疗人次（门诊+急诊归口本院区科室；组级无门诊归集=NULL）
  in_hosp_cnt         int           NULL,                  -- 在院人数（无病区科室/组级=NULL）
  admit_cnt           int           NULL,                  -- 当日入院（组级无 move 粒度=NULL）
  discharge_cnt       int           NULL,                  -- 当日出院（组级=drg_case 口径出院数；无出院=NULL 时按 0 聚合）
  surg_cnt            int           NULL,                  -- 手术台次（台次口径无组级事实=NULL）
  surg_l4_cnt         int           NULL,                  -- 四级手术台次（同上）
  alos                numeric(6,2)  NULL,                  -- 平均住院日·天（无出院=NULL）
  bed_use_rate        numeric(7,4)  NULL,                  -- 床位使用率 0~1（无床位科室=NULL）
  revenue             numeric(14,2) NULL,                  -- 医疗收入·元（组级无 charge 粒度=NULL）
  cost                numeric(14,2) NULL,                  -- 医疗成本·元（演示期 revenue×科室系数合成）
  profit              numeric(14,2) NULL,                  -- 收支结余·元（可负）
  drg_profit          numeric(14,2) NULL,                  -- DRG结余·元（可负；组级盈亏唯一落点）
  case_cnt            int           NULL,                  -- DRG入组病例数（当日出院且入组）
  cmi                 numeric(8,4)  NULL,                  -- 当日 CMI（日粒度噪声大，排名一律看 d30 快照）
  material_per_100rev numeric(8,2)  NULL,                  -- 百元耗材·元（口径B剔药；无收入=NULL）
  eff_score           numeric(6,2)  NULL,                  -- 科室运行效率分 0~100（schema §10 公式v1；仅 med/surg 科室行计算）
  CONSTRAINT pk_dept_oper_day PRIMARY KEY (date, dept_id),
  CONSTRAINT fk_dept_oper_day_dept FOREIGN KEY (dept_id) REFERENCES dim.department(id),
  CONSTRAINT ck_dod_counts CHECK (
    (outpt_cnt IS NULL OR outpt_cnt>=0) AND (in_hosp_cnt IS NULL OR in_hosp_cnt>=0)
    AND (admit_cnt IS NULL OR admit_cnt>=0) AND (discharge_cnt IS NULL OR discharge_cnt>=0)
    AND (surg_cnt IS NULL OR surg_cnt>=0) AND (surg_l4_cnt IS NULL OR surg_l4_cnt>=0)
    AND (surg_l4_cnt IS NULL OR surg_cnt IS NULL OR surg_l4_cnt<=surg_cnt)
    AND (case_cnt IS NULL OR case_cnt>=0)),
  CONSTRAINT ck_dod_rates CHECK (
    (bed_use_rate IS NULL OR (bed_use_rate>=0 AND bed_use_rate<=2))
    AND (eff_score IS NULL OR (eff_score>=0 AND eff_score<=100))
    AND (alos IS NULL OR alos>=0) AND (cmi IS NULL OR cmi>=0)
    AND (material_per_100rev IS NULL OR material_per_100rev>=0)),
  CONSTRAINT ck_dod_amt_nonneg CHECK (
    (revenue IS NULL OR revenue>=0) AND (cost IS NULL OR cost>=0))
);
COMMENT ON TABLE  dws.dept_oper_day IS '科室/医疗组运营日表：dept_id 承载 level=2 科室与 level=3 医疗组两级行；组级行仅 drg_case 可得列（case_cnt/cmi/drg_profit/alos/discharge_cnt）有值，其余 NULL';
COMMENT ON COLUMN dws.dept_oper_day.discharge_cnt IS '继承判决外加列：home/top10 当月出院降序与 compare inpt 列的唯一落点（v1.1 缺列，open-items #1）';
COMMENT ON COLUMN dws.dept_oper_day.eff_score IS '100×(0.30·norm(cmi)+0.25·norm(surg_cnt)+0.20·(1−norm(alos))+0.15·bed_use_rate+0.10·norm(profit))，norm=当日全科 min-max；非 med/surg 行 NULL';

-- ----------------------------------------------------------------------------
-- file: migrations/0303_dws_drg_dept_period.sql   lane: L5   verdict: 改造
-- contract: api-contract §13.1 topics·drg 科室表+stats / §14.1 drg_quadrant
-- partition: 不列入分区预案（周期汇总表）
-- 改造点：period varchar(10) → period_type+period_start 二元组（H7 裁决）；
--         +cost_idx/time_idx/rw2_ratio/lowrisk_mortality 四列（G18）
-- ----------------------------------------------------------------------------
CREATE TABLE dws.drg_dept_period (
  period_type        varchar(8)    NOT NULL,              -- 本表仅用 month / d30（dict period_type 子集）
  period_start       date          NOT NULL,              -- 周期首日；d30=as_of−29（演示锚 2026-09-29，as_of=2026-10-28）
  dept_id            bigint        NOT NULL,              -- 科室；0=全院哨兵行（院级病组谱/分布图直读）
  drg_code           varchar(16)   NOT NULL,              -- dim.drg_group.code
  case_cnt           int           NOT NULL DEFAULT 0,    -- 入组病例数（出院日期落期内）
  rw_avg             numeric(8,4)  NULL,                  -- 例均权重
  cmi_equiv          numeric(8,4)  NULL,                  -- 等效 CMI=Σrw/Σcase（单元格内=rw_avg；dept0 行亦然）
  total_profit       numeric(14,2) NULL,                  -- DRG结余合计·元（可负）
  profit_avg         numeric(14,2) NULL,                  -- 例均结余·元（可负）
  fee_avg            numeric(14,2) NULL,                  -- 例均费用·元
  cost_avg           numeric(14,2) NULL,                  -- 例均成本·元
  insure_avg         numeric(14,2) NULL,                  -- 例均医保支付·元
  los_avg            numeric(6,2)  NULL,                  -- 例均住院日·天
  material_ratio     numeric(7,4)  NULL,                  -- 材料费占比 0~1
  cost_idx           numeric(8,4)  NULL,                  -- 费用消耗指数=fee_avg/region_fee_avg（可>1）
  time_idx           numeric(8,4)  NULL,                  -- 时间消耗指数=los_avg/region_los_avg（可>1）
  rw2_ratio          numeric(7,4)  NULL,                  -- RW≥2 病例占比 0~1（组内 rw 恒定，单元格恒为 0/1，供加权聚合）
  lowrisk_mortality  numeric(7,4)  NULL,                  -- 低风险组死亡率 0~1；仅 drg_group.risk_level='low' 行有值
  quadrant           smallint      NULL,                  -- 四象限（单元格级）：cmi≥1&profit≥0→2 / cmi≥1&profit<0→1 / cmi<1&profit≥0→4 / cmi<1&profit<0→3
  CONSTRAINT pk_drg_dept_period PRIMARY KEY (period_type, period_start, dept_id, drg_code),
  CONSTRAINT fk_drg_dept_period_dept FOREIGN KEY (dept_id) REFERENCES dim.department(id),
  CONSTRAINT fk_drg_dept_period_drg  FOREIGN KEY (drg_code) REFERENCES dim.drg_group(code),
  CONSTRAINT ck_ddp_period_type CHECK (period_type IN ('month','d30')),
  CONSTRAINT ck_ddp_case_cnt CHECK (case_cnt>=0),
  CONSTRAINT ck_ddp_rates CHECK (
    (material_ratio IS NULL OR (material_ratio>=0 AND material_ratio<=2))
    AND (rw2_ratio IS NULL OR (rw2_ratio>=0 AND rw2_ratio<=2))
    AND (lowrisk_mortality IS NULL OR (lowrisk_mortality>=0 AND lowrisk_mortality<=2))),
  CONSTRAINT ck_ddp_idx CHECK (
    (cost_idx IS NULL OR cost_idx>=0) AND (time_idx IS NULL OR time_idx>=0)
    AND (rw_avg IS NULL OR rw_avg>=0) AND (cmi_equiv IS NULL OR cmi_equiv>=0) AND (los_avg IS NULL OR los_avg>=0)),
  CONSTRAINT ck_ddp_quadrant CHECK (quadrant IS NULL OR quadrant BETWEEN 1 AND 4),
  CONSTRAINT ck_ddp_avg_nonneg CHECK (
    (fee_avg IS NULL OR fee_avg>=0) AND (cost_avg IS NULL OR cost_avg>=0) AND (insure_avg IS NULL OR insure_avg>=0))
);
COMMENT ON TABLE  dws.drg_dept_period IS '病组×科室×周期盈亏汇总：大屏 drg_quadrant 单元格、topics·drg 科室表与院级 stats 的底数；dept_id=0 行供院级病组谱/RW分布直读';
COMMENT ON COLUMN dws.drg_dept_period.quadrant IS '单元格（科×组）象限；大屏科室级象限须先聚合 Σprofit/加权cmi 再判，不得直接沿用（见 open-items #7）';
COMMENT ON COLUMN dws.drg_dept_period.lowrisk_mortality IS '聚合口径：Σ(lowrisk_mortality×case_cnt)/Σcase_cnt 限 risk_level=low 行（精度的±，见 columns.md）';

-- ----------------------------------------------------------------------------
-- file: migrations/0304_dws_metric_value.sql   lane: L5   verdict: 继承·收窄
-- contract: api-contract §9.1(SAT_*) / §8.1(RESEARCH_*) / §12.1(BIZ_EQUIV/QUALITY_SCORE/sat)
--           / §13.1(EXAM_*/DRG_ENROLL_RATE…) / §5.1(SURG_L34/MIN_INVASIVE) / §10.1(EMR_GRADE_A_RATE)
-- partition: 不列入分区预案（指标长表）
-- 收窄纪律：只承接"宽表无专属列"的指标；凡 hospital_oper_day/dept_oper_day/drg_dept_period
--           同粒度已有列的同指标禁止双写（公约 §3/继承分析 O-清单）。
-- ----------------------------------------------------------------------------
CREATE TABLE dws.metric_value (
  metric_code        varchar(40)   NOT NULL,              -- FK→sys.metric_def(code)，禁止未注册 code
  date               date          NOT NULL,              -- =该 code 的 period_start（粒度由 metric_def.period 唯一决定：month→月初日、year→01-01、day→当日）
  dept_id            bigint        NOT NULL DEFAULT 0,    -- 0=院级哨兵
  group_id           bigint        NOT NULL DEFAULT 0,    -- 0=无医疗组；组级值时=dim.department level=3 行 id
  value              numeric(18,4) NOT NULL,              -- 规范量纲：amt=元 / rate=0~1 / cnt=个 / mins=分钟 / days=天 / idx=原值 / score=0~100 分
  extra              jsonb         NULL,                  -- 开放键集（如 {"source":"manual_seed","note":…}）；不承担过滤谓词
  CONSTRAINT pk_metric_value PRIMARY KEY (metric_code, dept_id, group_id, date),
  CONSTRAINT fk_metric_value_metric FOREIGN KEY (metric_code) REFERENCES sys.metric_def(code),
  CONSTRAINT fk_metric_value_dept   FOREIGN KEY (dept_id)  REFERENCES dim.department(id),
  CONSTRAINT fk_metric_value_group  FOREIGN KEY (group_id) REFERENCES dim.department(id)
);
COMMENT ON TABLE  dws.metric_value IS '通用指标长表（一数一源的尾部归宿）：长尾/手工/无专属列指标；value 一律规范量纲，展示换算由 metric_def.value_kind+disp_unit 在 API 层驱动';
COMMENT ON COLUMN dws.metric_value.date IS '取值周期首日（如月指标 2026-09-01）；同 code 跨周期冲突不存在——period 由 metric_def 钉死';
COMMENT ON COLUMN dws.metric_value.value IS 'CHECK 由 metric_def.value_kind 生成侧护栏（rate:−1e-4~2 / cnt≥0 / score 0~100 / idx 原值），列级不重复约束';

-- ----------------------------------------------------------------------------
-- 二级索引（与 indexes.md 登记一一对应；种子期直建，生产追加走 CONCURRENTLY）
-- 查询面见 indexes.md；M4 增补：drg_code/dept_id/group_id 三枚 FK 覆盖索引
-- ----------------------------------------------------------------------------
CREATE INDEX idx_dept_oper_day_dept_date      ON dws.dept_oper_day (dept_id, date);
CREATE INDEX idx_drg_dept_period_dept         ON dws.drg_dept_period (dept_id, period_type, period_start);
CREATE INDEX idx_drg_dept_period_drg          ON dws.drg_dept_period (drg_code);
CREATE INDEX idx_metric_value_code_dept_date  ON dws.metric_value (metric_code, dept_id, date);
CREATE INDEX idx_metric_value_date_code       ON dws.metric_value (date, metric_code);
CREATE INDEX idx_metric_value_dept            ON dws.metric_value (dept_id, metric_code, date);
CREATE INDEX idx_metric_value_group           ON dws.metric_value (group_id, metric_code, date);
