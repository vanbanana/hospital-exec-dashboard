-- ============================================================================
-- L7 ads-screen-alert — seed.sql（对象序号 0401/0402/0403/0404；0408 todo_order P1 无种子）
-- ----------------------------------------------------------------------------
-- 执行前提：L1(sys.metric_def/dict/user)、L2(dim.department/building/staff)、
--           L3(dwd.outpatient_hourly/bed_state_day/emergency_stay) 已播种；
--           L8d/L8e 的 4 个 metric_def 行供稿见 open-items O3。
-- 锚点：BASE_DATE = 2026-10-28；快照切面 09:00（对齐 L3 emergency_stay 演示态与 plan §5）。
-- 确定性：禁 random()/now()；campus_status 的 mz/wk/jz 三楼按公约 §3/§5.6 以 INSERT…SELECT
--        自 dwd 确定性派生（jz 缺行回落契约字面锚点、wk 缺行回零）；
--        today_kpi 全行自 dwd 推导（阶段3修复轮 audit G9/G10/G13——屏值随基准日，见 columns.md §0403）。
-- 幂等：全部 ON CONFLICT DO NOTHING，重跑安全；identity 显式值配 OVERRIDING。
-- ============================================================================

-- ============================================================================
-- [A1] 0401 ads.alert_rule —— 13 行（11 rule + 2 scenario）
-- 锚点：plan §4-L7 全清单 + settings §13.2 七行映射（README §映射表）；
--       级别按契约 §13.2（阶段3 修复轮 traceability M5 裁决：BED_OVER_95→urgent、
--       STOCK_TURN_SLOW→minor；原按 plan 的分歧史见 open-items O2）。
-- ============================================================================
INSERT INTO ads.alert_rule
  (code, name, alert_level, metric_code, op, threshold, scope, eval_json, dedup_min, drill_route, source, enabled, created_at, updated_at)
