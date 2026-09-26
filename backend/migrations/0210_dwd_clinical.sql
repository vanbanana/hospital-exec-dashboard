-- ============================================================================
-- lane: L4 dwd-clinical
-- 文件内容：dwd.surgery_case（0208，改造）+ dwd.drg_case（0209，改造）
-- 判决来源：公约 §4 继承裁决总账 #27/#28；schema-inheritance 判决表 + 缺口 G9/G18/G22
-- 依赖表：dim.department（id，含 level=3 医疗组）、dim.ward(code)、dim.staff(id)、
--         dim.drg_group(code)、sys.dict（surg_status/incision_class/mr_grade/
--         admit_path/discharge_type/rate_type 值域同文件 CHECK）
-- ============================================================================

CREATE SCHEMA IF NOT EXISTS dwd;

-- ----------------------------------------------------------------------------
-- file: backend/migrations/0208_dwd_surgery_case.sql  verdict: 改造
-- contract: api-contract §5.1（tab=手术）、§10.1（I类切口分母）、§14.1（今日手术）
-- partition: 生产期按月 RANGE(date)；PK/UQ 含时间键（公约 §5.2）
-- 改造点：+elective_flag（择期/急诊拆分）、+min_invasive（微创占比）、
--        +incision_class（质安 I 类切口手术分母）、status→surg_status（§6.4 命名）、
--        id 单列 PK → (id,date) 复合 PK（分区就绪）、case_no UQ → (case_no,date)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS dwd.surgery_case (
  id             bigint GENERATED ALWAYS AS IDENTITY,
  case_no        varchar(20)  NOT NULL,
  patient_masked varchar(32)  NOT NULL,
  dept_id        bigint       NOT NULL,
  ward_code      varchar(20)  NOT NULL,
  surg_level     smallint     NOT NULL,
  surg_status    varchar(8)   NOT NULL,
  elective_flag  bool         NOT NULL DEFAULT true,
  min_invasive   bool         NOT NULL DEFAULT false,
  incision_class varchar(4),
  plan_start     timestamptz  NOT NULL,
  actual_start   timestamptz,
  actual_end     timestamptz,
  room_no        varchar(8)   NOT NULL,
  date           date         NOT NULL,
  CONSTRAINT pk_surgery_case PRIMARY KEY (id, date),
  CONSTRAINT uq_surgery_case_case_no_date UNIQUE (case_no, date),
  CONSTRAINT fk_surgery_case_department FOREIGN KEY (dept_id) REFERENCES dim.department(id),
  CONSTRAINT fk_surgery_case_ward FOREIGN KEY (ward_code) REFERENCES dim.ward(code),
  CONSTRAINT ck_surgery_case_level CHECK (surg_level BETWEEN 1 AND 4),
  CONSTRAINT ck_surgery_case_status CHECK (surg_status IN ('sched','doing','done','pacu')),
  CONSTRAINT ck_surgery_case_incision CHECK (incision_class IS NULL OR incision_class IN ('I','II','III')),
  CONSTRAINT ck_surgery_case_actual_span CHECK (actual_end IS NULL OR actual_start IS NULL OR actual_end > actual_start),
  -- 状态与时刻列联动：sched 无实际时刻；doing 仅入室；done/pacu 双时刻齐
  CONSTRAINT ck_surgery_case_status_time CHECK (
       (surg_status = 'sched' AND actual_start IS NULL AND actual_end IS NULL)
    OR (surg_status = 'doing' AND actual_start IS NOT NULL AND actual_end IS NULL)
    OR (surg_status IN ('done','pacu') AND actual_start IS NOT NULL AND actual_end IS NOT NULL)
  )
);

