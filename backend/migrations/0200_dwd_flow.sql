-- ============================================================================
-- lane L3 dwd-flow — DDL 段（migrations 0201~0207）
-- bootstrap 兜底（audit M1/E1）：lane 文件头幂等建 schema，0000_bootstrap 存在时本行无害
CREATE SCHEMA IF NOT EXISTS dwd;
-- ============================================================================
-- 依据：conventions.md §2/§5/§6、plan.md §3/§4 L3、database-schema.md v1.1 §4
-- 口径：金额一律 numeric(14,2) 元；率 0~1；时刻 timestamptz；日粒度 date。
-- 分区就绪：本文件全部事实表 PK 均含时间键（公约 §5.2）；P0 不建分区，
--          生产期预案逐表注于头注释。
-- ============================================================================

-- ----------------------------------------------------------------------------
-- file: migrations/0201_dwd_outpatient_hourly.sql  lane: L3  verdict: 改造(继承#20)
-- contract: api-contract §5.1(门急诊 tab 普通/专家/候诊) §9.1(平均候诊) §14.1(KPI)
-- depends : dim.department (L2)
-- partition: 生产期按月 RANGE(stat_time)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS dwd.outpatient_hourly (
  stat_time    timestamptz    NOT NULL,            -- 统计时段起点，30min 粒度（对齐整点/半点）
  dept_id      bigint         NOT NULL,            -- 出诊科室（急诊行=急诊科，emerg_flag=true）
  emerg_flag   boolean        NOT NULL DEFAULT false, -- true=急诊行；false=门诊行（国考#1分子=门诊不含急诊，calibration §5.1）
  visit_cnt    int            NOT NULL DEFAULT 0,  -- 时段内就诊人次
  reg_cnt      int            NOT NULL DEFAULT 0,  -- 时段内挂号人次（≥visit_cnt，含退号）
  cancel_cnt   int            NOT NULL DEFAULT 0,  -- 退号人次（REG_CANCEL_RATE 分子，P2 指标已落列）
  appt_cnt     int            NOT NULL DEFAULT 0,  -- 预约就诊人次（APPT_RATE 分子，P2）
  expert_cnt   int            NOT NULL DEFAULT 0,  -- 专家门诊人次（改造新增；普通门诊=visit_cnt−expert_cnt，契约 §5.1）
  wait_min_sum numeric(12,1)  NOT NULL DEFAULT 0,  -- 候诊总分钟（改造新增；AVG_WAIT_MIN=Σwait_min_sum/Σvisit_cnt，契约 §9.1）
  fee_total    numeric(14,2)  NOT NULL DEFAULT 0,  -- 时段门急诊费用合计，单位：元（AVG_OP_FEE=Σfee_total/Σvisit_cnt）
  CONSTRAINT pk_outpatient_hourly PRIMARY KEY (stat_time, dept_id, emerg_flag),
  CONSTRAINT fk_outpatient_hourly_department FOREIGN KEY (dept_id) REFERENCES dim.department (id),
  CONSTRAINT ck_outpatient_hourly_nonneg CHECK (
    visit_cnt >= 0 AND reg_cnt >= 0 AND cancel_cnt >= 0 AND appt_cnt >= 0
    AND expert_cnt >= 0 AND wait_min_sum >= 0 AND fee_total >= 0),
  CONSTRAINT ck_outpatient_hourly_expert CHECK (expert_cnt <= visit_cnt),
  CONSTRAINT ck_outpatient_hourly_appt   CHECK (appt_cnt <= reg_cnt)
);
COMMENT ON COLUMN dwd.outpatient_hourly.expert_cnt   IS '专家门诊人次；普通门诊=visit_cnt−expert_cnt（契约 §5.1 stats 普通/专家拆分）';
COMMENT ON COLUMN dwd.outpatient_hourly.wait_min_sum IS '候诊总分钟；均值=sum/visit_cnt，契约 §5.1/§9.1 平均候诊 18min';
COMMENT ON COLUMN dwd.outpatient_hourly.emerg_flag   IS 'true=急诊行（仅急诊科）；门诊/急诊分桶是国考#1口径前提（calibration §5.1）';

-- ----------------------------------------------------------------------------
-- file: migrations/0202_dwd_reg_channel_day.sql  lane: L3  verdict: 新建(G3)
-- contract: api-contract §9.1 channel_distribution（38/24/18/14/6）
-- depends : 无（院级粒度，无 dept 维度——继承分析 G3 裁决）
-- partition: 生产期按月 RANGE(date)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS dwd.reg_channel_day (
  date     date        NOT NULL,          -- 统计日
  channel  varchar(16) NOT NULL,          -- dict: reg_channel（wechat_mp/kiosk/window/app/phone）
  reg_cnt  int         NOT NULL DEFAULT 0, -- 该渠道当日挂号人次（REG_CHANNEL_SHARE/ONLINE_REG_RATE 分子）
  CONSTRAINT pk_reg_channel_day PRIMARY KEY (date, channel),
  CONSTRAINT ck_reg_channel_day_channel CHECK (channel IN ('wechat_mp','kiosk','window','app','phone')),
  CONSTRAINT ck_reg_channel_day_cnt     CHECK (reg_cnt >= 0)
);
COMMENT ON COLUMN dwd.reg_channel_day.channel IS '挂号渠道，dict_type=reg_channel；契约 §9.1 五渠道占比 38/24/18/14/6';

-- ----------------------------------------------------------------------------
-- file: migrations/0203_dwd_inpatient_move.sql  lane: L3  verdict: 继承(继承#22)
-- contract: api-contract §4.1(live_inpatient 今日入院/出院) §5.1(住院 tab) §3.4(ALOS)
-- depends : dim.department / dim.ward (L2)
-- partition: 生产期按月 RANGE(event_time)；PK 按公约 §5.2 改复合 (id,event_time)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS dwd.inpatient_move (
  id             bigint       generated always as identity,
  patient_masked varchar(32)  NOT NULL,       -- 生成即脱敏 P100234（公约 §5.6 确定性生成器）
  dept_id        bigint       NOT NULL,       -- 事件所属科室（入院/出院/转入转出科室）
  ward_code      varchar(20)  NOT NULL,       -- 事件病区
  event          varchar(12)  NOT NULL,       -- dict: ip_event（admit/discharge/transfer）
  event_time     timestamptz  NOT NULL,       -- 事件时刻
  los_days       int,                          -- 住院天数，仅 discharge 行填（算头不算尾，calibration §5.2）；其余 NULL
  CONSTRAINT pk_inpatient_move PRIMARY KEY (id, event_time),
  CONSTRAINT fk_inpatient_move_department FOREIGN KEY (dept_id)   REFERENCES dim.department (id),
  CONSTRAINT fk_inpatient_move_ward       FOREIGN KEY (ward_code) REFERENCES dim.ward (code),
  CONSTRAINT ck_inpatient_move_event      CHECK (event IN ('admit','discharge','transfer')),
  CONSTRAINT ck_inpatient_move_los        CHECK (los_days IS NULL OR los_days >= 0)
);
COMMENT ON COLUMN dwd.inpatient_move.los_days IS '出院者住院天数（算头不算尾，当天入出计1天）；ALOS 分子。NULL=admit/transfer 行或在院未出（迟到数据）';

-- ----------------------------------------------------------------------------
-- file: migrations/0204_dwd_bed_state_day.sql  lane: L3  verdict: 继承(继承#23)
-- contract: api-contract §4.1(在院/床位使用率/病区占用) §5.1(住院 tab) §14.1(KPI2/3)
-- depends : dim.department / dim.ward (L2)
-- partition: 生产期按月 RANGE(date)
-- 借床口径（v1.1 冻结）：借入侧 bed_used ≤ bed_open+borrow_in（CHECK 物理护栏）；
--   借出侧 bed_used ≤ bed_open−borrow_out 与 全院日粒度 Σborrow_in=Σborrow_out
--   为跨行规则 → sim validate 对账，不写 CHECK（公约 §5.4）。
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS dwd.bed_state_day (
  date       date       NOT NULL,            -- 快照日（每晚 0 点口径，calibration §5.2 床日定义）
  ward_code  varchar(20) NOT NULL,           -- 病区
  dept_id    bigint      NOT NULL,           -- 病区归属科室（冗余自 dim.ward，省 join）
  bed_open   int         NOT NULL DEFAULT 0, -- 当日开放床位数（含消毒小修暂停床，不含<半年临时加床）
  bed_used   int         NOT NULL DEFAULT 0, -- 当日实际占用床位数（含临时加床占用）
  borrow_in  int         NOT NULL DEFAULT 0, -- 自他科借入床数（借入侧）
  borrow_out int         NOT NULL DEFAULT 0, -- 借给他科床数（借出侧）
  CONSTRAINT pk_bed_state_day PRIMARY KEY (date, ward_code),
  CONSTRAINT fk_bed_state_day_ward       FOREIGN KEY (ward_code) REFERENCES dim.ward (code),
  CONSTRAINT fk_bed_state_day_department FOREIGN KEY (dept_id)   REFERENCES dim.department (id),
  CONSTRAINT ck_bed_state_day_used CHECK (
    bed_used >= 0 AND bed_used <= bed_open + borrow_in
    AND borrow_in >= 0 AND borrow_out >= 0)
);
COMMENT ON COLUMN dwd.bed_state_day.bed_open IS '开放床位快照（WS/T 598 实际开放床日口径）；Σbed_used/Σbed_open=BED_USE_RATE';

-- ----------------------------------------------------------------------------
-- file: migrations/0205_dwd_emergency_stay.sql  lane: L3  verdict: 继承(继承#24)
-- contract: api-contract §4.1(急诊在观) §14.1(急诊楼 obs_cnt/obs_over6h/obs_max_min)
--           + alert OBS_OVER_6H 事实回溯源（阈值>6h，有意偏离白皮书24h，v1.1注）
-- depends : dim.department (L2)
-- partition: 生产期按月 RANGE(arrive_at)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS dwd.emergency_stay (
  id            bigint       generated always as identity,
  patient_masked varchar(32) NOT NULL,        -- 脱敏患者符 P1xxxxx
  arrive_at     timestamptz  NOT NULL,        -- 入观时刻
  leave_at      timestamptz,                  -- 离观时刻；NULL=仍在观（observing）
  stay_minutes  int,                           -- 留观分钟（仅归档值；observing 行 NULL，实时时长=now−arrive_at）
  obs_status    varchar(12)  NOT NULL,        -- dict: obs_status（observing/admitted/left）；§6.4 分域命名（audit M8）
  triage_level  smallint     NOT NULL,        -- dict: triage_level（1~4 预检分诊）
  dept_id       bigint       NOT NULL,        -- 留观科室（演示期恒=急诊科）
  CONSTRAINT pk_emergency_stay PRIMARY KEY (id, arrive_at),
  CONSTRAINT fk_emergency_stay_department FOREIGN KEY (dept_id) REFERENCES dim.department (id),
  CONSTRAINT ck_emergency_stay_status CHECK (obs_status IN ('observing','admitted','left')),
  CONSTRAINT ck_emergency_stay_triage CHECK (triage_level BETWEEN 1 AND 4),
  CONSTRAINT ck_emergency_stay_min    CHECK (stay_minutes IS NULL OR stay_minutes >= 0),
  CONSTRAINT ck_emergency_stay_leave  CHECK (leave_at IS NULL OR leave_at >= arrive_at)
);
COMMENT ON COLUMN dwd.emergency_stay.stay_minutes IS '归档留观分钟；observing 行不更新存 NULL，实时口径由 now−arrive_at 现算（契约 §14.1 obs_max_min）';

-- ----------------------------------------------------------------------------
-- file: migrations/0206_dwd_charge_day.sql  lane: L3  verdict: 继承(继承#25)
-- contract: api-contract §4.1(income_structure/dept_share) §6.1(收入/控费) §3.4(药占比/耗占比)
-- depends : dim.department (L2)
-- partition: 生产期按月 RANGE(date)
-- fee_cat 7 桶与病案 10 类/医保票据 14 项映射登记于 sys.dict(fee_cat).extra（calibration §3.5）。
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS dwd.charge_day (
  date          date         NOT NULL,          -- 入账日（权责发生制，当日发生当日入账）
  dept_id       bigint       NOT NULL,          -- 费用归属科室（开单科室口径）
  fee_cat       varchar(16)  NOT NULL,          -- dict: fee_cat 7桶（drug/material/exam/treat/surg/bed/other）
  out_fee       numeric(14,2) NOT NULL DEFAULT 0, -- 门诊侧费用·元
  in_fee        numeric(14,2) NOT NULL DEFAULT 0, -- 住院侧费用·元
  insurance_fee numeric(14,2),                   -- 医保支付部分·元；NULL=未结算（迟到数据）
  self_fee      numeric(14,2),                   -- 个人自付部分·元；NULL=未结算
  CONSTRAINT pk_charge_day PRIMARY KEY (date, dept_id, fee_cat),
  CONSTRAINT fk_charge_day_department FOREIGN KEY (dept_id) REFERENCES dim.department (id),
  CONSTRAINT ck_charge_day_cat CHECK (fee_cat IN ('drug','material','exam','treat','surg','bed','other')),
  CONSTRAINT ck_charge_day_amt CHECK (
    out_fee >= 0 AND in_fee >= 0
    AND (insurance_fee IS NULL OR insurance_fee >= 0)
    AND (self_fee      IS NULL OR self_fee      >= 0))
);
COMMENT ON COLUMN dwd.charge_day.fee_cat IS '汇总桶口径；法定病案10类/票据14项映射存 sys.dict.extra（calibration §3.5）';
COMMENT ON COLUMN dwd.charge_day.out_fee IS '门诊收入侧（OP_REVENUE 分子）；与 in_fee 合为医疗收入，不含财政/科教/其他收入（calibration §5.3）';

-- ----------------------------------------------------------------------------
-- file: migrations/0207_dwd_insurance_settle_day.sql  lane: L3  verdict: 新建(G19)
-- contract: api-contract §13.1 topics·insurance（5险种）与 topics·outp_fund（门诊统筹）
-- depends : dim.department (L2)
-- partition: 生产期按月 RANGE(date)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS dwd.insurance_settle_day (
  date        date          NOT NULL,          -- 结算日（局端日终批口径）
  dept_id     bigint        NOT NULL,          -- 结算归属科室
  ins_type    varchar(16)   NOT NULL,          -- dict: ins_type（employee/resident/maternity/severe/relief）
  biz_type    varchar(8)    NOT NULL,          -- dict: ins_biz_type（inp=住院结算 / op_fund=门诊统筹）
  settle_cnt  int           NOT NULL DEFAULT 0, -- 结算人次（契约 §13.1 cases → 库列 settle_cnt，公约 §6.4）
  fund_amt    numeric(14,2) NOT NULL DEFAULT 0, -- 统筹基金支付·元（契约 fund）
  self_amt    numeric(14,2) NOT NULL DEFAULT 0, -- 个人自付·元（含自费；契约 self）
  account_amt numeric(14,2) NOT NULL DEFAULT 0, -- 个人账户支出·元（契约 §13.1 outp_fund"个人账户支出"）
  reject_amt  numeric(14,2) NOT NULL DEFAULT 0, -- 拒付/扣款·元（INS_REJECT_RATE=reject/申报≈reject/fund 近似）
  remote_cnt  int           NOT NULL DEFAULT 0, -- 异地就医结算人次（契原子集，≤settle_cnt）
  chronic_cnt int           NOT NULL DEFAULT 0, -- 门诊慢特病结算人次（op_fund 口径主用，≤settle_cnt）
  CONSTRAINT pk_insurance_settle_day PRIMARY KEY (date, dept_id, ins_type, biz_type),
  CONSTRAINT fk_insurance_settle_day_department FOREIGN KEY (dept_id) REFERENCES dim.department (id),
  CONSTRAINT ck_insurance_settle_day_ins CHECK (ins_type IN ('employee','resident','maternity','severe','relief')),
  CONSTRAINT ck_insurance_settle_day_biz CHECK (biz_type IN ('inp','op_fund')),
  CONSTRAINT ck_insurance_settle_day_cnt CHECK (
    settle_cnt >= 0 AND remote_cnt >= 0 AND chronic_cnt >= 0
    AND remote_cnt <= settle_cnt AND chronic_cnt <= settle_cnt),
  CONSTRAINT ck_insurance_settle_day_amt CHECK (
    fund_amt >= 0 AND self_amt >= 0 AND account_amt >= 0 AND reject_amt >= 0)
);
COMMENT ON COLUMN dwd.insurance_settle_day.biz_type    IS 'inp=住院结算（topics·insurance 源）/ op_fund=门诊统筹（topics·outp_fund 源）';
COMMENT ON COLUMN dwd.insurance_settle_day.reject_amt  IS '医保拒付扣款额；0.8% 锚点按 reject/fund 近似（申报额未建列）';
COMMENT ON COLUMN dwd.insurance_settle_day.account_amt IS '个人账户支付（门诊统筹三件套之一：fund+account+self）；inp 行多为 0';
COMMENT ON COLUMN dwd.insurance_settle_day.chronic_cnt IS '慢特病结算人次；op_fund 行承载契约 §13.1"慢特病 1,846"';

-- ----------------------------------------------------------------------------
-- 二级索引（取舍与查询面映射见 indexes.md）
-- ----------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_oph_dept_time        ON dwd.outpatient_hourly (dept_id, stat_time);
CREATE INDEX IF NOT EXISTS idx_oph_emerg_time       ON dwd.outpatient_hourly (emerg_flag, stat_time) WHERE emerg_flag;
CREATE INDEX IF NOT EXISTS idx_imove_event_time     ON dwd.inpatient_move (event, event_time);
CREATE INDEX IF NOT EXISTS idx_imove_dept_time      ON dwd.inpatient_move (dept_id, event_time);
CREATE INDEX IF NOT EXISTS idx_imove_ward_time      ON dwd.inpatient_move (ward_code, event_time);
CREATE INDEX IF NOT EXISTS idx_bed_ward_date        ON dwd.bed_state_day (ward_code, date);
CREATE INDEX IF NOT EXISTS idx_bed_dept_date        ON dwd.bed_state_day (dept_id, date);
CREATE INDEX IF NOT EXISTS idx_estay_obs_arrive     ON dwd.emergency_stay (obs_status, arrive_at) WHERE obs_status='observing';
CREATE INDEX IF NOT EXISTS idx_estay_arrive         ON dwd.emergency_stay (arrive_at);
CREATE INDEX IF NOT EXISTS idx_estay_dept_arrive    ON dwd.emergency_stay (dept_id, arrive_at);
CREATE INDEX IF NOT EXISTS idx_chg_dept_date        ON dwd.charge_day (dept_id, date);
CREATE INDEX IF NOT EXISTS idx_chg_cat_date         ON dwd.charge_day (fee_cat, date);
CREATE INDEX IF NOT EXISTS idx_isd_dept_biz_date    ON dwd.insurance_settle_day (dept_id, biz_type, date);
CREATE INDEX IF NOT EXISTS idx_isd_ins_biz_date     ON dwd.insurance_settle_day (ins_type, biz_type, date);