VALUES
  -- —— settings 七行对应规则（阈值/级别按契约 §13.2；文案由 API 拼装） ——
  ('BED_OVER_95','床位使用率连续3日超95%','urgent','BED_USE_RATE','>',0.95,'dept',
   '{"window":"P3D","agg":"consecutive_days"}',720,
   '{"page":"/workbench/inpatient"}','rule',true, TIMESTAMPTZ '2026-10-22 00:00:00+08', TIMESTAMPTZ '2026-10-22 00:00:00+08'),
  ('DRUG_RATIO_WARN','药占比超30%','major','DRUG_RATIO','>',0.30,'hospital',
   '{"window":"P1M","agg":"avg"}',1440,
   '{"page":"/workbench/fee","params":{"topic":"drug_ratio"}}','rule',true, TIMESTAMPTZ '2026-10-22 00:00:00+08', TIMESTAMPTZ '2026-10-22 00:00:00+08'),
  ('MAT_OVER_20','耗占比超20%','major','MATERIAL_RATIO','>',0.20,'hospital',
   '{"window":"P1M","agg":"avg"}',1440,
   '{"page":"/workbench/fee","params":{"topic":"material_ratio"}}','rule',true, TIMESTAMPTZ '2026-10-22 00:00:00+08', TIMESTAMPTZ '2026-10-22 00:00:00+08'),
  ('INPT_FEE_SURGE','住院费用同比增幅超8%','urgent','INPT_FEE_YOY','>',0.08,'hospital',
   '{"window":"P1M","agg":"yoy"}',1440,
   '{"page":"/workbench/fee","params":{"topic":"inpt_fee"}}','rule',true, TIMESTAMPTZ '2026-10-22 00:00:00+08', TIMESTAMPTZ '2026-10-22 00:00:00+08'),
  ('STOCK_TURN_SLOW','库存周转天数超35天','minor','STOCK_TURN_DAYS','>',35,'hospital',
   '{"window":"P1M","agg":"max","basis":"耗材SPD库存周转天数"}',1440,
   '{"page":"/workbench/material","params":{"tab":"stock"}}','rule',true, TIMESTAMPTZ '2026-10-22 00:00:00+08', TIMESTAMPTZ '2026-10-22 00:00:00+08'),
  ('CRIT_TIMEOUT_95','危急值处理及时率低于95%','urgent','CRIT_TIMELY_RATE','<',0.95,'hospital',
   '{"window":"P1M","agg":"rate","basis":"当月及时处置率=及时闭环数/报告总数"}',1440,
   '{"page":"/workbench/quality","params":{"tab":"critical"}}','rule',true, TIMESTAMPTZ '2026-10-22 00:00:00+08', TIMESTAMPTZ '2026-10-22 00:00:00+08'),
  ('EQUIP_RUN_LOW','设备开机率低于60%','minor','EQUIP_RUN_RATE','<',0.60,'dept',
   '{"window":"P1M","agg":"avg","basis":"月均开机率"}',1440,
   '{"page":"/workbench/equipment"}','rule',false, TIMESTAMPTZ '2026-10-22 00:00:00+08', TIMESTAMPTZ '2026-10-22 00:00:00+08'),
  -- —— 运行监测规则（settings 外） ——
  ('OBS_OVER_6H','急诊留观超6小时','urgent','EMERG_OBS_OVER6H','>',0,'building',
   '{"window":"PT6H","agg":"count","basis":"留观中且 now−arrive_at>360min","scan_sec":60}',30,
   '{"page":"/workbench/emergency"}','rule',true, TIMESTAMPTZ '2026-10-22 00:00:00+08', TIMESTAMPTZ '2026-10-22 00:00:00+08'),
  ('ICU_USE_90','ICU占床率超90%','urgent','ICU_USE_RATE','>',0.90,'building',
   '{"window":"PT30M","agg":"latest"}',60,
   '{"page":"/workbench/inpatient","params":{"ward":"W_ICU_1"}}','rule',true, TIMESTAMPTZ '2026-10-22 00:00:00+08', TIMESTAMPTZ '2026-10-22 00:00:00+08'),
  ('SURG_TURN_OVER','手术间利用率连续超负荷','major','SURG_ROOM_USE_RATE','>',0.90,'hospital',
   '{"window":"P5D","agg":"consecutive_days","basis":"手术间日利用率连续5日越限"}',720,
   '{"page":"/workbench/surgery"}','rule',true, TIMESTAMPTZ '2026-10-22 00:00:00+08', TIMESTAMPTZ '2026-10-22 00:00:00+08'),
  ('CRIT_UNCLOSED_30M','危急值30分钟未闭环','major','CRIT_UNCLOSED','>',0,'hospital',
   '{"window":"PT30M","agg":"count","basis":"report_at 距今>30min 且 close_at IS NULL","scan_sec":60}',30,
   '{"page":"/workbench/quality","params":{"tab":"critical"}}','rule',true, TIMESTAMPTZ '2026-10-22 00:00:00+08', TIMESTAMPTZ '2026-10-22 00:00:00+08'),
  -- —— scenario 注入器规则（无指标三元组；参数在 eval_json） ——
  ('DRUG_STOCK_LOW','重点药品库存低于安全库存','minor',NULL,NULL,NULL,'hospital',
   '{"inject_key":"drug_stock_low","params":{"safe_days":7}}',1440,
   '{"page":"/workbench/material","params":{"tab":"drug_stock"}}','scenario',true, TIMESTAMPTZ '2026-10-22 00:00:00+08', TIMESTAMPTZ '2026-10-22 00:00:00+08'),
  ('DEVICE_MAINTAIN','设备维保到期提醒','minor',NULL,NULL,NULL,'dept',
   '{"inject_key":"device_maintain","params":{"lead_days":30}}',10080,
   '{"page":"/workbench/equipment","params":{"tab":"maintain"}}','scenario',true, TIMESTAMPTZ '2026-10-22 00:00:00+08', TIMESTAMPTZ '2026-10-22 00:00:00+08')
ON CONFLICT (code) DO NOTHING;
-- rows: 13 / 锚点: plan §4-L7 全清单；enabled 分布 12 true + EQUIP_RUN_LOW false（契约 §13.2 第七行 dis）

-- ============================================================================
-- [A2] 0402 ads.alert_event —— 8 行（5 打开态 id 101~105 + 3 已闭环历史 96~98）
-- 打开态计数 urgent1/major2/minor2 = §14.1 status.alert_open 硬锚点；
-- 跑马灯两条=OBS_OVER_6H/ICU_USE_90（§14.1 list 锚点，occurred_at 重锚 2026-10-28 09:00 切面）；
-- 与 §3.6 样例五码的覆盖缺口（INPT_FEE_SURGE/DRUG_RATIO_WARN/STOCK_TURN_SLOW 只能以闭环态共存）
-- 见 open-items O1；级别张力（ICU 事件 major vs 规则 urgent 等）见 O2。
-- ============================================================================
-- —— 打开态 5 条（id 区段对齐 §3.6 样例 101~105）；101/102 两条 payload 自 dwd 派生见后 ——
INSERT INTO ads.alert_event
  (id, rule_code, alert_level, title, dept_id, building_code, target_type, target_id,
   payload, drill_route, alert_status, source, occurred_at, ack_at, ack_by, done_at, closed_at, close_note, created_at)
