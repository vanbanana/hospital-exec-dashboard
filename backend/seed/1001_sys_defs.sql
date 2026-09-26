-- ============================================================================
-- lane L1 sys-org  种子·主段（确定性/幂等）——种子相位Ⅰ
-- file: seed_1_main.sql（拆自原 seed.sql；user dept_id 回填段拆至 seed_2_deferred.sql）
-- 锚点：BASE_DATE='2026-10-28'（公约 §1.5）；种子窗 2025-01-01~2026-12-31
-- 说明：本文件无随机函数/无当前时间函数，一切时间为字面量；全部 INSERT ... ON CONFLICT 幂等重跑。
-- 拆分：按 plan §3 段序——[S1]→seed/1001_dict.sql（全 dict 行，L1 汇编位）
--                        [S2]→seed/1002_metric_def.sql（L1 段；各 lane 行并入同文件按 code 排序）
--                        [S3]→sys 域账号/通知/数据源/偏好（本段不含 dept_id 回填，
--                             见 seed_2_deferred.sql：L2 dim.department 种子后执行）
-- ============================================================================

-- ============================================================================
-- [S1] sys.dict 全类型骨架（69 dict_type = 冻结 57 + 阶段3 增补 12，见 [S1b]）
-- 汇编规则：各域 lane 的 key 行经 open-items 供稿并入本文件；L1 先按冻结 key 集全量
-- 播种（label 为汇编初稿，域 lane 可提修正；本行集 ON CONFLICT DO NOTHING，
-- 修订请走 L1 汇编，勿旁路插入）。
-- ============================================================================

-- ---- L1 自有：hospital（/hospital/profile 数据源，契约 §2.2） ----
INSERT INTO sys.dict (dict_type, dict_key, dict_label, sort, extra) VALUES
 ('hospital','name','XX市人民医院',10,NULL),
 ('hospital','english_name','PEOPLE''S HOSPITAL',20,NULL),
 ('hospital','level','三级甲等综合医院',30,NULL),
 ('hospital','motto','厚德·精医·仁爱·创新',40,'["厚德","精医","仁爱","创新"]'::jsonb),
 ('hospital','slogans','以数据洞察全局 / 以科学决策引领医院高质量发展',50,'["以数据洞察全局","以科学决策引领医院高质量发展"]'::jsonb),
 ('hospital','pillars','人民至上·生命至上·健康至上',60,'["人民至上","生命至上","健康至上"]'::jsonb)
ON CONFLICT (dict_type, dict_key) DO NOTHING;

-- ---- L1 自有：账号/权限域（sys.user 消费） ----
INSERT INTO sys.dict (dict_type, dict_key, dict_label, sort) VALUES
 ('role_type','admin','管理员',10),
 ('role_type','president','院领导',20),
 ('role_type','ops_director','部门负责人',30),
 ('role_type','dept_leader','科室主任',40),
 ('role_type','viewer','只读用户',50),
 ('scope_type','all','全院',10),
 ('scope_type','domain','业务域',20),
 ('scope_type','dept','本科室',30)
ON CONFLICT (dict_type, dict_key) DO NOTHING;

-- ---- L1 自有：数据源/偏好/settings（sys.data_source、user_pref 消费） ----
INSERT INTO sys.dict (dict_type, dict_key, dict_label, sort) VALUES
 ('datasource_type','biz_rt','业务库 · 准实时',10),
 ('datasource_type','biz_hourly','业务库 · 小时级',20),
 ('datasource_type','biz_daily','业务库 · 日终批',30),
 ('datasource_type','bureau_daily','局端接口 · 日终批',40),
 ('datasource_status','connected','已连接',10),
 ('datasource_status','error','异常',20),
 ('range_type','month','本月',10),
 ('range_type','quarter','本季',20),
 ('range_type','year','本年',30)
ON CONFLICT (dict_type, dict_key) DO NOTHING;

-- ---- L1 自有：指标域（sys.metric_def 与全周期表消费） ----
INSERT INTO sys.dict (dict_type, dict_key, dict_label, sort) VALUES
 ('metric_category','operation','运营业务',10),
 ('metric_category','quality','质量安全',20),
 ('metric_category','finance','财务收支',30),
 ('metric_category','insurance','医保基金',40),
 ('metric_category','hr','人力资源',50),
 ('metric_category','research','科研教学',60),
 ('metric_category','patient','患者服务',70),
 ('metric_category','asset','资产后勤',80),
 ('metric_category','exam','国考监测',90),
 ('metric_category','screen','大屏态势',100),
 ('value_kind','cnt','计数',10),
 ('value_kind','amt','金额（元）',20),
 ('value_kind','rate','比率（0~1）',30),
 ('value_kind','idx','指数',40),
 ('value_kind','mins','时长（分钟）',50),
 ('value_kind','days','时长（天）',60),
 ('value_kind','score','评分（0~100）',70),
 ('period_type','day','日',10),
 ('period_type','week','周',20),
 ('period_type','month','月',30),
 ('period_type','quarter','季',40),
 ('period_type','year','年',50),
 ('period_type','d30','滚动30天',60),
 ('period_type','realtime','实时',70),
 ('topic_code','drg','DRG专题',10),
 ('topic_code','insurance','医保基金',20),
 ('topic_code','exam','国考指标',30),
 ('topic_code','outp_fund','门诊统筹',40)
ON CONFLICT (dict_type, dict_key) DO NOTHING;

-- ---- L1 自有：drill（v1.1 沿用；契约 v2.0 未下发下钻指令枚举，仅 route 一值，见 open-items O6） ----
INSERT INTO sys.dict (dict_type, dict_key, dict_label, sort) VALUES
 ('drill_type','route','路由跳转',10)
ON CONFLICT (dict_type, dict_key) DO NOTHING;

-- ---- L2 域供稿位：组织/人员/设备维 ----
INSERT INTO sys.dict (dict_type, dict_key, dict_label, sort) VALUES
 ('dept_category','med','内科',10),
 ('dept_category','surg','手术科室',20),
 ('dept_category','tech','医技科室',30),
 ('dept_category','nurse','护理单元',40),
 ('dept_category','adm','行政后勤',50),
 ('dept_category','hosp','院级',60),
 ('dept_domain','clinical','临床科室',10),
 ('dept_domain','platform','平台科室',20),
 ('dept_domain','tech','医技科室',30),
 ('dept_domain','admin','行政科室',40),
 ('clinic_line','med','内科线',10),
 ('clinic_line','surg','外科线',20),
 ('clinic_line','special','专科线',30),
 ('building_func','outpt','门诊',10),
 ('building_func','inpt','住院',20),
 ('building_func','emerg','急诊',30),
 ('building_func','tech','医技',40),
 ('building_func','adm','行政',50),
 ('building_func','other','其他',60),
 ('ward_type','general','普通病区',10),
 ('ward_type','icu','重症监护',20),
 ('ward_type','obs','留观病区',30),
 ('ward_type','or','手术间',40),
 ('title_level','senior_pos','正高',10),
 ('title_level','senior_sub','副高',20),
 ('title_level','middle','中级',30),
 ('title_level','junior','初级及以下',40),
 ('staff_type','doc','执业医师',10),
 ('staff_type','nur','护理人员',20),
 ('staff_type','tec','医技人员',30),
 ('staff_type','adm','行政后勤',40),
 ('device_dtype','CT','CT',10),
 ('device_dtype','MRI','MRI',20),
 ('device_dtype','DSA','DSA',30),
 ('device_dtype','ROBOT','手术机器人',40),
 ('device_dtype','LINAC','直线加速器',50),
 ('device_dtype','PETCT','PET/CT',60),
 ('device_dtype','ENDO','内镜',70),
 ('device_dtype','ESWL','体外碎石机',80),
 ('device_dtype','US','超声',90),
 ('device_dtype','DR','DR',100),
 ('device_dtype','OTHER','其他',110),
 ('drg_pay_type','DRG','DRG付费',10),
 ('drg_pay_type','DIP','DIP付费',20),
 ('risk_level','low','低风险',10),
 ('risk_level','mid','中风险',20),
 ('risk_level','midhigh','中高风险',30),
 ('risk_level','high','高风险',40)