COMMENT ON TABLE dwd.surgery_case IS '手术台次事实（一台一行）。写方=仿真器/未来ETL独占；API白名单读：当日realtime计数+L5穿透回溯（v1.1 §1）';
COMMENT ON COLUMN dwd.surgery_case.case_no IS '手术申请/登记号；分区就绪改造为 (case_no,date) 复合唯一';
COMMENT ON COLUMN dwd.surgery_case.patient_masked IS '脱敏患者号 P+6位数字（公约 §5.6 生成即脱敏）';
COMMENT ON COLUMN dwd.surgery_case.dept_id IS '手术科室 dim.department.level=2；FK';
COMMENT ON COLUMN dwd.surgery_case.ward_code IS '手术室虚拟病区 code（dim.ward.ward_type=''or''），楼宇抽屉 today.surg_* join 落点（v1.1 §3）';
COMMENT ON COLUMN dwd.surgery_case.surg_level IS '手术级别 1~4（dict: surgery_level）；三四级占比/SURG_L4 过滤列（契约 §5.1/§13.1）';
COMMENT ON COLUMN dwd.surgery_case.surg_status IS '状态 sched(排程)/doing(术中)/done(完成)/pacu(复苏)（dict: surg_status）；SURG_CNT 口径=status<>''sched''';
COMMENT ON COLUMN dwd.surgery_case.elective_flag IS '择期手术标志：true=择期 false=急诊（G22；契约 §5.1 择期/急诊拆分）';
COMMENT ON COLUMN dwd.surgery_case.min_invasive IS '微创手术标志（G22；MIN_INVASIVE_RATIO 分子，按术式目录判定）';
COMMENT ON COLUMN dwd.surgery_case.incision_class IS '切口等级 I/II/III（dict: incision_class）；NULL=无切口类操作（介入/内镜等），I类切口感染率分母列（契约 §10.1）';
COMMENT ON COLUMN dwd.surgery_case.plan_start IS '排程开始时刻';
COMMENT ON COLUMN dwd.surgery_case.actual_start IS '实际开始（入室）时刻；NULL=未开始（sched）';
COMMENT ON COLUMN dwd.surgery_case.actual_end IS '实际结束（出室）时刻；NULL=进行中（sched/doing）；手术时长=actual_end−actual_start';
COMMENT ON COLUMN dwd.surgery_case.room_no IS '手术间编号（种子 OR-01~OR-06）；手术间利用率=Σ占用台时/Σ(room×开放台时)';
COMMENT ON COLUMN dwd.surgery_case.date IS '手术日 = COALESCE(actual_start,plan_start)::date（一致性由写入方保证，v1.1 继承）；分区键';

-- ----------------------------------------------------------------------------
-- file: backend/migrations/0209_dwd_drg_case.sql  verdict: 改造
-- contract: api-contract §13.1（topic=drg 全块）、§10.1（甲级病案率）、
--           §5.1（术前住院日/四级手术国考口径）、§15（L5穿透预留）
-- partition: 生产期按月 RANGE(discharge_date)；PK/UQ 含时间键（公约 §5.2）
-- 改造点：+mr_grade/admit_path/discharge_type/main_diag_icd/main_oper_icd/
--        vent_hours/rate_type/pay_standard/ungrouped_flag；
--        drg_code 可 NULL（未入组）；emr_json/patient_name 建列缓填；
--        id 单列 PK → (id,discharge_date) 复合 PK；量级 scale-v2 重锚 ~10万行（14月窗）
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS dwd.drg_case (
  id             bigint GENERATED ALWAYS AS IDENTITY,
  case_no        varchar(20)  NOT NULL,
  patient_masked varchar(32)  NOT NULL,
  patient_name   varchar(32),
  gender         char(1)      NOT NULL,
  age            smallint     NOT NULL,
  dept_id        bigint       NOT NULL,
  group_id       bigint,
  attending_id   bigint       NOT NULL,
  drg_code       varchar(16),
  ungrouped_flag bool         NOT NULL DEFAULT false,
  rw             numeric(8,4),
  admit_date     date         NOT NULL,
  discharge_date date         NOT NULL,
  los_days       smallint     NOT NULL,
  admit_path     char(1)      NOT NULL,
  discharge_type char(1)      NOT NULL,
  main_diag_icd  varchar(12)  NOT NULL,
  main_oper_icd  varchar(12),
  vent_hours     numeric(8,1) NOT NULL DEFAULT 0,
  mr_grade       char(1)      NOT NULL,
  surg_level     smallint,
  surg_date      date,
  total_fee      numeric(14,2) NOT NULL,
  drug_fee       numeric(14,2) NOT NULL,
  material_fee   numeric(14,2) NOT NULL,
  exam_fee       numeric(14,2) NOT NULL,
  surg_fee       numeric(14,2) NOT NULL,
  other_fee      numeric(14,2) NOT NULL,
  insurance_pay  numeric(14,2) NOT NULL,
  cost_total     numeric(14,2) NOT NULL,
  profit         numeric(14,2) NOT NULL,
  pay_standard   numeric(14,2),
  rate_type      varchar(8)   NOT NULL,
  death_flag     bool         NOT NULL DEFAULT false,
  readmit15_flag bool         NOT NULL DEFAULT false,
  spec_flag      bool         NOT NULL DEFAULT false,
  emr_json       jsonb,
  CONSTRAINT pk_drg_case PRIMARY KEY (id, discharge_date),
  CONSTRAINT uq_drg_case_case_no_discharge UNIQUE (case_no, discharge_date),
  CONSTRAINT fk_drg_case_department FOREIGN KEY (dept_id) REFERENCES dim.department(id),
  CONSTRAINT fk_drg_case_group FOREIGN KEY (group_id) REFERENCES dim.department(id),
  CONSTRAINT fk_drg_case_attending FOREIGN KEY (attending_id) REFERENCES dim.staff(id),
  CONSTRAINT fk_drg_case_drg_group FOREIGN KEY (drg_code) REFERENCES dim.drg_group(code),
  CONSTRAINT ck_drg_case_gender CHECK (gender IN ('1','2','9')),
  CONSTRAINT ck_drg_case_age CHECK (age BETWEEN 0 AND 120),
  CONSTRAINT ck_drg_case_los CHECK (los_days >= 1),
  CONSTRAINT ck_drg_case_dates CHECK (discharge_date >= admit_date),
  CONSTRAINT ck_drg_case_admit_path CHECK (admit_path IN ('1','2','3','9')),
  CONSTRAINT ck_drg_case_discharge_type CHECK (discharge_type IN ('1','2','3','4','5','9')),
  CONSTRAINT ck_drg_case_mr_grade CHECK (mr_grade IN ('A','B','C')),
  CONSTRAINT ck_drg_case_rate_type CHECK (rate_type IN ('normal','high','low')),
  CONSTRAINT ck_drg_case_surg_level CHECK (surg_level IS NULL OR surg_level BETWEEN 1 AND 4),
  CONSTRAINT ck_drg_case_vent CHECK (vent_hours >= 0),
  CONSTRAINT ck_drg_case_fees_nonneg CHECK (
    total_fee > 0 AND drug_fee >= 0 AND material_fee >= 0 AND exam_fee >= 0
    AND surg_fee >= 0 AND other_fee >= 0 AND insurance_pay >= 0 AND cost_total >= 0),
  -- 费用分项合计=总费用（v1.1 §12-8 同行校验前置为 CHECK）
  CONSTRAINT ck_drg_case_fee_sum CHECK (
    abs(drug_fee + material_fee + exam_fee + surg_fee + other_fee - total_fee) <= 0.01),
  -- 未入组四件套联动（G18）：ungrouped 与 drg_code/rw/pay_standard 同 NULL/同非 NULL
  CONSTRAINT ck_drg_case_ungrouped CHECK (
       (ungrouped_flag AND drg_code IS NULL AND rw IS NULL AND pay_standard IS NULL)
    OR (NOT ungrouped_flag AND drg_code IS NOT NULL AND rw IS NOT NULL AND pay_standard IS NOT NULL)),
  -- 手术三件套联动：非手术患者 surg_level/surg_date/main_oper_icd 全 NULL
  CONSTRAINT ck_drg_case_surg_consist CHECK (
       ((surg_level IS NULL) = (surg_date IS NULL))
    AND ((surg_level IS NULL) = (main_oper_icd IS NULL))
    AND (surg_date IS NULL OR (surg_date >= admit_date AND surg_date <= discharge_date))),
  -- 死亡与离院方式等价（病案首页口径：5=死亡）
  CONSTRAINT ck_drg_case_death CHECK (death_flag = (discharge_type = '5'))
);