OVERRIDING SYSTEM VALUE
VALUES
  (103,'BED_OVER_95','major','部分科室床位使用率持续 > 95%',1,'wk','dept','1',
   '{"value":0.963,"consecutive_days":3,"dept_ids":[1,4,12],"evidence":{"table":"dwd.bed_state_day","pk_hint":"(date,ward_code)","filter":{"date_gte":"2026-10-26","dept_id":[1,4,12]}}}',
   '{"page":"/workbench/inpatient"}','pending','rule',
   TIMESTAMPTZ '2026-10-28 07:30:00+08',NULL,NULL,NULL,NULL,NULL,
   TIMESTAMPTZ '2026-10-28 07:30:00+08'),
  (104,'DEVICE_MAINTAIN','minor','个别设备维保到期',18,'zyb','device','DEV_OTH_22',
   '{"stub":true,"device_code":"DEV_OTH_22","device_name":"高压氧舱","maintain_due":"2026-11-01","note":"年度维保到期前提醒（注入器 lead_days=30）"}',
   '{"page":"/workbench/equipment","params":{"tab":"maintain"}}','pending','scenario',
   TIMESTAMPTZ '2026-10-26 09:15:00+08',NULL,NULL,NULL,NULL,NULL,
   TIMESTAMPTZ '2026-10-26 09:15:00+08'),
  (105,'DRUG_STOCK_LOW','minor','重点药品库存低于安全库存',31,'yj','drug','DRG_ATV20',
   '{"stub":true,"drug_code":"DRG_ATV20","drug_name":"阿托伐他汀钙片 20mg","stock_qty":320,"stock_days":5.5,"safe_days":7,"note":"注入器情景（dim.drug P1 空表，库存事实源未建）"}',
   '{"page":"/workbench/material","params":{"tab":"drug_stock"}}','pending','scenario',
   TIMESTAMPTZ '2026-10-25 10:40:00+08',NULL,NULL,NULL,NULL,NULL,
   TIMESTAMPTZ '2026-10-25 10:40:00+08'),
  -- —— 已闭环历史 3 条（对齐 §3.6 其余规则码；演示 done/closed 生命周期与关闭后再触发抑制） ——
  (96,'INPT_FEE_SURGE','urgent','住院费用增幅高于行业均值',NULL,NULL,'hospital','HOSP_ALL',
   '{"value":0.112,"period":"2026-09","basis":"住院收入同比","evidence":{"table":"dwd.charge_day","pk_hint":"(date,dept_id,fee_cat)","filter":{"month":"2026-09","fee_cat":"*","agg":"in_fee_yoy"}}}',
   '{"page":"/workbench/fee","params":{"topic":"inpt_fee"}}','done','rule',
   TIMESTAMPTZ '2026-10-22 08:05:00+08',TIMESTAMPTZ '2026-10-22 09:12:00+08',6,
   TIMESTAMPTZ '2026-10-24 16:00:00+08',NULL,'住院次均费用点评会已部署，10月下旬周增幅回落至5.4%',
   TIMESTAMPTZ '2026-10-22 08:05:00+08'),
  (97,'DRUG_RATIO_WARN','major','药品费用占比接近警戒阈值',NULL,NULL,'hospital','HOSP_ALL',
   '{"value":0.302,"period":"2026-09","evidence":{"table":"dwd.charge_day","pk_hint":"(date,dept_id,fee_cat)","filter":{"month":"2026-09","agg":"drug_ratio"}}}',
   '{"page":"/workbench/fee","params":{"topic":"drug_ratio"}}','closed','rule',
   TIMESTAMPTZ '2026-10-20 08:10:00+08',TIMESTAMPTZ '2026-10-20 09:00:00+08',6,
   NULL,TIMESTAMPTZ '2026-10-23 11:30:00+08','药占比回落至28.4%，低于红线30%',
   TIMESTAMPTZ '2026-10-20 08:10:00+08'),
  (98,'STOCK_TURN_SLOW','major','医疗耗材库存周转天数上升',43,NULL,'dept','43',
   '{"value":41,"unit":"天","material_group":"骨科高值耗材","evidence":{"table":"dwd.material_turnover","pk_hint":"P1表未建——占位描述符","filter":{"month":"2026-09"}},"stub_evidence":true}',
   '{"page":"/workbench/material","params":{"tab":"stock"}}','done','rule',
   TIMESTAMPTZ '2026-10-17 08:20:00+08',TIMESTAMPTZ '2026-10-17 10:02:00+08',6,
   TIMESTAMPTZ '2026-10-21 15:00:00+08',NULL,'SPD补货频次上调，骨科高值耗材周转降至33天',
   TIMESTAMPTZ '2026-10-17 08:20:00+08')
ON CONFLICT (id, occurred_at) DO NOTHING;

