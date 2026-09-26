-- ============================================================================
-- lane L8 newdom-hr-research — 种子·相位Ⅱ/Ⅲ：维度 + 事实 + 汇总表种子 + 供稿
-- 确定性：全部字面值 + generate_series + md5 散列；不使用随机/当前时钟函数。
-- 幂等：自然键/业务键 ON CONFLICT DO NOTHING；可重复执行。
-- 前置相位：Ⅰ 定义层（sys.dict/sys.metric_def，本 lane 供稿见 seed_1_defs.sql，
--   正式来源=L1 汇编 1001/1002）须先完成；L2 dim.department/dim.staff 已播种；
--   §A2 metric_value 段仅表级依赖 L5 dws.metric_value（migrations/0304）。
-- 段内序：D1 维表 → D2/D3 事实 → A1 本 lane dws 表 → A2 metric_value 供稿
--   （读 dim/dwd 行、写 dws 表，符合"事实相位先于汇总相位"公约）。
-- ============================================================================

-- ============================================================================
-- [D1] dim.discipline —— 重点学科维表（契约 §8.1 disciplines；≥3 行）
--   id 固定便于跨 lane 引用；id=0 哨兵承接非重点归口。leader_id 由依托科室
--   最高职称医师确定性回填（senior_pos→senior_sub→middle→junior 序）。
-- ============================================================================
INSERT INTO dim.discipline (id, code, name, discipline_level, dept_id, leader_id, sort, active)
OVERRIDING SYSTEM VALUE
VALUES
  (0,'NONE','非重点学科归口',NULL,0,NULL,0,true),
  (1,'CARDIO','心血管病学','national_key',2,NULL,1,true),   -- 依托 心血管内科(XNK=2)
  (2,'ORTHO','骨外科学','provincial_key',1,NULL,2,true),     -- 依托 骨科(GK=1)
  (3,'RESP','呼吸病学','provincial_key',6,NULL,3,true)       -- 依托 呼吸与危重症医学科(HXWZK=6)
ON CONFLICT (id) DO NOTHING;

SELECT setval(pg_get_serial_sequence('dim.discipline','id'),
              GREATEST((SELECT max(id) FROM dim.discipline), 1));

UPDATE dim.discipline dc
   SET leader_id = pick.id
  FROM (
    SELECT DISTINCT ON (s.dept_id) s.dept_id, s.id
      FROM dim.staff s
     WHERE s.staff_type = 'doc' AND s.active
     ORDER BY s.dept_id,
              CASE s.title_level WHEN 'senior_pos' THEN 0 WHEN 'senior_sub' THEN 1
                                 WHEN 'middle' THEN 2 ELSE 3 END,
              s.code
  ) pick
 WHERE pick.dept_id = dc.dept_id AND dc.id <> 0 AND dc.leader_id IS NULL;
-- rows: 4（哨兵1 + 重点3）；锚点: disciplines 表 name/level/leader 三行 + 哨兵