ON CONFLICT (dict_type, dict_key) DO NOTHING;

-- ---- L3/L4 域供稿位：门急诊/住院/手术/费用/病案 ----
INSERT INTO sys.dict (dict_type, dict_key, dict_label, sort) VALUES
 ('reg_channel','wechat_mp','微信小程序',10),
 ('reg_channel','kiosk','自助机',20),
 ('reg_channel','window','人工窗口',30),
 ('reg_channel','app','官方APP',40),
 ('reg_channel','phone','电话预约',50),
 ('reg_type','normal','普通门诊',10),
 ('reg_type','expert','专家门诊',20),
 ('reg_type','special','特需门诊',30),
 ('reg_type','free','义诊/免费',40),
 ('triage_level','1','Ⅰ级（濒危）',10),
 ('triage_level','2','Ⅱ级（危重）',20),
 ('triage_level','3','Ⅲ级（急症）',30),
 ('triage_level','4','Ⅳ级（非急症）',40),
 ('obs_status','observing','留观中',10),
 ('obs_status','admitted','转住院',20),
 ('obs_status','left','已离观',30),
 ('ip_event','admit','入院',10),
 ('ip_event','discharge','出院',20),
 ('ip_event','transfer','转科',30),
 ('surgery_level','1','一级手术',10),
 ('surgery_level','2','二级手术',20),
 ('surgery_level','3','三级手术',30),
 ('surgery_level','4','四级手术',40),
 ('surg_status','sched','已排台',10),
 ('surg_status','doing','术中',20),
 ('surg_status','done','已完成',30),
 ('surg_status','pacu','复苏中',40),
 ('mr_grade','A','甲级',10),
 ('mr_grade','B','乙级',20),
 ('mr_grade','C','丙级',30),
 ('incision_class','I','Ⅰ类切口',10),
 ('incision_class','II','Ⅱ类切口',20),
 ('incision_class','III','Ⅲ类切口',30),
 ('discharge_type','1','医嘱离院',10),
 ('discharge_type','2','医嘱转院',20),
 ('discharge_type','3','医嘱转社区',30),
 ('discharge_type','4','非医嘱离院',40),
 ('discharge_type','5','死亡',50),
 ('discharge_type','9','其他',60),
 ('admit_path','1','门诊入院',10),
 ('admit_path','2','急诊入院',20),
 ('admit_path','3','其他机构转入',30),
 ('admit_path','9','其他',40),
 ('rate_type','normal','正常倍率',10),
 ('rate_type','high','高倍率',20),
 ('rate_type','low','低倍率',30),
 ('ins_type','employee','职工医保',10),
 ('ins_type','resident','居民医保',20),
 ('ins_type','maternity','生育保险',30),
 ('ins_type','severe','大病保险',40),
 ('ins_type','relief','医疗救助',50),
 ('ins_biz_type','inp','住院结算',10),
 ('ins_biz_type','op_fund','门诊统筹',20),
 ('ins_run_status','stable','平稳',10),
 ('ins_run_status','watch','关注',20)
ON CONFLICT (dict_type, dict_key) DO NOTHING;

-- ---- L3/L4 域供稿位：费用分类（extra 登记病案10类与医保票据14项映射，公约 §2.4；初稿待域 lane 校订） ----
INSERT INTO sys.dict (dict_type, dict_key, dict_label, sort, extra) VALUES
 ('fee_cat','drug','药品费',10,'{"mr_items":["西药费","中成药费","中草药费"],"ins_items":["药品费"]}'::jsonb),
 ('fee_cat','material','卫生材料费',20,'{"mr_items":["卫生材料费"],"ins_items":["医用材料费"]}'::jsonb),
 ('fee_cat','exam','检查化验费',30,'{"mr_items":["检查费","化验费"],"ins_items":["检查费","化验费"]}'::jsonb),
 ('fee_cat','treat','治疗费',40,'{"mr_items":["治疗费","护理费","一般医疗服务费"],"ins_items":["治疗费","护理费"]}'::jsonb),
 ('fee_cat','surg','手术及麻醉费',50,'{"mr_items":["手术费","麻醉费"],"ins_items":["手术费","麻醉费"]}'::jsonb),
 ('fee_cat','bed','床位费',60,'{"mr_items":["床位费"],"ins_items":["床位费"]}'::jsonb),
 ('fee_cat','other','其他费用',70,'{"mr_items":["其他费用"],"ins_items":["其他"]}'::jsonb)
ON CONFLICT (dict_type, dict_key) DO NOTHING;

-- ---- L7 域供稿位：告警/督办/楼宇态 ----
INSERT INTO sys.dict (dict_type, dict_key, dict_label, sort) VALUES
 ('alert_level','urgent','高',10),
 ('alert_level','major','中',20),
 ('alert_level','minor','低',30),
 ('alert_status','pending','待处理',10),
 ('alert_status','processing','处理中',20),
 ('alert_status','done','已办结',30),
 ('alert_status','closed','已关闭',40),
 ('alert_source','rule','规则触发',10),
 ('alert_source','scenario','情景预置',20),
 ('alert_source','test','测试',30),
 ('todo_status','open','待处理',10),
 ('todo_status','doing','处理中',20),
 ('todo_status','done','已完成',30),
 ('todo_status','expired','已逾期',40),
 ('badge_level','info','信息',10),
 ('badge_level','ok','正常',20),
 ('badge_level','warn','预警',30),
 ('badge_level','alert','告警',40),
 ('campus_status_type','normal','正常',10),
 ('campus_status_type','busy','繁忙',20),
 ('campus_status_type','alert','告警',30)
ON CONFLICT (dict_type, dict_key) DO NOTHING;

-- ---- L6 域供稿位：对比/雷达 ----
INSERT INTO sys.dict (dict_type, dict_key, dict_label, sort) VALUES
 ('compare_dim','scale','业务规模',10),
 ('compare_dim','benefit','收入效益',20),
 ('compare_dim','efficiency','运营效率',30),
 ('compare_dim','quality','医疗质量',40),
 ('radar_dim','scale','业务规模',10),
 ('radar_dim','revenue','收入能力',20),
 ('radar_dim','efficiency','运营效率',30),
 ('radar_dim','quality','医疗质量',40),
 ('radar_dim','satisfaction','患者满意',50),
 ('radar_dim','research','科研教学',60)
ON CONFLICT (dict_type, dict_key) DO NOTHING;