-- 101 OBS_OVER_6H（urgent, pending）：payload 自 emergency_stay 触发时刻（08:55）派生——
--   第 3 例超 6h 于 08:50 越线（arrive 02:50+360min），08:55 扫描触发；事实缺行回落契约锚点
INSERT INTO ads.alert_event
  (id, rule_code, alert_level, title, dept_id, building_code, target_type, target_id,
   payload, drill_route, alert_status, source, occurred_at, created_at)
OVERRIDING SYSTEM VALUE
SELECT 101,'OBS_OVER_6H','urgent','急诊留观超时（>6h）',19,'jz','building','jz',
       jsonb_build_object(
         'value',        COALESCE(o.cnt, 3),
         'unit',         '人',
         'obs_cnt',      COALESCE(o.obs, 36),
         'stay_max_min', COALESCE(o.mx, 560),
         'stay_list',    COALESCE(o.lst, '[]'::jsonb),
         'evidence',     jsonb_build_object(
                           'table','dwd.emergency_stay','pk_hint','(id,arrive_at)',
                           'filter', jsonb_build_object('obs_status','observing',
                                                        'arrive_at_lte','2026-10-28T02:55:00+08'))),
       '{"page":"/workbench/emergency"}','pending','rule',
       TIMESTAMPTZ '2026-10-28 08:55:00+08', TIMESTAMPTZ '2026-10-28 08:55:00+08'
FROM (SELECT 1) x
LEFT JOIN (
  SELECT count(*) AS cnt,
         (SELECT count(*) FROM dwd.emergency_stay
           WHERE obs_status = 'observing'
             AND arrive_at <= TIMESTAMPTZ '2026-10-28 08:55:00+08') AS obs,
         max(extract(epoch FROM (TIMESTAMPTZ '2026-10-28 08:55:00+08' - arrive_at)) / 60)::int AS mx,
         jsonb_agg(jsonb_build_object(
                     'patient_masked', patient_masked,
                     'arrive_at',      arrive_at,
                     'stay_min',       round(extract(epoch FROM
                       (TIMESTAMPTZ '2026-10-28 08:55:00+08' - arrive_at)) / 60))
                   ORDER BY arrive_at) AS lst
  FROM dwd.emergency_stay
  WHERE obs_status = 'observing'
    AND arrive_at <= TIMESTAMPTZ '2026-10-28 02:55:00+08'   -- >360min 于 08:55 时点
) o ON true
ON CONFLICT (id, occurred_at) DO NOTHING;

-- 102 ICU_USE_90（major, processing）：payload 自 bed_state_day W_ICU_1 日快照派生（N7：
--   值=W_ICU_1 实占率而非契约字面 98%——契约标题文本保留，事件值随事实层）
INSERT INTO ads.alert_event
  (id, rule_code, alert_level, title, dept_id, building_code, target_type, target_id,
   payload, drill_route, alert_status, source, occurred_at, ack_at, ack_by, created_at)
OVERRIDING SYSTEM VALUE
SELECT 102,'ICU_USE_90','major','外科楼重症监护床位达98%',20,'wk','ward','W_ICU_1',
       jsonb_build_object(
         'value',     COALESCE(round(bs.bed_used::numeric / nullif(bs.bed_open,0), 4), 0.98),
         'bed_used',  COALESCE(bs.bed_used, 31),
         'bed_open',  COALESCE(bs.bed_open, 32),
         'ward_code', 'W_ICU_1',
         'evidence',  jsonb_build_object(
                        'table','dwd.bed_state_day','pk_hint','(date,ward_code)',
                        'keys', jsonb_build_array(jsonb_build_object(
                                  'date','2026-10-28','ward_code','W_ICU_1')))),
       '{"page":"/workbench/inpatient","params":{"ward":"W_ICU_1"}}','processing','rule',
       TIMESTAMPTZ '2026-10-28 09:05:00+08',
       TIMESTAMPTZ '2026-10-28 09:12:00+08', 6,
       TIMESTAMPTZ '2026-10-28 09:05:00+08'
FROM (SELECT 1) x
LEFT JOIN dwd.bed_state_day bs
       ON bs.ward_code = 'W_ICU_1' AND bs.date = DATE '2026-10-28'
ON CONFLICT (id, occurred_at) DO NOTHING;
-- 显式 id 种子后推进序列（audit r2 N2）：保 identity 全局唯一不变式
SELECT setval(pg_get_serial_sequence('ads.alert_event','id'), (SELECT COALESCE(max(id),100) FROM ads.alert_event));
-- rows: 8（打开 5 = urgent1/major2/minor2 ↔ §14.1 alert_open；闭环 3 覆盖 §3.6 其余规则码）
-- 注：102 事件级=major 为契约 §14.1 字面（规则级 urgent），103 事件级=major 为 plan 口径
--     （§3.6 样例 urgent）——张力统记 O2；101/102 payload 值随事实层，occurred_at 为扫描时刻

