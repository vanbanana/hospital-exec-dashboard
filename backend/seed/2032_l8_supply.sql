-- ============================================================================
-- lane L8c/L8d/L8e newdom-pat-qual-asset — 种子·相位Ⅲb：dws 供稿层
--   内容：§11 dws.quality_rule_audit / §12 dws.energy_month（本 lane 自有 dws
--         周期表，对应汇编 3010_l8_dws.sql）/ §13 dws.metric_value 供稿
--         （a)~(m) 13 段，对应汇编 3011_l8_metric_value.sql，含 L8pat 代播
--         INS_BALANCE_RATE/RX_OUTFLOW_RATE）
-- 相位：seed-manifest §1 Ⅲb——必须在 L5 相位Ⅲa（dws.hospital_oper_day 等
--       汇总行）之后执行：§13(k) ENERGY_PER_WAN_REV 分母读其 revenue 行；
--       §13 各派生段读本 lane 相位Ⅱ事实（seed_2_facts.sql 先行）。
-- 依赖：seed_2_facts（feedback/critical/infection/adverse/device/stock/wo
--       事实 + dim.material）；L3 dwd.inpatient_move/bed_state_day（HAI/百床
--       分母，缺则对应月空行）；L4 surgery_case（SSI 分母）；L5 dws.metric_value
--       表+dws.hospital_oper_day 行（缺则 ENERGY_PER_WAN_REV 空行不伪锚）；
--       L1 metric_def 先行合流（§13(m) EXISTS 守卫）。
-- 幂等：自有 dws 表 ON CONFLICT DO NOTHING；metric_value 供稿 ON CONFLICT
--       (metric_code,dept_id,group_id,date) DO NOTHING；可重复执行。
-- ============================================================================

\set ON_ERROR_STOP on

-- ---------------------------------------------------------------- §0 工具 --
CREATE OR REPLACE FUNCTION pg_temp.h01(k text) RETURNS numeric
LANGUAGE sql IMMUTABLE AS $f$
  -- 确定性散列 ∈[0,1)：取 md5 前 60bit 为正整数域，规避符号位
  SELECT (('x' || md5(k))::bit(60)::bigint)::numeric / 1152921504606846976.0
$f$;

-- @phase: 3b
-- ============================================================================
-- §11 dws.quality_rule_audit —— 8 制度 × 24 月（192 行）
-- 锚：2026-10 契约原值（sample/pass/issues）；其余月 sample ±8%、合格率 ±2pt 抖动。
-- O-N7（escalations）：非锚月 base_rate 上调至 0.94~0.98 → 生成通过率 92~100%
--   贴契约区间（锚月仍契约字面 88.6~99.1%，不另行加工）。
-- ============================================================================
INSERT INTO dws.quality_rule_audit (period_type, period_start, rule_code, rule_name, sample_cnt, pass_cnt, issues)
SELECT 'month', p0, rule_code, rule_name, sample_cnt, pass_cnt, issues
FROM (VALUES
  ('first_visit','首诊负责制',      280,270,'个别首诊病历书写延迟'),
  ('ward_round','三级查房制度',      260,240,'主任查房记录欠详实'),
  ('consult','会诊制度',            240,230,'常规会诊偶有超时'),
  ('crit_report','危急值报告制度',    280,276,'闭环确认偶有遗漏'),
  ('surg_check','手术安全核查制度',   220,218,'三方核查签字不全 2 例'),
  ('mr_write','病历书写规范',        300,266,'24小时出入院记录欠完整'),
  ('abx_class','抗菌药物分级管理',    260,237,'特殊级抗菌药越权使用 3 例'),
  ('shift_hand','值班交接班制度',     280,264,'床旁交接偶无双人签字')
) v(rule_code,rule_name,sample_cnt,pass_cnt,issues)
CROSS JOIN (SELECT '2026-10-01'::date AS p0) m
UNION ALL
SELECT 'month', p0, r.rule_code, r.rule_name,
       round(r.samp * (0.92 + 0.16*pg_temp.h01('qa.s.'||r.rule_code||'|'||p0::text)))::int AS sample_cnt,
       least(round(r.samp * (0.92 + 0.16*pg_temp.h01('qa.s.'||r.rule_code||'|'||p0::text)))::int,
             round(r.samp * (0.92 + 0.16*pg_temp.h01('qa.s.'||r.rule_code||'|'||p0::text))
                   * (r.base_rate + 0.04*(pg_temp.h01('qa.p.'||r.rule_code||'|'||p0::text) - 0.5)))::int) AS pass_cnt,
       CASE WHEN pg_temp.h01('qa.i.'||r.rule_code||'|'||p0::text) < 0.15 THEN NULL ELSE r.issues END
