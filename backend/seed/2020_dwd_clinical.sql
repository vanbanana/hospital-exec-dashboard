-- ============================================================================
-- lane: L4 dwd-clinical  /  seed.sql（0208 dwd.surgery_case + 0209 dwd.drg_case）
--
-- scale v2（2026-10-28 裁决）：BASE_DATE=2026-10-28；锚点月=2026-10。
--   手术窗口 2025-01~2026-12（台次曲线不变：10月=1286）；DRG 窗口
--   2025-11~2026-12（14 月 ≈10.4 万例，贴合"全窗 ~9.5~9.7万"带上界内；出院
--   曲线随 L3 inpatient_move 形态 ×1.0441——系数吸收两院表互斥，open-items #1）。
--   费用真源=dwd.charge_day.in_fee（G18/G2）：次均住院费≈12,000~13,000 元、
--   Σtotal_fee(Oct)≈Σin_fee(Oct)×~0.97；drg_case.rw=所入病组权重快照。
-- 确定性：全部 generate_series + md5(<key>)::bit(60) 取模，无 random()/now()；
--         幂等：事实表按窗口先 DELETE 再 INSERT；字典 ON CONFLICT 供行。
--
-- 锚点校验（种子执行后可查）：
--   手术 Oct-2026: 台次 1286 / 择期≈1048 急诊≈238 / 三四级≈58.6% / 微创≈42.3%
--     手术间利用率≈86.4%（占用=手术时长+接台间隔均12min, 6间×570min×31d）
--   DRG  Oct-2026: 出院 8,200（vs L3 Oct 8,120 +1.0%，F-N4 收敛）/ 入组率≈98.5%
--     RW六段盒内≈911/3533/2820/659/124/36（契约 870/3350/3060/662/128/37 ±10%）
--     CMI≈1.087 / RW≥2≈10% / 甲级病案≈98.6% / 低风险死亡 锚点月 2 例（配额）
--     科室月结余(元)：骨科+1,246,000 神外−128,000 心内+864,000 …(§13.1)
--   全窗：手术 24,266 台；DRG ~10.4 万例
-- ============================================================================

-- ─────────────────────────── §A sys.dict 供行 ────────────────────────────
-- L1 merge 到 1001；本 lane 新增枚举类型（CHECK 同域冗余见 ddl.sql）
INSERT INTO sys.dict (dict_type, dict_key, dict_label, sort) VALUES
  ('surg_status','sched','排程未开台',1),
  ('surg_status','doing','术中',2),
  ('surg_status','done','已完成',3),
  ('surg_status','pacu','复苏中',4),
  ('incision_class','I','I类切口(清洁)',1),
  ('incision_class','II','II类切口(清洁-污染)',2),
  ('incision_class','III','III类切口(污染)',3),
  ('mr_grade','A','甲级病案',1),
  ('mr_grade','B','乙级病案',2),
  ('mr_grade','C','丙级病案',3),
  ('admit_path','1','门诊入院',1),
  ('admit_path','2','急诊入院',2),
  ('admit_path','3','其他机构转入',3),
  ('admit_path','9','其他',9),
  ('discharge_type','1','医嘱离院',1),
  ('discharge_type','2','医嘱转院',2),
  ('discharge_type','3','医嘱转社区/乡镇',3),
  ('discharge_type','4','非医嘱离院',4),
  ('discharge_type','5','死亡',5),
  ('discharge_type','9','其他',9),
  ('rate_type','normal','正常倍率',1),
  ('rate_type','high','高倍率(费用>2.0×支付标准,经办细则口径)',2),
  ('rate_type','low','低倍率(费用<0.5×支付标准)',3)
ON CONFLICT (dict_type, dict_key) DO NOTHING;

-- ─────────── §B sys.metric_def 供行 —— 阶段3 收敛移除（audit M3）─────────────
-- 本 lane 原 25 行供稿整段移除：24 码与 L1 1002 正本重码且多处属性发散
-- （value_kind 用 avg/ratio/sum/enum 出 CHECK 域 7 行、period/day vs realtime、
-- DRG_PROFIT 公式内嵌 ÷1e4 万元换算违反 §1.1 元存储；EMR_GRADE_A_RATE 与
-- newdom-pat-qual-asset 供稿重码，质安域正本归后者）。L1/L8pat 定义为正本，
-- 发散裁决明细见 sys-org/open-items.md O10；本 lane 不再向 metric_def 供行。

-- ─────────────────────────── §C 维度形态守护（fail-fast + 降级告警）──────────────
DO $$
DECLARE miss text;
BEGIN
  -- 本 lane 种子依赖的 20 个临床/平台科室必须存在（按契约清单名 JOIN）
  SELECT string_agg(v.name, '、' ORDER BY v.name) INTO miss
  FROM (VALUES ('心血管内科'),('呼吸与危重症医学科'),('消化内科'),('神经内科'),('内分泌科'),
               ('肿瘤科'),('皮肤科'),('中医科'),('儿科'),('康复医学科'),('骨科'),('普通外科'),
               ('神经外科'),('泌尿外科'),('心胸外科'),('妇产科'),('耳鼻喉科'),('眼科'),
               ('急诊科'),('重症医学科'),('介入中心'),('内镜中心')) AS v(name)
  LEFT JOIN dim.department d ON d.name = v.name AND d.level = 2 AND d.active
  WHERE d.id IS NULL;
  IF miss IS NOT NULL THEN
    RAISE EXCEPTION 'L2 dim.department 缺科室（level=2 且 active）：% —— 请先完成 L2 种子', miss;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM dim.ward WHERE ward_type = 'or') THEN
    RAISE EXCEPTION 'dim.ward 缺 ward_type=''or'' 手术室虚拟病区';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM dim.staff WHERE staff_type = 'doc' AND active) THEN
    RAISE EXCEPTION 'dim.staff 无 active 医师';
  END IF;
  -- RW 六段每段至少一个病组（缺段仅告警：种子退化用最近邻病组，分段计数仍成立）
  PERFORM 1
  FROM (VALUES (0.00,0.5),(0.5,1.0),(1.0,2.0),(2.0,5.0),(5.0,10.0),(10.0,999.0)) AS b(lo,hi)
  WHERE NOT EXISTS (SELECT 1 FROM dim.drg_group g WHERE g.rw >= b.lo AND g.rw < b.hi);
  IF FOUND THEN
    RAISE WARNING 'dim.drg_group 存在空 RW 分段（期望 ≥10 段也有组，如 MDCA/心胸大血管组）；种子将退化取最近病组';
  END IF;