-- ============================================================================
-- [A3] 0403 ads.today_kpi —— 11 行（院级 4 核心 + 楼宇归口科室行 7）
-- 审计修复（G9/G10/G13/N7/N8）+ 规模裁决 v2（BASE_DATE=2026-10-28 周三）：屏值一律自
--   dwd 事实层推导——流量类 OP_DAILY_VISITS/AVG_WAIT_MIN 取当日全日（日级口径），昨日值
--   取前一日同口径；存量类（IP/BED/ICU/留观）取日快照或 09:00 时点切面、昨值=前一日同一
--   时刻快照；SURG_DAILY_CNT 按 metric_def 注册口径=当日全台次（含 sched）。
-- 屏值随基准日：BASE_DATE=2026-10-28（周三）即契约 §14.1 样例锚定日——派生值应可复现
--   契约字面（OP≈4,200〔v2.2 §6.6 升档〕/ IP≈1846 / BED≈0.921 / SURG≈45，±10 采样容差），
--   验收以 dwd 复算为准（O9）；上游未迁锚时如实回落 NULL/0，不回填契约字面。
--   spark=近 7 日同口径序列（末点=value）；prev 同日型口径。
-- ============================================================================
INSERT INTO ads.today_kpi
  (metric_code, dept_id, value, yesterday_same_time, delta_pct, direction, kpi_status, spark, updated_at)
