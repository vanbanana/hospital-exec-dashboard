-- ============================================================================
-- lane L8 newdom-hr-research — 种子·相位Ⅰ：定义注册（dict + metric_def 供稿）
-- 确定性：全部字面值；幂等：ON CONFLICT DO NOTHING，可重复执行。
-- 相位定位：本段两行集是 L1 汇编（seed/1001_dict.sql / 1002_metric_def.sql）的
--   供稿副本，键/文案与 L1 完全一致——并入后本段 apply 为空操作；独立保留仅为
--   本 lane 单跑自验。汇编相位：Ⅰ 定义层，先于一切事实/汇总种子。
-- 后序文件：seed_2_rest.sql（维度+事实+本 lane dws 表种子+metric_value 供稿）。
--   无 seed_3_supply.sql——本 lane 无任何"读 dws 汇总行"的供稿（metric_value 行
--   均为字面值，仅表级依赖 L5 migrations/0304 建表序，不依赖其行）。
-- ============================================================================

-- ============================================================================
-- [S1] sys.dict 域供稿 —— 并入1001
--   本 lane 消费的字典键行；键/文案与 L1 汇编完全一致（重复 ON CONFLICT 静默跳过，
--   仅供稿登记与独立验证用，勿视为第二来源）。
-- ============================================================================
INSERT INTO sys.dict (dict_type, dict_key, dict_label, sort, extra) VALUES
  ('staffing_status','shortage','紧缺',10,NULL),
  ('staffing_status','tight','紧张',20,NULL),
  ('staffing_status','sufficient','充足',30,NULL),
  ('discipline_level','national_key','国家临床重点',10,NULL),
  ('discipline_level','provincial_key','省级重点专科',20,NULL),
  ('discipline_level','hospital_key','院级重点',30,NULL),
  ('paper_quartile','q1','一区（Top）',10,NULL),
  ('paper_quartile','q2','二区',20,NULL),
  ('paper_quartile','q3','三区',30,NULL),
  ('paper_quartile','q4','四区',40,NULL),
  ('paper_quartile','cn_core','中文核心',50,NULL),
  ('project_level','national','国家级',10,NULL),
  ('project_level','provincial','省级',20,NULL),
  ('project_level','hospital','院级',30,NULL),
  ('project_level','other','其他',40,NULL),
  ('project_status','applying','申报中',10,NULL),
  ('project_status','ongoing','在研',20,NULL),
  ('project_status','closed','已结题',30,NULL)
ON CONFLICT (dict_type, dict_key) DO NOTHING;
-- rows: 18（staffing_status 3 / discipline_level 3 / paper_quartile 5 / project_level 4 / project_status 3）