-- ============================================================================
-- [D2] dwd.hr_cost_month —— 科室人员经费月表（改造；契约 §7.1 人员经费占比 32.5%）
--   24 个月 × 44 个 level≤2 科室（行政12+业务32；level=3 医疗组无直属人员不列）。
--   月度院级总额 = 当月目标占比 × 月业务支出口径：BASE_DATE=2026-10-28 后
--   "本月"=2026-10，锚 Σ=46,078,500 元 = 32.5% × 141,780,000 元（scale-decision §2
--   成本趋势第10月 14,178 万元）；2026 其余月支出=同表成本趋势×10⁴ 元，
--   2025 支出=2026 同月×0.94（同比 +6.4% 假设，见 open-items #14）。
--   科室分摊 = 加权编制人数占比（doc 1.60 / nur 1.00 / tec 1.10 / adm 0.85，
--   反映岗位薪酬相对水平），最大权重科室吸收分币尾差 → 月度合计精确命中。
-- ============================================================================
INSERT INTO dwd.hr_cost_month (period_type, period_start, dept_id, staff_cost_amt)
WITH m(period_start, month_total) AS (VALUES
  (date '2025-01-01', 24823444.80), (date '2025-02-01', 22498994.00),
  (date '2025-03-01', 30245496.40), (date '2025-04-01', 32732980.80),
  (date '2025-05-01', 35091619.40), (date '2025-06-01', 36703146.00),
  (date '2025-07-01', 39555999.00), (date '2025-08-01', 38558762.40),
  (date '2025-09-01', 37339873.80), (date '2025-10-01', 42380877.60),
  (date '2025-11-01', 40906901.20), (date '2025-12-01', 39537152.00),
  (date '2026-01-01', 27436800.00), (date '2026-02-01', 24768968.00),
  (date '2026-03-01', 33231352.00), (date '2026-04-01', 35916098.00),
  (date '2026-05-01', 38404940.00), (date '2026-06-01', 40115310.00),
  (date '2026-07-01', 43149570.00), (date '2026-08-01', 41772858.00),
  (date '2026-09-01', 40287165.00), (date '2026-10-01', 46078500.00),
  (date '2026-11-01', 44445636.00), (date '2026-12-01', 42928304.00)
),
w AS (
  SELECT s.dept_id,
         SUM(CASE s.staff_type WHEN 'doc' THEN 1.60 WHEN 'tec' THEN 1.10
                               WHEN 'adm' THEN 0.85 ELSE 1.00 END) AS wt
    FROM dim.staff s
   WHERE s.active
   GROUP BY s.dept_id
),
base AS (
  SELECT m.period_start, m.month_total, w.dept_id,
         ROUND(m.month_total * w.wt / (SELECT SUM(wt) FROM w), 2) AS amt,
         ROW_NUMBER() OVER (PARTITION BY m.period_start ORDER BY w.wt DESC, w.dept_id) AS rn
    FROM m CROSS JOIN w
)
SELECT 'month', b.period_start, b.dept_id,
       b.amt + CASE WHEN b.rn = 1
                    THEN b.month_total - SUM(b.amt) OVER (PARTITION BY b.period_start)
                    ELSE 0::numeric END
  FROM base b
ON CONFLICT (period_type, period_start, dept_id) DO NOTHING;
-- rows: 24 月 × 44 科 = 1,056；锚点: 2026-10 Σ=46,078,500 元 → 人员经费占比 32.5%

-- ============================================================================
-- [D3] dwd.research_project —— 科研课题主档（新建；契约 §8.1）
--   按 (apply_year×project_level) 规格组确定性生成：
--   · 年度立项数：国家 3/3/4/6/8/9/12、省级 10/12/12/16/20/24/30（2020~2026，
--     契约 trend 序列 2020-2024 按 L5 口径平移至 2022-2026）+ 院级 18/20/24/26/28/3/0
--     （2025 全院新立 36 与契约 delta"+6项"自洽：36→42）；
--   · 在研数按组内 ongoing_cnt 取前序 seq（近 5 年为主）→ Σongoing=186、
--     2026 新立=国12+省30+院0=42（院级 2025-2026 暂停立项，经费向省级以上集中）；
--   · funds_amt：组内反对称 jitter（Σ偏移=0）+ 末行吸收尾差 → 各年立项经费
--     精确命中 L5 RESEARCH_FUND 年序列（2020:500万…2026:3,480万）；
--   · discipline 归口：ongoing 行按 alloc 表划归 CARDIO 28 / ORTHO 22 / RESP 18，
--     其余 discipline_id=0；dept=依托科室或加权科室池散列指派；
--   · leader_id=承担科室最高职称在职医师（确定性散列序内取位）。
-- ============================================================================
INSERT INTO dwd.research_project
  (project_code, name, project_level, project_status, apply_year, start_date, end_date,
   funds_amt, dept_id, discipline_id, leader_id)