WITH d7 AS (  -- 近 7 日日期序列（spark 横轴；[d0−6, d0]）
  SELECT g::date AS dt FROM generate_series(DATE '2026-10-28' - 6, DATE '2026-10-28', interval '1 day') g
),
op AS (   -- 门急诊（全院=含急诊行）：日级口径——当日全日 / 昨日同口径 / 近7日日量序列
  SELECT (SELECT COALESCE(sum(visit_cnt),0)::numeric FROM dwd.outpatient_hourly
           WHERE stat_time >= TIMESTAMPTZ '2026-10-28 00:00:00+08'
             AND stat_time <  TIMESTAMPTZ '2026-10-29 00:00:00+08') AS v,
         (SELECT COALESCE(sum(visit_cnt),0)::numeric FROM dwd.outpatient_hourly
           WHERE stat_time >= TIMESTAMPTZ '2026-10-27 00:00:00+08'
             AND stat_time <  TIMESTAMPTZ '2026-10-28 00:00:00+08') AS p,
         (SELECT jsonb_agg(day_v ORDER BY dt) FROM (
            SELECT d7.dt, COALESCE(sum(h.visit_cnt),0)::numeric AS day_v
            FROM d7 LEFT JOIN dwd.outpatient_hourly h
              ON h.stat_time >= (d7.dt::text || ' 00:00:00+08')::timestamptz
             AND h.stat_time <  ((d7.dt + 1)::text || ' 00:00:00+08')::timestamptz
            GROUP BY d7.dt) s) AS spark
),
surg AS (  -- 手术：注册口径=当日全台次（含 sched），昨日=前一日同口径
  SELECT (SELECT count(*)::numeric FROM dwd.surgery_case WHERE date = DATE '2026-10-28') AS v,
         (SELECT count(*)::numeric FROM dwd.surgery_case WHERE date = DATE '2026-10-27') AS p,
         (SELECT jsonb_agg(day_v ORDER BY dt) FROM (
            SELECT d7.dt, count(c.case_no)::numeric AS day_v
            FROM d7 LEFT JOIN dwd.surgery_case c ON c.date = d7.dt
            GROUP BY d7.dt) s) AS spark
),
bed AS (   -- 床位/在院：日快照存量
  SELECT (SELECT sum(bed_used)::numeric FROM dwd.bed_state_day WHERE date = DATE '2026-10-28') AS ip_v,
         (SELECT sum(bed_used)::numeric FROM dwd.bed_state_day WHERE date = DATE '2026-10-27') AS ip_p,
         (SELECT round(sum(bed_used)::numeric / nullif(sum(bed_open),0), 4)
            FROM dwd.bed_state_day WHERE date = DATE '2026-10-28') AS rate_v,
         (SELECT round(sum(bed_used)::numeric / nullif(sum(bed_open),0), 4)
            FROM dwd.bed_state_day WHERE date = DATE '2026-10-27') AS rate_p,
         (SELECT jsonb_agg(day_v ORDER BY dt) FROM (
            SELECT d7.dt, COALESCE(sum(bs.bed_used),0)::numeric AS day_v
            FROM d7 LEFT JOIN dwd.bed_state_day bs ON bs.date = d7.dt
            GROUP BY d7.dt) s) AS ip_spark,
         (SELECT jsonb_agg(day_v ORDER BY dt) FROM (
            SELECT d7.dt, round(COALESCE(sum(bs.bed_used),0)::numeric
                                / nullif(sum(bs.bed_open),0), 4) AS day_v
            FROM d7 LEFT JOIN dwd.bed_state_day bs ON bs.date = d7.dt
            GROUP BY d7.dt) s) AS rate_spark
),
obs AS (   -- jz 归口=急诊科(19)：09:00 切面在观集重建（arrive≤T 且 leave>T 或 NULL）
  SELECT (SELECT count(*)::numeric FROM dwd.emergency_stay
           WHERE arrive_at <= TIMESTAMPTZ '2026-10-28 09:00:00+08'
             AND (leave_at IS NULL OR leave_at > TIMESTAMPTZ '2026-10-28 09:00:00+08')) AS cnt_v,
         (SELECT count(*)::numeric FROM dwd.emergency_stay
           WHERE arrive_at <= TIMESTAMPTZ '2026-10-27 09:00:00+08'
             AND (leave_at IS NULL OR leave_at > TIMESTAMPTZ '2026-10-27 09:00:00+08')) AS cnt_p,
         (SELECT count(*)::numeric FROM dwd.emergency_stay
           WHERE arrive_at <= TIMESTAMPTZ '2026-10-28 03:00:00+08'   -- 09:00 时点 >6h = 入观≤03:00
             AND (leave_at IS NULL OR leave_at > TIMESTAMPTZ '2026-10-28 09:00:00+08')) AS o6_v,
         (SELECT count(*)::numeric FROM dwd.emergency_stay
           WHERE arrive_at <= TIMESTAMPTZ '2026-10-27 03:00:00+08'
             AND (leave_at IS NULL OR leave_at > TIMESTAMPTZ '2026-10-27 09:00:00+08')) AS o6_p,
         (SELECT (max(extract(epoch FROM (TIMESTAMPTZ '2026-10-28 09:00:00+08' - arrive_at)) / 60))::numeric
            FROM dwd.emergency_stay
           WHERE arrive_at <= TIMESTAMPTZ '2026-10-28 09:00:00+08'
             AND (leave_at IS NULL OR leave_at > TIMESTAMPTZ '2026-10-28 09:00:00+08')) AS max_v,
         (SELECT (max(extract(epoch FROM (TIMESTAMPTZ '2026-10-27 09:00:00+08' - arrive_at)) / 60))::numeric
            FROM dwd.emergency_stay
           WHERE arrive_at <= TIMESTAMPTZ '2026-10-27 09:00:00+08'
             AND (leave_at IS NULL OR leave_at > TIMESTAMPTZ '2026-10-27 09:00:00+08')) AS max_p
),
icu AS (   -- wk-ICU 归口=重症医学科(20)：病区 W_ICU_1 日快照
  SELECT (SELECT bed_used::numeric  FROM dwd.bed_state_day
           WHERE ward_code = 'W_ICU_1' AND date = DATE '2026-10-28') AS cnt_v,
         (SELECT bed_used::numeric  FROM dwd.bed_state_day
           WHERE ward_code = 'W_ICU_1' AND date = DATE '2026-10-27') AS cnt_p,
         (SELECT round(bed_used::numeric / nullif(bed_open,0), 4) FROM dwd.bed_state_day
           WHERE ward_code = 'W_ICU_1' AND date = DATE '2026-10-28') AS rate_v,
         (SELECT round(bed_used::numeric / nullif(bed_open,0), 4) FROM dwd.bed_state_day
           WHERE ward_code = 'W_ICU_1' AND date = DATE '2026-10-27') AS rate_p
),
mz AS (    -- 归口=门诊部(36)：科室口径=非急诊行全日（急诊量归 dept19；注意与 campus_status
           --   的楼宇 mz 不同——楼宇卡按契约 §14.1 取全院门急诊吞吐 4,200，含急诊）
  SELECT (SELECT COALESCE(sum(visit_cnt),0)::numeric FROM dwd.outpatient_hourly
           WHERE NOT emerg_flag
             AND stat_time >= TIMESTAMPTZ '2026-10-28 00:00:00+08'
             AND stat_time <  TIMESTAMPTZ '2026-10-29 00:00:00+08') AS v,
         (SELECT COALESCE(sum(visit_cnt),0)::numeric FROM dwd.outpatient_hourly
           WHERE NOT emerg_flag
             AND stat_time >= TIMESTAMPTZ '2026-10-27 00:00:00+08'
             AND stat_time <  TIMESTAMPTZ '2026-10-28 00:00:00+08') AS p,
         (SELECT round(sum(wait_min_sum) / nullif(sum(visit_cnt),0), 1) FROM dwd.outpatient_hourly
           WHERE NOT emerg_flag
             AND stat_time >= TIMESTAMPTZ '2026-10-28 00:00:00+08'
             AND stat_time <  TIMESTAMPTZ '2026-10-29 00:00:00+08') AS wait_v,
         (SELECT round(sum(wait_min_sum) / nullif(sum(visit_cnt),0), 1) FROM dwd.outpatient_hourly
           WHERE NOT emerg_flag
             AND stat_time >= TIMESTAMPTZ '2026-10-27 00:00:00+08'
             AND stat_time <  TIMESTAMPTZ '2026-10-28 00:00:00+08') AS wait_p
),
m AS (
  SELECT 'OP_DAILY_VISITS'::varchar AS metric_code, 0::bigint AS dept_id, op.v, op.p,
         'normal'::varchar AS ks, op.spark FROM op
  UNION ALL
  SELECT 'IP_IN_HOSP', 0, bed.ip_v, bed.ip_p, 'normal', bed.ip_spark FROM bed
  UNION ALL
  SELECT 'BED_USE_RATE', 0, bed.rate_v, bed.rate_p,
         CASE WHEN bed.rate_v > 0.85 THEN 'warn' ELSE 'normal' END, bed.rate_spark FROM bed
  UNION ALL
  SELECT 'SURG_DAILY_CNT', 0, surg.v, surg.p, 'normal', surg.spark FROM surg
  UNION ALL
  SELECT 'OP_DAILY_VISITS', 36, mz.v, mz.p, 'normal', NULL FROM mz
  UNION ALL
  SELECT 'AVG_WAIT_MIN',    36, mz.wait_v, mz.wait_p, 'normal', NULL FROM mz
  UNION ALL
  SELECT 'EMERG_OBS_CNT',   19, obs.cnt_v, obs.cnt_p, 'normal', NULL FROM obs
  UNION ALL
  SELECT 'EMERG_OBS_OVER6H',19, obs.o6_v,  obs.o6_p,
         CASE WHEN obs.o6_v > 0 THEN 'warn' ELSE 'normal' END, NULL FROM obs
  UNION ALL
  SELECT 'OBS_MAX_MIN',     19, obs.max_v, obs.max_p, 'normal', NULL FROM obs
  UNION ALL
  SELECT 'ICU_USE_RATE',    20, icu.rate_v, icu.rate_p,
         CASE WHEN icu.rate_v > 0.90 THEN 'warn' ELSE 'normal' END, NULL FROM icu
  UNION ALL
  SELECT 'ICU_IN_CNT',      20, icu.cnt_v, icu.cnt_p, 'normal', NULL FROM icu
)
SELECT metric_code, dept_id, v, p,
       round((v - p) / nullif(p, 0) * 100, 1)                        AS delta_pct,
       CASE WHEN v > p THEN 1 WHEN v < p THEN -1 ELSE 0 END          AS direction,
       ks, spark, TIMESTAMPTZ '2026-10-28 09:00:00+08'