-- ============================================================================
-- [S2] sys.metric_def 域供稿 —— 并入1002
--   category=hr 9 行 + category=research 9 行；STAFF_CNT 携带 L1 预留 api_key='staff'。
--   value_kind→规范量纲：amt=元 / rate=0~1 / cnt=个 / idx=原值；disp_unit 驱动 API 换算。
-- ============================================================================
INSERT INTO sys.metric_def
  (code, name, disp_unit, value_kind, category, formula, source_table, direction,
   warn_low, warn_high, drill_route, owner, version, period, api_key, sort, enabled) VALUES
  -- ---- L8a HR（sort 910~980）----
  ('STAFF_CNT','在岗职工数','人','cnt','hr',
   'dim.staff 在岗(active)计数；院级/科室粒度；契约 §7.1 stats=2,368',
   'dim.staff',0,NULL,NULL,NULL,'人力资源部',1,'month','staff',910,true),
  ('DOCTOR_CNT','执业医师数','人','cnt','hr',
   'dim.staff[staff_type=''doc''] 在岗计数；契约=812',
   'dim.staff',0,NULL,NULL,NULL,'人力资源部',1,'month',NULL,920,true),
  ('NURSE_CNT','注册护士数','人','cnt','hr',
   'dim.staff[staff_type=''nur''] 在岗计数；契约=1,046',
   'dim.staff',0,NULL,NULL,NULL,'人力资源部',1,'month',NULL,930,true),
  ('DOC_NURSE_RATIO','医护比','-','idx','hr',
   '护士数/医师数（护:医比值）；契约出参串 "1 : 1.29" 由 API 按 ''1 : ''||ROUND(value,2) 拼装；目标≥1:1.25，无护理编配科室出参 ''—''',
   'dim.staff',1,1.25,NULL,NULL,'人力资源部',1,'month',NULL,940,true),
  ('SENIOR_TITLE_RATIO','高级职称占比','%','rate','hr',
   '(title_level∈senior_pos,senior_sub)/在岗；实算 284/2,368=0.1199（契约标题 18.2% 与同节 titles 矩阵自相矛盾，L2 open-items O13 已裁决保矩阵，本 lane 从实算）',
   'dim.staff',1,NULL,NULL,NULL,'人力资源部',1,'month',NULL,950,true),
  ('STAFF_STRUCT_SHARE','人员岗位构成占比','%','rate','hr',
   '各 staff_type 在岗计数/在岗总数（多值出参，API 按 doc/nur/tec/adm 展开为 structure 四段）；不落入 metric_value（单键位容不下 4 值），dim.staff 实时推导',
   'dim.staff',0,NULL,NULL,NULL,'人力资源部',1,'month',NULL,960,true),
  ('STAFF_QUOTA','核定编制数','人','cnt','hr',
   'dim.department.staff_quota（HRP 年度核定编制）；契约 §7.1 dept_staffing quota 列',
   'dim.department',0,NULL,NULL,NULL,'人力资源部',1,'year',NULL,970,true),
  ('STAFF_GAP','人员缺口数','人','cnt','hr',
   'staff_quota − 在岗计数（科室粒度，>0=缺编）；status 文案阈值见 dwd 事实复核：缺口≥10→shortage、5~9→tight、<5→sufficient（契约八行反推，open-items L8-#4）',
   'dim.department',-1,NULL,NULL,NULL,'人力资源部',1,'month',NULL,971,true),
  ('STAFF_COST_RATIO','人员经费占比','%','rate','hr',
   'Σdwd.hr_cost_month.staff_cost_amt / Σ业务支出(dws cost)；国考#33"人员支出占业务支出比重"导向逐步提高（calibration §1.2 行业引导区间 40%~45%）；契约=32.5%',
   'dwd.hr_cost_month',1,NULL,NULL,NULL,'人力资源部',1,'month',NULL,980,true),
  -- ---- L8b 科研（sort 1010~1090）----
  ('RESEARCH_PROJ_CNT','在研课题数','项','cnt','research',
   'count(dwd.research_project[project_status=''ongoing''])；院级/学科(discipline)粒度；契约=186',
   'dwd.research_project',1,NULL,NULL,NULL,'医务部',1,'year',NULL,1010,true),
  ('RESEARCH_NEW_CNT','年度新立项数','项','cnt','research',
   'count(apply_year=当年) 含各级立项；契约=42 且 delta=+6 要求 2025=36（=国9+省24+院3），project_trend 仅画其中国/省序列',
   'dwd.research_project',1,NULL,NULL,NULL,'医务部',1,'year',NULL,1020,true),
  ('RESEARCH_FUND','科研经费','万元','amt','research',
   'Σdwd.research_project.funds_amt 按 apply_year 聚合（立项批复经费口径，非到账流水）；库内元，出参÷10⁴为万元；契约 2026=3,480 万元',
   'dwd.research_project',1,NULL,NULL,NULL,'医务部',1,'year',NULL,1030,true),
  ('SCI_PAPER_CNT','SCI论文数','篇','cnt','research',
   'Σdws.research_paper_period.paper_cnt WHERE quartile∈(q1,q2,q3,q4)；契约=98（分区 14/28/36/20）',
   'dws.research_paper_period',1,NULL,NULL,NULL,'医务部',1,'year',NULL,1040,true),
  ('PAPER_CNT','论文发表数','篇','cnt','research',
   'Σpaper_cnt 全部 quartile（含 cn_core 中文核心）；契约 2026=166(=98+68)',
   'dws.research_paper_period',1,NULL,NULL,NULL,'医务部',1,'year',NULL,1050,true),
  ('TRAINEE_CNT','住培学员数','人','cnt','research',
   '在培住院医师规范化培训学员数；住培系统 P3 对接前手工锚定；契约=312',
   'manual',0,NULL,NULL,NULL,'医务部',0,'year',NULL,1060,true),
  ('TRAINEE_PASS_RATE','住培首次结业率','%','rate','research',
   '首次结业考核通过/结业考核人数；契约 note=96.2%（国考#48 口径为首次执业医师考试通过率，calibration 纠偏待裁决；演示按契约标签）',
   'manual',1,NULL,NULL,NULL,'医务部',0,'year',NULL,1070,true),
  ('CME_COVER_RATE','继教覆盖率','%','rate','research',
   '完成继续医学教育学分人数/应参加人数；契约=98.4%；继教系统 P3',
   'manual',1,NULL,NULL,NULL,'医务部',0,'year',NULL,1080,true),
  ('TRANSFER_AMT','成果转化金额','万元','amt','research',
   'Σ成果转化合同额（学科粒度，经 dim.discipline.dept_id 映射 metric_value.dept_id）；库内元出参÷10⁴；契约 心内150/骨科80/呼危45 万元',
   'manual',1,NULL,NULL,NULL,'医务部',0,'year',NULL,1090,true)