FROM (VALUES
  -- O-N7：base_rate 上调至 0.94~0.98（±2pt → 月率 92~100% 契约区间）；
  --       锚月行另以契约字面直落，不经此参数。
  ('first_visit','首诊负责制',      280.0, 0.9600, '个别首诊病历书写延迟'),
  ('ward_round','三级查房制度',      260.0, 0.9450, '主任查房记录欠详实'),
  ('consult','会诊制度',            240.0, 0.9600, '常规会诊偶有超时'),
  ('crit_report','危急值报告制度',    280.0, 0.9800, '闭环确认偶有遗漏'),
  ('surg_check','手术安全核查制度',   220.0, 0.9800, '三方核查签字不全 2 例'),
  ('mr_write','病历书写规范',        300.0, 0.9400, '24小时出入院记录欠完整'),
  ('abx_class','抗菌药物分级管理',    260.0, 0.9450, '特殊级抗菌药越权使用 3 例'),
  ('shift_hand','值班交接班制度',     280.0, 0.9500, '床旁交接偶无双人签字')
) r(rule_code,rule_name,samp,base_rate,issues)
CROSS JOIN LATERAL (
  SELECT (date_trunc('month', '2025-01-01'::date) + (g.m || ' month')::interval)::date AS p0
  FROM generate_series(0, 23) g(m)) mm
WHERE p0 <> '2026-10-01'
ON CONFLICT (period_type, period_start, rule_code) DO NOTHING;
-- rows: 192

-- ============================================================================
-- §12 dws.energy_month —— 24 月 × 3 分项（72 行）
-- 锚：契约 5~10月分项原值（万元×1e4=元）；Oct Σ=186 万命中 stats（锚月随
--     BASE_DATE 移 Oct）。契约 total 序列与分项和在 5/6 月不等 → total 不落行
--     由 API 聚合（open-items #10）。
--     其余月按季节形状延展（电夏季峰/气冬季峰/水平稳）。energy_qty 按当量单价派生。
-- ============================================================================
INSERT INTO dws.energy_month (period_type, period_start, energy_type, energy_amt, energy_qty)
SELECT 'month', p0::date, et, amt, round(amt / unit_price, 1)
FROM (VALUES
  -- (年月, 电万元, 水万元, 气万元) —— 2026-05~10 为契约原值段（趋势窗随锚月右移）
  ('2025-01-01', 98,32,46),('2025-02-01', 92,30,44),('2025-03-01', 95,32,39),
  ('2025-04-01',102,33,35),('2025-05-01',110,35,31),('2025-06-01',124,39,27),
  ('2025-07-01',136,42,25),('2025-08-01',142,44,26),('2025-09-01',134,42,28),
  ('2025-10-01',116,38,33),('2025-11-01',102,34,39),('2025-12-01',106,33,45),
  ('2026-01-01',104,34,45),('2026-02-01', 97,32,41),('2026-03-01',102,34,36),
  ('2026-04-01',108,36,33),('2026-05-01',112,38,32),('2026-06-01',126,42,28),
  ('2026-07-01',142,46,26),('2026-08-01',138,44,28),('2026-09-01',120,40,32),
  ('2026-10-01',114,38,34),('2026-11-01',112,37,42),('2026-12-01',108,35,47)
) v(p0, elec_w, water_w, gas_w)
CROSS JOIN LATERAL (VALUES
  ('electricity', elec_w::numeric * 10000, 0.82),
  ('water',       water_w::numeric * 10000, 4.00),
  ('gas',         gas_w::numeric * 10000, 3.40)
) e(et, amt, unit_price)
ON CONFLICT (period_type, period_start, energy_type) DO NOTHING;
-- rows: 72