WITH spec AS (
  SELECT * FROM (VALUES
    (2020::smallint,'national'::varchar(16),  3,  1,  2400000::numeric),
    (2020,'provincial',10,  0,  1880000),
    (2020,'hospital',  18,  0,   720000),
    (2021,'national',   3,  2,  3300000),
    (2021,'provincial',12,  2,  3600000),
    (2021,'hospital',  20,  0,  1100000),
    (2022,'national',   4,  4,  6000000),
    (2022,'provincial',12,  8,  4800000),
    (2022,'hospital',  24,  3,  1200000),
    (2023,'national',   6,  6,  9000000),
    (2023,'provincial',16, 16,  6400000),
    (2023,'hospital',  26, 12,  1400000),
    (2024,'national',   8,  8, 11600000),
    (2024,'provincial',20, 20,  9200000),
    (2024,'hospital',  28, 26,  1600000),
    (2025,'national',   9,  9, 16200000),
    (2025,'provincial',24, 24, 12000000),
    (2025,'hospital',   3,  3,  1200000),
    (2026,'national',  12, 12, 18000000),
    (2026,'provincial',30, 30, 16800000)
  ) AS v(apply_year, plevel, new_cnt, ongoing_cnt, total_funds)
),
proj AS (
  SELECT s.*, g.seq
    FROM spec s CROSS JOIN LATERAL generate_series(1, s.new_cnt) AS g(seq)
),
alloc AS (  -- ongoing 行（seq≤ongoing_cnt）学科归口划拨；Σ CARDIO 28/ORTHO 22/RESP 18
  SELECT * FROM (VALUES
    (2024::smallint,'national'::varchar(16),'CARDIO'::varchar(16),1),
    (2025,'national','CARDIO',2),(2026,'national','CARDIO',3),
    (2025,'national','ORTHO',1),(2026,'national','ORTHO',2),
    (2023,'national','RESP',1),(2024,'national','RESP',1),(2026,'national','RESP',1),
    (2022,'provincial','RESP',1),
    (2023,'provincial','CARDIO',3),(2023,'provincial','ORTHO',2),(2023,'provincial','RESP',2),
    (2024,'provincial','CARDIO',4),(2024,'provincial','ORTHO',3),(2024,'provincial','RESP',2),
    (2025,'provincial','CARDIO',6),(2025,'provincial','ORTHO',4),(2025,'provincial','RESP',3),
    (2026,'provincial','CARDIO',6),(2026,'provincial','ORTHO',5),(2026,'provincial','RESP',4),
    (2023,'hospital','ORTHO',1),(2023,'hospital','RESP',1),
    (2024,'hospital','CARDIO',2),(2024,'hospital','ORTHO',3),(2024,'hospital','RESP',1),
    (2025,'hospital','CARDIO',1),(2025,'hospital','ORTHO',1),(2025,'hospital','RESP',1)
  ) AS a(apply_year, plevel, disc_code, cnt)
),
alloc2 AS (
  SELECT a.*, SUM(a.cnt) OVER (PARTITION BY a.apply_year, a.plevel
                              ORDER BY a.disc_code) AS cum_hi
    FROM alloc a
),
priced AS (  -- 反对称 jitter：Σ(seq−(n+1)/2)=0 保组内合计；末行另收尾差
  SELECT p.*,
         CASE WHEN p.seq <= p.ongoing_cnt THEN 'ongoing'::varchar ELSE 'closed'::varchar END AS st,
         'RP' || p.apply_year || '-' || CASE p.plevel WHEN 'national' THEN 'N'
                WHEN 'provincial' THEN 'P' WHEN 'hospital' THEN 'H' ELSE 'O' END
              || lpad(p.seq::text, 3, '0') AS pcode,
         CASE WHEN p.seq < p.new_cnt
              THEN ROUND(p.total_funds / p.new_cnt
                         + (p.seq - (p.new_cnt + 1) / 2.0)
                           * CASE p.plevel WHEN 'national' THEN 80000
                                           WHEN 'provincial' THEN 12000 ELSE 4000 END, 2)
         END AS raw_amt
    FROM proj p
),
final AS (
  SELECT pr.*,
         COALESCE(pr.raw_amt,
                  pr.total_funds - SUM(pr.raw_amt) OVER (PARTITION BY pr.apply_year, pr.plevel)
                 ) AS amt
    FROM priced pr
),
named AS (  -- 资助计划名池（确定性取位）
  SELECT f.*,
         (CASE f.plevel
            WHEN 'national'   THEN (ARRAY['国家自然科学基金面上项目','国家自然科学基金青年基金','国家重点研发计划子课题','国家科技重大专项子课题'])
            WHEN 'provincial' THEN (ARRAY['省自然科学基金面上项目','省重点研发计划课题','省卫生健康委科研课题','省中医药管理局课题'])
            ELSE                   (ARRAY['院级科研基金重点项目','院级科研基金一般项目','院级青年科研基金','院级重点培育专项'])
          END)[1 + (('x' || substr(md5(f.pcode), 1, 7))::bit(28)::bigint % 4)]
         || '（' || f.pcode || '）' AS pname
    FROM final f
),
pool AS (  -- 非归口课题承担科室加权池（临床为主，平台/医技少量）
  SELECT d.id AS dept_id, pw.w,
         SUM(pw.w) OVER (ORDER BY pw.code) AS cum_hi
    FROM (VALUES
      ('GK',7),('XNK',6),('HXWZK',6),('PWK',14),('FCK',12),('SJNK',10),('XHNK',9),
      ('ZLK',9),('SJWK',7),('XTXK',7),('NFMK',7),('MNWK',6),('EBHK',5),('YK',5),
      ('ZYK',6),('PFK',3),('EK',5),('KFK',3),('ZZYXK',4),('JZK',3),('MZK',2),
      ('JYK',2),('BLK',1)
    ) pw(code, w)
    JOIN dim.department d ON d.code = pw.code
),
placed AS (
  SELECT n.*,
         COALESCE(ds.id, 0) AS disc_id,
         COALESCE(ds.dept_id,
                  (SELECT pl.dept_id FROM pool pl
                    WHERE (('x' || substr(md5(n.pcode || '|dept'), 1, 7))::bit(28)::bigint
                           % (SELECT SUM(w) FROM pool)) < pl.cum_hi
                    ORDER BY pl.cum_hi LIMIT 1)) AS dept
    FROM named n
    LEFT JOIN (
      SELECT a2.apply_year, a2.plevel, dsc.id, dsc.dept_id, a2.cum_hi - a2.cnt + 1 AS seq_lo, a2.cum_hi AS seq_hi
        FROM alloc2 a2 JOIN dim.discipline dsc ON dsc.code = a2.disc_code
    ) ds ON ds.apply_year = n.apply_year AND ds.plevel = n.plevel
            AND n.seq BETWEEN ds.seq_lo AND ds.seq_hi
),
leaded AS (
  SELECT p.*,
         (SELECT l.id FROM (
            SELECT s2.id, s2.dept_id,
                   ROW_NUMBER() OVER (PARTITION BY s2.dept_id
                                      ORDER BY CASE s2.title_level WHEN 'senior_pos' THEN 0
                                               WHEN 'senior_sub' THEN 1 WHEN 'middle' THEN 2 ELSE 3 END,
                                               s2.code) AS rn,
                   COUNT(*) OVER (PARTITION BY s2.dept_id) AS n
              FROM dim.staff s2 WHERE s2.staff_type = 'doc' AND s2.active) l
           WHERE l.dept_id = p.dept
             AND l.rn = 1 + (('x' || substr(md5(p.pcode || '|leader'), 1, 7))::bit(28)::bigint
                             % GREATEST(l.n, 1))
           LIMIT 1) AS lead_id
    FROM placed p
)
SELECT pcode, pname, plevel, st, apply_year,
       (make_date(apply_year, 1, 15)
        + (('x' || substr(md5(pcode || '|start'), 1, 7))::bit(28)::bigint % 300) * INTERVAL '1 day')::date AS start_date,
       CASE WHEN st = 'closed'
            THEN (make_date(apply_year, 1, 15)
                  + (('x' || substr(md5(pcode || '|start'), 1, 7))::bit(28)::bigint % 300
                     + 730
                     + ('x' || substr(md5(pcode || '|dur'), 1, 7))::bit(28)::bigint % 730)
                    * INTERVAL '1 day')::date
       END AS end_date,
       amt, dept, disc_id, lead_id
  FROM leaded