END $$;

-- ─────────────────────────── §D dwd.surgery_case ──────────────────────────────
-- 幂等：清窗口后重灌
DELETE FROM dwd.surgery_case WHERE date BETWEEN '2025-01-01' AND '2026-12-31';

INSERT INTO dwd.surgery_case
  (case_no, patient_masked, dept_id, ward_code, surg_level, surg_status,
   elective_flag, min_invasive, incision_class, plan_start, actual_start, actual_end,
   room_no, date)
WITH P AS (
  SELECT date '2026-10-28' AS base_date
),
spar AS (  -- 手术科室向量：契约 §5.1 台次(10月)/科室均时(分钟)；级别/微创/择期/切口标定值
  SELECT v.*, (sum(cnt) OVER (ORDER BY ord) - cnt)::numeric / sum(cnt) OVER () AS lo_share,
              sum(cnt) OVER (ORDER BY ord)::numeric / sum(cnt) OVER () AS hi_share
  FROM (VALUES
    -- ord 名称  月台次 均时(折算后)  L1 L2 L3 L4   微创  择期   切口 I II III(余=NULL)
    ( 1,'骨科',            286, 40.9, 0.07,0.36,0.42,0.15, 0.40,0.86, 0.78,0.07,0.02),
    ( 2,'普通外科',        242, 55.6, 0.10,0.31,0.46,0.13, 0.45,0.82, 0.30,0.55,0.10),
    ( 3,'妇产科',          186, 37.4, 0.14,0.33,0.35,0.18, 0.57,0.76, 0.55,0.35,0.05),
    ( 4,'神经外科',        128,125.9, 0.05,0.17,0.49,0.29, 0.17,0.70, 0.88,0.08,0.01),
    ( 5,'泌尿外科',        116, 52.2, 0.12,0.29,0.41,0.18, 0.63,0.92, 0.80,0.12,0.02),
    ( 6,'心胸外科',         98,141.3, 0.03,0.15,0.45,0.37, 0.25,0.87, 0.85,0.12,0.01),
    ( 7,'耳鼻喉科',         86, 34.8, 0.22,0.43,0.28,0.07, 0.42,0.90, 0.75,0.20,0.01),
    ( 8,'眼科',             74, 22.7, 0.36,0.48,0.14,0.02, 0.47,0.92, 0.94,0.02,0.00),
    ( 9,'内镜中心',         18, 43.3, 0.10,0.32,0.45,0.13, 0.85,0.60, 0.10,0.10,0.05),
    (10,'介入中心',         14, 72.7, 0.03,0.27,0.48,0.22, 0.88,0.70, 0.05,0.20,0.05),
    (11,'肿瘤科',            8, 77.5, 0.05,0.30,0.40,0.25, 0.40,0.70, 0.60,0.30,0.05),
    (12,'儿科',              6, 35.6, 0.20,0.45,0.28,0.07, 0.50,0.85, 0.60,0.30,0.05),
    (13,'皮肤科',            6, 18.6, 0.40,0.40,0.18,0.02, 0.30,0.90, 0.50,0.40,0.05),
    (14,'急诊科',           10, 23.1, 0.25,0.40,0.28,0.07, 0.20,0.20, 0.30,0.50,0.15),
    (15,'重症医学科',        5, 85.9, 0.00,0.30,0.45,0.25, 0.30,0.60, 0.60,0.30,0.10),
    (16,'神经内科',          3, 40.0, 0.10,0.40,0.38,0.12, 0.25,0.80, 0.70,0.20,0.05)
  ) v(ord,name,cnt,dur,l1,l2,l3,l4,mis,elec,ici,icii,iciii)
),
mon AS (
  SELECT * FROM (VALUES
    -- 2025 = 契约 §5.1 trend "last" 全年基线；2026 = "current"（10月=1286 锚点月）
    ('2025-01-01', 750),('2025-02-01', 650),('2025-03-01', 850),('2025-04-01', 900),
    ('2025-05-01', 950),('2025-06-01', 980),('2025-07-01',1020),('2025-08-01',1050),
    ('2025-09-01',1000),('2025-10-01',1100),('2025-11-01',1050),('2025-12-01',1000),
    ('2026-01-01', 860),('2026-02-01', 720),('2026-03-01', 980),('2026-04-01',1020),
    ('2026-05-01',1080),('2026-06-01',1120),('2026-07-01',1180),('2026-08-01',1210),
    ('2026-09-01',1150),('2026-10-01',1286),('2026-11-01',1200),('2026-12-01',1160)
  ) v(m,cnt)
),
daycdf AS (  -- 逐日台次权重：周日低台（0.45），周六同平日（三级医院周六择期照常）
  SELECT m.m::date AS month_start, dy::date AS day,
         (sum(w) OVER (PARTITION BY m.m ORDER BY dy) - w)
           / sum(w) OVER (PARTITION BY m.m) AS lo,
         sum(w) OVER (PARTITION BY m.m ORDER BY dy)
           / sum(w) OVER (PARTITION BY m.m) AS hi
  FROM mon m
  JOIN LATERAL (
    SELECT d::date AS dy,
           CASE extract(dow FROM d)::int WHEN 0 THEN 0.45 ELSE 1.0 END AS w
    FROM generate_series(m.m::date, (m.m::date + interval '1 month - 1 day')::date,
                         interval '1 day') d
  ) x ON true
),
seq AS (
  SELECT m.m::date AS month_start, s AS seq, m.cnt AS mcnt
  FROM mon m CROSS JOIN LATERAL generate_series(1, m.cnt) AS s
),
u AS (  -- 每例确定性抽签向量 u01..u10 ∈ [0,1)
  SELECT month_start, seq, mcnt,
    ('x'||substr(md5('surg:'||month_start||':'||seq||':01'),1,15))::bit(60)::bigint / 1152921504606846976.0 AS u01,
    ('x'||substr(md5('surg:'||month_start||':'||seq||':02'),1,15))::bit(60)::bigint / 1152921504606846976.0 AS u02,
    ('x'||substr(md5('surg:'||month_start||':'||seq||':03'),1,15))::bit(60)::bigint / 1152921504606846976.0 AS u03,
    ('x'||substr(md5('surg:'||month_start||':'||seq||':04'),1,15))::bit(60)::bigint / 1152921504606846976.0 AS u04,
    ('x'||substr(md5('surg:'||month_start||':'||seq||':05'),1,15))::bit(60)::bigint / 1152921504606846976.0 AS u05,
    ('x'||substr(md5('surg:'||month_start||':'||seq||':06'),1,15))::bit(60)::bigint / 1152921504606846976.0 AS u06,
    ('x'||substr(md5('surg:'||month_start||':'||seq||':07'),1,15))::bit(60)::bigint / 1152921504606846976.0 AS u07,
    ('x'||substr(md5('surg:'||month_start||':'||seq||':08'),1,15))::bit(60)::bigint / 1152921504606846976.0 AS u08,
    ('x'||substr(md5('surg:'||month_start||':'||seq||':09'),1,15))::bit(60)::bigint / 1152921504606846976.0 AS u09,
    ('x'||substr(md5('surg:'||month_start||':'||seq||':10'),1,15))::bit(60)::bigint / 1152921504606846976.0 AS u10
  FROM seq
),
alloc AS (  -- 科室 + 手术日（按份额CDF+逐日权重CDF确定性落格）
  SELECT u.*, sp.name AS dept_name, dr.id AS dept_id, sp.dur AS dur_mean,
         sp.l1,sp.l2,sp.l3,sp.l4, sp.mis,sp.elec, sp.ici,sp.icii,sp.iciii,
         dy.day AS date
  FROM u
  JOIN spar sp ON u.seq::numeric / u.mcnt > sp.lo_share
              AND u.seq::numeric / u.mcnt <= sp.hi_share   -- 位置分配：锚点月科室台次=参数精确值
  JOIN dim.department dr ON dr.name = sp.name AND dr.level = 2 AND dr.active
  JOIN daycdf dy ON dy.month_start = u.month_start AND u.u02 >= dy.lo AND u.u02 < dy.hi
),
attr AS (
  SELECT a.*,
    CASE WHEN u04 < l1 THEN 1 WHEN u04 < l1+l2 THEN 2
         WHEN u04 < l1+l2+l3 THEN 3 ELSE 4 END AS surg_level,
    (u05 < elec) AS elective_flag,
    (u09 < mis)  AS min_invasive,
    CASE WHEN u08 < ici THEN 'I' WHEN u08 < ici+icii THEN 'II'
         WHEN u08 < ici+icii+iciii THEN 'III' ELSE NULL END AS incision_class,
    -- 时长 = 科室均时 × [0.55,1.45] 均匀抖动 × (四级+急诊修正) ÷ 1.05 修正因子
    greatest(10, least(480,
      round(dur_mean * (0.55 + 0.90*u03)
            * (1 + 0.15 * (u04 >= l1+l2+l3)::int)          -- 四级手术偏长
            * (1 + 0.15 * (u05 >= elec)::int)              -- 急诊手术偏长
            / 1.05)
    ))::int AS dur_min,
    'OR-0' || (1 + floor(u06 * 6)::int) AS room_no,
    'P' || lpad((100000 + floor(u10 * 900000))::int::text, 6, '0') AS patient_masked
  FROM alloc a
),
sched AS (  -- 房间排程：同 (date, room) 内按 seq 顺序累加 (时长+接台12min)，无重叠
  SELECT t.*,
    date + interval '8 hours'
      + (coalesce(sum(dur_min + 11 + (u09 < 0.5)::int) OVER (PARTITION BY date, room_no
                ORDER BY seq ROWS UNBOUNDED PRECEDING), 0) - dur_min - 11 - (u09 < 0.5)::int)
        * interval '1 minute' AS slot_start
  FROM attr t
),
ord AS (  -- 当日台次按开台时刻排序 → BASE_DATE 状态分位
  SELECT s.*,
    row_number() OVER (PARTITION BY date ORDER BY slot_start, room_no, seq) AS rn_day,
    count(*)     OVER (PARTITION BY date) AS n_day
  FROM sched s
),
final AS (
  SELECT s.*,
    CASE  -- 状态：BASE_DATE 前=done(基线)；BASE+1..+2=sched(已排程)；
          -- 更早未来月=done(全年基线曲线)；BASE_DATE 当天按序已开台→进行中→待开台
      WHEN s.date >  P.base_date + 2 THEN 'done'
      WHEN s.date >  P.base_date     THEN 'sched'
      WHEN s.date <  P.base_date     THEN 'done'
      ELSE CASE WHEN s.rn_day <= 0.70 * s.n_day THEN 'done'
                WHEN s.rn_day <= 0.82 * s.n_day THEN 'doing'
                WHEN s.rn_day <= 0.90 * s.n_day THEN 'pacu'
                ELSE 'sched' END
    END AS surg_status,
    s.slot_start - ((4 + floor(u07 * 15)::int) * interval '1 minute') AS plan_start
  FROM ord s, P
)
SELECT 'S' || to_char(f.date, 'YYYYMMDD') || '-' || lpad(f.seq::text, 6, '0'),
       f.patient_masked, f.dept_id,
       (SELECT w.code FROM dim.ward w WHERE w.ward_type = 'or' ORDER BY w.code LIMIT 1),
       f.surg_level, f.surg_status, f.elective_flag, f.min_invasive, f.incision_class,
       f.plan_start,
       CASE WHEN f.surg_status IN ('done','doing','pacu') THEN f.slot_start END,
       CASE WHEN f.surg_status IN ('done','pacu') THEN f.slot_start + f.dur_min * interval '1 minute' END,
       f.room_no, f.date