COMMENT ON TABLE dwd.drg_case IS '病案首页/DRG结算病例（一次出院结算一行，含全部出院病例量级）。写方=仿真器/未来ETL；API白名单读：L5病例穿透；质安域 mr_grade 数据源';
COMMENT ON COLUMN dwd.drg_case.case_no IS '病案结算号；(case_no,discharge_date) 复合唯一（分区就绪）';
COMMENT ON COLUMN dwd.drg_case.patient_masked IS '脱敏患者号 P+6位数字';
COMMENT ON COLUMN dwd.drg_case.patient_name IS '实名（建列缓填，仿真期 NULL=masked；真实期 ETL 写入，?unmask=1 唯一数据源，硬伤 H9/U9）';
COMMENT ON COLUMN dwd.drg_case.gender IS 'GB/T 2261.1：1男 2女 9未说明';
COMMENT ON COLUMN dwd.drg_case.group_id IS '医疗组 dim.department.level=3；NULL=科室未分医疗组（真空值，API出 null）';
COMMENT ON COLUMN dwd.drg_case.attending_id IS '主治医师 dim.staff.id（doctor 字段来源）';
COMMENT ON COLUMN dwd.drg_case.drg_code IS '入组 DRG（dim.drg_group.code）；NULL=未入组（与 ungrouped_flag 联动）';
COMMENT ON COLUMN dwd.drg_case.ungrouped_flag IS '未入组标志（G18）；入组率=1−Σungrouped/N（契约 §13.1 锚 98.5%）';
COMMENT ON COLUMN dwd.drg_case.rw IS '病例权重=drg_group.rw 快照；CMI 分子；未入组 NULL';
COMMENT ON COLUMN dwd.drg_case.los_days IS '住院天数（算头不算尾，当天入出计1）；ALOS/PREOP_ALOS 分母系';
COMMENT ON COLUMN dwd.drg_case.admit_path IS '入院途径 1门诊/2急诊/3其他机构转入/9其他（dict: admit_path；病案首页口径）';
COMMENT ON COLUMN dwd.drg_case.discharge_type IS '离院方式 1医嘱/2医嘱转院/3转社区/4非医嘱/5死亡/9其他（dict: discharge_type；与 death_flag 等价联动）';
COMMENT ON COLUMN dwd.drg_case.main_diag_icd IS '主要诊断 医保版 ICD-10（CHS-DRG 分组器必备输入，calibration §2.1）';
COMMENT ON COLUMN dwd.drg_case.main_oper_icd IS '主要手术操作 医保版 ICD-9-CM-3；NULL=非手术病例';
COMMENT ON COLUMN dwd.drg_case.vent_hours IS '呼吸机使用时长·小时；≥96h 触发 MDCA 先期分组（医保办发〔2019〕36号）';
COMMENT ON COLUMN dwd.drg_case.mr_grade IS '病案质量等级 A甲/B乙/C丙（dict: mr_grade）；甲级病案率=ΣA/N（契约 §10.1 锚 98.6%）';
COMMENT ON COLUMN dwd.drg_case.surg_level IS '本例最高手术级别 1~4；国考#6 出院患者四级手术比例分子；NULL=非手术';
COMMENT ON COLUMN dwd.drg_case.surg_date IS '手术日期；preop_alos=surg_date−admit_date；NULL=非手术';
COMMENT ON COLUMN dwd.drg_case.total_fee IS '住院总费用·元';
COMMENT ON COLUMN dwd.drg_case.drug_fee IS '药品费·元（fee_cat=drug 归集）';
COMMENT ON COLUMN dwd.drg_case.material_fee IS '卫生材料费·元（fee_cat=material）';
COMMENT ON COLUMN dwd.drg_case.exam_fee IS '检查化验费·元（fee_cat=exam）';
COMMENT ON COLUMN dwd.drg_case.surg_fee IS '手术治疗费·元（fee_cat=surg）';
COMMENT ON COLUMN dwd.drg_case.other_fee IS '其他费用·元（treat/bed/other 归并桶；分项合计=total_fee 由 CHECK 保证）';
COMMENT ON COLUMN dwd.drg_case.insurance_pay IS '医保结算支付额·元（normal 例≈pay_standard×基金分担比；高低倍率/未入组按项目付费折算）';
COMMENT ON COLUMN dwd.drg_case.cost_total IS '病例成本·元；DRG盈亏分母侧';
COMMENT ON COLUMN dwd.drg_case.profit IS 'DRG结余=insurance_pay−cost_total·元（可负；契约 profit 万元出参由 API ÷10000；科室锚点 骨科+124.6万/神外−12.8万）';
COMMENT ON COLUMN dwd.drg_case.pay_standard IS 'DRG支付标准·元=rw×费率（倍率判定基准）；未入组 NULL';
COMMENT ON COLUMN dwd.drg_case.rate_type IS '倍率分型 normal/high/low（dict: rate_type）；high=费用>2.0×标准、low=<0.5×标准（calibration §2.2 经办细则口径）';
COMMENT ON COLUMN dwd.drg_case.death_flag IS '住院死亡标志；低风险组死亡率分子（与 drg_group.risk_level 联算）';
COMMENT ON COLUMN dwd.drg_case.readmit15_flag IS '出院后15日内再入院标志（READMIT_15D_RATE）';
COMMENT ON COLUMN dwd.drg_case.spec_flag IS '特例单议候选标志（≤统筹区5%口径，医保办发〔2024〕9号）';
COMMENT ON COLUMN dwd.drg_case.emr_json IS '脱敏结构化病案（建列缓填；仅 L5 展示载荷，不承担过滤）';

-- ----------------------------------------------------------------------------
-- 索引（indexes.md）：月度扫描走 PK 分区键前缀；科室/病组/病案等级下钻补 btree；
-- 状态/医疗组/医师下钻为修复轮补建（audit G-idx）
-- ----------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_surgcase_dept_date   ON dwd.surgery_case (dept_id, date);
CREATE INDEX IF NOT EXISTS idx_surgcase_room_date   ON dwd.surgery_case (date, room_no, plan_start);
CREATE INDEX IF NOT EXISTS idx_surgcase_status_date ON dwd.surgery_case (surg_status, date);
CREATE INDEX IF NOT EXISTS idx_drgcase_dept_disch   ON dwd.drg_case (dept_id, discharge_date);
CREATE INDEX IF NOT EXISTS idx_drgcase_group_disch  ON dwd.drg_case (drg_code, discharge_date);
CREATE INDEX IF NOT EXISTS idx_drgcase_medgroup     ON dwd.drg_case (group_id);
CREATE INDEX IF NOT EXISTS idx_drgcase_attending    ON dwd.drg_case (attending_id);
CREATE INDEX IF NOT EXISTS idx_drgcase_mrgrade      ON dwd.drg_case (mr_grade, discharge_date);