ON CONFLICT (code) DO NOTHING;
-- rows: 18（HR 9 + 科研 9）

-- ============================================================================
-- lane L8c/L8d/L8e newdom-pat-qual-asset — 种子·相位Ⅰ：定义层
--   内容：§1 sys.dict 供稿（并入 1001_dict.sql）/ §1b 冻结集外 9 dict_type
--         供稿清单（并入 1001 增补段，登记用注释）/ §2 sys.metric_def 供稿
--         （并入 1002_metric_def.sql）/ §3 dim.material（本 lane 维表 0110，
--         相位Ⅰb，对应汇编 1105_dim_material.sql）
-- 相位：seed-manifest §1 Ⅰa(dict/metric_def)+Ⅰb(dim)；仅依赖 DDL，
--       先于一切事实/汇总种子；被 L8 全部下游段引用。
-- 依赖：L1 sys.dict/sys.metric_def 表已建（DDL 相位）；sys.user 无关。
-- 幂等：全部 ON CONFLICT DO NOTHING；并入 L1 汇编后本文件 apply 为空操作。
-- 后序：seed_2_facts.sql（相位Ⅱ 事实）→ seed_3_supply.sql（相位Ⅲb 供稿）。
-- ============================================================================

\set ON_ERROR_STOP on

-- @phase: 1a
-- ============================================================================
-- §1 sys.dict 供稿 —— 并入 1001_dict.sql（L1 汇编段）
-- 公约 §2.4：冻结集内 dict_type 的 key 行已由 L1 seed 落库；此处幂等重供给
-- （同键同 label，并入或独立重跑均不漂移）。冻结集外枚举本 lane 只用表内 CHECK，
-- dict_type 追加需求统一走 open-items 上报（不自行注册）。
-- ============================================================================
INSERT INTO sys.dict (dict_type, dict_key, dict_label, sort, extra) VALUES
  ('feedback_type','complaint','投诉',10,NULL),
  ('feedback_type','praise','表扬',20,NULL),
  ('feedback_channel','hotline_12345','12345热线',10,NULL),
  ('feedback_channel','suggestion_box','现场意见箱',20,NULL),
  ('feedback_channel','phone','电话',30,NULL),
  ('feedback_channel','miniapp','小程序',40,NULL),
  ('feedback_channel','onsite','现场',50,NULL),
  ('feedback_channel','other','其他',60,NULL),
  ('feedback_status','pending','待核实',10,NULL),
  ('feedback_status','processing','处理中',20,NULL),
  ('feedback_status','rectified','已整改',30,NULL),
  ('feedback_status','closed','已办结',40,NULL),
  ('feedback_status','archived','已归档',50,NULL),
  ('feedback_score','very_satisfied','非常满意',10,NULL),
  ('feedback_score','satisfied','满意',20,NULL),
  ('feedback_score','fair','基本满意',30,NULL),
  ('feedback_score','pending_eval','待评价',40,NULL),
  ('adverse_cat','fall','跌倒/坠床',10,NULL),
  ('adverse_cat','med_error','用药错误',20,NULL),
  ('adverse_cat','tube_slip','管路滑脱',30,NULL),
  ('adverse_cat','pressure_ulcer','压力性损伤',40,NULL),  -- label 与契约"院内压疮"不一致→open-items #9
  ('adverse_cat','surg_related','手术相关',50,NULL),
  ('adverse_cat','transfusion','输血相关',60,NULL),
  ('adverse_cat','other','其他',70,NULL),
  ('roi_level','good','良好',10,NULL),
  ('roi_level','normal','一般',20,NULL),
  ('roi_level','low','偏低',30,NULL),
  ('energy_type','electricity','电',10,NULL),
  ('energy_type','water','水',20,NULL),
  ('energy_type','gas','燃气',30,NULL)
