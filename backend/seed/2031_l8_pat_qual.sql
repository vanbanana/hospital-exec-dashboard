-- ============================================================================
-- lane L8c/L8d/L8e newdom-pat-qual-asset — 种子·相位Ⅱ：dwd 事实层
--   表：dwd.critical_value(0210) / dwd.infection_case(0211) / dwd.adverse_event(0212) /
--       dwd.feedback_event(0213) / dwd.device_run_day(0216) / dwd.material_stock_day(0217) /
--       dwd.logistics_order(0218)
-- 相位：seed-manifest §1 Ⅱ 事实层，对应汇编 2032_l8c_feedback.sql /
--       2033_l8d_quality.sql / 2034_l8e_assets.sql；依赖 Ⅰa+Ⅰb 就绪。
-- 锚点：api-contract §9.1（投诉24/表扬86/五态流转）、§10.1（危急值及时率99.1/
--       院感1.24·趋势2.2→回控/不良36起/切口0.38）、§11.1（开机率94.2/库存28天·
--       预警梯度46→29/工单156·完结率92%）；BASE_DATE=2026-10-28（scale-decision §0）。
-- 方法：零 random()/零当前时刻函数；伪随机=pg_temp.h01(md5) ∈[0,1)；月度曲线走
--       VALUES；锚点月（2026-10）计数用闭式残差校正；infection_case 率驱动
--       （round(率×L3 当月出院)），随规模裁决分母自校准。
-- 依赖：seed_1_defs（dim.material——stock_day FK）；L2 dim.department/dim.device
--       （fail-fast 断言）；L3 dwd.inpatient_move（感染率分母，缺则当月 0 行不伪锚）、
--       L4 dwd.surgery_case（SSI I 类分母，缺则 i_cnt=0）。
-- 幂等：各事实段先导 DELETE 自有键域再插，可重复执行。
-- 窗口：2025-01-01 ~ 2026-12-31。
-- ============================================================================

\set ON_ERROR_STOP on

-- ---------------------------------------------------------------- §0 工具 --
CREATE OR REPLACE FUNCTION pg_temp.h01(k text) RETURNS numeric
LANGUAGE sql IMMUTABLE AS $f$
  -- 确定性散列 ∈[0,1)：取 md5 前 60bit 为正整数域，规避符号位
  SELECT (('x' || md5(k))::bit(60)::bigint)::numeric / 1152921504606846976.0
$f$;

-- 上游就绪断言（缺维度即 fail-fast，错误信息写缺什么）
DO $$
DECLARE miss text;
BEGIN
  SELECT string_agg(code, ',') INTO miss FROM (
    VALUES ('JZK'),('ZZYXK'),('XNK'),('HXWZK'),('SJNK'),('XHNK'),('ZLK'),('EK'),
           ('KFK'),('GK'),('PWK'),('SJWK'),('MNWK'),('XTXK'),('FCK'),('EBHK'),('YK'),
           ('PFK'),('ZYK'),('NFMK'),('MZB'),('HLB'),('YWB'),('HQBZ'),('ZKB'),
           ('JRZX'),('NJZX'),('FSK'),('FLK'),('HYXK'),('JYK'),('SXK'),('YXB'),('CSK')
  ) req(code)
  WHERE NOT EXISTS (SELECT 1 FROM dim.department d WHERE d.code = req.code);
  IF miss IS NOT NULL THEN RAISE EXCEPTION 'L8 seed 依赖缺失：dim.department 缺 %', miss; END IF;
  IF (SELECT count(*) FROM dim.device) < 68 THEN
    RAISE EXCEPTION 'L8 seed 依赖缺失：dim.device 仅 % 台（锚 68）', (SELECT count(*) FROM dim.device);
  END IF;
END $$;
-- @phase: 2
-- ============================================================================
-- §4 dwd.critical_value —— 危急值事实（2,766 行）
-- 口径：及时=closed 且 close_at−report_at≤30min；每月 (closed,late) 显式配比。
-- 锚：2026-10 closed=110/late=1 → 及时率 109/110=99.09%→99.1；
--     +BASE_DATE(10-28) 晨 2 条 open（07:35 已超 30min→CRIT_UNCLOSED_30M 命中 1 条；
--     08:52 窗口内）。非锚月及时率 96.6%~98.3% 梯度上行（回控剧情）。
-- ============================================================================
DELETE FROM dwd.critical_value
 WHERE report_at >= '2025-01-01'::timestamptz AND report_at < '2027-01-01'::timestamptz;

INSERT INTO dwd.critical_value (patient_masked, item, result_value, dept_id, report_at, notice_at, close_at, cv_status)
WITH mc(y,m,closed_cnt,late_cnt) AS (VALUES
  (2025,1,112,3),(2025,2, 98,3),(2025,3,116,4),(2025,4,108,3),
  (2025,5,118,4),(2025,6,114,3),(2025,7,120,4),(2025,8,124,3),
  (2025,9,116,3),(2025,10,122,4),(2025,11,118,3),(2025,12,121,3),
  (2026,1,110,3),(2026,2,101,2),(2026,3,117,3),(2026,4,112,2),
  (2026,5,118,3),(2026,6,113,2),(2026,7,119,2),(2026,8,121,2),
  (2026,9,118,3),(2026,10,110,1),(2026,11,118,2),(2026,12,120,2)),
mo AS (
  SELECT closed_cnt, late_cnt, make_date(y,m,1) AS p0,
         extract(day from (make_date(y,m,1)+interval '1 month -1 day')::date)::int AS dim
  FROM mc),
sq AS (SELECT mo.*, g.s FROM mo CROSS JOIN LATERAL generate_series(1, closed_cnt) g(s)),
wp AS (  -- 患者所在科室权重池（急诊/ICU 高发）
  SELECT d.id AS dept_id, x.w,
         SUM(x.w) OVER (ORDER BY x.ord) AS cum, SUM(x.w) OVER () AS tot
  FROM (VALUES ('JZK',20,1),('ZZYXK',18,2),('XNK',12,3),('HXWZK',10,4),('SJNK',8,5),
               ('XHNK',7,6),('ZLK',6,7),('PWK',6,8),('GK',5,9),('MNWK',4,10),('FCK',4,11)
       ) x(code,w,ord) JOIN dim.department d ON d.code=x.code),
it AS (  -- 危急值项目+结果文本对（LIS 快照 15 项）
  SELECT row_number() OVER () AS rn, item, result_value FROM (VALUES
    ('血钾','6.8 mmol/L'),('血钾','2.6 mmol/L'),('血红蛋白','46 g/L'),
    ('血小板','18×10⁹/L'),('白细胞','1.2×10⁹/L'),('肌钙蛋白I','3.6 ng/mL'),
    ('血糖','2.2 mmol/L'),('血糖','24.8 mmol/L'),('血钠','118 mmol/L'),
    ('肌酐','856 μmol/L'),('凝血酶原时间','INR 4.8'),('降钙素原','12.5 ng/mL'),
    ('血淀粉酶','1280 U/L'),('总胆红素','342 μmol/L'),('血气分析','pH 7.18')
  ) v(item,result_value)),