-- ---- L8 域供稿位：患者/质安/科研/资产 ----
INSERT INTO sys.dict (dict_type, dict_key, dict_label, sort) VALUES
 ('feedback_type','complaint','投诉',10),
 ('feedback_type','praise','表扬',20),
 ('feedback_channel','hotline_12345','12345热线',10),
 ('feedback_channel','suggestion_box','现场意见箱',20),
 ('feedback_channel','phone','电话',30),
 ('feedback_channel','miniapp','小程序',40),
 ('feedback_channel','onsite','现场',50),
 ('feedback_channel','other','其他',60),
 ('feedback_status','pending','待核实',10),
 ('feedback_status','processing','处理中',20),
 ('feedback_status','rectified','已整改',30),
 ('feedback_status','closed','已办结',40),
 ('feedback_status','archived','已归档',50),
 ('feedback_score','very_satisfied','非常满意',10),
 ('feedback_score','satisfied','满意',20),
 ('feedback_score','fair','基本满意',30),
 ('feedback_score','pending_eval','待评价',40),
 ('adverse_cat','fall','跌倒/坠床',10),
 ('adverse_cat','med_error','用药错误',20),
 ('adverse_cat','tube_slip','管路滑脱',30),
 ('adverse_cat','pressure_ulcer','院内压疮',40),
 ('adverse_cat','surg_related','手术相关',50),
 ('adverse_cat','transfusion','输血相关',60),
 ('adverse_cat','other','其他',70),
 ('discipline_level','national_key','国家临床重点',10),
 ('discipline_level','provincial_key','省级重点专科',20),
 ('discipline_level','hospital_key','院级重点',30),
 ('paper_quartile','q1','一区（Top）',10),
 ('paper_quartile','q2','二区',20),
 ('paper_quartile','q3','三区',30),
 ('paper_quartile','q4','四区',40),
 ('paper_quartile','cn_core','中文核心',50),
 ('project_level','national','国家级',10),
 ('project_level','provincial','省级',20),
 ('project_level','hospital','院级',30),
 ('project_level','other','其他',40),
 ('project_status','applying','申报中',10),
 ('project_status','ongoing','在研',20),
 ('project_status','closed','已结题',30),
 ('staffing_status','shortage','紧缺',10),
 ('staffing_status','tight','紧张',20),
 ('staffing_status','sufficient','充足',30),
 ('roi_level','good','良好',10),
 ('roi_level','normal','一般',20),
 ('roi_level','low','偏低',30),
 ('energy_type','electricity','电',10),
 ('energy_type','water','水',20),
 ('energy_type','gas','燃气',30)
ON CONFLICT (dict_type, dict_key) DO NOTHING;

-- ============================================================================
-- [S1b] dict_type 增补汇编（阶段3 修复轮 · audit-implementability M5）
-- 12 类原 CHECK-only 值域经审核注册入 dict_type（ddl.sql ck_dict_dict_type
-- 已同步扩至 69 类）。键值逐行采自来源 lane 的 columns.md/seed.sql 声明，
-- 不臆造；L9 sim job_run_status 经其 lane 自选不登记，不入本集。
-- ============================================================================

-- ---- 来源 newdom-pat-qual-asset（L8d）：危急值生命周期 / 院感部位 / 不良事件分级 ----
INSERT INTO sys.dict (dict_type, dict_key, dict_label, sort) VALUES
 ('crit_status','open','未闭环',10),
 ('crit_status','closed','已闭环',20),
 -- crit_item：危急值项目滚动目录，键=项目名（dwd.critical_value.item 直存中文名），
 -- 13 项为 L8d 种子实播集，新检验项目上线时经 L1 汇编追加
 ('crit_item','血钾','血钾',10),
 ('crit_item','血红蛋白','血红蛋白',20),
 ('crit_item','血小板','血小板',30),
 ('crit_item','白细胞','白细胞',40),
 ('crit_item','肌钙蛋白I','肌钙蛋白I',50),
 ('crit_item','血糖','血糖',60),
 ('crit_item','血钠','血钠',70),
 ('crit_item','肌酐','肌酐',80),
 ('crit_item','凝血酶原时间','凝血酶原时间',90),
 ('crit_item','降钙素原','降钙素原',100),
 ('crit_item','血淀粉酶','血淀粉酶',110),
 ('crit_item','总胆红素','总胆红素',120),
 ('crit_item','血气分析','血气分析',130),
 ('inf_site','resp','呼吸道',10),
 ('inf_site','urinary','泌尿道',20),
 ('inf_site','blood','血流',30),
 ('inf_site','ssi','手术部位(SSI)',40),
 ('inf_site','gi','消化道',50),
 ('inf_site','skin','皮肤',60),
 ('inf_site','other','其他',70),
 -- adverse_level：键为 dwd.adverse_event.event_level(smallint) 的字符态，文案用 SAC 四级
 ('adverse_level','1','Ⅰ级（警告事件）',10),
 ('adverse_level','2','Ⅱ级（不良后果事件）',20),
 ('adverse_level','3','Ⅲ级（未造成后果事件）',30),
 ('adverse_level','4','Ⅳ级（隐患事件）',40)
ON CONFLICT (dict_type, dict_key) DO NOTHING;

-- ---- 来源 newdom-pat-qual-asset（L8d）：核心制度质检规则 8 键 ----
INSERT INTO sys.dict (dict_type, dict_key, dict_label, sort) VALUES
 ('qar_rule','first_visit','首诊负责制',10),
 ('qar_rule','ward_round','三级查房制度',20),
 ('qar_rule','consult','会诊制度',30),
 ('qar_rule','crit_report','危急值报告制度',40),
 ('qar_rule','surg_check','手术安全核查制度',50),
 ('qar_rule','mr_write','病历书写规范',60),
 ('qar_rule','abx_class','抗菌药物分级管理',70),
 ('qar_rule','shift_hand','值班交接班制度',80)
ON CONFLICT (dict_type, dict_key) DO NOTHING;

-- ---- 来源 newdom-pat-qual-asset（L8e）：后勤工单 / 耗材目录 ----
INSERT INTO sys.dict (dict_type, dict_key, dict_label, sort) VALUES
 ('wo_type','repair','维修',10),
 ('wo_type','maintain','维保',20),
 ('wo_type','clean','保洁',30),
 ('wo_type','transport','运送',40),
 ('wo_type','other','其他',50),
 ('wo_status','open','待接单',10),
 ('wo_status','doing','处理中',20),
 ('wo_status','done','已完结',30),
 ('wo_status','cancelled','已取消',40),
 ('material_cat','common','普通耗材',10),
 ('material_cat','implant','植入物',20),
 ('material_cat','reagent','试剂造影',30),
 ('material_cat','suture','缝合材料',40),
 ('material_cat','catheter','导管',50),
 ('material_cat','sterile','无菌防护',60),
 ('material_cat','other','其他',70),
 -- material_unit：dim.material.unit 直存中文单位字面量，键=值
 ('material_unit','个','个',10),
 ('material_unit','支','支',20),
 ('material_unit','盒','盒',30),
 ('material_unit','套','套',40),
 ('material_unit','瓶','瓶',50),
 ('material_unit','包','包',60),
 ('material_unit','件','件',70),
 ('material_unit','条','条',80),
 ('material_unit','副','副',90),
 ('material_unit','根','根',100),
 ('material_unit','片','片',110)