-- ============================================================================
-- §13 dws.metric_value 供稿 —— 本域指标值行（并入汇编 3011_l8_metric_value.sql）
-- 写面：院0 月行；SAT_*/EMR_GRADE_A_RATE/REG_CHANNEL_SHARE/DEVICE_* 不写值
-- （SAT/EMR L5 已写；渠道与设备粒度超出键域，API 直读 dwd 聚合）。
-- ============================================================================

-- (a) 患者域：COMPLAINT_CNT / PRAISE_CNT（feedback_event 月聚合，院0）
INSERT INTO dws.metric_value (metric_code, date, dept_id, group_id, value, extra)
SELECT m, p, 0, 0, v, NULL FROM (
  SELECT 'COMPLAINT_CNT' AS m, date_trunc('month', event_date)::date AS p, count(*)::numeric AS v
  FROM dwd.feedback_event WHERE fb_type='complaint' GROUP BY 2
  UNION ALL
  SELECT 'PRAISE_CNT', date_trunc('month', event_date)::date, count(*)::numeric
  FROM dwd.feedback_event WHERE fb_type='praise' GROUP BY 2
) u
ON CONFLICT (metric_code, dept_id, group_id, date) DO NOTHING;
-- rows: 48

-- (b) 手工锚定·患者：ONLINE_REG_RATE（version=0 口径未定；锚 0.886 爬坡序列）
INSERT INTO dws.metric_value (metric_code, date, dept_id, group_id, value, extra)
SELECT 'ONLINE_REG_RATE', p0::date, 0, 0, v, '{"src":"manual-anchor","note":"契约锚 88.6%；口径待定 open-items #2"}'::jsonb
FROM (VALUES
  ('2025-01-01',0.7920),('2025-02-01',0.7880),('2025-03-01',0.8010),('2025-04-01',0.8060),
  ('2025-05-01',0.8120),('2025-06-01',0.8180),('2025-07-01',0.8240),('2025-08-01',0.8290),
  ('2025-09-01',0.8340),('2025-10-01',0.8410),('2025-11-01',0.8470),('2025-12-01',0.8520),
  ('2026-01-01',0.8560),('2026-02-01',0.8510),('2026-03-01',0.8580),('2026-04-01',0.8620),
  ('2026-05-01',0.8680),('2026-06-01',0.8730),('2026-07-01',0.8770),('2026-08-01',0.8800),
  ('2026-09-01',0.8830),('2026-10-01',0.8860),('2026-11-01',0.8880),('2026-12-01',0.8900)
) v(p0, v)
ON CONFLICT (metric_code, dept_id, group_id, date) DO NOTHING;
-- rows: 24

-- (c) 质安域派生：CRIT_TIMELY_RATE / ADVERSE_EVENT_CNT / CRIT_UNCLOSED
INSERT INTO dws.metric_value (metric_code, date, dept_id, group_id, value, extra)
SELECT m, p, 0, 0, round(v,4), NULL FROM (
  SELECT 'CRIT_TIMELY_RATE' AS m, date_trunc('month', report_at)::date AS p,
         count(*) FILTER (WHERE close_at - report_at <= interval '30 minutes')::numeric
           / NULLIF(count(*),0) AS v
  FROM dwd.critical_value WHERE cv_status='closed' GROUP BY 2
  UNION ALL
  SELECT 'ADVERSE_EVENT_CNT', date_trunc('month', event_date)::date, count(*)::numeric
  FROM dwd.adverse_event GROUP BY 2
) u
ON CONFLICT (metric_code, dept_id, group_id, date) DO NOTHING;
INSERT INTO dws.metric_value (metric_code, date, dept_id, group_id, value, extra)
SELECT 'CRIT_UNCLOSED', '2026-10-28', 0, 0,
       count(*)::numeric, '{"asof":"2026-10-28T09:00+08","note":"realtime 点值"}'::jsonb