ev AS (
  SELECT sq.s, p0, late_cnt,
         p0 + floor((sq.s-1)*dim/closed_cnt)::int AS d0,
         pg_temp.h01('cv.h.'||p0::text||'|'||sq.s) AS hh,
         1 + floor(pg_temp.h01('cv.i.'||p0::text||'|'||sq.s)*15)::int AS ipick,
         (SELECT dept_id FROM wp
           WHERE pg_temp.h01('cv.d.'||p0::text||'|'||sq.s)*tot <= cum ORDER BY cum LIMIT 1) AS dept_id
  FROM sq)
SELECT 'P'||lpad((300000 + row_number() OVER (ORDER BY ev.p0, ev.s))::text, 6, '0'),
       it.item, it.result_value, ev.dept_id,
       (ev.d0 + interval '6 hours' + (ev.hh*57600)::int * interval '1 second') AS report_at,
       (ev.d0 + interval '6 hours' + (ev.hh*57600)::int * interval '1 second'
          + (2 + pg_temp.h01('cv.n.'||ev.p0::text||'|'||ev.s)*8)::int * interval '1 minute') AS notice_at,
       (ev.d0 + interval '6 hours' + (ev.hh*57600)::int * interval '1 second' +
          CASE WHEN ev.s <= ev.late_cnt                        -- 迟闭环 35~95min
               THEN (35 + pg_temp.h01('cv.l.'||ev.p0::text||'|'||ev.s)*60)::int * interval '1 minute'
               ELSE ( 8 + pg_temp.h01('cv.c.'||ev.p0::text||'|'||ev.s)*20)::int * interval '1 minute'
          END) AS close_at,
       'closed'
FROM ev JOIN it ON it.rn = ev.ipick
UNION ALL
-- BASE_DATE 晨间 2 条未闭环（07:35 超 30min 触发 CRIT_UNCLOSED_30M；08:52 窗口内）
SELECT 'P399001','肌钙蛋白I','4.1 ng/mL', (SELECT id FROM dim.department WHERE code='ZZYXK'),
       '2026-10-28 07:35:00+08','2026-10-28 07:41:00+08',NULL,'open'
UNION ALL
SELECT 'P399002','血钾','6.7 mmol/L', (SELECT id FROM dim.department WHERE code='JZK'),
       '2026-10-28 08:52:00+08','2026-10-28 08:57:00+08',NULL,'open';
-- rows: 2,764 closed + 2 open = 2,766

-- ============================================================================
-- §5 dwd.infection_case —— 院感确诊事实（率驱动生成，行数随 L3 分母自校准）
-- 口径：月发生率=count(confirm_date)/当月出院。[规模裁决轮] 出院分母约 ×2
--   （Oct≈8,110，scale-decision §1/§3）后计数改率驱动：total=round(rate_pct×当月
--   出院/100)，L3 分母漂移零失锚；L3 未播种的月自动 0 行→HAI 为空不伪锚。
-- 锚：契约趋势 5~10月=2.2/2.0/2.1/1.9/1.9/1.8% 与 stats 1.24%（锚月=2026-10）
--   互斥 → stats 优先：Oct rate_pct=1.24（open-items #7；基数 ~8,110→约 101 例，
--   MTD≤10-28 均匀分布自然 ≈1.24%，无需残段构造）；趋势前 5 点保留契约字面，
--   越线→回控形态不变；Jan~Apr 过渡 1.95~2.05%，Nov/Dec 续稳 1.15/1.10%。
-- ssi_cnt=round(total×7.2%)；I 类切口 SSI=least(ssi_cnt, round(L4 当月 I 类切口
--   ×irate))——锚月 irate=0.0038 对齐契约 0.38%（其余月 0.40~0.55% 高位过渡；
--   L4 未播种 i_cnt 落 0，联动注记 open-items #12）。
-- ============================================================================
DELETE FROM dwd.infection_case
 WHERE confirm_date >= '2025-01-01' AND confirm_date < '2027-01-01';

INSERT INTO dwd.infection_case (patient_masked, dept_id, confirm_date, inf_site, ssi_flag, incision_class)
WITH mc(y,m,rate_pct,irate) AS (VALUES
  -- 2025：趋势前置段（高出线期 2.4~3.0%；I 类切口感染率同期高位 0.55%）
  (2025,1,2.60,0.0055),(2025,2,2.50,0.0055),(2025,3,2.70,0.0055),(2025,4,2.70,0.0055),
  (2025,5,2.80,0.0055),(2025,6,2.90,0.0055),(2025,7,3.00,0.0055),(2025,8,3.00,0.0055),
  (2025,9,2.80,0.0055),(2025,10,2.80,0.0055),(2025,11,2.60,0.0055),(2025,12,2.40,0.0055),
  -- 2026：契约点位 May~Sep=2.2/2.0/2.1/1.9/1.9%；Oct=锚定 1.24%（stats 优先）；
  -- Q1 过渡；Nov/Dec 锚后低位续稳。irate 逐季收敛至锚 0.0038
  (2026,1,2.00,0.0050),(2026,2,1.95,0.0050),(2026,3,2.00,0.0048),(2026,4,2.05,0.0045),
  (2026,5,2.20,0.0045),(2026,6,2.00,0.0045),(2026,7,2.10,0.0042),(2026,8,1.90,0.0042),
  (2026,9,1.90,0.0040),(2026,10,1.24,0.0038),(2026,11,1.15,0.0040),(2026,12,1.10,0.0040)),
dc AS (  -- 分母=L3 当月出院实数（率驱动源；缺种子→COALESCE 0→当月无行）
  SELECT date_trunc('month', event_time)::date AS p0, count(*) AS disch_cnt
  FROM dwd.inpatient_move WHERE event='discharge' GROUP BY 1),
ic AS (  -- 分母=L4 当月 I 类切口实数（0.38% 锚随分母自校准）
  SELECT date_trunc('month', date)::date AS p0, count(*) AS icl_den
  FROM dwd.surgery_case WHERE incision_class='I' GROUP BY 1),
mo AS (
  SELECT make_date(y,m,1) AS p0,
         extract(day from (make_date(y,m,1)+interval '1 month -1 day')::date)::int AS dim,
         round(rate_pct * COALESCE(dc.disch_cnt,0) / 100.0)::int AS total,
         round(rate_pct * COALESCE(dc.disch_cnt,0) / 100.0 * 0.072)::int AS ssi_cnt,
         least(round(rate_pct * COALESCE(dc.disch_cnt,0) / 100.0 * 0.072)::int,
               round(COALESCE(ic.icl_den,0) * irate))::int AS i_cnt
  FROM mc
  LEFT JOIN dc ON dc.p0 = make_date(y,m,1)
  LEFT JOIN ic ON ic.p0 = make_date(y,m,1)),
sq AS (SELECT mo.*, g.s FROM mo CROSS JOIN LATERAL generate_series(1, total) g(s)),
wp AS (  -- 归属科室权重池（重症/呼吸/神内/肿瘤高发）
  SELECT d.id AS dept_id, x.w,
         SUM(x.w) OVER (ORDER BY x.ord) AS cum, SUM(x.w) OVER () AS tot
  FROM (VALUES ('ZZYXK',15,1),('HXWZK',12,2),('SJNK',10,3),('XNK',10,4),('ZLK',9,5),
               ('XHNK',8,6),('PWK',8,7),('SJWK',7,8),('GK',7,9),('MNWK',5,10),
               ('FCK',4,11),('EK',4,12),('JZK',3,13),('KFK',2,14),('XTXK',3,15)
       ) x(code,w,ord) JOIN dim.department d ON d.code=x.code),