ON CONFLICT (dict_type, dict_key) DO NOTHING;

-- ---- 来源 ads-workbench（L6）columns.md O1：工作台事项状态 ----
INSERT INTO sys.dict (dict_type, dict_key, dict_label, sort) VALUES
 ('workitem_status','pending','待启动',10),
 ('workitem_status','doing','进行中',20),
 ('workitem_status','done','已完成',30)
ON CONFLICT (dict_type, dict_key) DO NOTHING;

-- ---- 来源 L1 自有：sys.user.user_status（smallint 0/1 的字符态键，与 surgery_level 同形） ----
INSERT INTO sys.dict (dict_type, dict_key, dict_label, sort) VALUES
 ('user_status','0','停用',10),
 ('user_status','1','启用',20)
ON CONFLICT (dict_type, dict_key) DO NOTHING;

-- ---- 来源 dim-public（L2）open-items O9：抗菌药物分级（dim.drug.abx_level） ----
INSERT INTO sys.dict (dict_type, dict_key, dict_label, sort) VALUES
 ('abx_level','unrestricted','非限制使用级',10),
 ('abx_level','restricted','限制使用级',20),
 ('abx_level','special','特殊使用级',30)
ON CONFLICT (dict_type, dict_key) DO NOTHING;

-- rows: dict 310 / 锚点: 69 dict_type（冻结 57 + 阶段3 增补 12），key 集逐行对齐来源 lane CHECK

-- ============================================================================
-- [S2] sys.metric_def —— L1 段（operation/finance/insurance/screen/exam + 兜底 1 行 quality）
-- 列序：code,name,disp_unit,value_kind,category,formula,source_table,direction,
--        warn_low,warn_high,drill_route,owner,version,period,api_key,sort
-- 约定：warn_* 规范量纲（rate 0~1、amt 元）；source_table='manual'=无事实源手工指标；
--       version=0=口径未定（公约 §3.4）
-- ============================================================================
INSERT INTO sys.metric_def
 (code, name, disp_unit, value_kind, category, formula, source_table, direction,
  warn_low, warn_high, drill_route, owner, version, period, api_key, sort)