FROM dwd.critical_value WHERE cv_status='open'
ON CONFLICT (metric_code, dept_id, group_id, date) DO NOTHING;
-- rows: 48 + 1

-- (d) HAI_RATE（分子 infection_case / 分母 inpatient_move 出院；L3 缺种子时为空）
WITH ha AS (
  SELECT date_trunc('month', confirm_date)::date AS p, count(*) AS cases
  FROM dwd.infection_case GROUP BY 1),
dc AS (
  SELECT date_trunc('month', event_time)::date AS p, count(*) AS disch
  FROM dwd.inpatient_move WHERE event='discharge' GROUP BY 1)
INSERT INTO dws.metric_value (metric_code, date, dept_id, group_id, value, extra)
SELECT 'HAI_RATE', ha.p, 0, 0, round(ha.cases::numeric / NULLIF(dc.disch,0), 4), NULL
FROM ha JOIN dc ON dc.p = ha.p
ON CONFLICT (metric_code, dept_id, group_id, date) DO NOTHING;
-- rows: ≤24

-- (e) ADVERSE_PER_100BED（分母=当月日均 bed_used；L3 缺种子时为空）
WITH ae AS (
  SELECT date_trunc('month', event_date)::date AS p, count(*) AS cnt
  FROM dwd.adverse_event GROUP BY 1),
bd AS (
  -- 先按日Σ病区占用床，再月均——bed_state_day 粒度是 日×病区
  SELECT date_trunc('month', date)::date AS p, avg(day_beds) AS beds
  FROM (SELECT date, sum(bed_used) AS day_beds FROM dwd.bed_state_day GROUP BY date) d
  GROUP BY 1)
INSERT INTO dws.metric_value (metric_code, date, dept_id, group_id, value, extra)
SELECT 'ADVERSE_PER_100BED', ae.p, 0, 0, round(ae.cnt / NULLIF(bd.beds,0) * 100, 4), NULL
FROM ae JOIN bd ON bd.p = ae.p
ON CONFLICT (metric_code, dept_id, group_id, date) DO NOTHING;
-- rows: ≤24

-- (f) INCISION1_INF_RATE（分母=L4 surgery_case I 类切口；L4 缺种子时为空）
WITH si AS (
  SELECT date_trunc('month', confirm_date)::date AS p, count(*) AS num
  FROM dwd.infection_case WHERE ssi_flag AND incision_class='I' GROUP BY 1),
sg AS (
  SELECT date_trunc('month', date)::date AS p, count(*) AS den
  FROM dwd.surgery_case WHERE incision_class='I' GROUP BY 1)
INSERT INTO dws.metric_value (metric_code, date, dept_id, group_id, value, extra)
SELECT 'INCISION1_INF_RATE', si.p, 0, 0, round(si.num::numeric / NULLIF(sg.den,0), 4), NULL
FROM si JOIN sg ON sg.p = si.p
ON CONFLICT (metric_code, dept_id, group_id, date) DO NOTHING;
-- rows: ≤24

-- (g) RULE_PASS_RATE（quality_rule_audit 月聚合）
INSERT INTO dws.metric_value (metric_code, date, dept_id, group_id, value, extra)
SELECT 'RULE_PASS_RATE', period_start, 0, 0,
       round(sum(pass_cnt)::numeric / NULLIF(sum(sample_cnt),0), 4), NULL
FROM dws.quality_rule_audit WHERE period_type='month' GROUP BY period_start
ON CONFLICT (metric_code, dept_id, group_id, date) DO NOTHING;
-- rows: 24