sw AS (  -- SSI 归属手术科室
  SELECT d.id AS dept_id, x.w,
         SUM(x.w) OVER (ORDER BY x.ord) AS cum, SUM(x.w) OVER () AS tot
  FROM (VALUES ('GK',20,1),('PWK',18,2),('SJWK',15,3),('FCK',15,4),('MNWK',12,5),
               ('XTXK',10,6),('EBHK',6,7),('YK',4,8)
       ) x(code,w,ord) JOIN dim.department d ON d.code=x.code),
st AS (  -- 非 SSI 部位权重
  SELECT * FROM (VALUES
    ('resp',42,1),('urinary',28,2),('blood',11,3),('gi',9,4),('skin',6,5),('other',4,6)
  ) v(site,w,ord)),
stc AS (SELECT site, SUM(w) OVER (ORDER BY ord) AS cum, SUM(w) OVER () AS tot FROM st),
ev AS (
  SELECT sq.s, p0, total, ssi_cnt, i_cnt, dim,
         p0 + floor((sq.s-1)*dim/total)::int AS confirm_date,
         sq.s > total - ssi_cnt AS is_ssi,   -- 末段 ssi_cnt 条为 SSI
         pg_temp.h01('ic.h.'||p0::text||'|'||sq.s) AS hh,
         pg_temp.h01('ic.s.'||p0::text||'|'||sq.s) AS hs
  FROM sq)
SELECT 'P'||lpad((400000 + row_number() OVER (ORDER BY p0, s))::text, 6, '0'),
       CASE WHEN is_ssi
            THEN (SELECT dept_id FROM sw WHERE hh*tot <= cum ORDER BY cum LIMIT 1)
            ELSE (SELECT dept_id FROM wp WHERE hh*tot <= cum ORDER BY cum LIMIT 1) END,
       confirm_date,
       CASE WHEN is_ssi THEN 'ssi'
            ELSE (SELECT site FROM stc WHERE hs*tot <= cum ORDER BY cum LIMIT 1) END,
       is_ssi,
       CASE WHEN NOT is_ssi THEN NULL
            WHEN total - s + 1 <= i_cnt THEN 'I'        -- ssi 子序列前 i_cnt 条为 I 类
            WHEN hs < 0.60 THEN 'II' ELSE 'III' END
FROM ev;
-- rows: 随 L3 分母定（新量级口径约 3,3xx：Σ rate_pct×月出院；本行数注释见 README §5 实测）

-- ============================================================================
-- §6 dwd.adverse_event —— 不良事件（835 行）
-- 锚：2026-10=36 起；7 类分布按契约值缩放到 36（契约分布值合计 42≠36→open-items #6）：
--     fall10/med8/tube6/ulcer5/surg3/trans2/other2。百床=36/日均占用床1846≈1.95。
-- ============================================================================
DELETE FROM dwd.adverse_event
 WHERE event_date >= '2025-01-01' AND event_date < '2027-01-01';

INSERT INTO dwd.adverse_event (event_date, dept_id, adverse_cat, event_level, patient_masked, event_desc)
WITH mc(y,m,cnt) AS (VALUES
  (2025,1,30),(2025,2,26),(2025,3,34),(2025,4,32),(2025,5,36),(2025,6,35),
  (2025,7,38),(2025,8,40),(2025,9,36),(2025,10,38),(2025,11,35),(2025,12,39),
  (2026,1,32),(2026,2,28),(2026,3,34),(2026,4,33),(2026,5,36),(2026,6,35),
  (2026,7,38),(2026,8,37),(2026,9,33),(2026,10,36),(2026,11,36),(2026,12,38)),
mo AS (
  SELECT cnt, make_date(y,m,1) AS p0,
         extract(day from (make_date(y,m,1)+interval '1 month -1 day')::date)::int AS dim,
         (y=2026 AND m=10) AS is_anchor
  FROM mc),
-- 锚月：逐类定额；其余月：权重近似分布（fall30/med24/tube17/ulcer14/surg9/trans3/other3）
catw AS (SELECT * FROM (VALUES
  ('fall',30,1),('med_error',24,2),('tube_slip',17,3),('pressure_ulcer',14,4),
  ('surg_related',9,5),('transfusion',3,6),('other',3,7)) v(cat,w,ord)),
catc AS (SELECT cat, SUM(w) OVER (ORDER BY ord) AS cum, SUM(w) OVER () AS tot FROM catw),
anch AS (  -- 锚月逐类定额展开
  SELECT mo.p0, mo.dim, x.cat, g.s AS cseq, x.ccnt
  FROM mo JOIN (VALUES
    ('fall',10),('med_error',8),('tube_slip',6),('pressure_ulcer',5),
    ('surg_related',3),('transfusion',2),('other',2)) x(cat,ccnt) ON mo.is_anchor
  CROSS JOIN LATERAL generate_series(1, x.ccnt) g(s)),
gen AS (   -- 非锚月权重展开
  SELECT mo.p0, mo.dim, mo.cnt, g.s
  FROM mo CROSS JOIN LATERAL generate_series(1, mo.cnt) g(s) WHERE NOT mo.is_anchor),
wp AS (
  SELECT d.id AS dept_id, x.w,
         SUM(x.w) OVER (ORDER BY x.ord) AS cum, SUM(x.w) OVER () AS tot
  FROM (VALUES ('HXWZK',10,1),('SJNK',9,2),('XNK',9,3),('ZLK',8,4),('XHNK',7,5),
               ('NFMK',6,6),('EK',6,7),('KFK',5,8),('GK',7,9),('PWK',7,10),
               ('SJWK',5,11),('FCK',6,12),('MNWK',4,13),('EBHK',3,14),('JZK',8,15),
               ('ZZYXK',6,16),('PFK',3,17),('ZYK',2,18)
       ) x(code,w,ord) JOIN dim.department d ON d.code=x.code),
dp AS (SELECT dept_id, cum, tot FROM wp),
pd AS (SELECT * FROM (VALUES
  ('fall','患者夜间如厕跌倒（无损伤）'),('fall','轮椅转运制动未锁定致跌倒'),
  ('med_error','口服药发放剂量与医嘱不符（及时发现）'),('med_error','输液滴速设定错误'),
  ('tube_slip','留置胃管非计划性拔管'),('tube_slip','导尿管牵拉脱出'),
  ('pressure_ulcer','骶尾部 II 期压力性损伤'),('pressure_ulcer','足跟部 I 期压疮'),
  ('surg_related','术中器械清点不符（复核后齐）'),('surg_related','术后敷料遗留切口边缘'),
  ('transfusion','输血发热反应（自限性）'),('transfusion','血型复核双人签字不全'),
  ('other','病区轮椅缺失延误检查'),('other','患者腕带信息磨损无法扫码')
  ) v(cat,desc0)),