FROM final f;

-- ─────────────────────────── §E dwd.drg_case ──────────────────────────────────
DELETE FROM dwd.drg_case WHERE discharge_date BETWEEN '2025-01-01' AND '2026-12-31';

INSERT INTO dwd.drg_case
  (case_no, patient_masked, patient_name, gender, age, dept_id, group_id,
   attending_id, drg_code, ungrouped_flag, rw,
   admit_date, discharge_date, los_days, admit_path, discharge_type,
   main_diag_icd, main_oper_icd, vent_hours, mr_grade,
   surg_level, surg_date,
   total_fee, drug_fee, material_fee, exam_fee, surg_fee, other_fee,
   insurance_pay, cost_total, profit, pay_standard, rate_type,
   death_flag, readmit15_flag, spec_flag, emr_json)
WITH P AS (
  SELECT date '2026-10-28' AS base_date, 5848.0::numeric AS rate25, 6880.0::numeric AS rate26
),
dpar AS (  -- 科室向量（calib4 标定——真实 dim.drg_group 60 组均 base_rate 6,880）
           -- disch=§5.1 科室出院(入组÷0.985 反解+小科室)作份额向量；锚点月实播
           --   =份额×8,200（F-N4 收敛，open-items #1）；ungrp=1−入组/出院；
           --   c1..c5=六段 cdf
           --   （RAS 边际对齐：段分布 [940,3650,2932,662,128,37]=契约±10%盒内、
           --   全局 CMI≈1.087——契约段字面×真实组均值隐含 CMI≥1.11，见 #4）；
           --   cmi=实现科室CMI（契约值×~0.955 折减 #2）；margin=契约profit÷disch
           --   ÷0.9475（元/例）；fee_ratio=契约次均费÷(cmi×6880×1.02)，小科室封顶内插
  SELECT v.*, (sum(disch) OVER (ORDER BY ord) - disch)::numeric / sum(disch) OVER () AS lo_share,
              sum(disch) OVER (ORDER BY ord)::numeric / sum(disch) OVER () AS hi_share
  FROM (VALUES
    ( 1,'心血管内科',1381,0.0152,0.0362,0.3805,0.8749,0.9640,0.9910,1.3175,0.30,6.6,660.3,1.34,0.9600,0.248,0.090),
    ( 2,'骨科',1251,0.0152,0.0490,0.4303,0.8529,0.9692,0.9932,1.2858,0.62,7.8,1051.2,1.76,0.8800,0.124,0.220),
    ( 3,'呼吸与危重症医学科',1100,0.0155,0.0749,0.5279,0.8918,0.9839,0.9972,1.0986,0.12,7.4,410.7,1.46,0.9400,0.326,0.080),
    ( 4,'普通外科',1020,0.0147,0.0639,0.4930,0.8873,0.9780,0.9970,1.1448,0.62,6.3,1016.1,1.78,0.8600,0.182,0.160),
    ( 5,'神经内科',899,0.0156,0.1006,0.6112,0.9381,0.9928,0.9989,0.9445,0.10,7.9,448.5,1.46,0.9000,0.364,0.080),
    ( 6,'肿瘤科',822,0.0146,0.0568,0.4666,0.8786,0.9770,0.9952,1.1913,0.35,8.2,-444.2,1.78,0.9800,0.428,0.080),
    ( 7,'妇产科',804,0.0149,0.4244,0.9415,0.9944,0.9999,1.0000,0.5653,0.50,3.3,0.0,1.78,0.8800,0.156,0.100),
    ( 8,'儿科',718,0.0153,0.2436,0.8313,0.9761,0.9990,0.9999,0.7021,0.22,4.4,417.5,0.87,0.8400,0.264,0.080),
    ( 9,'神经外科',298,0.0134,0.0349,0.3549,0.7927,0.9462,0.9790,1.5288,0.68,10.7,-453.3,1.54,0.8500,0.130,0.180),
    (10,'消化内科',40,0.0250,0.1121,0.6412,0.9501,0.9948,0.9993,0.9000,0.30,5.5,844.3,1.74,0.9800,0.330,0.080),
    (11,'泌尿外科',30,0.0020,0.0860,0.5750,0.9375,0.9915,0.9986,0.9775,0.68,5.8,879.5,1.78,0.9000,0.160,0.150),
    (12,'内分泌科',25,0.0400,0.1839,0.7652,0.9676,0.9981,0.9998,0.7712,0.08,6.3,844.3,1.76,0.9500,0.380,0.080),
    (13,'心胸外科',20,0.0020,0.0287,0.3450,0.8938,0.9654,0.9897,1.3292,0.85,9.3,-897.1,1.72,0.8750,0.140,0.200),
    (14,'重症医学科',18,0.0556,0.0167,0.2593,0.8582,0.9373,0.9790,1.6062,0.40,11.8,-1759.0,1.78,0.9400,0.220,0.080),
    (15,'耳鼻喉科',14,0.0020,0.3007,0.8725,0.9762,0.9993,1.0000,0.6619,0.60,4.9,1206.2,1.72,0.8800,0.120,0.120),
    (16,'眼科',11,0.0020,0.4244,0.9415,0.9944,0.9999,1.0000,0.5653,0.80,3.0,1151.4,1.78,0.8000,0.080,0.200),
    (17,'中医科',9,0.0020,0.4244,0.9415,0.9944,0.9999,1.0000,0.5653,0.05,7.9,820.9,1.78,0.8500,0.620,0.020),
    (18,'康复医学科',8,0.0020,0.4244,0.9415,0.9944,0.9999,1.0000,0.5653,0.05,10.7,791.6,1.76,0.9500,0.300,0.080),
    (19,'皮肤科',6,0.0020,0.4136,0.9373,0.9936,0.9999,1.0000,0.5714,0.15,6.8,879.5,1.75,0.9000,0.300,0.060),
    (20,'急诊科',4,0.2500,0.1965,0.7924,0.9891,0.9994,0.9999,0.7201,0.15,3.3,791.6,1.78,0.9500,0.300,0.080)
  ) v(ord,name,disch,ungrp,c1,c2,c3,c4,c5,cmi,surg_p,los_mean,margin,fee_ratio,fund_share,drug_sh,mat_sh)
),
mon AS (
  SELECT * FROM (VALUES
    -- 窗口=2025-11~2026-12（14 月）：随 L3 ipc 曲线形态；锚点月收敛 8,200
    -- （F-N4：vs L3 Oct 8,120 仅 +1.0%；科室入组按 dpar 份额等比落数，见 #1）
    ('2025-11-01',6911),('2025-12-01',6696),
    ('2026-01-01',6168),('2026-02-01',5196),('2026-03-01',6701),('2026-04-01',7130),
    ('2026-05-01',7569),('2026-06-01',7788),('2026-07-01',8437),('2026-08-01',8866),
    ('2026-09-01',8207),('2026-10-01',8200),('2026-11-01',7998),('2026-12-01',7789)
  ) v(m,cnt)
),
daycdf AS (  -- 逐日出院权重：周日/周六少出院
  SELECT m.m::date AS month_start, dy::date AS day,
         (sum(w) OVER (PARTITION BY m.m ORDER BY dy) - w)
           / sum(w) OVER (PARTITION BY m.m) AS lo,
         sum(w) OVER (PARTITION BY m.m ORDER BY dy)
           / sum(w) OVER (PARTITION BY m.m) AS hi
  FROM mon m
  JOIN LATERAL (
    SELECT d::date AS dy,
           CASE extract(dow FROM d)::int WHEN 0 THEN 0.55 WHEN 6 THEN 0.80 ELSE 1.02 END AS w
    FROM generate_series(m.m::date, (m.m::date + interval '1 month - 1 day')::date,
                         interval '1 day') d
  ) x ON true
),
seq AS (
  SELECT m.m::date AS month_start, s AS seq, m.cnt AS mcnt
  FROM mon m CROSS JOIN LATERAL generate_series(1, m.cnt) AS s
),
u AS (  -- 每例 33 个确定性抽签 u01..u33 ∈ [0,1)
  SELECT month_start, seq, mcnt,
    ('x'||substr(md5('drg:'||month_start||':'||seq||':01'),1,15))::bit(60)::bigint / 1152921504606846976.0 AS u01,
    ('x'||substr(md5('drg:'||month_start||':'||seq||':02'),1,15))::bit(60)::bigint / 1152921504606846976.0 AS u02,
    ('x'||substr(md5('drg:'||month_start||':'||seq||':03'),1,15))::bit(60)::bigint / 1152921504606846976.0 AS u03,
    ('x'||substr(md5('drg:'||month_start||':'||seq||':04'),1,15))::bit(60)::bigint / 1152921504606846976.0 AS u04,
    ('x'||substr(md5('drg:'||month_start||':'||seq||':05'),1,15))::bit(60)::bigint / 1152921504606846976.0 AS u05,
    ('x'||substr(md5('drg:'||month_start||':'||seq||':06'),1,15))::bit(60)::bigint / 1152921504606846976.0 AS u06,
    ('x'||substr(md5('drg:'||month_start||':'||seq||':07'),1,15))::bit(60)::bigint / 1152921504606846976.0 AS u07,
    ('x'||substr(md5('drg:'||month_start||':'||seq||':08'),1,15))::bit(60)::bigint / 1152921504606846976.0 AS u08,
    ('x'||substr(md5('drg:'||month_start||':'||seq||':09'),1,15))::bit(60)::bigint / 1152921504606846976.0 AS u09,
    ('x'||substr(md5('drg:'||month_start||':'||seq||':10'),1,15))::bit(60)::bigint / 1152921504606846976.0 AS u10,
    ('x'||substr(md5('drg:'||month_start||':'||seq||':11'),1,15))::bit(60)::bigint / 1152921504606846976.0 AS u11,
    ('x'||substr(md5('drg:'||month_start||':'||seq||':12'),1,15))::bit(60)::bigint / 1152921504606846976.0 AS u12,
    ('x'||substr(md5('drg:'||month_start||':'||seq||':13'),1,15))::bit(60)::bigint / 1152921504606846976.0 AS u13,
    ('x'||substr(md5('drg:'||month_start||':'||seq||':14'),1,15))::bit(60)::bigint / 1152921504606846976.0 AS u14,
    ('x'||substr(md5('drg:'||month_start||':'||seq||':15'),1,15))::bit(60)::bigint / 1152921504606846976.0 AS u15,
    ('x'||substr(md5('drg:'||month_start||':'||seq||':16'),1,15))::bit(60)::bigint / 1152921504606846976.0 AS u16,
    ('x'||substr(md5('drg:'||month_start||':'||seq||':17'),1,15))::bit(60)::bigint / 1152921504606846976.0 AS u17,
    ('x'||substr(md5('drg:'||month_start||':'||seq||':18'),1,15))::bit(60)::bigint / 1152921504606846976.0 AS u18,
    ('x'||substr(md5('drg:'||month_start||':'||seq||':19'),1,15))::bit(60)::bigint / 1152921504606846976.0 AS u19,
    ('x'||substr(md5('drg:'||month_start||':'||seq||':20'),1,15))::bit(60)::bigint / 1152921504606846976.0 AS u20,
    ('x'||substr(md5('drg:'||month_start||':'||seq||':21'),1,15))::bit(60)::bigint / 1152921504606846976.0 AS u21,
    ('x'||substr(md5('drg:'||month_start||':'||seq||':22'),1,15))::bit(60)::bigint / 1152921504606846976.0 AS u22,
    ('x'||substr(md5('drg:'||month_start||':'||seq||':23'),1,15))::bit(60)::bigint / 1152921504606846976.0 AS u23,
    ('x'||substr(md5('drg:'||month_start||':'||seq||':24'),1,15))::bit(60)::bigint / 1152921504606846976.0 AS u24,
    ('x'||substr(md5('drg:'||month_start||':'||seq||':25'),1,15))::bit(60)::bigint / 1152921504606846976.0 AS u25,
    ('x'||substr(md5('drg:'||month_start||':'||seq||':26'),1,15))::bit(60)::bigint / 1152921504606846976.0 AS u26,
    ('x'||substr(md5('drg:'||month_start||':'||seq||':27'),1,15))::bit(60)::bigint / 1152921504606846976.0 AS u27,
    ('x'||substr(md5('drg:'||month_start||':'||seq||':28'),1,15))::bit(60)::bigint / 1152921504606846976.0 AS u28,
    ('x'||substr(md5('drg:'||month_start||':'||seq||':29'),1,15))::bit(60)::bigint / 1152921504606846976.0 AS u29,
    ('x'||substr(md5('drg:'||month_start||':'||seq||':30'),1,15))::bit(60)::bigint / 1152921504606846976.0 AS u30,
    ('x'||substr(md5('drg:'||month_start||':'||seq||':31'),1,15))::bit(60)::bigint / 1152921504606846976.0 AS u31,
    ('x'||substr(md5('drg:'||month_start||':'||seq||':32'),1,15))::bit(60)::bigint / 1152921504606846976.0 AS u32,
    ('x'||substr(md5('drg:'||month_start||':'||seq||':33'),1,15))::bit(60)::bigint / 1152921504606846976.0 AS u33
  FROM seq
),
alloc AS (  -- 科室 + 出院日
  SELECT u.*, dp.name AS dept_name, dr.id AS dept_id,
         dp.ungrp, dp.c1, dp.c2, dp.c3, dp.c4, dp.c5, dp.cmi, dp.surg_p,
         dp.los_mean, dp.margin, dp.fee_ratio, dp.fund_share, dp.drug_sh, dp.mat_sh,
         dy.day AS discharge_date
  FROM u
  JOIN dpar dp ON u.seq::numeric / u.mcnt > dp.lo_share
              AND u.seq::numeric / u.mcnt <= dp.hi_share   -- 位置分配：锚点月科室出院=参数精确值
  JOIN dim.department dr ON dr.name = dp.name AND dr.level = 2 AND dr.active
  JOIN daycdf dy ON dy.month_start = u.month_start AND u.u02 >= dy.lo AND u.u02 < dy.hi
),
seg AS (  -- 未入组判定 + 六段抽取 + 段内目标权重
  SELECT a.*,
    (u05 < ungrp) AS ungrouped_flag,
    CASE WHEN u05 >= ungrp THEN
      CASE WHEN u06 < c1 THEN 1 WHEN u06 < c2 THEN 2 WHEN u06 < c3 THEN 3
           WHEN u06 < c4 THEN 4 WHEN u06 < c5 THEN 5 ELSE 6 END END AS seg_no,
    CASE WHEN u05 >= ungrp THEN
      CASE WHEN u06 < c1 THEN 0.20 + 0.24*u07
           WHEN u06 < c2 THEN 0.50 + 0.15*power(u07,1.5)   -- 段内下沉抽组（实现均值≈0.62）
           WHEN u06 < c3 THEN CASE WHEN u07 < 0.80 THEN 1.00 + 0.28*(u07/0.80)
                                   ELSE 1.28 + 0.60*((u07-0.80)/0.20) END  -- ~12% 入 1.5-2
           WHEN u06 < c4 THEN 2.05 + 2.50*power(u07,6.0)   -- ~12% 入 3-5（N5 空洞修复）
           WHEN u06 < c5 THEN 5.02 + 0.80*u07
           ELSE 10.10 + 1.20*u07 END END AS target_rw
  FROM alloc a
),
grp AS (  -- 段内最近邻病组（段空则全局最近邻，守护已告警）；费率优先用病组 base_rate
  SELECT s.*, gg.code AS drg_code, gg.rw, gg.risk_level,
         COALESCE(gg.base_rate, 6880.00) AS base_rate
  FROM seg s
  LEFT JOIN LATERAL (
    SELECT g.code, g.rw, g.risk_level, g.base_rate
    FROM dim.drg_group g
    WHERE NOT s.ungrouped_flag
    ORDER BY (g.rw >= CASE s.seg_no WHEN 1 THEN 0    WHEN 2 THEN 0.5 WHEN 3 THEN 1.0
                                    WHEN 4 THEN 2.0  WHEN 5 THEN 5.0 ELSE 10.0 END
          AND g.rw <  CASE s.seg_no WHEN 1 THEN 0.5  WHEN 2 THEN 1.0 WHEN 3 THEN 2.0
                                    WHEN 4 THEN 5.0  WHEN 5 THEN 10.0 ELSE 999.0 END) DESC,
             abs(g.rw - s.target_rw), g.code
    LIMIT 1
  ) gg ON true
),
flag AS (  -- 标志位与入院/离院/病案质量
  SELECT g.*,
    greatest(1, least(120,
      round(los_mean * (0.30 + 1.40*u03)
            + CASE WHEN u04 > 0.97 THEN los_mean*1.6 ELSE 0 END)))::int AS los_days,
    (u08 < CASE COALESCE(risk_level,'mid')
             WHEN 'low' THEN 0.0        -- 低危死亡走 mort 配额（audit B4：≤2例/锚点月）
             WHEN 'mid' THEN 0.004
             WHEN 'midhigh' THEN 0.012 WHEN 'high' THEN 0.025 ELSE 0.006 END) AS death_p,
    row_number() OVER (
      PARTITION BY month_start, (risk_level IS NOT NULL AND risk_level = 'low')
      ORDER BY (rw >= 0.5), u08) AS low_rnk,   -- 低危子集内升序；rw<0.5 组优先落额

    (u09 < 0.024) AS readmit15_draw,
    CASE WHEN u10 < 0.925 THEN 'normal' WHEN u10 < 0.970 THEN 'high' ELSE 'low' END AS rate_type,
    (u18 < 0.987) AS grade_a,
    (u18 >= 0.998) AS grade_c,
    CASE WHEN u19 < CASE WHEN dept_name IN ('急诊科','重症医学科') THEN 0.28 ELSE 0.58 END
              THEN '1'
         WHEN u19 < 0.90 THEN '2' WHEN u19 < 0.95 THEN '3' ELSE '9' END AS admit_path,
    CASE WHEN u20 < 0.93 THEN '1' WHEN u20 < 0.965 THEN '2'
         WHEN u20 < 0.98 THEN '3' WHEN u20 < 0.993 THEN '4' ELSE '9' END AS disch_type_draw,
    (u21 < CASE WHEN (u10 >= 0.925 AND u10 < 0.970) OR rw >= 5 THEN 0.06
                ELSE 0.008 END) AS spec_flag,   -- 高倍率/RW≥5 特例单议概率上调
    (u22 < CASE dept_name WHEN '重症医学科' THEN 0.35 WHEN '神经外科' THEN 0.12
                          WHEN '心胸外科' THEN 0.12 WHEN '呼吸与危重症医学科' THEN 0.08
                          ELSE 0.015 END) AS vent_flag,
    (u25 < surg_p) AS surg_flag
  FROM grp g
),
mort AS (  -- 低风险死亡配额化：每月低危子集按 u08 升序取定额（锚点月 2 例、
           -- 余月 1 例），排序键 (rw>=0.5) 使配额优先落在 RW<0.5 病组——
           -- 两口径（risk_level='low' 0.02% / RW<0.5 段非零）同时满足
  SELECT f.*,
    CASE WHEN risk_level = 'low'
         THEN low_rnk <= CASE WHEN month_start = date '2026-10-01' THEN 2 ELSE 1 END
         ELSE death_p END AS death_flag
  FROM flag f
),
tim AS (
  SELECT f.*,
    discharge_date - (los_days - 1) AS admit_date,
    CASE WHEN grade_c THEN 'C' WHEN grade_a THEN 'A' ELSE 'B' END AS mr_grade,
    CASE WHEN death_flag THEN '5' ELSE disch_type_draw END AS discharge_type,
    (readmit15_draw AND NOT death_flag) AS readmit15_flag,
    CASE WHEN vent_flag THEN
           CASE WHEN u23 < 0.10 THEN 96 + floor(u23 * 2400)::numeric   -- 长程通气 96~335h（MDCA先期组口径）
                ELSE 4 + floor(u23 * 72)::numeric END                  -- 常规通气 11~75h
         ELSE 0 END AS vent_hours
  FROM mort f
),
surg AS (  -- 手术属性：级别随科室 CMI 偏移；术日 = 入院后 0..min(los,4)-1 天
  SELECT t.*,
    CASE WHEN surg_flag THEN
      CASE WHEN u26 < least(0.08 + 0.14*cmi, 0.55) THEN 4
           WHEN u26 < least(0.08 + 0.14*cmi, 0.55) + 0.38 THEN 3
           WHEN u26 < least(0.08 + 0.14*cmi, 0.55) + 0.72 THEN 2
           ELSE 1 END END AS surg_level,
    CASE WHEN surg_flag THEN
      admit_date + floor(u27 * greatest(1, least(los_days, 4)))::int END AS surg_date
  FROM tim t
),
fee AS (  -- 费用链：支付标准→倍率→总费用→基金支付→成本→结余
  SELECT s.*, base_rate * CASE WHEN extract(year FROM discharge_date) = 2025
                               THEN P.rate25 / P.rate26 ELSE 1.0 END AS rate_eff,
    CASE WHEN ungrouped_flag THEN NULL
         ELSE round(rw * base_rate * CASE WHEN extract(year FROM discharge_date) = 2025
                                          THEN P.rate25 / P.rate26 ELSE 1.0 END, 2)
    END AS pay_standard,
    round((CASE
      WHEN ungrouped_flag THEN cmi * P.rate26 * fee_ratio * (0.70 + 0.70*u11)
             * CASE WHEN extract(year FROM discharge_date)=2025
                    THEN P.rate25 / P.rate26 ELSE 1.0 END
      WHEN rate_type = 'high' THEN rw * base_rate * CASE WHEN extract(year FROM discharge_date)=2025
                                                         THEN P.rate25 / P.rate26 ELSE 1.0 END
                                  * (3.05 + 1.90*u11)
      WHEN rate_type = 'low'  THEN rw * base_rate * CASE WHEN extract(year FROM discharge_date)=2025
                                                         THEN P.rate25 / P.rate26 ELSE 1.0 END
                                  * (0.28 + 0.19*u11)
      ELSE rw * base_rate * CASE WHEN extract(year FROM discharge_date)=2025
                                 THEN P.rate25 / P.rate26 ELSE 1.0 END
              * least(greatest(fee_ratio * (0.78 + 0.50*u11), 0.50), 1.95)
    END) * CASE WHEN death_flag THEN 1.22 ELSE 1.0 END, 2) AS total_fee
  FROM surg s, P
),
fee2 AS (
  SELECT f.*,
    CASE  -- 医保结算支付：normal≈支付标准×基金分担比(封顶0.97×费用)；高低倍率/未入组按项目付费折算
      WHEN ungrouped_flag THEN round(total_fee * (0.66 + 0.10*u12), 2)
      WHEN rate_type = 'high' THEN round(total_fee * (0.70 + 0.10*u12), 2)
      WHEN rate_type = 'low'  THEN round(total_fee * (0.65 + 0.08*u12), 2)
      ELSE round(least(pay_standard * fund_share * (0.97 + 0.05*u12),
                       total_fee * 0.97), 2)
    END AS insurance_pay
  FROM fee f
),
fee3 AS (
  SELECT f.*,
    round(greatest(insurance_pay
                   - margin * (CASE WHEN rate_type = 'normal' AND NOT ungrouped_flag
                                    THEN 1.0 ELSE 0.30 END)
                               * (0.55 + 0.90*u13),
                   total_fee * 0.30, 200.0), 2) AS cost_total  -- 地板 0.45→0.30：
                   -- 次均费升档后 0.45×fee 会吞掉 margin 空间（G2 重锚后遗症修正）
  FROM fee2 f
),
split AS (  -- 分项归一：other_fee 兜底使五项和 = total_fee（CHECK 保证）
  SELECT f.*, insurance_pay - cost_total AS profit,
    total_fee * drug_sh * (0.70 + 0.60*u14) AS p_drug,
    total_fee * mat_sh  * (0.60 + 0.70*u15) AS p_mat,
    total_fee * 0.24    * (0.70 + 0.60*u16) AS p_exam,
    total_fee * CASE WHEN surg_flag THEN 0.22 + 0.14*u17 ELSE 0.03*(0.5+u17) END AS p_surg
  FROM fee3 f
),
split2 AS (
  SELECT s.*,
    round(p_drug * sc, 2) AS drug_fee, round(p_mat * sc, 2) AS material_fee,
    round(p_exam * sc, 2) AS exam_fee, round(p_surg * sc, 2) AS surg_fee
  FROM (
    SELECT s.*, least(1.0, total_fee * 0.96 / nullif(p_drug+p_mat+p_exam+p_surg, 0)) AS sc
    FROM split s) s
),
pick AS (  -- ICD/医疗组/医师 确定性抽取
  SELECT s2.*,
    total_fee - drug_fee - material_fee - exam_fee - surg_fee AS other_fee,
    (SELECT p.icd FROM (
       VALUES ('心血管内科','I21.9'),('心血管内科','I50.9'),('心血管内科','I48.9'),
              ('骨科','S72.0'),('骨科','M17.9'),('骨科','M51.2'),
              ('呼吸与危重症医学科','J18.0'),('呼吸与危重症医学科','J44.1'),('呼吸与危重症医学科','J45.9'),
              ('普通外科','K35.9'),('普通外科','K80.2'),('普通外科','C18.9'),
              ('神经内科','I63.9'),('神经内科','G40.9'),('神经内科','G45.0'),
              ('肿瘤科','C34.9'),('肿瘤科','C50.9'),('肿瘤科','C16.9'),
              ('儿科','J06.9'),('儿科','J18.0'),('儿科','A09.9'),
              ('神经外科','I63.9'),('神经外科','S06.5'),('神经外科','C71.9'),
              ('妇产科','O80.1'),('妇产科','O82.9'),('妇产科','N83.2'),
              ('消化内科','K29.7'),('消化内科','K52.9'),('消化内科','K92.2'),
              ('泌尿外科','N20.0'),('泌尿外科','N40.9'),('泌尿外科','C61.9'),
              ('内分泌科','E11.9'),('内分泌科','E04.2'),('内分泌科','E87.6'),
              ('心胸外科','I25.2'),('心胸外科','I07.0'),('心胸外科','C34.0'),
              ('重症医学科','A41.9'),('重症医学科','J96.0'),('重症医学科','I46.0'),
              ('耳鼻喉科','J32.9'),('耳鼻喉科','J35.0'),('耳鼻喉科','H66.9'),
              ('眼科','H25.9'),('眼科','H40.1'),('眼科','H33.0'),
              ('中医科','I69.3'),('中医科','M54.5'),('中医科','K29.7'),
              ('康复医学科','I69.3'),('康复医学科','G81.9'),('康复医学科','M54.5'),
              ('皮肤科','L40.9'),('皮肤科','L03.1'),('皮肤科','C44.9'),
              ('急诊科','T07.9'),('急诊科','J18.0'),('急诊科','R56.8')
       ) p(dept,icd)
     WHERE p.dept = s2.dept_name
     ORDER BY p.icd
     OFFSET floor(s2.u24 * 3)::int LIMIT 1) AS main_diag_icd,
    (SELECT p.icd FROM (
       VALUES ('心血管内科','36.06'),('心血管内科','88.55'),('心血管内科','39.72'),
              ('骨科','81.54'),('骨科','79.35'),('骨科','03.09'),
              ('呼吸与危重症医学科','33.24'),('呼吸与危重症医学科','34.04'),('呼吸与危重症医学科','31.45'),
              ('普通外科','51.23'),('普通外科','47.09'),('普通外科','45.80'),
              ('神经内科','39.59'),('神经内科','88.72'),('神经内科','03.31'),
              ('肿瘤科','86.06'),('肿瘤科','32.41'),('肿瘤科','85.41'),
              ('儿科','47.09'),('儿科','53.49'),('儿科','21.22'),
              ('神经外科','01.24'),('神经外科','02.34'),('神经外科','01.39'),
              ('妇产科','74.10'),('妇产科','68.41'),('妇产科','73.59'),
              ('消化内科','45.23'),('消化内科','43.89'),('消化内科','42.33'),
              ('泌尿外科','57.00'),('泌尿外科','55.03'),('泌尿外科','56.31'),
              ('内分泌科','06.39'),('内分泌科','07.62'),('内分泌科','41.90'),
              ('心胸外科','35.22'),('心胸外科','32.49'),('心胸外科','37.32'),
              ('重症医学科','96.04'),('重症医学科','31.10'),('重症医学科','96.72'),
              ('耳鼻喉科','28.30'),('耳鼻喉科','22.63'),('耳鼻喉科','21.31'),
              ('眼科','13.41'),('眼科','14.74'),('眼科','13.19'),
              ('中医科','99.29'),('中医科','93.35'),('中医科','99.62'),
              ('康复医学科','93.39'),('康复医学科','93.89'),('康复医学科','93.19'),
              ('皮肤科','86.22'),('皮肤科','86.30'),('皮肤科','86.04'),
              ('急诊科','54.19'),('急诊科','38.93'),('急诊科','97.04')
       ) p(dept,icd)
     WHERE p.dept = s2.dept_name
     ORDER BY p.icd
     OFFSET floor(s2.u28 * 3)::int LIMIT 1) AS main_oper_icd,
    (SELECT st.id FROM dim.staff st
     WHERE st.dept_id = s2.dept_id AND st.staff_type = 'doc' AND st.active
     ORDER BY st.id
     OFFSET floor(s2.u29 * (SELECT count(*) FROM dim.staff st2
                            WHERE st2.dept_id = s2.dept_id AND st2.staff_type='doc' AND st2.active))::int
     LIMIT 1) AS attending_id,
    (SELECT g3.id FROM dim.department g3
     WHERE g3.parent_id = s2.dept_id AND g3.level = 3 AND g3.active
     ORDER BY g3.id
     OFFSET floor(s2.u30 * (SELECT count(*) FROM dim.department g4
                            WHERE g4.parent_id = s2.dept_id AND g4.level=3 AND g4.active))::int
     LIMIT 1) AS group_id
  FROM split2 s2
)
SELECT 'D' || to_char(discharge_date, 'YYYYMMDD') || '-' || lpad(seq::text, 6, '0'),
       'P' || lpad((100000 + floor(u31 * 900000))::int::text, 6, '0'),
       NULL,                                            -- patient_name 建列缓填
       CASE WHEN dept_name = '妇产科' THEN '2' WHEN u32 < 0.55 THEN '1' ELSE '2' END,
       CASE WHEN dept_name = '儿科'  THEN 1 + floor(u33*14)::int
            WHEN dept_name = '妇产科' THEN 20 + floor(u33*26)::int
            ELSE 20 + floor(70 * power(u33, 0.8))::int END,
       dept_id, group_id,
       COALESCE(attending_id, (SELECT min(id) FROM dim.staff WHERE staff_type='doc' AND active)),
       CASE WHEN ungrouped_flag THEN NULL ELSE drg_code END,
       ungrouped_flag,
       CASE WHEN ungrouped_flag THEN NULL ELSE rw END,
       admit_date, discharge_date, los_days, admit_path, discharge_type,
       COALESCE(main_diag_icd, 'R69.9'),
       CASE WHEN surg_flag THEN main_oper_icd ELSE NULL END,
       vent_hours, mr_grade,
       surg_level, surg_date,
       total_fee, drug_fee, material_fee, exam_fee, surg_fee, other_fee,
       insurance_pay, cost_total, profit, pay_standard, rate_type,
       death_flag, readmit15_flag, spec_flag, NULL      -- emr_json 建列缓填
FROM pick;