VALUES
 -- -- 业务量与规模（metric-dict §1.1；ONLINE_REG_RATE 归 L8c patient） --
 ('OP_DAILY_VISITS','今日门急诊人次','人','cnt','operation','Σ当日 outpatient_hourly.visit_cnt（门+急，契约口径=outpt_cnt+emerg_cnt，§14.1）','dwd.outpatient_hourly',0,NULL,NULL,NULL,'门诊部',1,'realtime',NULL,10),
 ('OP_VISIT_CNT','门急诊人次','人次','cnt','operation','Σ outpatient_hourly.visit_cnt 按日/月/年聚合（§3.1/§3.2/§4.1/§5.1）','dwd.outpatient_hourly',1,NULL,NULL,'{"type":"route","path":"/metric/OP_VISIT_CNT","label":"指标详情"}'::jsonb,'门诊部',1,'day','outpatient',20),
 ('OP_NORMAL_CNT','普通门诊人次','人次','cnt','operation','Σ visit_cnt WHERE reg_type=''normal''（§5.1 门急诊 stats）','dwd.outpatient_hourly',1,NULL,NULL,NULL,'门诊部',1,'month',NULL,30),
 ('OP_EXPERT_CNT','专家门诊人次','人次','cnt','operation','Σ expert_cnt（专家门诊拆分，§5.1）','dwd.outpatient_hourly',1,NULL,NULL,NULL,'门诊部',1,'month',NULL,40),
 ('EMERG_VISIT_CNT','急诊人次','人次','cnt','operation','Σ visit_cnt WHERE emerg_flag（=dws.emerg_cnt，§5.1）','dwd.outpatient_hourly',0,NULL,NULL,NULL,'门诊部',1,'month',NULL,50),
 ('REG_CNT','挂号人次','人次','cnt','operation','Σ outpatient_hourly.reg_cnt','dwd.outpatient_hourly',0,NULL,NULL,NULL,'门诊部',1,'day',NULL,60),
 ('REG_CANCEL_RATE','退号率','%','rate','operation','Σ cancel_cnt / Σ reg_cnt（schema §9 P2 登记，提前入库）','dwd.outpatient_hourly',-1,NULL,NULL,NULL,'门诊部',1,'day',NULL,70),
 ('APPT_RATE','预约就诊率','%','rate','operation','Σ appt_cnt / Σ visit_cnt（schema §9 P2 登记，提前入库）','dwd.outpatient_hourly',1,NULL,NULL,NULL,'门诊部',1,'day',NULL,80),
 ('ADMIT_CNT','入院人数','人','cnt','operation','count inpatient_move event=''admit''（检索别名 IP_ADMIT_CNT，不立 code）','dwd.inpatient_move',0,NULL,NULL,NULL,'医务部',1,'day',NULL,90),
 ('DISCH_CNT','出院人数','人次','cnt','operation','count inpatient_move event=''discharge''（§3.1 住院人次/§3.3 top10）','dwd.inpatient_move',1,NULL,NULL,'{"type":"route","path":"/metric/DISCH_CNT","label":"指标详情"}'::jsonb,'医务部',1,'day','inpatient',100),
 ('IP_IN_HOSP','在院人数','人','cnt','operation','Σ bed_state_day.bed_used 当日 ≈ Σadmit−Σdischarge（§4.1 live/§14.1 KPI2）','dwd.bed_state_day',0,NULL,NULL,NULL,'医务部',1,'realtime',NULL,110),
 ('SURG_DAILY_CNT','今日手术台次','台','cnt','operation','count surgery_case 当日（§14.1 KPI4，日 ~45 台锚点）','dwd.surgery_case',1,NULL,NULL,NULL,'医务部',1,'realtime',NULL,120),
 ('SURG_CNT','手术台次','台','cnt','operation','count surgery_case surg_status<>''sched'' 按日/月/年（月 1,286 锚点）','dwd.surgery_case',1,NULL,NULL,'{"type":"route","path":"/metric/SURG_CNT","label":"指标详情"}'::jsonb,'医务部',1,'month','surgery',130),
 ('SURG_DOING_CNT','手术进行中台数','台','cnt','operation','count surg_status IN(''doing'',''pacu'')（§4.1 live）','dwd.surgery_case',0,NULL,NULL,NULL,'医务部',1,'realtime',NULL,140),
 ('SURG_ELECTIVE_CNT','择期手术台次','台','cnt','operation','count elective_flag（§5.1 手术 stats）','dwd.surgery_case',1,NULL,NULL,NULL,'医务部',1,'month',NULL,150),
 ('SURG_EMERG_CNT','急诊手术台次','台','cnt','operation','count NOT elective_flag','dwd.surgery_case',0,NULL,NULL,NULL,'医务部',1,'month',NULL,160),
 ('EMERG_OBS_CNT','急诊在观人数','人','cnt','operation','count emergency_stay obs_status=''observing''（§4.1 live；schema 键 obs_cnt）','dwd.emergency_stay',0,NULL,NULL,NULL,'急诊科',1,'realtime',NULL,170),
 ('ICU_IN_CNT','重症监护在科人数','人','cnt','operation','Σ bed_used WHERE ward_type=''icu''（§4.1 live）','dwd.bed_state_day',0,NULL,NULL,NULL,'医务部',1,'realtime',NULL,180),
 ('BIZ_EQUIV','业务量当量','当量','cnt','operation','门急诊人次 + 出院人次×10（暂定演示加权，version=1 待业务方复核；与 compare outp/inpt 列自洽）','dws.dept_oper_day',1,NULL,NULL,NULL,'医务部',1,'month',NULL,190),
 -- -- 效率与床位（metric-dict §1.2） --
 ('BED_USE_RATE','床位使用率','%','rate','operation','Σ bed_used / Σ bed_open（借床口径 v1.1 §4 冻结；>95% 红线；direction=0 双向超界皆险，公约 §3.3）','dwd.bed_state_day',0,NULL,0.95,'{"type":"route","path":"/metric/BED_USE_RATE","label":"指标详情"}'::jsonb,'医务部',1,'day',NULL,200),
 ('ALOS','平均住院日','天','days','operation','Σ los_days / Σ 出院人数（锚点 6.8 天）','dwd.inpatient_move',-1,NULL,NULL,'{"type":"route","path":"/metric/ALOS","label":"指标详情"}'::jsonb,'医务部',1,'month',NULL,210),
 ('BED_TURNOVER_CNT','床位周转次数','次','cnt','operation','期内出院人数 / 同期平均开放床位数（锚点 3.4 次）','dwd.bed_state_day',1,NULL,NULL,NULL,'医务部',1,'month',NULL,220),
 ('AVG_WAIT_MIN','平均候诊时长','分钟','mins','operation','avg(接诊时刻−挂号/签到时刻)；schema 键 queue_avg_min（锚点 18min）','dwd.outpatient_hourly',-1,NULL,NULL,NULL,'门诊部',1,'day',NULL,230),
 ('AVG_SURG_MIN','平均手术时长','分钟','mins','operation','avg(actual_end−actual_start)（§5.1 手术表 avg 列）','dwd.surgery_case',0,NULL,NULL,NULL,'医务部',1,'month',NULL,240),
 ('SURG_ROOM_USE_RATE','手术间利用率','%','rate','operation','手术占用台时 / 手术间开放台时（锚点 86.4%；告警 SURG_TURN_OVER 挂接）','dwd.surgery_case',1,NULL,NULL,NULL,'医务部',1,'month',NULL,250),
 ('PREOP_ALOS','术前住院日','天','days','operation','avg(surg_date−admit_date)（drg_case 直出）','dwd.drg_case',-1,NULL,NULL,NULL,'医务部',1,'month',NULL,260),
 ('LONGSTAY_CNT','超长住院人数','人','cnt','operation','count 在院/出院 WHERE los>30 天','dwd.inpatient_move',-1,NULL,NULL,NULL,'医务部',1,'day',NULL,270),
 ('EMERG_OBS_OVER6H','急诊留观超6h人数','人','cnt','operation','count obs_status=''observing'' WHERE 在观时长>6h（阈值可配，有意偏离白皮书24h；告警 OBS_OVER_6H）','dwd.emergency_stay',-1,NULL,NULL,NULL,'急诊科',1,'realtime',NULL,280),
 ('OBS_MAX_MIN','留观最长时长','分钟','mins','operation','max(当前时刻−arrive_at)（observing 行实时算；schema 键 obs_max_min）','dwd.emergency_stay',-1,NULL,NULL,NULL,'急诊科',1,'realtime',NULL,290),
 ('ICU_USE_RATE','ICU占床率','%','rate','operation','ICU 病区 bed_used/bed_open（>90% 红，告警 ICU_USE_90；direction=-1 公约 §3.3）','dwd.bed_state_day',-1,NULL,0.90,NULL,'医务部',1,'day',NULL,300),
 -- -- DRG 与病组（metric-dict §1.5；RW 为病组属性不立 code） --
 ('CMI','病例组合指数','-','idx','operation','Σ rw / Σ 入组病例（锚点 1.08）','dwd.drg_case',1,NULL,NULL,'{"type":"route","path":"/metric/CMI","label":"指标详情"}'::jsonb,'医保办',1,'month',NULL,310),
 ('DRG_ENROLL_RATE','入组率','%','rate','operation','入组病例数 / 出院病例数（锚点 98.5%）','dwd.drg_case',1,NULL,NULL,NULL,'医保办',1,'month',NULL,320),
 ('COST_INDEX','费用消耗指数','-','idx','operation','Σ(例均费用/区域同病组例均费用)/病例数（锚点 0.92，依赖区域基准）','dws.drg_dept_period',-1,NULL,NULL,NULL,'医保办',1,'month',NULL,330),
 ('TIME_INDEX','时间消耗指数','-','idx','operation','Σ(例均住院日/区域同病组例均住院日)/病例数（锚点 0.95）','dws.drg_dept_period',-1,NULL,NULL,NULL,'医保办',1,'month',NULL,340),
 ('RW_GE2_RATIO','RW≥2病例占比','%','rate','operation','count(rw≥2)/入组病例数（锚点 10.2%）','dwd.drg_case',1,NULL,NULL,NULL,'医保办',1,'month',NULL,350),
 ('LOW_RISK_DEATH_RATE','低风险组死亡率','%','rate','quality','低风险组死亡病例/低风险组病例数（risk_level=''low''，锚点 0.02%）','dwd.drg_case',-1,NULL,NULL,NULL,'质控办',1,'month',NULL,360),
 ('DRG_PROFIT','DRG结余','万元','amt','operation','Σ(insurance_pay−cost_total)（对账=dws.drg_profit；骨科 +124.6 万锚点）','dwd.drg_case',1,NULL,NULL,NULL,'医保办',1,'month',NULL,370),
 ('DRG_CASE_CNT','入组病例数','例','cnt','operation','count drg_case 已入组（topics cases 列/screen case_cnt）','dwd.drg_case',1,NULL,NULL,NULL,'医保办',1,'month',NULL,380),
 ('SURG_L4_RATIO','四级手术占比','%','rate','operation','surg_level=''4'' 台次/总手术台次（手术台次口径）','dwd.surgery_case',1,NULL,NULL,NULL,'医务部',1,'month',NULL,390),
 ('SURG_L34_RATIO','三四级手术占比','%','rate','operation','surg_level≥3 台次/总台次（锚点 58.6%）','dwd.surgery_case',1,NULL,NULL,NULL,'医务部',1,'month',NULL,400),
 ('SURG_L4_DISCH_RATIO','出院患者四级手术比例','%','rate','operation','出院患者中四级手术例数/出院患者手术例数（国考口径，§3.4 子口径拆分）','dwd.drg_case',1,NULL,NULL,NULL,'医务部',1,'month',NULL,410),
 ('MIN_INVASIVE_RATIO','微创手术占比','%','rate','operation','min_invasive 台次/总台次（锚点 42.3%）','dwd.surgery_case',1,NULL,NULL,NULL,'医务部',1,'month',NULL,420),
 ('DEATH_RATE','住院死亡率','%','rate','quality','death_flag 病例/出院人数','dwd.drg_case',-1,NULL,NULL,NULL,'质控办',1,'month',NULL,430),
 ('READMIT_15D_RATE','15日再入院率','%','rate','quality','readmit15_flag 病例/出院人数','dwd.drg_case',-1,NULL,NULL,NULL,'质控办',1,'month',NULL,440),
 ('SPEC_CASE_CNT','特例单议病例数','例','cnt','insurance','count spec_flag（申报工具 P2）','dwd.drg_case',0,NULL,NULL,NULL,'医保办',1,'month',NULL,450),
 ('DRG_QUADRANT','DRG盈亏四象限','-','idx','operation','(drg_profit, cmi) 按 split(x=0,y=1.0) 分象限 → 1~4（screen drg_quadrant）','dws.drg_dept_period',0,NULL,NULL,NULL,'医保办',1,'d30',NULL,460),
 -- -- 手术分级构成（metric-dict §1.7 尾行，归 operation） --
 ('SURG_LEVEL_DIST','手术分级构成','%','rate','operation','一至四级手术台次各占比例（§5.1 distribution）','dwd.surgery_case',0,NULL,NULL,NULL,'医务部',1,'month',NULL,470),
 -- -- 综合评分/排名（metric-dict §1.12 归 operation/quality 兜底） --
 ('DEPT_EFF_SCORE','科室运行效率分','分','score','operation','100×(0.30·norm(cmi)+0.25·norm(surg_cnt)+0.20·(1−norm(alos))+0.15·bed_use_rate+0.10·norm(profit))（schema §10 公式 v1）','dws.dept_oper_day',1,NULL,NULL,NULL,'院办',1,'d30',NULL,480),
 ('DEPT_RANK_NO','科室排名','名','cnt','operation','dept_rank_day.rank_no（当期度量降序）','ads.dept_rank_day',-1,NULL,NULL,NULL,'院办',1,'d30',NULL,490),
 ('RADAR_CAP_SCORE','六维能力指数','分','score','operation','业务规模/收入能力/运营效率/医疗质量/患者满意/科研教学六维合成（合成口径未定，手工种子值；公约 §3.4/U5）','manual',1,NULL,NULL,NULL,'院办',0,'month',NULL,500),
 ('WORK_PROGRESS_RATE','重点工作完成进度','%','rate','operation','督办事项完成百分比（行政填报/里程碑）','ads.work_item',1,NULL,NULL,NULL,'院办',1,'month',NULL,510),
 -- -- 收支与成本（metric-dict §1.3；STAFF_COST_RATIO→L8a、ENERGY_*→L8e、FIXED_ASSET_AMT→L8e） --
 ('REVENUE_DAILY','医疗收入（日）','万元','amt','finance','hospital_oper_day.revenue = Σ charge_day(out_fee+in_fee)','dws.hospital_oper_day',1,NULL,NULL,NULL,'财务部',1,'day',NULL,520),
 ('REVENUE','医疗总收入','万元','amt','finance','Σ revenue 按月/季/年（月 14,800 万锚点（10月峰值，scale-decision §2）；home kpi/收入结构/operations）','dws.hospital_oper_day',1,NULL,NULL,'{"type":"route","path":"/metric/REVENUE","label":"指标详情"}'::jsonb,'财务部',1,'month','revenue',530),
 ('OP_REVENUE','门诊收入','万元','amt','finance','Σ charge_day.out_fee（锚点 ~8,950 万/年区间）','dwd.charge_day',1,NULL,NULL,NULL,'财务部',1,'month',NULL,540),
 ('IP_REVENUE','住院收入','万元','amt','finance','Σ charge_day.in_fee（dept_share_top8 度量）','dwd.charge_day',1,NULL,NULL,NULL,'财务部',1,'month',NULL,550),
 ('REV_STRUCT_SHARE','收入结构占比','%','rate','finance','分项收入/医疗总收入（住院/门诊/其他，§4.1 income_structure）','dwd.charge_day',0,NULL,NULL,NULL,'财务部',1,'month',NULL,560),
 ('MED_SVC_RATIO','医疗服务收入占比','%','rate','finance','剔除药品/耗材/检查化验收入占比（fee_cat 归集口径）','dwd.charge_day',1,NULL,NULL,'{"type":"route","path":"/metric/MED_SVC_RATIO","label":"指标详情"}'::jsonb,'财务部',1,'month',NULL,570),
 ('COST','医疗成本','万元','amt','finance','Σ cost（HRP 全成本口径；dws.cost）','dws.hospital_oper_day',-1,NULL,NULL,NULL,'财务部',1,'month',NULL,580),
 ('PROFIT','收支结余','万元','amt','finance','revenue − cost（operations balance 序列/dept_table）','dws.hospital_oper_day',1,NULL,NULL,NULL,'财务部',1,'month',NULL,590),
 ('PROFIT_MARGIN','收支结余率','%','rate','finance','(revenue−cost)/revenue（契约 margin 列）','dws.hospital_oper_day',1,NULL,NULL,NULL,'财务部',1,'month',NULL,600),
 ('PER_BED_DAY_REV','每床日收入','元','amt','finance','(住院收入−药品−耗材)/实际占用床日数（国考指标）','dwd.charge_day',1,NULL,NULL,NULL,'财务部',1,'month',NULL,610),
 -- -- 药品耗材与费用控制（metric-dict §1.4；ABX_DDD/OP_INFUSION_RATE→L8d） --
 ('DRUG_RATIO','药占比','%','rate','finance','Σ drug_fee/Σ total_fee（红线 30%，settings 阈值/告警 DRUG_RATIO_WARN）','dwd.charge_day',-1,NULL,0.30,'{"type":"route","path":"/metric/DRUG_RATIO","label":"指标详情"}'::jsonb,'药学部',1,'month',NULL,620),
 ('MATERIAL_RATIO','耗材占比','%','rate','finance','Σ material_fee/Σ total_fee（红线 20%，settings 阈值/告警 MAT_OVER_20）','dwd.charge_day',-1,NULL,0.20,'{"type":"route","path":"/metric/MATERIAL_RATIO","label":"指标详情"}'::jsonb,'设备科',1,'month',NULL,630),
 ('COST_RATIO_MATERIAL','百元医疗收入消耗卫生材料','元','amt','finance','Σ material_fee/Σ revenue×100（红线≤15 元，锚点 12.6 元口径B剔药；勿与 MATERIAL_RATIO 混）','dwd.charge_day',-1,NULL,15.00,NULL,'设备科',1,'month',NULL,640),
 ('AVG_OP_FEE','次均门诊费用','元','amt','finance','门诊收入(元)/门急诊人次（§5.1 表 avg 列；锚点 300 元）','dwd.charge_day',-1,NULL,NULL,NULL,'财务部',1,'month',NULL,650),
 ('AVG_IP_FEE','次均住院费用','元','amt','finance','住院收入(元)/出院人数（锚点 13,000 元）','dwd.charge_day',-1,NULL,NULL,NULL,'财务部',1,'month',NULL,660),
 ('AVG_FEE_GROWTH','次均费用增幅','%','rate','finance','本期次均费用同比变动率（红线≤8%）','dws.hospital_oper_day',-1,NULL,0.08,NULL,'财务部',1,'month',NULL,670),
 ('OTHER_INCOME_AMT','其他收入','万元','amt','finance','收入结构其他组份（契约 income_structure，占比 4%≈580 万/月，scale-decision §2；无专属事实列→manual，值行 L5 段 L1 供稿，traceability M4）','manual',0,NULL,NULL,NULL,'财务部',1,'month',NULL,675),
 ('INPT_FEE_YOY','住院费用增幅','%','rate','finance','住院费用同比增长率（红线>8%；告警 INPT_FEE_SURGE/settings 阈值）','dws.hospital_oper_day',-1,NULL,0.08,NULL,'财务部',1,'month',NULL,680),
 -- -- 医保基金（metric-dict §1.6 全部 16 项） --
 ('INS_SETTLE_CNT','医保结算人次','人次','cnt','insurance','count 结算记录（住院结算 biz_type=''inp''；锚点 8,462 人次）','dwd.insurance_settle_day',1,NULL,NULL,NULL,'医保办',1,'month',NULL,690),
 ('INS_SETTLE','医保基金支付额','万元','amt','insurance','Σ fund_amt（锚点 9,860 万；schema §9 已登记口径）','dwd.insurance_settle_day',0,NULL,NULL,NULL,'医保办',1,'month',NULL,700),
 ('INS_BALANCE_RATE','医保基金结余率','%','rate','insurance','(基金收入−基金支付)/基金收入（锚点 6.8%；基金收入为局端外源，演示期手工值——值行由 L5 段 L1 供稿兜底，traceability M2）','manual',1,NULL,NULL,NULL,'医保办',1,'month',NULL,710),
 ('INS_REJECT_RATE','拒付扣款率','%','rate','insurance','拒付扣款金额/申报金额（锚点 0.8%）','dwd.insurance_settle_day',-1,NULL,NULL,NULL,'医保办',1,'month',NULL,720),
 ('AVG_INS_FEE','次均医保费用','元','amt','insurance','医保结算总费用(元)/结算人次','dwd.insurance_settle_day',0,NULL,NULL,NULL,'医保办',1,'month',NULL,730),
 ('INS_REMOTE_CNT','异地就医结算人次','人次','cnt','insurance','Σ remote_cnt（锚点 486 人次）','dwd.insurance_settle_day',1,NULL,NULL,NULL,'医保办',1,'month',NULL,740),
 ('INS_REIMB_RATIO','医保报销比例','%','rate','insurance','基金支付/(基金支付+个人自付)，分险种（insurance ratio 列）','dwd.insurance_settle_day',0,NULL,NULL,NULL,'医保办',1,'month',NULL,750),
 ('SELF_PAY_RATIO','自费比例','%','rate','insurance','Σ self_fee/Σ(insurance_fee+self_fee)（schema §9 已登记）','dwd.charge_day',-1,NULL,NULL,NULL,'医保办',1,'month',NULL,760),
 ('SELF_PAY_AMT','个人自付金额','万元','amt','insurance','Σ self_amt 分险种（insurance self 列）','dwd.insurance_settle_day',0,NULL,NULL,NULL,'医保办',1,'month',NULL,770),
 ('OP_FUND_SETTLE_CNT','门诊统筹结算人次','人次','cnt','insurance','count biz_type=''op_fund''（锚点 6,248 人次）','dwd.insurance_settle_day',1,NULL,NULL,NULL,'医保办',1,'month',NULL,780),
 ('OP_FUND_PAY','门诊统筹基金支付','万元','amt','insurance','Σ统筹支付（锚点 486 万）','dwd.insurance_settle_day',1,NULL,NULL,NULL,'医保办',1,'month',NULL,790),
 ('OP_FUND_AVG_FEE','人均统筹费用','元','amt','insurance','统筹支付(元)/结算人次（锚点 78 元）','dwd.insurance_settle_day',0,NULL,NULL,NULL,'医保办',1,'month',NULL,800),
 ('OP_ACCT_PAY','个人账户支出','万元','amt','insurance','Σ个人账户支付（锚点 326 万）','dwd.insurance_settle_day',0,NULL,NULL,NULL,'医保办',1,'month',NULL,810),
 ('CHRONIC_SETTLE_CNT','慢特病结算人次','人次','cnt','insurance','Σ chronic_cnt（锚点 1,846 人次）','dwd.insurance_settle_day',1,NULL,NULL,NULL,'医保办',1,'month',NULL,820),
 ('CHRONIC_RATIO','慢特病结算占比','%','rate','insurance','慢特病结算人次/统筹结算人次（outp_fund chronic 列）','dwd.insurance_settle_day',0,NULL,NULL,NULL,'医保办',1,'month',NULL,830),
 ('RX_OUTFLOW_RATE','处方外流率','%','rate','insurance','外流处方数/门诊处方总数（锚点 12.4%；处方流转平台外源→manual；值行 L5 段 L1 供稿兜底，traceability M3）','manual',-1,NULL,NULL,NULL,'药学部',1,'month',NULL,840),
 -- -- 大屏态势（metric-dict §1.12，screen 类） --
 ('ALERT_OPEN_CNT','未闭环告警数','条','cnt','screen','count alert_event alert_status IN(''pending'',''processing'')（§14.1 alert_open 分层）','ads.alert_event',-1,NULL,NULL,NULL,'质控办',1,'realtime',NULL,850),
 ('DEVICE_ALERT_CNT','设备告警数','条','cnt','screen','count 设备类 open 告警（楼宇级；campus_status metrics 键 device_alert）','ads.alert_event',-1,NULL,NULL,NULL,'设备科',1,'realtime',NULL,860),
 -- -- 国考监测（metric-dict §1.12，exam 类） --
 ('EXAM_SCORE','国考预估得分','分','idx','exam','国考指标加权总分（锚点 786 分超 score 0~100 护栏→value_kind=idx，audit m3/L5-O5；exam_indicator 加权）','dws.exam_indicator',1,NULL,NULL,NULL,'医务部',1,'year',NULL,870),
 ('EXAM_TARGET_RATE','国考指标达标率','%','rate','exam','达标指标数/已监测指标数（锚点 82.4%）','dws.exam_indicator',1,NULL,NULL,NULL,'医务部',1,'month',NULL,880),
 ('EXAM_DIM_SCORE_RATE','国考维度得分率','%','rate','exam','维度得分/满分（医疗质量/运营效率/持续发展/满意度四维）','dws.exam_indicator',1,NULL,NULL,NULL,'医务部',1,'year',NULL,890),
 -- -- 兜底（无 lane 认领，category=quality；L8d 可接管，见 open-items O4） --
 ('QUALITY_SCORE','质量综合评分','分','score','quality','compare dim=quality 科室质量分（合成口径未定，手工种子值；公约 §3.4/U5）','manual',1,NULL,NULL,NULL,'质控办',0,'month',NULL,900)