allrows AS (
  SELECT p0 + floor((cseq-1)*dim/ccnt)::int AS event_date, cat,
         'ae.'||p0::text||'|'||cat||'|'||cseq AS k FROM anch
  UNION ALL
  SELECT p0 + floor((s-1)*dim/cnt)::int,
         (SELECT cat FROM catc WHERE pg_temp.h01('ae.c.'||p0::text||'|'||s)*tot <= cum ORDER BY cum LIMIT 1),
         'ae.'||p0::text||'|'||s FROM gen)
SELECT event_date,
       (SELECT dept_id FROM dp WHERE pg_temp.h01('ae.d.'||k)*tot <= cum ORDER BY cum LIMIT 1),
       cat,
       CASE WHEN pg_temp.h01('ae.l.'||k) < 0.04 THEN 1
            WHEN pg_temp.h01('ae.l.'||k) < 0.34 THEN 2
            WHEN pg_temp.h01('ae.l.'||k) < 0.78 THEN 3 ELSE 4 END,
       CASE WHEN cat IN ('other','surg_related') AND pg_temp.h01('ae.p.'||k) < 0.45 THEN NULL
            ELSE 'P'||lpad((500000 + floor(pg_temp.h01('ae.pn.'||k)*9999))::text,6,'0') END,
       (SELECT desc0 FROM pd WHERE pd.cat = allrows.cat
          OFFSET floor(pg_temp.h01('ae.t.'||k)*2) LIMIT 1)
FROM allrows;
-- rows: 835（锚月 36 精确，其余月 26~40）

-- ============================================================================
-- §7 dwd.feedback_event —— 投诉/表扬台账（2,494 行）
-- 锚：2026-10 投诉=24（含契约 4 行原样）/ 表扬=86（含契约 2 行原样），余 generic；
--     五态流转按事件龄期分派（近期 pending/processing，远期 closed/archived）。
-- ============================================================================
DELETE FROM dwd.feedback_event
 WHERE event_date >= '2025-01-01' AND event_date < '2027-01-01';

INSERT INTO dwd.feedback_event (event_date, fb_type, dept_id, fb_channel, content, fb_status, visit_eval)
WITH mc(y,m,complaints,praises) AS (VALUES
  (2025,1,28,58),(2025,2,25,54),(2025,3,30,66),(2025,4,27,64),
  (2025,5,32,72),(2025,6,29,70),(2025,7,34,78),(2025,8,36,80),
  (2025,9,30,74),(2025,10,33,82),(2025,11,31,84),(2025,12,35,88),
  (2026,1,27,64),(2026,2,24,60),(2026,3,29,70),(2026,4,26,68),
  (2026,5,30,74),(2026,6,28,76),(2026,7,32,82),(2026,8,31,84),
  (2026,9,26,80),(2026,10,20,84),(2026,11,27,88),(2026,12,26,92)),  -- 10月 generic=20/84（钉死 6 行契约样例后补足 24/86）
mo AS (
  SELECT complaints, praises, make_date(y,m,1) AS p0,
         extract(day from (make_date(y,m,1)+interval '1 month -1 day')::date)::int AS dim
  FROM mc),
sq AS (  -- 两类统一展开：typ=0 投诉 s∈[1,complaints]；typ=1 表扬 s∈[1,praises]
  SELECT mo.*, t.typ, g.s,
         CASE WHEN t.typ=0 THEN mo.complaints ELSE mo.praises END AS cnt
  FROM mo CROSS JOIN (VALUES (0),(1)) t(typ)
    CROSS JOIN LATERAL generate_series(1, CASE WHEN t.typ=0 THEN complaints ELSE praises END) g(s)),
dpc AS (  -- 投诉涉及科室权重（门诊部/后勤/医技平台类高发）
  SELECT d.id AS dept_id, SUM(x.w) OVER (ORDER BY x.ord) AS cum, SUM(x.w) OVER () AS tot
  FROM (VALUES ('MZB',18,1),('JZK',14,2),('HLB',10,3),('HQBZ',8,4),('FSK',8,5),
               ('GK',7,6),('JYK',6,7),('XNK',6,8),('PWK',6,9),('YXB',5,10),
               ('CSK',5,11),('SJNK',4,12),('ZLK',3,13)
       ) x(code,w,ord) JOIN dim.department d ON d.code=x.code),
dpp AS (  -- 表扬涉及科室权重（临床一线高发）
  SELECT d.id AS dept_id, SUM(x.w) OVER (ORDER BY x.ord) AS cum, SUM(x.w) OVER () AS tot
  FROM (VALUES ('GK',10,1),('XNK',10,2),('HXWZK',8,3),('ZLK',8,4),('EK',8,5),
               ('FCK',8,6),('JZK',8,7),('ZZYXK',7,8),('SJNK',7,9),('PWK',6,10),
               ('XTXK',5,11),('HLB',5,12),('MNWK',4,13),('KFK',4,14),('CSK',3,15)
       ) x(code,w,ord) JOIN dim.department d ON d.code=x.code),
chc AS (  -- 投诉渠道：电话/意见箱/热线为主
  SELECT ch, SUM(w) OVER (ORDER BY ord) AS cum, SUM(w) OVER () AS tot FROM (VALUES
    ('phone',30,1),('suggestion_box',20,2),('hotline_12345',20,3),
    ('onsite',15,4),('miniapp',12,5),('other',3,6)) v(ch,w,ord)),
chp AS (  -- 表扬渠道：小程序/热线为主
  SELECT ch, SUM(w) OVER (ORDER BY ord) AS cum, SUM(w) OVER () AS tot FROM (VALUES
    ('miniapp',35,1),('hotline_12345',25,2),('phone',20,3),
    ('onsite',12,4),('other',8,5)) v(ch,w,ord)),
cpool AS (SELECT * FROM (VALUES
  (1,'门诊缴费窗口排队时间过长'),(2,'候诊区座椅不足'),(3,'取报告自助机故障'),
  (4,'陪护床管理不规范'),(5,'停车场出口排队拥堵'),(6,'食堂菜品单一'),
  (7,'病房卫生间异味'),(8,'叫号声音过小听不清'),(9,'检查预约周期长'),
  (10,'病区夜间噪音影响休息'),(11,'出院结算等待时间长'),(12,'电梯高峰期拥挤')
  ) v(rn,txt)),
ppool AS (SELECT * FROM (VALUES
  (1,'医护人员深夜救治及时，家属致谢'),(2,'术后随访细致'),(3,'护理服务周到'),
  (4,'导医服务耐心'),(5,'住院环境整洁'),(6,'医生解释病情清楚'),
  (7,'急诊分诊快速高效'),(8,'康复治疗指导专业'),(9,'病案复印办理便捷'),
  (10,'志愿者陪同就诊贴心')) v(rn,txt)),