UNION ALL
-- 申报中 6 行（apply_year/funds 未批复=NULL；承担科室定列轮转）
SELECT 'RPA-' || lpad(a.seq::text, 2, '0'),
       CASE WHEN a.seq <= 3 THEN '国家自然科学基金面上项目' ELSE '省自然科学基金面上项目' END
         || '（申报' || a.seq || '）',
       CASE WHEN a.seq <= 3 THEN 'national' ELSE 'provincial' END,
       'applying', NULL, NULL, NULL, NULL,
       (SELECT d.id FROM dim.department d
         WHERE d.code = (ARRAY['XNK','GK','HXWZK','PWK','ZLK','JYK'])[a.seq]),
       0, NULL
  FROM generate_series(1, 6) AS a(seq)
ON CONFLICT (project_code) DO NOTHING;
-- rows: 294（spec 288 + 申报中 6）；锚点: ongoing=186 / 2026新立42 / 2025新立36(+6项) /
--       年立项经费 2020~2026=500/800/1200/1680/2240/2940/3480 万元（库内元）

-- ============================================================================
-- [A1] dws.research_paper_period —— 论文分区年度汇总（契约 §8.1 paper_distribution）
--   锚点 2026：q1..q4=14/28/36/20（SCI=98）、cn_core=68（中文核心）；
--   学科归口 SCI 篇数对回 L5 SCI_PAPER_CNT 科室行：CARDIO 22/ORTHO 16/RESP 14，
--   中文核心全院挂哨兵 0；2024/2025 按 PAPER_CNT 年序列(140/155)配平。
-- ============================================================================
INSERT INTO dws.research_paper_period (period_type, period_start, quartile, discipline_id, paper_cnt) VALUES
  -- 2026（SCI=98 / 中文核心=68 / 合计=166）
  ('year', date '2026-01-01', 'q1', 1, 5), ('year', date '2026-01-01', 'q1', 2, 3),
  ('year', date '2026-01-01', 'q1', 3, 2), ('year', date '2026-01-01', 'q1', 0, 4),
  ('year', date '2026-01-01', 'q2', 1, 7), ('year', date '2026-01-01', 'q2', 2, 4),
  ('year', date '2026-01-01', 'q2', 3, 4), ('year', date '2026-01-01', 'q2', 0, 13),
  ('year', date '2026-01-01', 'q3', 1, 6), ('year', date '2026-01-01', 'q3', 2, 6),
  ('year', date '2026-01-01', 'q3', 3, 5), ('year', date '2026-01-01', 'q3', 0, 19),
  ('year', date '2026-01-01', 'q4', 1, 4), ('year', date '2026-01-01', 'q4', 2, 3),
  ('year', date '2026-01-01', 'q4', 3, 3), ('year', date '2026-01-01', 'q4', 0, 10),
  ('year', date '2026-01-01', 'cn_core', 0, 68),
  -- 2025（SCI=91 / 中文核心=64 / 合计=155）
  ('year', date '2025-01-01', 'q1', 1, 4), ('year', date '2025-01-01', 'q1', 2, 2),
  ('year', date '2025-01-01', 'q1', 3, 2), ('year', date '2025-01-01', 'q1', 0, 4),
  ('year', date '2025-01-01', 'q2', 1, 6), ('year', date '2025-01-01', 'q2', 2, 4),
  ('year', date '2025-01-01', 'q2', 3, 3), ('year', date '2025-01-01', 'q2', 0, 12),
  ('year', date '2025-01-01', 'q3', 1, 6), ('year', date '2025-01-01', 'q3', 2, 4),
  ('year', date '2025-01-01', 'q3', 3, 4), ('year', date '2025-01-01', 'q3', 0, 18),
  ('year', date '2025-01-01', 'q4', 1, 3), ('year', date '2025-01-01', 'q4', 2, 3),
  ('year', date '2025-01-01', 'q4', 3, 2), ('year', date '2025-01-01', 'q4', 0, 14),
  ('year', date '2025-01-01', 'cn_core', 0, 64),
  -- 2024（SCI=84 / 中文核心=56 / 合计=140）
  ('year', date '2024-01-01', 'q1', 1, 3), ('year', date '2024-01-01', 'q1', 2, 2),
  ('year', date '2024-01-01', 'q1', 3, 2), ('year', date '2024-01-01', 'q1', 0, 3),
  ('year', date '2024-01-01', 'q2', 1, 5), ('year', date '2024-01-01', 'q2', 2, 3),
  ('year', date '2024-01-01', 'q2', 3, 2), ('year', date '2024-01-01', 'q2', 0, 12),
  ('year', date '2024-01-01', 'q3', 1, 5), ('year', date '2024-01-01', 'q3', 2, 3),
  ('year', date '2024-01-01', 'q3', 3, 3), ('year', date '2024-01-01', 'q3', 0, 19),
  ('year', date '2024-01-01', 'q4', 1, 3), ('year', date '2024-01-01', 'q4', 2, 2),
  ('year', date '2024-01-01', 'q4', 3, 2), ('year', date '2024-01-01', 'q4', 0, 15),
  ('year', date '2024-01-01', 'cn_core', 0, 56)