ON CONFLICT (code) DO NOTHING;
-- rows: metric_def 91（operation 47 / finance 18 / insurance 17 / screen 2 / exam 3 / quality 4）
-- 锚点: plan §5（月 12,300 门急诊/月 1,286 台手术/月 14,800 万收入（10月峰值）/医保 8,462 人次·9,860 万等）
-- 他 lane 并入现状：hr(L8a 9)/research(L8b 9)=newdom-hr-research 18 行；
-- patient/quality/asset=newdom-pat-qual-asset 32 行（含 EMR_GRADE_A_RATE 正本）；
-- L4 原 25 行供稿块经阶段3 M3 裁决整体移除（发散点见 open-items O10）
-- api_key='staff' 须由 L8a STAFF_CNT 行携带（README 对外约定）
-- api_key 唯一性：本文件占用 outpatient/inpatient/surgery/revenue；staff 预留 L8a

-- ============================================================================
-- [S3] sys 域账号/通知/数据源/偏好
-- 执行序要求：本段相位Ⅰ可独立执行——dept_id 一律 NULL 入库，回填见 seed_2_deferred.sql。
-- 演示口令仅本地用（bcrypt cost=10）：admin/Admin@123、president/President@123、
-- ops_director/Ops@123、dept_leader/Leader@123、vp_medical/Vp@123、
-- med_director/Med@123、fin_director/Fin@123
-- ============================================================================
INSERT INTO sys.user
 (id, username, password_hash, real_name, emp_no, job_title, avatar, role,
  dept_id, scope_type, scope_val, user_status, last_login_at, created_at, updated_at)