ev AS (
  SELECT s, typ, cnt,
         p0 + floor((s-1)*dim/cnt)::int AS event_date,
         CASE WHEN typ=0 THEN 'complaint' ELSE 'praise' END AS fb_type,
         CASE WHEN typ=0
              THEN (SELECT dept_id FROM dpc WHERE pg_temp.h01('fb.d.'||p0||'|c|'||s)*tot <= cum ORDER BY cum LIMIT 1)
              ELSE (SELECT dept_id FROM dpp WHERE pg_temp.h01('fb.d.'||p0||'|p|'||s)*tot <= cum ORDER BY cum LIMIT 1) END AS dept_id,
         CASE WHEN typ=0
              THEN (SELECT ch FROM chc WHERE pg_temp.h01('fb.c.'||p0||'|c|'||s)*tot <= cum ORDER BY cum LIMIT 1)
              ELSE (SELECT ch FROM chp WHERE pg_temp.h01('fb.c.'||p0||'|p|'||s)*tot <= cum ORDER BY cum LIMIT 1) END AS fb_channel,
         CASE WHEN typ=0
              THEN (SELECT txt FROM cpool WHERE rn = 1 + floor(pg_temp.h01('fb.t.'||p0||'|c|'||s)*12)::int)
              ELSE (SELECT txt FROM ppool WHERE rn = 1 + floor(pg_temp.h01('fb.t.'||p0||'|p|'||s)*10)::int) END AS content,
         -- 五态流转：龄期≤4d 待核实/处理中；≤15d 处理中/已整改；≤60d 已整改/已办结；否则 办结/归档
         CASE WHEN ('2026-10-28'::date - (p0 + floor((s-1)*dim/cnt)::int)) <= 4
              THEN CASE WHEN pg_temp.h01('fb.s.'||p0||'|'||typ||'|'||s) < 0.5 THEN 'pending' ELSE 'processing' END
              WHEN ('2026-10-28'::date - (p0 + floor((s-1)*dim/cnt)::int)) <= 15
              THEN CASE WHEN typ=0 THEN
                     CASE WHEN pg_temp.h01('fb.s.'||p0||'|'||typ||'|'||s) < 0.5 THEN 'processing' ELSE 'rectified' END
                   ELSE CASE WHEN pg_temp.h01('fb.s.'||p0||'|'||typ||'|'||s) < 0.3 THEN 'pending' ELSE 'closed' END END
              WHEN ('2026-10-28'::date - (p0 + floor((s-1)*dim/cnt)::int)) <= 60
              THEN CASE WHEN pg_temp.h01('fb.s.'||p0||'|'||typ||'|'||s) < 0.45 THEN 'rectified' ELSE 'closed' END
              ELSE CASE WHEN pg_temp.h01('fb.s.'||p0||'|'||typ||'|'||s) < 0.55 THEN 'closed' ELSE 'archived' END END AS fb_status,
         pg_temp.h01('fb.v.'||p0::text||'|'||typ||'|'||s) AS hv
  FROM sq)
SELECT event_date, fb_type, dept_id, fb_channel, content, fb_status,
       -- 回访评价：未办结→pending_eval；表扬办结→满意以上为主；投诉办结→满意/基本满意为主
       CASE WHEN fb_status IN ('pending','processing') THEN 'pending_eval'
            WHEN fb_type='praise'
            THEN CASE WHEN hv < 0.62 THEN 'very_satisfied'
                      WHEN hv < 0.92 THEN 'satisfied' ELSE 'fair' END
            ELSE CASE WHEN hv < 0.10 THEN 'pending_eval'
                      WHEN hv < 0.55 THEN 'satisfied'
                      WHEN hv < 0.90 THEN 'fair' ELSE 'very_satisfied' END END AS visit_eval
FROM ev;

-- 契约 §9.1 样例 6 行原样落库（日期重锚 2026-10 尾段，同 L5 满意度移轴约定）
INSERT INTO dwd.feedback_event (event_date, fb_type, dept_id, fb_channel, content, fb_status, visit_eval) VALUES
  ('2026-10-28','praise',   (SELECT id FROM dim.department WHERE code='JZK'), 'hotline_12345','急诊科医护人员深夜救治及时，家属致谢','closed','very_satisfied'),
  ('2026-10-27','complaint',(SELECT id FROM dim.department WHERE code='MZB'), 'suggestion_box','门诊缴费窗口排队时间过长（高峰时段）','processing','pending_eval'),
  ('2026-10-26','complaint',(SELECT id FROM dim.department WHERE code='HLB'), 'phone','住院部陪护床管理不规范','rectified','fair'),
  ('2026-10-25','praise',   (SELECT id FROM dim.department WHERE code='GK'),  'miniapp','骨科王主任术后随访细致','archived','very_satisfied'),
  ('2026-10-24','complaint',(SELECT id FROM dim.department WHERE code='FSK'), 'onsite','放射科取报告自助机故障','closed','satisfied'),
  ('2026-10-22','complaint',(SELECT id FROM dim.department WHERE code='HQBZ'),'phone','停车场出口排队拥堵','pending','pending_eval');
-- rows: generic 2,488（投诉696+表扬1,792）+ 契约样例 6 = 2,494（2026-10 = 24/86 精确）

-- ============================================================================
-- §8 dwd.device_run_day —— 68 台 × 730 天（49,640 行）
-- 锚：2026-10 Σrun/Σplan=0.942（闭式校正：非锚机整体缩放 k，命名机组保契约开机率）；
--     7 组 large_equipments 月均检查/创收（命名组日定额→月合计≈契约值 ±1%）。
-- 画像列：rate=基准开机率、ex=日均检查人次、inc=日均创收元（写入列为运行值）。
-- ============================================================================
DELETE FROM dwd.device_run_day
 WHERE date >= '2025-01-01' AND date < '2027-01-01';