-- (h) 手工锚定·质安：ABX_DDD / ABX_DDD_IP / OP_INFUSION_RATE
INSERT INTO dws.metric_value (metric_code, date, dept_id, group_id, value, extra)
SELECT m, p0::date, 0, 0, v, '{"src":"manual-anchor"}'::jsonb FROM (VALUES
  ('ABX_DDD','2025-01-01',42.6),('ABX_DDD','2025-04-01',41.8),('ABX_DDD','2025-07-01',40.9),
  ('ABX_DDD','2025-10-01',40.1),('ABX_DDD','2026-01-01',39.4),('ABX_DDD','2026-04-01',38.6),
  ('ABX_DDD','2026-07-01',37.5),('ABX_DDD','2026-09-01',36.6),('ABX_DDD','2026-10-01',36.2),
  ('ABX_DDD_IP','2025-01-01',44.8),('ABX_DDD_IP','2025-04-01',43.9),('ABX_DDD_IP','2025-07-01',43.0),
  ('ABX_DDD_IP','2025-10-01',42.2),('ABX_DDD_IP','2026-01-01',41.5),('ABX_DDD_IP','2026-04-01',40.4),
  ('ABX_DDD_IP','2026-07-01',39.3),('ABX_DDD_IP','2026-09-01',38.6),('ABX_DDD_IP','2026-10-01',38.2),
  ('OP_INFUSION_RATE','2025-01-01',0.1180),('OP_INFUSION_RATE','2025-04-01',0.1140),
  ('OP_INFUSION_RATE','2025-07-01',0.1100),('OP_INFUSION_RATE','2025-10-01',0.1060),
  ('OP_INFUSION_RATE','2026-01-01',0.1030),('OP_INFUSION_RATE','2026-04-01',0.1010),
  ('OP_INFUSION_RATE','2026-07-01',0.1000),('OP_INFUSION_RATE','2026-09-01',0.0990),
  ('OP_INFUSION_RATE','2026-10-01',0.0980)
) v(m,p0,v)
ON CONFLICT (metric_code, dept_id, group_id, date) DO NOTHING;
-- rows: 27（季度稀疏点序列：演示期锚点轨迹，月粒度补齐待真实源接入）

-- (i) 资产域派生：EQUIP_RUN_RATE / POSITIVE_RATE / WORK_ORDER_* / LARGE_DEVICE_CNT
INSERT INTO dws.metric_value (metric_code, date, dept_id, group_id, value, extra)
SELECT m, p, 0, 0, round(v,4), NULL FROM (
  SELECT 'EQUIP_RUN_RATE' AS m, date_trunc('month', date)::date AS p,
         sum(run_hours) / NULLIF(sum(plan_hours),0) AS v
  FROM dwd.device_run_day GROUP BY 2
  UNION ALL
  SELECT 'POSITIVE_RATE', date_trunc('month', date)::date,
         sum(positive_cnt)::numeric / NULLIF(sum(exam_cnt),0)
  FROM dwd.device_run_day GROUP BY 2
  UNION ALL
  SELECT 'WORK_ORDER_CNT', date_trunc('month', created_at)::date, count(*)::numeric
  FROM dwd.logistics_order GROUP BY 2
  UNION ALL
  SELECT 'WORK_ORDER_DONE_RATE', date_trunc('month', created_at)::date,
         count(*) FILTER (WHERE wo_status='done')::numeric / NULLIF(count(*),0)
  FROM dwd.logistics_order GROUP BY 2
  UNION ALL
  SELECT 'LARGE_DEVICE_CNT', p0, count(*)::numeric FROM dim.device d
    CROSS JOIN (SELECT (date_trunc('month','2025-01-01'::date)+(g||' month')::interval)::date AS p0
                FROM generate_series(0,23) g) mm WHERE d.active GROUP BY p0
) u WHERE v IS NOT NULL
ON CONFLICT (metric_code, dept_id, group_id, date) DO NOTHING;
-- rows: 120（5 码 × 24 月）

-- (j) STOCK_TURN_DAYS（月末快照；2026-10 取 BASE_DATE 2026-10-28）
WITH mend AS (
  SELECT p0,
         CASE WHEN p0 = '2026-10-01' THEN '2026-10-28'::date     -- 当前月取 BASE_DATE 快照
              ELSE (p0 + interval '1 month - 1 day')::date END AS snap
  FROM (SELECT (date_trunc('month','2025-01-01'::date)+(g||' month')::interval)::date AS p0
        FROM generate_series(0,23) g) mm)