ON CONFLICT (period_type, period_start, quartile, discipline_id) DO NOTHING;
-- rows: 51（每年 17 行 = q1..q4 × 4学科归口 + cn_core×1）；注: disciplines.papers 列=单学科 Σq1..q4

-- ============================================================================
-- [A2] dws.metric_value —— L8a HR 指标行（跨 lane 追加，登记于 README 供出节）
--   院级 dept_id=0、月粒度 date=月首日；BASE_DATE=2026-10-28 → "本月"=2026-10，
--   2026-10 锚点行与 dim.staff/hr_cost_month 实算一致，更早月份为确定性回填
--   序列（dim.staff 无历史维度，extra 标 backcast）。
--   科研/TRAINING 指标行已由 L5 播种（manual_seed），本 lane 不重写。
-- ============================================================================
INSERT INTO dws.metric_value (metric_code, dept_id, group_id, date, value, extra)
SELECT m.code, 0, 0, s.period_start, m.value::numeric(18,4), m.extra
FROM (VALUES
  (date '2025-01-01', 2272, 752,  968, 0.1120, 0.3080),
  (date '2025-02-01', 2282, 758,  974, 0.1125, 0.3100),
  (date '2025-03-01', 2292, 764,  981, 0.1130, 0.3110),
  (date '2025-04-01', 2300, 770,  988, 0.1135, 0.3120),
  (date '2025-05-01', 2308, 775,  994, 0.1140, 0.3130),
  (date '2025-06-01', 2316, 780, 1000, 0.1146, 0.3140),
  (date '2025-07-01', 2323, 784, 1006, 0.1152, 0.3150),
  (date '2025-08-01', 2330, 788, 1011, 0.1158, 0.3160),
  (date '2025-09-01', 2336, 791, 1016, 0.1164, 0.3170),
  (date '2025-10-01', 2342, 794, 1020, 0.1170, 0.3180),
  (date '2025-11-01', 2348, 796, 1023, 0.1176, 0.3190),
  (date '2025-12-01', 2353, 798, 1026, 0.1182, 0.3200),
  (date '2026-01-01', 2356, 800, 1029, 0.1184, 0.3200),
  (date '2026-02-01', 2358, 802, 1031, 0.1186, 0.3208),
  (date '2026-03-01', 2360, 804, 1033, 0.1188, 0.3212),
  (date '2026-04-01', 2361, 805, 1035, 0.1190, 0.3218),
  (date '2026-05-01', 2363, 807, 1036, 0.1192, 0.3220),
  (date '2026-06-01', 2364, 808, 1036, 0.1194, 0.3226),
  (date '2026-07-01', 2363, 804, 1033, 0.1196, 0.3230),
  (date '2026-08-01', 2360, 801, 1030, 0.1194, 0.3218),
  (date '2026-09-01', 2359, 798, 1023, 0.1192, 0.3215),
  (date '2026-10-01', 2368, 812, 1046, 0.1199, 0.3250),
  (date '2026-11-01', 2370, 814, 1050, 0.1200, 0.3258),
  (date '2026-12-01', 2372, 816, 1054, 0.1202, 0.3266)
) AS s(period_start, staff_cnt, doc_cnt, nur_cnt, senior_r, cost_r)
CROSS JOIN LATERAL (VALUES
  ('STAFF_CNT',         s.staff_cnt::numeric, '{"source":"dim.staff","note":"2026-10 起与主档实算一致；更早月份为确定性回填（staff 无历史维度）"}'::jsonb),
  ('DOCTOR_CNT',        s.doc_cnt::numeric,   '{"source":"dim.staff","note":"同上回填口径"}'::jsonb),
  ('NURSE_CNT',         s.nur_cnt::numeric,   '{"source":"dim.staff","note":"同上回填口径"}'::jsonb),
  ('DOC_NURSE_RATIO',   ROUND(s.nur_cnt::numeric / s.doc_cnt, 4), '{"source":"dim.staff","note":"护/医比值；出参串 ''1 : 1.29'' 由 API 拼装"}'::jsonb),
  ('SENIOR_TITLE_RATIO', s.senior_r::numeric, '{"source":"dim.staff","note":"2026-10=284/2368 实算；契约标题 18.2% 矛盾见 open-items/L2 O13"}'::jsonb),
  ('STAFF_COST_RATIO',   s.cost_r::numeric,   '{"source":"dwd.hr_cost_month","note":"分母=dws 业务支出(L5)；2026-10 锚 0.325（Σ本月/141.78M）"}'::jsonb)
) AS m(code, value, extra)
ON CONFLICT (metric_code, dept_id, group_id, date) DO NOTHING;
-- rows: 6 指标 × 24 月 = 144；锚点 2026-10: 2368/812/1046/1.2882/0.1199/0.3250

