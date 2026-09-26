-- ============================================================================
-- lane L8c/L8d/L8e newdom-pat-qual-asset — DDL 段
--   migrations: 0110 / 0210 / 0211 / 0212 / 0213 / 0216 / 0217 / 0218 / 0307 / 0308
-- 依据：conventions.md §1/§2/§5/§6、plan.md §3/§4、schema-inheritance G7/G10~G15、
--       database-schema.md v1.1（critical_value/device_run_day 继承骨架）
-- 口径：金额 numeric(14,2) 元（新列 _amt 后缀）；率 numeric(7,4) 存 0~1；
--       时刻 timestamptz；日粒度 date；周期=period_type+period_start 二元组。
-- 分区就绪：全部事实表 PK 含时间键（公约 §5.2）；P0 不建分区，生产期按月 RANGE。
-- 字典纪律：冻结集内枚举（feedback_*/adverse_cat/energy_type/incision_class）同值域
--           CHECK 落表；冻结集外枚举（crit_status/crit_item/inf_site/adverse_level/
--           wo_type/wo_status/material_cat/material_unit/qar_rule）本表内 CHECK 兜底，
--           dict_type 追加经 open-items 上报（公约 §2.4.3：lane 不得自建 dict_type）。
-- 幂等：schema/table/index 全部 IF NOT EXISTS（审计 E1/E2 修复，乱序/重复 apply 安全）。
-- ============================================================================

CREATE SCHEMA IF NOT EXISTS dim;
CREATE SCHEMA IF NOT EXISTS dwd;
CREATE SCHEMA IF NOT EXISTS dws;