INSERT INTO dwd.device_run_day (date, device_code, plan_hours, run_hours, exam_cnt, positive_cnt, income_amt, opex_amt)
WITH dd AS (SELECT g::date AS dt FROM generate_series('2025-01-01','2026-12-31',interval '1 day') g),
dev AS (
  SELECT d.code, d.value_yuan, p.grp, p.plan_h, p.rate, p.ex, p.inc
  FROM dim.device d JOIN (VALUES
    -- 契约 7 组命名设备（grp 非空=锚定组，开机率按契约钉死）
    ('DEV_MRI_01','MRI3', 12.0,0.968, 47.7, 81000),('DEV_MRI_02','MRI3', 12.0,0.968, 47.7, 81000),
    ('DEV_CT_01','CT256',12.0,0.946, 68.7, 68667),('DEV_CT_02','CT256',12.0,0.946, 68.7, 68667),
    ('DEV_DSA_01','DSA', 12.0,0.884, 12.7, 98667),
    ('DEV_LINAC_01','LINAC',12.0,0.912,14.0, 89333),
    ('DEV_PETCT_01','PETCT',12.0,0.726, 6.2, 52667),
    ('DEV_ENDO_01','ENDO',10.0,0.898, 9.1, 12556),('DEV_ENDO_02','ENDO',10.0,0.898, 9.1, 12556),
    ('DEV_ENDO_03','ENDO',10.0,0.898, 9.1, 12556),('DEV_ENDO_04','ENDO',10.0,0.898, 9.1, 12556),
    ('DEV_ENDO_05','ENDO',10.0,0.898, 9.1, 12556),('DEV_ENDO_06','ENDO',10.0,0.898, 9.1, 12556),
    ('DEV_ESWL_01','ESWL',10.0,0.642, 3.1, 15333),
    -- 其余 53 台（grp=NULL 参与开机率校正池）
    ('DEV_MRI_03',NULL,12.0,0.960, 40.0, 55000),
    ('DEV_CT_03',NULL,12.0,0.958, 85.0, 50000),('DEV_CT_04',NULL,12.0,0.955, 80.0, 46000),
    ('DEV_CT_05',NULL,12.0,0.970,110.0, 62000),('DEV_CT_06',NULL,10.0,0.900, 22.0, 12000),
    ('DEV_DR_01',NULL,10.0,0.940, 62.0,  6500),('DEV_DR_02',NULL,10.0,0.936, 58.0,  5800),
    ('DEV_DR_03',NULL,10.0,0.930, 24.0,  5600),('DEV_DR_04',NULL,10.0,0.950, 66.0,  7200),
    ('DEV_DR_05',NULL, 8.0,0.920, 18.0,  3200),
    ('DEV_DSA_02',NULL,12.0,0.880,  7.0, 65000),('DEV_DSA_03',NULL,12.0,0.850,  4.0, 80000),
    ('DEV_LINAC_02',NULL,12.0,0.905,15.0, 95000),
    ('DEV_OTH_02',NULL, 8.0,0.800,  3.0,  8000),('DEV_OTH_03',NULL,10.0,0.900, 12.0, 18000),
    ('DEV_ENDO_07',NULL,10.0,0.880,  8.0, 18000),('DEV_ENDO_08',NULL, 8.0,0.700,  2.0,  6000),
    ('DEV_ENDO_09',NULL,10.0,0.850,  8.0, 12000),('DEV_ENDO_10',NULL,10.0,0.820,  6.0,  9000),
    ('DEV_ENDO_11',NULL,10.0,0.840,  5.0, 14000),
    ('DEV_OTH_04',NULL, 8.0,0.750,  3.0,  9000),('DEV_ROBOT_01',NULL,12.0,0.880,  2.5, 46000),
    ('DEV_OTH_05',NULL,10.0,0.850,  5.0,  4000),('DEV_OTH_06',NULL,10.0,0.860,  4.0,  6000),
    ('DEV_OTH_07',NULL,10.0,0.780,  3.0,  8000),('DEV_OTH_08',NULL,10.0,0.820,  3.5,  9000),
    ('DEV_OTH_26',NULL,10.0,0.800,  3.0, 12000),
    ('DEV_OTH_09',NULL, 8.0,0.860,  1.5, 15000),('DEV_OTH_10',NULL, 8.0,0.840,  1.5, 14000),
    ('DEV_OTH_11',NULL, 8.0,0.880,  0.8, 12000),('DEV_OTH_12',NULL, 8.0,0.860,  0.8, 12000),
    ('DEV_OTH_13',NULL, 8.0,0.840,  1.0,  6000),('DEV_OTH_16',NULL, 8.0,0.830,  1.0,  6200),
    ('DEV_OTH_14',NULL,10.0,0.800,  2.5, 14000),('DEV_OTH_15',NULL,10.0,0.780,  2.0, 11000),
    ('DEV_US_07',NULL,10.0,0.950, 32.0,  9500),
    ('DEV_US_01',NULL,10.0,0.960, 45.0, 11000),('DEV_US_02',NULL,10.0,0.958, 44.0, 10800),
    ('DEV_US_03',NULL,10.0,0.955, 42.0, 10200),('DEV_US_04',NULL,10.0,0.952, 40.0,  9800),
    ('DEV_US_05',NULL,10.0,0.950, 40.0,  9600),('DEV_US_06',NULL,10.0,0.948, 38.0,  9400),
    ('DEV_US_10',NULL, 8.0,0.940, 22.0,  5600),
    ('DEV_US_08',NULL,10.0,0.940, 30.0,  8500),('DEV_US_09',NULL,10.0,0.938, 29.0,  8400),
    ('DEV_OTH_17',NULL, 8.0,0.720,  1.5,  8000),
    ('DEV_OTH_18',NULL,12.0,0.965,400.0, 45000),('DEV_OTH_19',NULL,12.0,0.960,380.0, 42000),
    ('DEV_OTH_20',NULL,12.0,0.880,120.0, 28000),('DEV_OTH_21',NULL,10.0,0.900, 60.0,  6000),
    ('DEV_OTH_22',NULL,10.0,0.820, 12.0,  7000),('DEV_OTH_23',NULL,10.0,0.780, 10.0,  4500),
    ('DEV_OTH_24',NULL,10.0,0.800,  5.0, 30000),('DEV_OTH_25',NULL,10.0,0.760,  4.0, 22000)
  ) p(code,grp,plan_h,rate,ex,inc) ON p.code = d.code
  WHERE d.active),
raw AS (
  SELECT dt, dev.code, grp, plan_h, rate,
         -- ~1.5% 维保日：plan=0（分母剔除），其余排班 plan_h
         CASE WHEN pg_temp.h01('dr.m.'||dev.code||'|'||dt) < 0.015 THEN 0 ELSE plan_h END AS plan_hours,
         CASE WHEN pg_temp.h01('dr.m.'||dev.code||'|'||dt) < 0.015 THEN 0
              ELSE round(plan_h * rate * (0.97 + 0.05*pg_temp.h01('dr.r.'||dev.code||'|'||dt)), 2) END AS run_raw,
         CASE WHEN pg_temp.h01('dr.m.'||dev.code||'|'||dt) < 0.015 THEN 0
              ELSE greatest(0, round(ex * (0.85 + 0.30*pg_temp.h01('dr.e.'||dev.code||'|'||dt))))::int END AS exam_cnt,
         CASE WHEN pg_temp.h01('dr.m.'||dev.code||'|'||dt) < 0.015 THEN 0
              ELSE round(inc * (0.85 + 0.30*pg_temp.h01('dr.i.'||dev.code||'|'||dt)), 2) END AS income_amt,
         round(value_yuan * 0.00028 + 400 * (0.9 + 0.2*pg_temp.h01('dr.o.'||dev.code||'|'||dt)), 2) AS opex_amt,
         dt BETWEEN '2026-10-01' AND '2026-10-31' AS is_anchor
  FROM dd CROSS JOIN dev),
anchk AS (  -- 闭式校正：非命名组缩放系数使 2026-10 全院 Σrun/Σplan = 0.942 精确
  SELECT (0.942*SUM(plan_hours) - SUM(run_raw) FILTER (WHERE grp IS NOT NULL))
         / NULLIF(SUM(run_raw) FILTER (WHERE grp IS NULL), 0) AS k
  FROM raw WHERE is_anchor)
SELECT dt, code, plan_hours,
       least(24.00, round(run_raw * CASE WHEN is_anchor AND grp IS NULL THEN (SELECT k FROM anchk) ELSE 1 END, 2)),
       exam_cnt,
       least(exam_cnt, round(exam_cnt * (0.10 + 0.30*pg_temp.h01('dr.p.'||code||'|'||dt)))::int),
       income_amt, opex_amt
FROM raw
ON CONFLICT (date, device_code) DO NOTHING;
-- rows: 49,640（68×730，窗口 2025-01-01~2026-12-31 含端点共 730 天；锚月 Σrun/Σplan=0.9420 精确）