OVERRIDING SYSTEM VALUE VALUES
 (1,'president','$2y$10$a6YzD8tz4q7uWXGv7HC3VOD9yOQqZcrsaG2sa/oEpulP1Q7B9mCmy','王建国','president','院长','/assets/workbench/director_avatar.png','president',NULL,'all',NULL,1,'2026-10-28 08:46:00+08','2026-01-02 09:00:00+08','2026-01-02 09:00:00+08'),
 (2,'ops_director','$2y$10$cmRnQbYN13ty5.V3IbA6f.fl3WV7D6KaEJcaziu8hu8Fs5iNMybD6','李明','ops_director','运营办主任','','ops_director',NULL,'domain','ops_quality',1,'2026-10-28 09:30:00+08','2026-01-02 09:00:00+08','2026-01-02 09:00:00+08'),
 (3,'dept_leader','$2y$10$665dCbnVJy6rJHyg2b/mfeaEGOdmUnYXrA/Ut7gOWvda0IS25o1K6','刘志远','dept_leader','骨科主任','','dept_leader',NULL,'dept','GK',1,'2026-10-28 08:30:00+08','2026-01-02 09:00:00+08','2026-01-02 09:00:00+08'),
 (4,'admin','$2y$10$LW1.NRFdYjaZDjyVv3VyC.HYGLCcbdud2XZZLaC./2UuLfWksnCEu','系统管理员','admin','系统管理员','','admin',NULL,'all',NULL,1,'2026-10-28 09:12:00+08','2026-01-02 09:00:00+08','2026-01-02 09:00:00+08'),
 (5,'vp_medical','$2y$10$e0Zs1hKdNT4NG7YDD..rHumOL/mdALXwDXNZDBwBAm6SgQNC6O3he','陈国平','vp_medical','分管副院长','','president',NULL,'all',NULL,1,'2026-10-27 17:32:00+08','2026-01-02 09:00:00+08','2026-01-02 09:00:00+08'),
 (6,'med_director','$2y$10$39utQMwZzYDy27faHFaEIe.Z7oMWnlnSjsRvlLb9Hja5SDTN8PZrK','赵明诚','med_director','医务部主任','','ops_director',NULL,'domain','medical',1,'2026-10-28 08:58:00+08','2026-01-02 09:00:00+08','2026-01-02 09:00:00+08'),
 (7,'fin_director','$2y$10$f8NdXf.GUMxbI7LMk2UcA.Y0xmtXN1/CfEdJTRpfZIkellt7zO4Vm','孙雅琴','fin_director','财务部主任','','ops_director',NULL,'domain','finance',1,'2026-10-28 09:05:00+08','2026-01-02 09:00:00+08','2026-01-02 09:00:00+08')