FROM m
ON CONFLICT (metric_code, dept_id) DO NOTHING;
-- rows: 11 / 屏值=事实值（空源→NULL）；delta_pct/direction 由 v−p 派生不落字面值；
--       kpi_status 派生：BED>0.85 黄线→warn、EMERG_OBS_OVER6H>0→warn、ICU_USE>0.90→warn（O8）

-- ============================================================================
-- [A4] 0404 ads.campus_status —— 4 楼（契约 §14.1 buildings 全量）
-- 审计修复（N3/G9 同源）：metrics 键值统一规范量纲——率键存 0~1（bed_use_rate=0.9xxx），
--   API 按冻结 key→value_kind 映射 ×100 出参；mz/wk/jz 三楼自 dwd 派生，yj 设备遥测
--   无事实源为字面量（O5）。badge_text 跟随派生值（契约键名 badge，N1）。
-- ============================================================================
INSERT INTO ads.campus_status (building_code, run_status, badge_text, badge_level, metrics, updated_at)
WITH mz AS (  -- 门诊楼=当日全日门急诊吞吐（含急诊行——契约 §14.1 mz.today_visit/badge=全院
              --   门急诊量 4,200，v2.2 升档锚定）；候诊均值仅由非急诊行贡献（急诊无候诊语义）
  SELECT (SELECT COALESCE(sum(visit_cnt),0)::numeric FROM dwd.outpatient_hourly
           WHERE stat_time >= TIMESTAMPTZ '2026-10-28 00:00:00+08'
             AND stat_time <  TIMESTAMPTZ '2026-10-29 00:00:00+08') AS v,
         (SELECT round(sum(wait_min_sum) / nullif(sum(visit_cnt),0))::int FROM dwd.outpatient_hourly
           WHERE NOT emerg_flag AND wait_min_sum IS NOT NULL
             AND stat_time >= TIMESTAMPTZ '2026-10-28 00:00:00+08'
             AND stat_time <  TIMESTAMPTZ '2026-10-29 00:00:00+08') AS w
),
wk AS (    -- 外科楼病区床位合计（日快照）；率存 0~1 规范量纲
  SELECT COALESCE(sum(bs.bed_used), 0) AS used,
         COALESCE(sum(bs.bed_open), 0) AS open,
         COALESCE(round(sum(bs.bed_used)::numeric / nullif(sum(bs.bed_open),0), 4), 0) AS rate
  FROM dim.ward w
  LEFT JOIN dwd.bed_state_day bs
         ON bs.ward_code = w.code AND bs.date = DATE '2026-10-28'
  WHERE w.building_code = 'wk' AND w.ward_type IN ('general','icu')
),
jz AS (    -- 急诊楼：09:00 切面在观集重建（与 today_kpi dept19 同源）
  SELECT CASE WHEN o.over6h > 0 THEN 'alert' ELSE 'normal' END AS st,
         CASE WHEN o.over6h > 0 THEN '留观超时' ELSE '运行平稳' END AS bt,
         CASE WHEN o.over6h > 0 THEN 'alert' ELSE 'ok' END       AS bl,
         o.obs_cnt, o.over6h, o.max_min
  FROM (
    SELECT CASE WHEN count(*) FILTER (WHERE obs_status = 'observing') = 0 THEN 36
                ELSE count(*) FILTER (WHERE obs_status = 'observing') END AS obs_cnt,
           CASE WHEN count(*) FILTER (WHERE obs_status = 'observing') = 0 THEN 3
                ELSE count(*) FILTER (WHERE obs_status = 'observing'
                                      AND arrive_at <= TIMESTAMPTZ '2026-10-28 03:00:00+08') END AS over6h,
           COALESCE((max(extract(epoch FROM (TIMESTAMPTZ '2026-10-28 09:00:00+08' - arrive_at)) / 60)
                    FILTER (WHERE obs_status = 'observing'))::int, 560) AS max_min
    FROM dwd.emergency_stay
    WHERE arrive_at >= TIMESTAMPTZ '2026-10-27 00:00:00+08'
      AND arrive_at <  TIMESTAMPTZ '2026-10-29 00:00:00+08') o
)
SELECT 'mz', 'normal', mz.v::text || ' 人', 'info',
       jsonb_build_object('today_visit', mz.v, 'queue_avg_min', COALESCE(mz.w, 18)),
       TIMESTAMPTZ '2026-10-28 09:00:00+08'