-- ============================================================================
-- §9 dwd.material_stock_day —— 24 物资 × 730 天（17,520 行）
-- 锚：2026-10-28 库存可用天数梯度 46/42/36/34/31/29（契约 stock_alerts 6 行，
--     9/24~26 三日平台保持预警稳定）；院级 STOCK_TURN_DAYS 同快照=28.0
--     （残差校正件 MAT_118 吸收 Σ 差额，闭式）。
-- ============================================================================
DELETE FROM dwd.material_stock_day
 WHERE date >= '2025-01-01' AND date < '2027-01-01';

INSERT INTO dwd.material_stock_day (date, material_code, onhand_qty, avg_daily_use)
WITH dd AS (SELECT g::date AS dt FROM generate_series('2025-01-01','2026-12-31',interval '1 day') g),
mp AS (  -- 画像：(code, 日均耗基线, 目标库存天数, 锚定 days[9/24~26])
  SELECT * FROM (VALUES
    ('MAT_001',3000.0, 22.0, 46.0),('MAT_002',   2.0, 18.0, 42.0),
    ('MAT_003',  60.0, 20.0, 36.0),('MAT_004',  80.0, 21.0, 34.0),
    ('MAT_005',  12.0, 19.0, 31.0),('MAT_006', 150.0, 20.0, 29.0),
    ('MAT_101',5000.0, 18.0, NULL),('MAT_102',1200.0, 19.0, NULL),
    ('MAT_103',2600.0, 18.0, NULL),('MAT_104',3000.0, 16.0, NULL),
    ('MAT_105',3500.0, 17.0, NULL),('MAT_106', 400.0, 21.0, NULL),
    ('MAT_107',  90.0, 20.0, NULL),('MAT_108', 300.0, 19.0, NULL),
    ('MAT_109',1600.0, 17.0, NULL),('MAT_110', 500.0, 20.0, NULL),
    ('MAT_111', 700.0, 18.0, NULL),('MAT_112', 150.0, 22.0, NULL),
    ('MAT_113',1800.0, 16.0, NULL),('MAT_114',3500.0, 16.0, NULL),
    ('MAT_115', 220.0, 19.0, NULL),('MAT_116',  25.0, 22.0, NULL),
    ('MAT_117',  60.0, 21.0, NULL),('MAT_118', 160.0, 20.0, NULL)
  ) v(code,use0,days0,anchor_days)),
raw AS (
  SELECT dt, m.code, m.unit_price_amt AS price, mp.use0, mp.days0, mp.anchor_days,
         round(mp.use0 * (0.97 + 0.06*pg_temp.h01('ms.u.'||mp.code||'|'||date_trunc('week',dt)::date)))::numeric AS use_d,
         round(mp.use0 * (mp.days0 + 4.0*(pg_temp.h01('ms.o.'||mp.code||'|'||dt) - 0.5)))::int AS oh_raw
  FROM dd CROSS JOIN mp JOIN dim.material m ON m.code = mp.code),
fix AS (  -- 2026-10-28 残差：令 Σonhand_amt = 28.0 × Σuse_amt，差额落到 MAT_118
  SELECT 28.0 * SUM(use_d * price)
         - SUM((CASE WHEN anchor_days IS NOT NULL THEN anchor_days
                     ELSE oh_raw / NULLIF(use_d,0) END) * use_d * price)
             FILTER (WHERE code <> 'MAT_118') AS resid_amt
  FROM raw WHERE dt = '2026-10-28')
SELECT dt, code,
       CASE WHEN dt BETWEEN '2026-10-26' AND '2026-10-28' AND anchor_days IS NOT NULL
            THEN round(anchor_days * use_d)::int                                  -- 预警梯度钉死
            WHEN dt = '2026-10-28' AND code = 'MAT_118'
            THEN greatest(0, round((SELECT resid_amt FROM fix)
                     / NULLIF((SELECT unit_price_amt FROM dim.material WHERE code='MAT_118'),0)))::int
            ELSE oh_raw END AS onhand_qty,
       round(use_d, 2) AS avg_daily_use
FROM raw
ON CONFLICT (date, material_code) DO NOTHING;
-- rows: 17,520

-- ============================================================================
-- §10 dwd.logistics_order —— 后勤工单（3,757 行）
-- 锚：2026-10=156 单，done=144 → 完结率 144/156=92.31%→92%；其余月 130~172，
--     完结率 ~93%±；类型 repair45/maintain20/clean15/transport15/other5。
-- ============================================================================
DELETE FROM dwd.logistics_order
 WHERE created_at >= '2025-01-01'::timestamptz AND created_at < '2027-01-01'::timestamptz;

INSERT INTO dwd.logistics_order (wo_type, wo_status, dept_id, created_at, finished_at)
WITH mc(y,m,cnt) AS (VALUES
  (2025,1,148),(2025,2,132),(2025,3,155),(2025,4,150),(2025,5,162),(2025,6,158),
  (2025,7,166),(2025,8,170),(2025,9,159),(2025,10,168),(2025,11,163),(2025,12,172),
  (2026,1,150),(2026,2,138),(2026,3,152),(2026,4,148),(2026,5,158),(2026,6,155),
  (2026,7,162),(2026,8,160),(2026,9,152),(2026,10,156),(2026,11,159),(2026,12,164)),
mo AS (
  SELECT cnt, make_date(y,m,1) AS p0,
         extract(day from (make_date(y,m,1)+interval '1 month -1 day')::date)::int AS dim,
         (y=2026 AND m=10) AS is_anchor
  FROM mc),
sq AS (SELECT mo.*, g.s FROM mo CROSS JOIN LATERAL generate_series(1, cnt) g(s)),
wp AS (  -- 报修科室权重（住院病区/平台科室为主）
  SELECT d.id AS dept_id, SUM(x.w) OVER (ORDER BY x.ord) AS cum, SUM(x.w) OVER () AS tot
  FROM (VALUES ('HXWZK',9,1),('SJNK',8,2),('XNK',8,3),('XHNK',6,4),('ZLK',6,5),
               ('NFMK',4,6),('EK',5,7),('KFK',4,8),('GK',7,9),('PWK',7,10),
               ('SJWK',5,11),('FCK',6,12),('MNWK',4,13),('XTXK',4,14),('JZK',7,15),
               ('ZZYXK',4,16),('CSK',3,17),('YXB',2,18),('CSSD',2,19),('NJZX',2,20)
       ) x(code,w,ord) JOIN dim.department d ON d.code=x.code),
tw AS (SELECT * FROM (VALUES
  ('repair',45,1),('maintain',20,2),('clean',15,3),('transport',15,4),('other',5,5)
  ) v(tp,w,ord)),