ON CONFLICT (dict_type, dict_key) DO NOTHING;
-- rows: 30（并入 1001）

-- §1b 待注册 dict_type 供稿清单 —— 并入 1001_dict.sql（L1 增补段）
-- 下列 9 类不在公约 §2.4 冻结 57 集内：sys.dict.dict_type CHECK 未放开前本清单仅
-- 作登记（表内 CHECK 已兜底值域，见 open-items #8 / 审计 M5）。L1 增补时将下方
-- 注释 VALUES 逐字并入 1001_dict.sql 即可（键名/排序与表内 CHECK 一一对应）。
--
-- INSERT INTO sys.dict (dict_type, dict_key, dict_label, sort, extra) VALUES
--   -- crit_status：dwd.critical_value.cv_status
--   ('crit_status','open','未闭环',10,NULL),
--   ('crit_status','closed','已闭环',20,NULL),
--   -- crit_item：dwd.critical_value.item（滚动字典；演示期键=LIS 项目名，正式期
--   -- 接检验主数据字典换码，label 为项目名）
--   ('crit_item','血钾','血钾',10,NULL),('crit_item','血红蛋白','血红蛋白',20,NULL),
--   ('crit_item','血小板','血小板',30,NULL),('crit_item','白细胞','白细胞',40,NULL),
--   ('crit_item','肌钙蛋白I','肌钙蛋白I',50,NULL),('crit_item','血糖','血糖',60,NULL),
--   ('crit_item','血钠','血钠',70,NULL),('crit_item','肌酐','肌酐',80,NULL),
--   ('crit_item','凝血酶原时间','凝血酶原时间',90,NULL),('crit_item','降钙素原','降钙素原',100,NULL),
--   ('crit_item','血淀粉酶','血淀粉酶',110,NULL),('crit_item','总胆红素','总胆红素',120,NULL),
--   ('crit_item','血气分析','血气分析',130,NULL),
--   -- inf_site：dwd.infection_case.inf_site
--   ('inf_site','resp','呼吸道',10,NULL),('inf_site','urinary','泌尿道',20,NULL),
--   ('inf_site','blood','血流',30,NULL),('inf_site','ssi','手术部位',40,NULL),
--   ('inf_site','gi','消化道',50,NULL),('inf_site','skin','皮肤软组织',60,NULL),
--   ('inf_site','other','其他',70,NULL),
--   -- adverse_level：dwd.adverse_event.event_level（int→键）
--   ('adverse_level','1','Ⅰ级（警告事件）',10,NULL),
--   ('adverse_level','2','Ⅱ级（不良后果）',20,NULL),
--   ('adverse_level','3','Ⅲ级（未造成后果）',30,NULL),
--   ('adverse_level','4','Ⅳ级（隐患事件）',40,NULL),
--   -- wo_type：dwd.logistics_order.wo_type
--   ('wo_type','repair','维修',10,NULL),('wo_type','maintain','维保',20,NULL),
--   ('wo_type','clean','保洁',30,NULL),('wo_type','transport','运送',40,NULL),
--   ('wo_type','other','其他',50,NULL),
--   -- wo_status：dwd.logistics_order.wo_status
--   ('wo_status','open','待接单',10,NULL),('wo_status','doing','处理中',20,NULL),
--   ('wo_status','done','已完结',30,NULL),('wo_status','cancelled','已取消',40,NULL),
--   -- material_cat：dim.material.mcategory
--   ('material_cat','common','普通耗材',10,NULL),('material_cat','implant','植入物',20,NULL),
--   ('material_cat','reagent','试剂',30,NULL),('material_cat','suture','缝合材料',40,NULL),
--   ('material_cat','catheter','导管类',50,NULL),('material_cat','sterile','无菌敷料',60,NULL),
--   ('material_cat','other','其他',70,NULL),
--   -- material_unit：dim.material.unit（ASCII 键 + 中文 label，审计 m9 建议落地）
--   ('material_unit','pcs','个',10,NULL),('material_unit','tube','支',20,NULL),
--   ('material_unit','box','盒',30,NULL),('material_unit','set','套',40,NULL),
--   ('material_unit','btl','瓶',50,NULL),('material_unit','pack','包',60,NULL),
--   ('material_unit','item','件',70,NULL),('material_unit','strip','条',80,NULL),
--   ('material_unit','pair','副',90,NULL),('material_unit','stick','根',100,NULL),
--   ('material_unit','tab','片',110,NULL),
--   -- qar_rule：dws.quality_rule_audit.rule_code（rule_name 列现为文案直供过渡）
--   ('qar_rule','first_visit','首诊负责制',10,NULL),
--   ('qar_rule','ward_round','三级查房制度',20,NULL),
--   ('qar_rule','consult','会诊制度',30,NULL),
--   ('qar_rule','crit_report','危急值报告制度',40,NULL),
--   ('qar_rule','surg_check','手术安全核查制度',50,NULL),
--   ('qar_rule','mr_write','病历书写规范',60,NULL),
--   ('qar_rule','abx_class','抗菌药物分级管理',70,NULL),
--   ('qar_rule','shift_hand','值班交接班制度',80,NULL)
-- ON CONFLICT (dict_type, dict_key) DO NOTHING;
-- rows: 9 类 61 键（并入 1001，随 L1 dict_type CHECK 增补生效）