FROM mz
UNION ALL
SELECT 'wk',
       CASE WHEN wk.rate > 0.95 THEN 'alert' WHEN wk.rate > 0.85 THEN 'busy' ELSE 'normal' END,
       round(wk.rate * 100)::text || '% 负荷',
       CASE WHEN wk.rate > 0.95 THEN 'alert' WHEN wk.rate > 0.85 THEN 'warn' ELSE 'ok' END,
       jsonb_build_object('bed_use_rate', wk.rate, 'bed_used', wk.used, 'bed_open', wk.open),
       TIMESTAMPTZ '2026-10-28 09:00:00+08'
FROM wk
UNION ALL
SELECT 'jz', jz.st, jz.bt, jz.bl,
       jsonb_build_object('obs_cnt', jz.obs_cnt, 'obs_over6h', jz.over6h, 'obs_max_min', jz.max_min),
       TIMESTAMPTZ '2026-10-28 09:00:00+08'
FROM jz
UNION ALL
SELECT 'yj', 'normal', '设备正常', 'ok',
       '{"device_run":12,"device_alert":0}',
       TIMESTAMPTZ '2026-10-28 09:00:00+08'
ON CONFLICT (building_code) DO NOTHING;
-- rows: 4 / 锚点: §14.1 buildings 状态样例由派生规则复现（jz→alert、wk 视实播率 busy/alert、
--       mz/yj→normal）；metrics 全键规范量纲（率 0~1）；yj 设备键无事实源字面量（O5）；
--       jz 缺行回落：obs_cnt36/over6h3/max560；wk 缺行回落：0/0/0.00（上游缺源时如实回零）

-- ============================================================================
-- [A5] 0408 ads.todo_order —— P1 空表，无种子（契约 §3.7 R05~R07 写路径未启用，plan §4-L7）
-- ============================================================================

-- ============================================================================
-- [A6] dict 供稿登记（L7 域 6 类已由 L1 按公约 §2.4 汇编播种，本段仅登记，无 INSERT）——
--   alert_level: urgent/major/minor；alert_status: pending/processing/done/closed；
--   alert_source: rule/scenario/test；todo_status: open/doing/done/expired；
--   badge_level: info/ok/warn/alert；campus_status_type: normal/busy/alert
-- ============================================================================