INSERT INTO dws.metric_value (metric_code, date, dept_id, group_id, value, extra)
SELECT 'STOCK_TURN_DAYS', mend.p0, 0, 0,
       round(sum(s.onhand_qty*m.unit_price_amt) / NULLIF(sum(s.avg_daily_use*m.unit_price_amt),0), 2), NULL
FROM mend JOIN dwd.material_stock_day s ON s.date = mend.snap
          JOIN dim.material m ON m.code = s.material_code
GROUP BY mend.p0
ON CONFLICT (metric_code, dept_id, group_id, date) DO NOTHING;
-- rows: 24

-- (k) 能耗系：ENERGY_COST/分项×3/ENERGY_PER_WAN_REV（分母 hospital_oper_day.revenue）
WITH em AS (
  SELECT period_start AS p, energy_type, energy_amt FROM dws.energy_month),
rev AS (
  SELECT date_trunc('month', date)::date AS p, sum(revenue) AS rev_amt
  FROM dws.hospital_oper_day GROUP BY 1)
INSERT INTO dws.metric_value (metric_code, date, dept_id, group_id, value, extra)
SELECT m, p, 0, 0, round(v,4), NULL FROM (
  SELECT 'ENERGY_COST' AS m, p, sum(energy_amt) AS v FROM em GROUP BY p
  UNION ALL SELECT 'ENERGY_ELEC_AMT',  p, sum(energy_amt) FROM em WHERE energy_type='electricity' GROUP BY p
  UNION ALL SELECT 'ENERGY_WATER_AMT', p, sum(energy_amt) FROM em WHERE energy_type='water'       GROUP BY p
  UNION ALL SELECT 'ENERGY_GAS_AMT',   p, sum(energy_amt) FROM em WHERE energy_type='gas'         GROUP BY p
  UNION ALL SELECT 'ENERGY_PER_WAN_REV', em.p, sum(em.energy_amt) / NULLIF(r.rev_amt/10000.0, 0)
             FROM em JOIN rev r ON r.p = em.p GROUP BY em.p, r.rev_amt
) u WHERE v IS NOT NULL
ON CONFLICT (metric_code, dept_id, group_id, date) DO NOTHING;
-- rows: ≤120（ENERGY_PER_WAN_REV 依赖 L5 hospital_oper_day 种子）

-- (l) 手工锚定·资产：FIXED_ASSET_AMT（锚 2026-10=12.6 亿缓升轨迹）
INSERT INTO dws.metric_value (metric_code, date, dept_id, group_id, value, extra)
SELECT 'FIXED_ASSET_AMT', p0::date, 0, 0, v, '{"src":"manual-anchor","unit":"元"}'::jsonb FROM (VALUES
  ('2025-01-01',1158000000.00),('2025-04-01',1172000000.00),('2025-07-01',1190000000.00),
  ('2025-10-01',1206000000.00),('2026-01-01',1221000000.00),('2026-04-01',1238000000.00),
  ('2026-07-01',1247000000.00),('2026-09-01',1254000000.00),('2026-10-01',1260000000.00)
) v(p0,v)
ON CONFLICT (metric_code, dept_id, group_id, date) DO NOTHING;
-- rows: 9

-- (m) 手工锚定·医保域代播（traceability 审计 M2/M3：metric_def 已由 L1 注册、
--     全库无值行 → 契约必需 stats 缺值）。权属属医保域（dwd-flow/L5），本轮
--     由 L8 代播锚定轨迹，合流时归位注记见 README §3。锚点月 2026-10：
--     INS_BALANCE_RATE 基金结余率 6.8% / RX_OUTFLOW_RATE 处方外流率 12.4%。
INSERT INTO dws.metric_value (metric_code, date, dept_id, group_id, value, extra)
SELECT m, p0::date, 0, 0, v,
       '{"src":"manual-anchor","note":"traceability M2/M3 代播；分子为局端外源（version=0 口径）"}'::jsonb