-- ============================================================================
-- §2 sys.metric_def 供稿 —— 并入 1002_metric_def.sql（L1 汇编段，按 code 排序）
-- 列序：code,name,disp_unit,value_kind,category,formula,source_table,direction,
--       warn_low,warn_high,drill_route,owner,version,period,api_key,sort
-- 口径：warn_* 规范量纲；source_table='manual'=采集型无事实源；version=0=口径未定。
-- SAT_*/EMR_GRADE_A_RATE 的 metric_value 行由 L5 seed 已写，本 lane 只供定义；
-- REG_CHANNEL_SHARE/DEVICE_* 因渠道/设备粒度超出 metric_value 键域（dept_id 语义），
-- 只登记口径，值由 API 对 dwd 表区间聚合出参（H10 例外，README §映射注明）。
-- ============================================================================
INSERT INTO sys.metric_def
 (code, name, disp_unit, value_kind, category, formula, source_table, direction,
  warn_low, warn_high, drill_route, owner, version, period, api_key, sort)
VALUES
 -- -- 患者域（§9.1；sort 910+） --
 ('SAT_OP_SCORE','门诊满意度','%','score','patient','门诊满意度问卷综合评分（采集型；0~100 存储，出参值不变 unit=%；锚 96.4）','manual',1,NULL,NULL,NULL,'门诊部',1,'month',NULL,910),
 ('SAT_IP_SCORE','住院满意度','%','score','patient','住院满意度问卷综合评分（采集型；锚 97.2）','manual',1,NULL,NULL,NULL,'护理部',1,'month',NULL,920),
 ('COMPLAINT_CNT','投诉件数','件','cnt','patient','count dwd.feedback_event WHERE fb_type=''complaint''（锚 24 件/月）','dwd.feedback_event',-1,NULL,NULL,NULL,'院办公室',1,'month',NULL,930),
 ('PRAISE_CNT','表扬件数','件','cnt','patient','count dwd.feedback_event WHERE fb_type=''praise''（锚 86 件/月）','dwd.feedback_event',1,NULL,NULL,NULL,'院办公室',1,'month',NULL,940),
 ('REG_CHANNEL_SHARE','挂号渠道构成','%','rate','patient','dwd.reg_channel_day 渠道占比（L3 事实源；渠道粒度超出 metric_value 键域，API 区间聚合出参 §9.1 channel_distribution 38/24/18/14/6）','dwd.reg_channel_day',0,NULL,NULL,NULL,'门诊部',1,'month',NULL,950),
 ('ONLINE_REG_RATE','网约挂号率','%','rate','patient','网约渠道挂号量/总挂号量（口径未定：渠道全集非窗口占比≤82% 与契约锚 88.6% 冲突，version=0 待裁决，open-items #2）','manual',1,NULL,NULL,NULL,'门诊部',0,'month',NULL,960),
 -- -- 质安域（§10.1/§6.1；sort 1010+） --
 ('EMR_GRADE_A_RATE','甲级病案率','%','rate','quality','Σ(drg_case.mr_grade=''A'')/Σ出院病例（锚 98.6%；值行 L5 已写）','dwd.drg_case',1,NULL,NULL,NULL,'质控办',1,'month',NULL,1010),
 ('HAI_RATE','院感发生率','%','rate','quality','当月院感确诊例数/当月出院人数（公约 §3.4 分母裁决=出院人数；官方惯用住院日口径见 open-items #7；锚 1.24% MTD、趋势 2.2→1.8 越线回控）','dwd.infection_case',-1,NULL,0.020,'{"type":"route","path":"/metric/HAI_RATE","label":"指标详情"}'::jsonb,'医务部',1,'month',NULL,1020),
 ('CRIT_TIMELY_RATE','危急值处理及时率','%','rate','quality','Σ(已闭环且 close_at−report_at≤30min)/Σ已闭环（未闭环不进分母，由 CRIT_UNCLOSED 单列监控；锚 99.1%；settings 阈值<95% 挂 CRIT_TIMEOUT_95）','dwd.critical_value',1,0.95,NULL,NULL,'医务部',1,'month',NULL,1030),
 ('CRIT_UNCLOSED','危急值未闭环数','条','cnt','quality','count critical_value WHERE cv_status=''open''（alert CRIT_UNCLOSED_30M=dwd 实时明细>30min 直查；本指标为未闭环总量）','dwd.critical_value',-1,NULL,5,NULL,'医务部',1,'realtime',NULL,1040),
 ('ADVERSE_EVENT_CNT','不良事件上报数','起','cnt','quality','count dwd.adverse_event（锚 36 起/月）','dwd.adverse_event',0,NULL,NULL,NULL,'质控办',1,'month',NULL,1050),
 ('ADVERSE_PER_100BED','不良事件百床发生率','起/百床','idx','quality','月事件数/当月日均占用床×100（分母取 bed_used 实测占用；锚 36/1846≈1.95；"开放床"口径分歧见 open-items #5）','dwd.adverse_event',-1,NULL,NULL,NULL,'质控办',1,'month',NULL,1060),
 ('INCISION1_INF_RATE','I类切口感染率','%','rate','quality','SSI 且 incision_class=''I'' 例数 / 同期 I 类切口手术例数（分母 L4 surgery_case；锚 0.38%）','dwd.infection_case',-1,NULL,0.005,NULL,'医务部',1,'month',NULL,1070),
 ('RULE_PASS_RATE','核心制度抽检合格率','%','rate','quality','Σpass_cnt/Σsample_cnt（dws.quality_rule_audit 8 项制度）','dws.quality_rule_audit',1,0.90,NULL,NULL,'质控办',1,'month',NULL,1080),
 ('ABX_DDD','抗菌药物使用强度(全院)','DDDs','idx','quality','AUD=抗菌药累计DDD数/同期收治人天×100（锚 36.2，契约 §10.1 stats；演示期无药品事实源→manual）','manual',-1,NULL,40,NULL,'药学部',1,'month',NULL,1090),
 ('ABX_DDD_IP','住院抗菌药物使用强度','DDDs','idx','quality','住院口径 AUD（锚 38.2，契约 §6.1 cost_controls 红线≤40；与全院 36.2 并存口径见 open-items #4）','manual',-1,NULL,40,NULL,'药学部',1,'month',NULL,1100),
 ('OP_INFUSION_RATE','门诊输液率','%','rate','quality','门诊输液人次/门诊人次（锚 9.8% 超标，契约 §6.1 cost_controls 红线≤8%；演示期无输液事实源→manual）','manual',-1,NULL,0.08,NULL,'门诊部',1,'month',NULL,1110),
 -- -- 资产后勤域（§11.1；sort 1210+） --
 ('FIXED_ASSET_AMT','固定资产总额','亿元','amt','asset','HRP 固定资产台账余额（锚 12.6 亿=1,260,000,000 元；演示期 manual 锚定）','manual',1,NULL,NULL,NULL,'财务部',1,'month',NULL,1210),
 ('LARGE_DEVICE_CNT','大型设备台数','台','cnt','asset','count dim.device WHERE active（契约注"单价≥100万"——L2 68 台全值≥115万，等价全集；口径注记 open-items #14）','dim.device',1,NULL,NULL,NULL,'设备科',1,'month',NULL,1220),
 ('EQUIP_RUN_RATE','设备开机率','%','rate','asset','Σrun_hours/Σplan_hours（锚 94.2%；settings 阈值<60% 挂 EQUIP_RUN_LOW）','dwd.device_run_day',1,0.60,NULL,NULL,'设备科',1,'month',NULL,1230),
 ('STOCK_TURN_DAYS','库存周转天数','天','days','asset','月末快照 Σ(onhand_qty×单价)/Σ(avg_daily_use×单价)（锚 28 天；settings"库存周转>35天"挂 STOCK_TURN_SLOW）','dwd.material_stock_day',-1,NULL,35,NULL,'后勤保障部',1,'month',NULL,1240),
 ('ENERGY_COST','能耗费用合计','万元','amt','asset','Σ dws.energy_month.energy_amt（锚 186 万/月；total 不存行，派生）','dws.energy_month',-1,NULL,NULL,NULL,'总务科',1,'month',NULL,1250),
 ('ENERGY_ELEC_AMT','电费','万元','amt','asset','Σ energy_amt WHERE energy_type=''electricity''','dws.energy_month',-1,NULL,NULL,NULL,'总务科',1,'month',NULL,1260),
 ('ENERGY_WATER_AMT','水费','万元','amt','asset','Σ energy_amt WHERE energy_type=''water''','dws.energy_month',-1,NULL,NULL,NULL,'总务科',1,'month',NULL,1270),
 ('ENERGY_GAS_AMT','燃气费','万元','amt','asset','Σ energy_amt WHERE energy_type=''gas''','dws.energy_month',-1,NULL,NULL,NULL,'总务科',1,'month',NULL,1280),
 ('ENERGY_PER_WAN_REV','万元收入能耗支出','元/万元','idx','asset','Σ当月能耗费用/(Σ当月医疗收入/1e4)（国考#34 口径；分母 dws.hospital_oper_day.revenue）','dws.energy_month',-1,NULL,NULL,NULL,'总务科',1,'month',NULL,1290),
 ('WORK_ORDER_CNT','后勤工单量','单','cnt','asset','count dwd.logistics_order 当月建单（锚 156 单）','dwd.logistics_order',0,NULL,NULL,NULL,'后勤保障部',1,'month',NULL,1300),
 ('WORK_ORDER_DONE_RATE','工单完结率','%','rate','asset','Σ(done)/Σ单（锚 92%）','dwd.logistics_order',1,0.85,NULL,NULL,'后勤保障部',1,'month',NULL,1310),
 ('DEVICE_EXAM_CNT','设备检查人次','人次','cnt','asset','Σ device_run_day.exam_cnt（设备粒度；长表只登记口径，§11.1 large_equipments monthly 列由 API 聚合）','dwd.device_run_day',1,NULL,NULL,NULL,'设备科',1,'month',NULL,1320),
 ('DEVICE_INCOME','设备创收','万元','amt','asset','Σ device_run_day.income_amt（设备粒度同上；契约出参万元）','dwd.device_run_day',1,NULL,NULL,NULL,'设备科',1,'month',NULL,1330),
 ('DEVICE_ROI','设备效益评级','-','idx','asset','月度 Σincome_amt/Σopex_amt 收益比，映射 roi_level（≥250万&率≥0.85→good；<200万或率<0.75→low；余 normal——README §映射）','dwd.device_run_day',1,NULL,NULL,NULL,'设备科',1,'month',NULL,1340),
 ('POSITIVE_RATE','检查阳性率','%','rate','asset','Σpositive_cnt/Σexam_cnt（device_run_day；院级月聚合）','dwd.device_run_day',1,NULL,NULL,NULL,'设备科',1,'month',NULL,1350)