tc AS (SELECT tp, SUM(w) OVER (ORDER BY ord) AS cum, SUM(w) OVER () AS tot FROM tw),
ev AS (
  SELECT s, p0, cnt, is_anchor,
         p0 + floor((s-1)*dim/cnt)::int AS d0,
         p0 + floor((s-1)*dim/cnt)::int + interval '7 hours'
           + (pg_temp.h01('lo.h.'||p0::text||'|'||s)*43200)::int * interval '1 second' AS created_at,
         pg_temp.h01('lo.s.'||p0::text||'|'||s) AS hs,
         pg_temp.h01('lo.f.'||p0::text||'|'||s) AS hf,
         (SELECT dept_id FROM wp WHERE pg_temp.h01('lo.d.'||p0::text||'|'||s)*tot <= cum ORDER BY cum LIMIT 1) AS dept_id,
         (SELECT tp FROM tc WHERE pg_temp.h01('lo.t.'||p0::text||'|'||s)*tot <= cum ORDER BY cum LIMIT 1) AS wo_type
  FROM sq)
SELECT wo_type,
       -- 锚月定额 144/8/4；距今>20 天的旧单全闭环或取消；近单按完结梯度
       CASE WHEN is_anchor
            THEN CASE WHEN s <= 144 THEN 'done' WHEN s <= 152 THEN 'doing' ELSE 'open' END
            WHEN ('2026-10-28'::date - d0) > 20
            THEN CASE WHEN hs < 0.955 THEN 'done' ELSE 'cancelled' END
            ELSE CASE WHEN hf < 0.86 THEN 'done' WHEN hf < 0.94 THEN 'doing'
                      WHEN hf < 0.98 THEN 'open' ELSE 'cancelled' END END AS wo_status,
       dept_id, created_at,
       CASE WHEN (is_anchor AND s <= 144)
              OR (NOT is_anchor AND (('2026-10-28'::date - d0) > 20 AND hs < 0.955)
                  OR (NOT is_anchor AND ('2026-10-28'::date - d0) <= 20 AND hf < 0.86))
            THEN created_at + (4 + hf*68) * interval '1 hour' END AS finished_at
FROM ev;
-- rows: 3,757（锚月 156：done144/doing8/open4 → 完结率 0.9231≈0.92）

-- ============================================================================
-- §V-a 自洽校验（相位Ⅱ：事实锚点复核，本地执行期生效）
-- ============================================================================
DO $$
DECLARE n numeric; m2 numeric;
BEGIN
  -- 患者域
  ASSERT (SELECT count(*) FROM dwd.feedback_event
           WHERE fb_type='complaint' AND event_date BETWEEN '2026-10-01' AND '2026-10-31') = 24,
         'feedback complaint Oct != 24';
  ASSERT (SELECT count(*) FROM dwd.feedback_event
           WHERE fb_type='praise' AND event_date BETWEEN '2026-10-01' AND '2026-10-31') = 86,
         'feedback praise Oct != 86';
  -- 危急值及时率 99.1（闭环保底 110/及时 109）
  SELECT count(*) FILTER (WHERE close_at - report_at <= interval '30 minutes')::numeric
           / count(*) INTO n
    FROM dwd.critical_value
   WHERE cv_status='closed' AND report_at >= '2026-10-01' AND report_at < '2026-11-01';
  ASSERT n BETWEEN 0.985 AND 0.995, 'critical timely rate out of band';
  ASSERT (SELECT count(*) FROM dwd.critical_value WHERE cv_status='open') = 2,
         'open critical values != 2';
  -- 院感率驱动复核：Oct 例数=round(0.0124×当月出院) 且月率/MTD 率均落 1.24%±0.06pt
  -- （L3 未播种时当月 0 行→两带按 NULL 放行，不伪锚）
  SELECT CASE WHEN d.cnt = 0 THEN NULL ELSE c.cnt::numeric / d.cnt END INTO n
    FROM (SELECT count(*) cnt FROM dwd.inpatient_move
           WHERE event='discharge' AND event_time >= '2026-10-01' AND event_time < '2026-11-01') d,
         (SELECT count(*) cnt FROM dwd.infection_case
           WHERE confirm_date BETWEEN '2026-10-01' AND '2026-10-31') c;
  ASSERT n IS NULL OR (n BETWEEN 0.0118 AND 0.0130), 'infection Oct rate out of band';
  SELECT CASE WHEN d.cnt = 0 THEN NULL ELSE c.cnt::numeric / d.cnt END INTO m2
    FROM (SELECT count(*) cnt FROM dwd.inpatient_move
           WHERE event='discharge' AND event_time >= '2026-10-01' AND event_time < '2026-10-29') d,
         (SELECT count(*) cnt FROM dwd.infection_case
           WHERE confirm_date BETWEEN '2026-10-01' AND '2026-10-28') c;
  ASSERT m2 IS NULL OR (m2 BETWEEN 0.0105 AND 0.0140), 'infection MTD rate out of band';
  -- SSI I 类率：分子=SSI∧I 类例数 / 分母=L4 当月 I 类切口例数；缺 L4 种子时跳过（n 置 NULL 放行）
  SELECT CASE WHEN d.cnt = 0 THEN NULL ELSE n2.cnt::numeric / d.cnt END INTO n
    FROM (SELECT count(*) cnt FROM dwd.surgery_case
           WHERE date >= '2026-10-01' AND date < '2026-11-01' AND incision_class='I') d,
         (SELECT count(*) cnt FROM dwd.infection_case
           WHERE ssi_flag AND incision_class='I'
             AND confirm_date BETWEEN '2026-10-01' AND '2026-10-31') n2;
  ASSERT n IS NULL OR (n BETWEEN 0.0034 AND 0.0042), 'incision-I infection rate out of band';
  -- 不良事件 36 起
  ASSERT (SELECT count(*) FROM dwd.adverse_event
           WHERE event_date BETWEEN '2026-10-01' AND '2026-10-31') = 36, 'adverse Oct != 36';
  -- 开机率 0.942 ±0.002
  SELECT sum(run_hours)/sum(plan_hours) INTO n FROM dwd.device_run_day
   WHERE date BETWEEN '2026-10-01' AND '2026-10-31';
  ASSERT n BETWEEN 0.940 AND 0.944, 'equip run rate out of band';
  -- 库存预警梯度 46/42/36/34/31/29 @2026-10-28
  ASSERT (SELECT count(*) FROM dwd.material_stock_day s JOIN dim.material m ON m.code=s.material_code
           WHERE s.date='2026-10-28' AND s.material_code IN
             ('MAT_001','MAT_002','MAT_003','MAT_004','MAT_005','MAT_006')
             AND round(s.onhand_qty::numeric / NULLIF(s.avg_daily_use,0))
                 = CASE s.material_code WHEN 'MAT_001' THEN 46 WHEN 'MAT_002' THEN 42
                                        WHEN 'MAT_003' THEN 36 WHEN 'MAT_004' THEN 34
                                        WHEN 'MAT_005' THEN 31 WHEN 'MAT_006' THEN 29 END) = 6,
         'stock alert gradient mismatch';
  -- 工单 156 / 完结率 ~0.923
  ASSERT (SELECT count(*) FROM dwd.logistics_order
           WHERE created_at >= '2026-10-01' AND created_at < '2026-11-01') = 156, 'wo Oct != 156';
  SELECT count(*) FILTER (WHERE wo_status='done')::numeric / count(*) INTO n
    FROM dwd.logistics_order WHERE created_at >= '2026-10-01' AND created_at < '2026-11-01';
  ASSERT n BETWEEN 0.915 AND 0.930, 'wo done rate out of band';
END $$;
-- @endphase