FROM (VALUES
  -- 基金结余率：缓升轨 → 2026-10=0.068
  ('INS_BALANCE_RATE','2025-01-01',0.0600),('INS_BALANCE_RATE','2025-04-01',0.0620),
  ('INS_BALANCE_RATE','2025-07-01',0.0630),('INS_BALANCE_RATE','2025-10-01',0.0640),
  ('INS_BALANCE_RATE','2026-01-01',0.0650),('INS_BALANCE_RATE','2026-04-01',0.0660),
  ('INS_BALANCE_RATE','2026-07-01',0.0670),('INS_BALANCE_RATE','2026-09-01',0.0675),
  ('INS_BALANCE_RATE','2026-10-01',0.0680),
  -- 处方外流率：缓降轨 → 2026-10=0.124
  ('RX_OUTFLOW_RATE','2025-01-01',0.1390),('RX_OUTFLOW_RATE','2025-04-01',0.1370),
  ('RX_OUTFLOW_RATE','2025-07-01',0.1350),('RX_OUTFLOW_RATE','2025-10-01',0.1330),
  ('RX_OUTFLOW_RATE','2026-01-01',0.1310),('RX_OUTFLOW_RATE','2026-04-01',0.1290),
  ('RX_OUTFLOW_RATE','2026-07-01',0.1260),('RX_OUTFLOW_RATE','2026-09-01',0.1250),
  ('RX_OUTFLOW_RATE','2026-10-01',0.1240)
) v(m,p0,v)
-- 定义行属 L1 权属：仅当 1002 合流后（code 存在）才落值行，缺省时静默跳过不中断
WHERE EXISTS (SELECT 1 FROM sys.metric_def md WHERE md.code = v.m)
ON CONFLICT (metric_code, dept_id, group_id, date) DO NOTHING;
-- rows: 18（L1 定义先行合流后；定义缺位时 0）

-- ============================================================================
-- §V-b 自洽校验（相位Ⅲb：dws 表与供稿锚点复核，本地执行期生效）
-- ============================================================================
DO $$
DECLARE n numeric;
BEGIN
  -- 制度抽检 8 行
  ASSERT (SELECT count(*) FROM dws.quality_rule_audit
           WHERE period_start='2026-10-01') = 8, 'rule audit Oct != 8';
  -- O-N7：非锚月抽检通过率带 0.92~1.00（含 round 微差下限 0.915 放行）
  ASSERT NOT EXISTS (SELECT 1 FROM dws.quality_rule_audit
                      WHERE period_start <> '2026-10-01'
                        AND pass_cnt::numeric / sample_cnt NOT BETWEEN 0.915 AND 1.0),
         'rule audit pass rate out of 92-100% band';
  -- 能耗 2026-10 Σ=186 万元
  ASSERT (SELECT sum(energy_amt) FROM dws.energy_month WHERE period_start='2026-10-01')
         = 1860000.00, 'energy Oct != 186万';
  -- 固定资产锚
  ASSERT (SELECT value FROM dws.metric_value
           WHERE metric_code='FIXED_ASSET_AMT' AND date='2026-10-01') = 1260000000.00,
         'fixed asset anchor missing';
  -- HAI 锚月率带（Oct=round(0.0124×出院)，合约锚 ≈1.24%）
  SELECT value INTO n FROM dws.metric_value
   WHERE metric_code='HAI_RATE' AND date='2026-10-01';
  ASSERT n IS NULL OR (n BETWEEN 0.0118 AND 0.0130), 'HAI_RATE anchor out of band';
  -- 医保域代播锚（M2/M3）
  ASSERT (SELECT value FROM dws.metric_value
           WHERE metric_code='INS_BALANCE_RATE' AND date='2026-10-01') = 0.0680,
         'INS_BALANCE_RATE anchor missing';
  ASSERT (SELECT value FROM dws.metric_value
           WHERE metric_code='RX_OUTFLOW_RATE' AND date='2026-10-01') = 0.1240,
         'RX_OUTFLOW_RATE anchor missing';
END $$;
-- @endphase