ON CONFLICT (code) DO NOTHING;
-- rows: 32（并入 1002；patient 6 / quality 11 / asset 15）

-- @endphase

-- @phase: 1b
-- ============================================================================
-- §3 dim.material —— 24 行（0110；契约 §11.1 stock_alerts 6 项 + 常规库 18 项）
-- use_day/days_tgt 为种子画像参数（不入表）：库存天数锚点由 §9 stock_day 行承载。
-- ============================================================================
INSERT INTO dim.material (code, name, mcategory, spec, unit, unit_price_amt, high_value_flag, warn_days, active)
SELECT * FROM (VALUES
  -- stock_alerts 契约 6 行（days 锚点在 §9 BASE_DATE 快照钉死 46/42/36/34/31/29）
  ('MAT_001','一次性使用输液器','common',NULL,'tube',    1.20,false,28,true),
  ('MAT_002','骨科植入物（接骨板）','implant','锁定加压板 8 孔','set',8500.00,true ,28,true),
  ('MAT_003','造影剂（碘海醇）','reagent','100ml:35g','btl', 180.00,false,28,true),
  ('MAT_004','医用缝合线','suture','可吸收 3-0','pack',  45.00,false,28,true),
  ('MAT_005','中心静脉导管','catheter','三腔 7Fr','set',1200.00,true ,28,true),
  ('MAT_006','无菌手术衣','sterile','加强型 L','item',  28.00,false,28,true),
  -- 常规库 18 项（周转梯度 15~26 天，残差校正件=MAT_118）
  ('MAT_101','一次性使用注射器','common','5ml','tube',   0.85,false,28,true),
  ('MAT_102','无菌纱布','common','8×10cm','pack',     2.40,false,28,true),
  ('MAT_103','医用检查手套','common','丁腈 M','pair',   1.60,false,28,true),
  ('MAT_104','医用外科口罩','common','灭菌','pcs',     0.90,false,28,true),
  ('MAT_105','真空采血管','reagent','EDTA-K2 紫帽','tube', 0.70,false,28,true),
  ('MAT_106','静脉留置针','catheter','24G','tube',     18.00,false,28,true),
  ('MAT_107','一次性导尿管','catheter','F16','stick',   22.00,false,28,true),
  ('MAT_108','一次性吸氧管','common','双鼻式','stick',   3.50,false,28,true),
  ('MAT_109','心电电极片','common','一次性','tab',     0.50,false,28,true),
  ('MAT_110','手术刀片','sterile','11 号','tab',       3.20,false,28,true),
  ('MAT_111','医用棉球','common','脱脂 500g','pack',    4.50,false,28,true),
  ('MAT_112','免洗手消毒液','sterile','500ml','btl',  28.00,false,28,true),
  ('MAT_113','血糖试纸','reagent','葡萄糖氧化酶','strip', 2.10,false,28,true),
  ('MAT_114','真空采血针','common','21G','tube',        0.60,false,28,true),
  ('MAT_115','一次性引流袋','catheter','1000ml','pcs', 8.50,false,28,true),
  ('MAT_116','医用腹带','other','均码','strip',         35.00,false,28,true),
  ('MAT_117','医用冰袋','other','250g','pcs',         12.00,false,28,true),
  ('MAT_118','雾化吸入管','catheter','口含式','set',   9.80,false,28,true)
) AS p(code,name,mcategory,spec,unit,unit_price_amt,high_value_flag,warn_days,active)
ON CONFLICT (code) DO NOTHING;
-- rows: 24
-- @endphase