ON CONFLICT (username) DO NOTHING;
-- rows: user 7（4 演示账号 + settings users 6 行并集）/ 锚点: §2.1 角色三档+§13.2 users
-- 注：dept scope_val='GK' 已对齐 L2 冻结 code（骨科=GK，id=1；O2 收口）；
--     dept_id 回填已拆出至 seed_2_deferred.sql（依赖 L2 dim.department 种子，相位Ⅱ末执行）
-- OVERRIDING 定值后推进 identity 序列，防应用侧新账号撞种子 id（L2 同款做法）
SELECT setval(pg_get_serial_sequence('sys.user','id'), GREATEST((SELECT max(id) FROM sys.user), 1));

INSERT INTO sys.notice (id, title, publish_date, is_urgent, created_at)
OVERRIDING SYSTEM VALUE VALUES
 (201,'关于加强医疗质量安全管理的通知','2026-10-28',true ,'2026-10-28 08:00:00+08'),
 (202,'院务会会议材料（10月）','2026-10-27',true ,'2026-10-27 09:00:00+08'),
 (203,'请审阅2027年预算编制方案','2026-10-26',true ,'2026-10-26 10:00:00+08'),
 (204,'智慧医院二期建设进展汇报','2026-10-25',false,'2026-10-25 14:00:00+08'),
 (205,'上级主管部门调研安排','2026-10-24',false,'2026-10-24 15:00:00+08')
ON CONFLICT (id) DO NOTHING;
-- rows: notice 5 / 锚点: §3.7 样例改写为 2026-10 当周（BASE_DATE=2026-10-28 周三），urgent 3+2 保持样例分布
SELECT setval(pg_get_serial_sequence('sys.notice','id'), GREATEST((SELECT max(id) FROM sys.notice), 1));

INSERT INTO sys.data_source (code, name, ds_type, ds_status, last_sync_at) VALUES
 ('HIS_OP','HIS 门诊收费系统','biz_rt','connected','2026-10-28 09:42:00+08'),
 ('HIS_IP','HIS 住院管理系统','biz_rt','connected','2026-10-28 09:42:00+08'),
 ('EMR','EMR 电子病历','biz_hourly','connected','2026-10-28 09:00:00+08'),
 ('LIS','LIS 检验系统','biz_hourly','connected','2026-10-28 09:05:00+08'),
 ('HRP','HRP 人财物系统','biz_daily','connected','2026-10-28 06:30:00+08'),
 ('INS_API','医保结算接口','bureau_daily','error','2026-10-27 23:58:00+08')
ON CONFLICT (code) DO NOTHING;
-- rows: data_source 6 / 锚点: §13.2 data_sources（医保接口异常态保留，sync 改 2026-10）

-- preferences：单用户（president）一份偏好集 = 5 行（"单行"歧义见 open-items O5）
INSERT INTO sys.user_pref (user_id, pref_key, pref_val, updated_at) VALUES
 (1,'default_range','"month"'::jsonb,'2026-10-28 09:00:00+08'),
 (1,'refresh_interval','300'::jsonb,'2026-10-28 09:00:00+08'),
 (1,'alert_sound','true'::jsonb,'2026-10-28 09:00:00+08'),
 (1,'unit_abbreviation','true'::jsonb,'2026-10-28 09:00:00+08'),
 (1,'privacy_mask','true'::jsonb,'2026-10-28 09:00:00+08')
ON CONFLICT (user_id, pref_key) DO NOTHING;
-- rows: user_pref 5 / 锚点: §13.2 preferences（本月/5分钟/声音开/缩写开/脱敏开）
SELECT setval(pg_get_serial_sequence('sys.user_pref','id'), GREATEST((SELECT max(id) FROM sys.user_pref), 1));

-- sys.audit_log：P1 空表，不播种（公约 §4 继承·空表）