-- ----------------------------------------------------------------------------
-- file: migrations/0110_dim_material.sql  lane: L8e  verdict: 新建·提前(继承分析#17/G13)
-- contract: api-contract §11.1 stock_alerts（name/days/level 源）+ stats 库存周转天数
-- depends : 无（主数据维表；枚举值域本文件 CHECK 兜底）
-- partition: 不适用（维表）
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS dim.material (
  id              bigint         GENERATED ALWAYS AS IDENTITY,
  code            varchar(20)    NOT NULL,
  name            varchar(64)    NOT NULL,
  mcategory       varchar(16)    NOT NULL,          -- 耗材类目 7 键（dict_type=material_cat 待注册）
  spec            varchar(64),                      -- 规格型号；业务真空可空（主档未录入）
  unit            varchar(12)    NOT NULL,          -- 计量单位 ASCII 键（dict_type=material_unit 待注册，label 中文；审计 m9 建议键换 ASCII）
  unit_price_amt  numeric(14,2)  NOT NULL,          -- 参考单价·元（库存额/日均消耗额要素）
  high_value_flag boolean        NOT NULL DEFAULT false, -- 高值耗材标志
  warn_days       smallint       NOT NULL DEFAULT 28,    -- 库存可用天数预警阈值·天
  active          boolean        NOT NULL DEFAULT true,
  CONSTRAINT pk_material PRIMARY KEY (id),
  CONSTRAINT uq_material_code UNIQUE (code),
  CONSTRAINT ck_material_cat CHECK (mcategory IN ('common','implant','reagent','suture','catheter','sterile','other')),
  CONSTRAINT ck_material_unit CHECK (unit IN ('pcs','tube','box','set','btl','pack','item','strip','pair','stick','tab')),
  CONSTRAINT ck_material_amt CHECK (unit_price_amt >= 0),
  CONSTRAINT ck_material_warn CHECK (warn_days >= 0)
);
COMMENT ON TABLE  dim.material IS '医用耗材/物资主档（v1.1 缓建 → G13 提前：stock_alerts 首版需要）；库存可用天数=dwd.material_stock_day.onhand_qty/avg_daily_use 派生不落列';
COMMENT ON COLUMN dim.material.mcategory IS '耗材类目：common 普通耗材/implant 植入物/reagent 试剂造影/suture 缝合材料/catheter 导管/sterile 无菌防护/other（dict_type=material_cat 待冻结集追加）';
COMMENT ON COLUMN dim.material.spec IS '规格型号文本；NULL=主档未录入（业务真空），API 出参省略';
COMMENT ON COLUMN dim.material.unit_price_amt IS '参考单价·元；库存额=Σ(onhand×price)、日均消耗额=Σ(avg_daily_use×price)，STOCK_TURN_DAYS 两要素';
COMMENT ON COLUMN dim.material.high_value_flag IS '高值医用耗材标志（国考增1"重点监控高值耗材收入占比"归集口径，calibration §4）';
COMMENT ON COLUMN dim.material.warn_days IS '库存可用天数预警阈值·天；stock_alerts level 判定规则：days≥40→urgent，28≤days<40→major，days>warn_days 入预警列表（见 README 映射）';
COMMENT ON COLUMN dim.material.active IS '在用标志；停用/淘汰物资 active=false 不删行（历史库存行保留）';

CREATE INDEX IF NOT EXISTS idx_material_cat ON dim.material (mcategory);

-- ----------------------------------------------------------------------------
-- file: migrations/0210_dwd_critical_value.sql  lane: L8d  verdict: 继承·提前(P2→P0)
-- contract: api-contract §10.1 stats 危急值处理及时率 99.1%；§13.2 settings 阈值
--           "危急值超时率（及时率<95%）"；alert CRIT_UNCLOSED_30M/CRIT_TIMEOUT_95 事实溯源
-- depends : dim.department (L2)
-- partition: 生产期按月 RANGE(report_at)
-- 口径钉死：及时=已闭环且 close_at−report_at ≤ 30min（与 CRIT_UNCLOSED_30M 窗口同源）；
--           CRIT_TIMELY_RATE=及时闭环数/已闭环数（open 行不进分母，由 CRIT_UNCLOSED 单列监控）。
--           v1.1 列形沿用；status→cv_status（公约 §6.4 分域命名）。
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS dwd.critical_value (
  id             bigint        GENERATED ALWAYS AS IDENTITY,
  patient_masked varchar(32)   NOT NULL,          -- 脱敏患者号 P+6位
  item           varchar(32)   NOT NULL,          -- 危急值项目名（LIS 项目目录快照）
  result_value   varchar(64)   NOT NULL,          -- 结果值文本（含单位，异构不拆列）
  dept_id        bigint        NOT NULL,          -- 患者所在/处置科室
  report_at      timestamptz   NOT NULL,          -- 检验/检查系统报出时刻
  notice_at      timestamptz   NOT NULL,          -- 通知临床接收时刻
  close_at       timestamptz,                     -- 处置闭环时刻；NULL=未闭环
  cv_status      varchar(8)    NOT NULL DEFAULT 'open', -- 闭环状态 open/closed（dict crit_status 待注册）
  CONSTRAINT pk_critical_value PRIMARY KEY (id, report_at),
  CONSTRAINT fk_critical_value_department FOREIGN KEY (dept_id) REFERENCES dim.department (id),
  CONSTRAINT ck_critical_value_status CHECK (cv_status IN ('open','closed')),
  CONSTRAINT ck_critical_value_notice CHECK (notice_at >= report_at),
  CONSTRAINT ck_critical_value_close  CHECK (close_at IS NULL OR close_at >= report_at),
  -- 状态-时刻联动：closed 必有 close_at，open 恒无
  CONSTRAINT ck_critical_value_status_close CHECK (
       (cv_status = 'closed' AND close_at IS NOT NULL)
    OR (cv_status = 'open'   AND close_at IS NULL))
);
COMMENT ON TABLE  dwd.critical_value IS '危急值全流程事实（报出→通知→处置闭环）；v1.1 P2 提前启用：契约 §10.1 危急值处理及时率 99.1% 为 P0 指标；dws.critical_unclosed 底数';
COMMENT ON COLUMN dwd.critical_value.item IS '危急值项目目录快照（血钾/血红蛋白/肌钙蛋白/血小板等）；dict_type=crit_item 待注册（open-item）';
COMMENT ON COLUMN dwd.critical_value.result_value IS '检验/检查结果文本（数值+单位原样，如 6.8 mmol/L）；展示直读，不承担过滤';
COMMENT ON COLUMN dwd.critical_value.dept_id IS '患者所在科室（接收科室）；按科室及时率过滤列';
COMMENT ON COLUMN dwd.critical_value.report_at IS '危急值报出时刻；分区键；CRIT_TIMELY_RATE 时间零点';
COMMENT ON COLUMN dwd.critical_value.notice_at IS '通知临床接收时刻；report→notice 段为报告时限子指标预留';
COMMENT ON COLUMN dwd.critical_value.close_at IS '处置闭环时刻；NULL=未闭环（cv_status=open，迟到数据语义）';
COMMENT ON COLUMN dwd.critical_value.cv_status IS 'open/closed；与 close_at 联动由 CHECK 物理保证（五态前端流转词 dict=crit_status 待注册）';

CREATE INDEX IF NOT EXISTS idx_critical_value_dept_time ON dwd.critical_value (dept_id, report_at);
CREATE INDEX IF NOT EXISTS idx_critical_value_open      ON dwd.critical_value (report_at) WHERE cv_status = 'open';

-- ----------------------------------------------------------------------------
-- file: migrations/0211_dwd_infection_case.sql  lane: L8d  verdict: 新建(G10)
-- contract: api-contract §10.1 stats 院感发生率 1.24% + infection_trend（6点 2.2→1.8
--           越线回控剧情）+ stats I类切口感染率 0.38%（分子=ssi_flag∧incision_class='I'）
-- depends : dim.department (L2)；切口分母由 L4 surgery_case.incision_class 供给
--           （plan §1：只锁列形态约定，不等 L4 种子）
-- partition: 生产期按月 RANGE(confirm_date)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS dwd.infection_case (
  id             bigint        GENERATED ALWAYS AS IDENTITY,
  patient_masked varchar(32)   NOT NULL,          -- 脱敏患者号
  dept_id        bigint        NOT NULL,          -- 院感归属科室（确诊时所在科室）
  confirm_date   date          NOT NULL,          -- 院感确诊日期
  inf_site       varchar(16)   NOT NULL,          -- 感染部位 7 键（dict inf_site 待注册）
  ssi_flag       boolean       NOT NULL DEFAULT false, -- 手术部位感染标志（SSI）
  incision_class varchar(4),                      -- 手术切口等级 I/II/III；NULL=非 SSI
  CONSTRAINT pk_infection_case PRIMARY KEY (id, confirm_date),
  CONSTRAINT fk_infection_case_department FOREIGN KEY (dept_id) REFERENCES dim.department (id),
  CONSTRAINT ck_infection_case_site CHECK (inf_site IN ('resp','urinary','blood','ssi','gi','skin','other')),
  CONSTRAINT ck_infection_case_incision CHECK (incision_class IS NULL OR incision_class IN ('I','II','III')),
  -- 部位联动：ssi_flag ⇔ inf_site='ssi' ⇔ incision_class 非空（三态一致）
  CONSTRAINT ck_infection_case_ssi CHECK (
       ssi_flag = (inf_site = 'ssi') AND ssi_flag = (incision_class IS NOT NULL))
);
COMMENT ON TABLE  dwd.infection_case IS '院内感染确诊逐例事实；HAI_RATE=当月确诊数/当月出院人数（公约 §3.4 分母裁决，官方惯用住院日口径见 open-item）；INCISION1_INF_RATE 分子=SSI 且切口 I 类';
COMMENT ON COLUMN dwd.infection_case.confirm_date IS '院感确诊日期（报告口径）；分区键；infection_trend 月度归属轴';
COMMENT ON COLUMN dwd.infection_case.inf_site IS '感染部位：resp 呼吸道/urinary 泌尿道/blood 血流/ssi 手术部位/gi 消化道/skin 皮肤/other（dict_type=inf_site 待注册）';
COMMENT ON COLUMN dwd.infection_case.ssi_flag IS '手术部位感染标志；与 inf_site=''ssi''、incision_class 非空三者联动（CHECK 钉死）';
COMMENT ON COLUMN dwd.infection_case.incision_class IS '手术切口等级 I/II/III（dict incision_class，与 L4 surgery_case 同值域）；NULL=非手术部位感染（不适用语义）';

CREATE INDEX IF NOT EXISTS idx_infection_case_date      ON dwd.infection_case (confirm_date);
CREATE INDEX IF NOT EXISTS idx_infection_case_dept_date ON dwd.infection_case (dept_id, confirm_date);
CREATE INDEX IF NOT EXISTS idx_infection_case_ssi       ON dwd.infection_case (incision_class, confirm_date) WHERE ssi_flag;

-- ----------------------------------------------------------------------------
-- file: migrations/0212_dwd_adverse_event.sql  lane: L8d  verdict: 新建(G11)
-- contract: api-contract §10.1 adverse_events 7 类分布 + stats 不良事件上报数 36 起
--           （百床 1.95 = 月事件数/当期平均占用床×100，见 open-item 分母口径）
-- depends : dim.department (L2)
-- partition: 生产期按月 RANGE(event_date)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS dwd.adverse_event (
  id             bigint        GENERATED ALWAYS AS IDENTITY,
  event_date     date          NOT NULL,          -- 事件发生日期
  dept_id        bigint        NOT NULL,          -- 上报/责任科室
  adverse_cat    varchar(16)   NOT NULL,          -- dict adverse_cat 7 类
  event_level    smallint      NOT NULL,          -- 不良事件分级 I~IV（dict adverse_level 待注册）
  patient_masked varchar(32),                     -- 涉事患者（脱敏）；NULL=无明确患者
  event_desc     varchar(200)  NOT NULL,          -- 事件简述
  CONSTRAINT pk_adverse_event PRIMARY KEY (id, event_date),
  CONSTRAINT fk_adverse_event_department FOREIGN KEY (dept_id) REFERENCES dim.department (id),
  CONSTRAINT ck_adverse_event_cat CHECK (adverse_cat IN ('fall','med_error','tube_slip','pressure_ulcer','surg_related','transfusion','other')),
  CONSTRAINT ck_adverse_event_level CHECK (event_level BETWEEN 1 AND 4)
);
COMMENT ON TABLE  dwd.adverse_event IS '医疗安全不良事件上报事实（契约 7 分类体系）；ADVERSE_EVENT_CNT/ADVERSE_PER_100BED 分子源';
COMMENT ON COLUMN dwd.adverse_event.adverse_cat IS '事件分类：fall 跌倒坠床/med_error 用药错误/tube_slip 管路滑脱/pressure_ulcer 院内压疮/surg_related 手术相关/transfusion 输血相关/other';
COMMENT ON COLUMN dwd.adverse_event.event_level IS '分级 1=I级警告事件 2=II级不良后果 3=III级未造成后果 4=IV级隐患事件（卫健委不良事件分级口径）';
COMMENT ON COLUMN dwd.adverse_event.patient_masked IS '涉事患者脱敏号；NULL=无明确涉事患者（设备/环境/流程类事件，不适用语义）';

CREATE INDEX IF NOT EXISTS idx_adverse_event_date      ON dwd.adverse_event (event_date);
CREATE INDEX IF NOT EXISTS idx_adverse_event_dept_date ON dwd.adverse_event (dept_id, event_date);
CREATE INDEX IF NOT EXISTS idx_adverse_event_cat_date  ON dwd.adverse_event (adverse_cat, event_date);

-- ----------------------------------------------------------------------------
-- file: migrations/0213_dwd_feedback_event.sql  lane: L8c  verdict: 新建(G7)
-- contract: api-contract §9.1 complaints_praises（date/type/dept/channel/content/
--           status/score 全列）+ stats 本月投诉 24/本月表扬 86
-- depends : dim.department (L2，含 level=1 职能科室——护理部/门诊部/后勤保障部等投诉对象)
-- partition: 生产期按月 RANGE(event_date)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS dwd.feedback_event (
  id             bigint        GENERATED ALWAYS AS IDENTITY,
  event_date     date          NOT NULL,          -- 受理日期
  fb_type        varchar(10)   NOT NULL,          -- dict feedback_type：complaint/praise
  dept_id        bigint        NOT NULL,          -- 涉及科室
  fb_channel     varchar(16)   NOT NULL,          -- dict feedback_channel 6 键（分域命名 fb_*，审计 m4 同键异义修复）
  content        text          NOT NULL,          -- 反映内容
  fb_status      varchar(12)   NOT NULL DEFAULT 'pending',      -- dict feedback_status 五态
  visit_eval     varchar(16)   NOT NULL DEFAULT 'pending_eval', -- dict feedback_score 回访评价（枚举非数值→_eval 命名，审计 m5）
  CONSTRAINT pk_feedback_event PRIMARY KEY (id, event_date),
  CONSTRAINT fk_feedback_event_department FOREIGN KEY (dept_id) REFERENCES dim.department (id),
  CONSTRAINT ck_feedback_event_type CHECK (fb_type IN ('complaint','praise')),
  CONSTRAINT ck_feedback_event_channel CHECK (fb_channel IN ('hotline_12345','suggestion_box','phone','miniapp','onsite','other')),
  CONSTRAINT ck_feedback_event_status CHECK (fb_status IN ('pending','processing','rectified','closed','archived')),
  CONSTRAINT ck_feedback_event_score CHECK (visit_eval IN ('very_satisfied','satisfied','fair','pending_eval'))
);
COMMENT ON TABLE  dwd.feedback_event IS '投诉/表扬台账（受理→核实→整改→办结→归档 五态流转）；契约 complaints_praises 行无 id，本表 (id,event_date) 技术主键承载（分区就绪+U3 兼容）';
COMMENT ON COLUMN dwd.feedback_event.fb_type IS 'complaint 投诉/praise 表扬（dict feedback_type；契约 type 列中文出参走 dict_label）';
COMMENT ON COLUMN dwd.feedback_event.dept_id IS '涉及科室；允许 level=1 职能行（门诊部/护理部/后勤保障部为契约样例投诉对象）';
COMMENT ON COLUMN dwd.feedback_event.fb_channel IS '受理渠道：hotline_12345/suggestion_box/phone/miniapp/onsite/other（dict feedback_channel；API 出参键名仍为 channel）';
COMMENT ON COLUMN dwd.feedback_event.fb_status IS '五态：pending 待核实/processing 处理中/rectified 已整改/closed 已办结/archived 已归档（dict feedback_status）';
COMMENT ON COLUMN dwd.feedback_event.visit_eval IS '回访评价：very_satisfied/satisfied/fair/pending_eval（dict feedback_score）；pending_eval=未回访（契约"待评价"原值；API 出参键名仍为 score）';

CREATE INDEX IF NOT EXISTS idx_feedback_event_date       ON dwd.feedback_event (event_date);
CREATE INDEX IF NOT EXISTS idx_feedback_event_dept_date  ON dwd.feedback_event (dept_id, event_date);
CREATE INDEX IF NOT EXISTS idx_feedback_event_type_date  ON dwd.feedback_event (fb_type, event_date);
CREATE INDEX IF NOT EXISTS idx_feedback_event_status     ON dwd.feedback_event (fb_status, event_date);

-- ----------------------------------------------------------------------------
-- file: migrations/0216_dwd_device_run_day.sql  lane: L8e  verdict: 继承·提前(P2→P0)
-- contract: api-contract §11.1 large_equipments（open_rate/monthly/income/roi 全列）
--           + stats 设备开机率 94.2%；settings 阈值"设备开机率<60%"；POSITIVE_RATE 落点
-- depends : dim.device (L2，68 台种子锚点)
-- partition: 生产期按月 RANGE(date)
-- 改造点：v1.1 income→income_amt、opex_total→opex_amt（公约 §1.1 金额 _amt 统一）；
--        +plan_hours 可用机时分母（EQUIP_RUN_RATE=Σrun/Σplan 可算化；open-item 记录改名）
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS dwd.device_run_day (
  date         date          NOT NULL,            -- 运行日
  device_code  varchar(20)   NOT NULL,            -- 设备码 dim.device.code
  plan_hours   numeric(6,2)  NOT NULL DEFAULT 0,  -- 当日排班可用机时·h（维保/停用日=0）
  run_hours    numeric(6,2)  NOT NULL DEFAULT 0,  -- 实际开机时长·h
  exam_cnt     int           NOT NULL DEFAULT 0,  -- 检查/治疗人次
  positive_cnt int           NOT NULL DEFAULT 0,  -- 阳性人次
  income_amt   numeric(14,2) NOT NULL DEFAULT 0,  -- 当日创收·元
  opex_amt     numeric(14,2) NOT NULL DEFAULT 0,  -- 当日运营成本·元（折旧+维保+能耗+人力分摊）
  CONSTRAINT pk_device_run_day PRIMARY KEY (date, device_code),
  CONSTRAINT fk_device_run_day_device FOREIGN KEY (device_code) REFERENCES dim.device (code),
  CONSTRAINT ck_device_run_day_hours CHECK (plan_hours >= 0 AND plan_hours <= 24 AND run_hours >= 0 AND run_hours <= 24),
  CONSTRAINT ck_device_run_day_cnt CHECK (exam_cnt >= 0 AND positive_cnt >= 0 AND positive_cnt <= exam_cnt),
  CONSTRAINT ck_device_run_day_amt CHECK (income_amt >= 0 AND opex_amt >= 0)
);
COMMENT ON TABLE  dwd.device_run_day IS '大型设备运行日事实（每台每日一行）；契约 §11.1 large_equipments 与开机率唯一事实源；v1.1 P2→P0 提前';
COMMENT ON COLUMN dwd.device_run_day.plan_hours IS '当日排班可用机时·h（开机率分母）；维保/停用日=0（业务真空：当日不可用时段不摊薄分子）';
COMMENT ON COLUMN dwd.device_run_day.run_hours IS '实际开机时长·h；允许 >plan_hours（加班超用，护栏 ≤24）';
COMMENT ON COLUMN dwd.device_run_day.positive_cnt IS '检查阳性人次；POSITIVE_RATE=Σpositive_cnt/Σexam_cnt';
COMMENT ON COLUMN dwd.device_run_day.income_amt IS '当日设备创收·元（v1.1 income→_amt 改名）；契约月创收列=Σ÷1e4 万元出参';
COMMENT ON COLUMN dwd.device_run_day.opex_amt IS '当日运营成本·元（v1.1 opex_total→_amt 改名）；ROI=Σincome/Σopex，分级映射 roi_level 见 README';

CREATE INDEX IF NOT EXISTS idx_device_run_day_dev_date ON dwd.device_run_day (device_code, date);

-- ----------------------------------------------------------------------------
-- file: migrations/0217_dwd_material_stock_day.sql  lane: L8e  verdict: 新建(G13)
-- contract: api-contract §11.1 stock_alerts（6 行：name/days=库存可用天数/level）
--           + stats 库存周转天数 28 天；alert STOCK_TURN_SLOW 事实源
-- depends : dim.material (本 lane 0110)
-- partition: 生产期按月 RANGE(date)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS dwd.material_stock_day (
  date          date          NOT NULL,           -- 快照日（日终结存口径）
  material_code varchar(20)   NOT NULL,           -- 物资码 dim.material.code
  onhand_qty    int           NOT NULL DEFAULT 0, -- 当日结存数量
  avg_daily_use numeric(12,2) NOT NULL DEFAULT 0, -- 近 30 日滑动平均日用量
  CONSTRAINT pk_material_stock_day PRIMARY KEY (date, material_code),
  CONSTRAINT fk_material_stock_day_material FOREIGN KEY (material_code) REFERENCES dim.material (code),
  CONSTRAINT ck_material_stock_day_nonneg CHECK (onhand_qty >= 0 AND avg_daily_use >= 0)
);
COMMENT ON TABLE  dwd.material_stock_day IS '物资库存日态快照；stock_days=onhand_qty/avg_daily_use 查询时派生（一数一源不落列）；stock_alerts level：days≥40→urgent/≥28→major/>warn_days→minor';
COMMENT ON COLUMN dwd.material_stock_day.avg_daily_use IS '滑动 30 日均耗（SPD 口径）；院级周转天数 STOCK_TURN_DAYS=Σ(onhand×price)/Σ(avg_daily_use×price)';

CREATE INDEX IF NOT EXISTS idx_material_stock_day_mat ON dwd.material_stock_day (material_code, date);

-- ----------------------------------------------------------------------------
-- file: migrations/0218_dwd_logistics_order.sql  lane: L8e  verdict: 新建(G15)
-- contract: api-contract §11.1 stats 后勤工单（本月 156 单/完结率 92%）
-- depends : dim.department (L2)
-- partition: 生产期按月 RANGE(created_at)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS dwd.logistics_order (
  id          bigint       GENERATED ALWAYS AS IDENTITY,
  wo_type     varchar(16)  NOT NULL,              -- 工单类型 5 键（dict wo_type 待注册）
  wo_status   varchar(12)  NOT NULL,              -- 工单状态 4 键（dict wo_status 待注册）
  dept_id     bigint       NOT NULL,              -- 报修/归口科室
  created_at  timestamptz  NOT NULL,              -- 建单时刻
  finished_at timestamptz,                         -- 完结时刻；NULL=未完结
  CONSTRAINT pk_logistics_order PRIMARY KEY (id, created_at),
  CONSTRAINT fk_logistics_order_department FOREIGN KEY (dept_id) REFERENCES dim.department (id),
  CONSTRAINT ck_logistics_order_type CHECK (wo_type IN ('repair','maintain','clean','transport','other')),
  CONSTRAINT ck_logistics_order_status CHECK (wo_status IN ('open','doing','done','cancelled')),
  CONSTRAINT ck_logistics_order_time CHECK (finished_at IS NULL OR finished_at >= created_at),
  -- 状态-时刻联动：done 必带完结时刻；open/doing/cancelled 恒无（cancelled 不记完结时刻）
  CONSTRAINT ck_logistics_order_status_time CHECK (
       (wo_status = 'done' AND finished_at IS NOT NULL)
    OR (wo_status <> 'done' AND finished_at IS NULL))
);
COMMENT ON TABLE  dwd.logistics_order IS '后勤工单事实（报修/维保/保洁/运送/其他）；WORK_ORDER_CNT/WORK_ORDER_DONE_RATE 事实源';
COMMENT ON COLUMN dwd.logistics_order.wo_type IS 'repair 维修/maintain 维保/clean 保洁/transport 运送/other（dict_type=wo_type 待注册）';
COMMENT ON COLUMN dwd.logistics_order.wo_status IS 'open 待接单/doing 处理中/done 已完结/cancelled 已取消（dict_type=wo_status 待注册）';
COMMENT ON COLUMN dwd.logistics_order.finished_at IS '完结时刻；仅 done 行有值，其余状态恒 NULL（未发生语义；cancelled 撤单不记完结时刻）';

CREATE INDEX IF NOT EXISTS idx_logistics_order_created   ON dwd.logistics_order (created_at);
CREATE INDEX IF NOT EXISTS idx_logistics_order_dept_time ON dwd.logistics_order (dept_id, created_at);
CREATE INDEX IF NOT EXISTS idx_logistics_order_open      ON dwd.logistics_order (created_at) WHERE wo_status IN ('open','doing');

-- ----------------------------------------------------------------------------
-- file: migrations/0307_dws_quality_rule_audit.sql  lane: L8d  verdict: 新建(G12)
-- contract: api-contract §10.1 rules_compliance（8 项核心制度抽检：name/sample/pass/
--           rate/issues；契约注 rate=pass/sample×100% 派生不落列）
-- depends : 无（rule_code 表内 CHECK；dict qar_rule 待注册）
-- partition: 不列入分区预案（周期汇总小表）
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS dws.quality_rule_audit (
  period_type  varchar(8)   NOT NULL,             -- 抽检周期粒度（本表只用 month/quarter）
  period_start date         NOT NULL,             -- 周期首日
  rule_code    varchar(24)  NOT NULL,             -- 制度编码 8 键
  rule_name    varchar(40)  NOT NULL,             -- 制度名称（当期快照；契约 name 列直出）
  sample_cnt   int          NOT NULL DEFAULT 0,   -- 抽检例数（契约 sample）
  pass_cnt     int          NOT NULL DEFAULT 0,   -- 合格例数（契约 pass；≤sample_cnt）
  issues       text,                              -- 主要问题描述；NULL=本期无记录问题
  CONSTRAINT pk_quality_rule_audit PRIMARY KEY (period_type, period_start, rule_code),
  CONSTRAINT ck_quality_rule_audit_period CHECK (period_type IN ('month','quarter')),
  CONSTRAINT ck_quality_rule_audit_rule CHECK (rule_code IN ('first_visit','ward_round','consult','crit_report','surg_check','mr_write','abx_class','shift_hand')),
  CONSTRAINT ck_quality_rule_audit_cnt CHECK (sample_cnt >= 0 AND pass_cnt >= 0 AND pass_cnt <= sample_cnt)
);
COMMENT ON TABLE  dws.quality_rule_audit IS '核心制度抽检周期表（十八项制度首版覆盖契约 8 项）；执行合规率=pass_cnt/sample_cnt 派生（契约注：rate=pass/sample*100%）';
COMMENT ON COLUMN dws.quality_rule_audit.rule_code IS 'first_visit 首诊负责/ward_round 三级查房/consult 会诊/crit_report 危急值报告/surg_check 手术安全核查/mr_write 病历书写/abx_class 抗菌药物分级/shift_hand 值班交接班（dict_type=qar_rule 待注册）';
COMMENT ON COLUMN dws.quality_rule_audit.rule_name IS '制度名当期快照（dict 未注册期由本列直供契约 name；注册后 join dict_label 出参）';
COMMENT ON COLUMN dws.quality_rule_audit.issues IS '主要问题文本；NULL=本期抽检无记录问题（业务真空）';

CREATE INDEX IF NOT EXISTS idx_quality_rule_audit_rule ON dws.quality_rule_audit (rule_code, period_start);

-- ----------------------------------------------------------------------------
-- file: migrations/0308_dws_energy_month.sql  lane: L8e  verdict: 新建(G14)
-- contract: api-contract §11.1 energy_trend（electricity/water/gas 3 分项 + total）
--           + stats 本月能耗费用 186（万元出参）；国考#34 万元收入能耗支出分子
-- depends : 无（energy_type dict 已冻结）
-- partition: 不列入分区预案（月汇总小表）
-- 一数一源：分项为正源、total=Σenergy_type 派生不落行（契约 total 序列与分项和
--           5/6 月不等 → open-item 记录，库侧不存重复口径）
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS dws.energy_month (
  period_type  varchar(8)    NOT NULL DEFAULT 'month',
  period_start date          NOT NULL,            -- 月份首日
  energy_type  varchar(16)   NOT NULL,            -- dict energy_type：electricity/water/gas
  energy_amt   numeric(14,2) NOT NULL DEFAULT 0,  -- 能耗费用·元（契约万元出参 ÷1e4）
  energy_qty   numeric(14,2),                     -- 用量（kWh/吨/m³，随 type 释义）；NULL=未采表
  CONSTRAINT pk_energy_month PRIMARY KEY (period_type, period_start, energy_type),
  CONSTRAINT ck_energy_month_period CHECK (period_type = 'month'),
  CONSTRAINT ck_energy_month_type CHECK (energy_type IN ('electricity','water','gas')),
  CONSTRAINT ck_energy_month_amt CHECK (energy_amt >= 0),
  CONSTRAINT ck_energy_month_qty CHECK (energy_qty IS NULL OR energy_qty >= 0)
);
COMMENT ON TABLE  dws.energy_month IS '分项能耗费用月表（采集型，能管系统日终批汇总）；total 由 API 聚合（不存行防双写；与契约 total 序列偏差见 open-item）';
COMMENT ON COLUMN dws.energy_month.energy_amt IS '分项能耗费用·元；契约 §11.1 energy_trend 分项序列=本列 ÷1e4；stats 本月能耗=Σ当月分项';
COMMENT ON COLUMN dws.energy_month.energy_qty IS '用量原始值（electricity=kWh、water=吨、gas=m³，异构随 type 释义）；NULL=未采表（迟到数据）';