-- ============================================================================
-- [V] 校验段（sim validate 建议断言；交付前本 lane 已本地跑过，见 README §5）
-- ============================================================================
-- SELECT SUM(staff_cost_amt) FROM dwd.hr_cost_month WHERE period_start='2026-10-01';                                   -- 应=46,078,500（=32.5%×141,780,000 支出）
-- SELECT count(*) FROM dwd.research_project WHERE project_status='ongoing';                                             -- 应=186
-- SELECT project_level, count(*) FROM dwd.research_project WHERE apply_year=2026 GROUP BY project_level;               -- national12/provincial30
-- SELECT count(*) FROM dwd.research_project WHERE apply_year=2025;                                                     -- 应=36（delta +6 分母）
-- SELECT apply_year, SUM(funds_amt) FROM dwd.research_project GROUP BY apply_year ORDER BY apply_year;                 -- 5/8/12/16.8/22.4/29.4/34.8 M
-- SELECT quartile, SUM(paper_cnt) FROM dws.research_paper_period WHERE period_start='2026-01-01' GROUP BY quartile;    -- q1..q4/cn=14/28/36/20/68
-- SELECT discipline_id, count(*) FROM dwd.research_project WHERE project_status='ongoing' GROUP BY discipline_id;       -- 1:28/2:22/3:18/0:118
