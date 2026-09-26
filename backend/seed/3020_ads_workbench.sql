-- ============================================================================
-- lane: L6 ads-workbench  种子（确定性 / 幂等 / 锚点量级）
-- 锚点：BASE_DATE='2026-10-28'（规模裁决书 v2 §0，取代 2026-09-26）；本文件无伪随机、无当前时间函数调用
-- 幂等：全部 INSERT ... ON CONFLICT (...) DO NOTHING
-- 执行序（plan §3 段序"汇总/快照"段）：必须在 L1(1001_dict+1002_metric_def 含 L8
--        供稿行) + L2(dim.department) + L5(dws.dept_oper_day/drg_dept_period) 之后。
--        0405 为 INSERT…SELECT 派生表达式，不手抄数值（plan §3 种子纪律）。
-- 拆段落仓建议：seed/4305_benchmark_peer.sql / 4306_exam_indicator.sql /
--              4405_dept_rank_day.sql / 4406_work_item.sql / 4407_radar_score.sql
-- ============================================================================

-- ============================================================================
-- §0305  dws.benchmark_peer —— compare benchmarks 6 行（审计 M7 修复轮）
-- ours_val 派生自 dws（不再直写契约字面）；region_avg/bench_val 库外数据保留契约原值
-- ============================================================================
WITH fy AS (    -- 院级宽表【全年】累计/加权（year=2026 → 2026 自然年全窗；裁决书 §6.5：
                -- compare 年口径=全年 Σ≈108,900，非 YTD 84,700；hospital_oper_day 已播至 12-31）
  SELECT SUM(outpt_cnt + emerg_cnt)                                AS op_visit_cnt,
         SUM(discharge_cnt)                                        AS disch_cnt,
         SUM(alos * discharge_cnt) / NULLIF(SUM(discharge_cnt), 0) AS alos,
         SUM(drug_fee) / NULLIF(SUM(revenue), 0)                   AS drug_ratio,
         SUM(cmi * discharge_cnt) / NULLIF(SUM(discharge_cnt), 0)  AS cmi
  FROM dws.hospital_oper_day
  WHERE campus_code = 'main'
    AND date BETWEEN DATE '2026-01-01' AND DATE '2026-12-31'
),
l34 AS (        -- 三四级占比年值：metric_value 月行(dept0) × 当月手术台次加权（全年）
  SELECT SUM(mv.value * s.surg_cnt) / NULLIF(SUM(s.surg_cnt), 0) AS ratio
  FROM dws.metric_value mv
  JOIN (SELECT date_trunc('month', date)::date AS m, SUM(surg_cnt) AS surg_cnt
        FROM dws.hospital_oper_day
        WHERE campus_code = 'main' AND date BETWEEN DATE '2026-01-01' AND DATE '2026-12-31'
        GROUP BY 1) s ON s.m = mv.date
  WHERE mv.metric_code = 'SURG_L34_RATIO' AND mv.dept_id = 0 AND mv.group_id = 0
)
INSERT INTO dws.benchmark_peer
  (period_type, period_start, metric_code, name, ours_val, region_avg, bench_val)
SELECT 'year', DATE '2026-01-01', b.metric_code, b.name,
       ROUND(b.ours_val, 4), b.region_avg, b.bench_val
FROM (
  SELECT 'OP_VISIT_CNT'   AS metric_code, '年门急诊量（万人次）' AS name,
         (SELECT op_visit_cnt FROM fy) AS ours_val, 900000 AS region_avg, 1280000 AS bench_val
  UNION ALL
  SELECT 'DISCH_CNT',      '年出院人数（万人）',
         (SELECT disch_cnt FROM fy), 82200, 115800
  UNION ALL
  SELECT 'ALOS',           '平均住院日（天）',
         (SELECT alos FROM fy), 7.9, 6.2
  UNION ALL
  SELECT 'SURG_L34_RATIO', '三四级手术占比（%）',
         (SELECT ratio FROM l34), 0.482, 0.650
  UNION ALL
  SELECT 'DRUG_RATIO',     '药占比（%）',
         (SELECT drug_ratio FROM fy), 0.316, 0.250
  UNION ALL
  SELECT 'CMI',            'CMI 值',
         (SELECT cmi FROM fy), 0.96, 1.22
) b
WHERE b.ours_val IS NOT NULL          -- 上游断供时降级为空集而非报错（O9 期间允许部分行）
ON CONFLICT (period_type, period_start, metric_code) DO NOTHING;
-- rows: ≤6（派生行）/ 锚点(v2.2 E9 + R3-M4 校正值): ours=全年实算（门急诊×10→108.8万、
--       出院→8.64万量级——契约 109.0/9.73 为裁决书旧错值，将按派生口径更正）；
--       region/bench 契约字面：门急诊 90.0/128.0 万、出院 8.22/11.58 万（其余三行契约未改）
--       gap 复算：+18.8万 / +0.42万 / −1.1天 / +10.4pct / −3.2pct / +0.12 对齐契约（M4 修正后）

-- ============================================================================
-- §0306  dws.exam_indicator —— 国考集市（契约 §13.1 topic=exam）
--   年度行：TOTAL_SCORE(786=0.7860×1000) + DIM_* 四维得分率 + 重点指标 6 行
--   月度行：TARGET_RATE 近 6 月序列 [74.2→82.4]（契约 chart.values）
-- ============================================================================
INSERT INTO dws.exam_indicator
  (period_type, period_start, code, name, full_score, score_rate, direction, owner_dept_id, metric_code)
VALUES
  -- 聚合行（owner=NULL 多部门共担；code 为保留行标识）
  ('year', DATE '2026-01-01', 'TOTAL_SCORE',      '国考预估得分',           1000, 0.7860, 1, NULL, 'EXAM_SCORE'),
  ('year', DATE '2026-01-01', 'DIM_QUALITY',      '医疗质量得分率',         NULL, 0.8620, 1, NULL, 'EXAM_DIM_SCORE_RATE'),
  ('year', DATE '2026-01-01', 'DIM_EFFICIENCY',   '运营效率得分率',         NULL, 0.7860, 1, NULL, 'EXAM_DIM_SCORE_RATE'),
  ('year', DATE '2026-01-01', 'DIM_GROWTH',       '持续发展得分率',         NULL, 0.7480, 1, NULL, 'EXAM_DIM_SCORE_RATE'),
  ('year', DATE '2026-01-01', 'DIM_SATISFACTION', '满意度得分率',           NULL, 0.9120, 1, NULL, 'EXAM_DIM_SCORE_RATE'),
  -- 重点指标行（契约 table 六行原值：full=分值、score_rate=得分率 0~1、direction=趋势）
  -- owner 映射：医务部=34 / 财务部=39 / 人力资源部=40 / 后勤保障部=41 / 护理部=35
  ('year', DATE '2026-01-01', 'SURG_L4_DISCH_RATIO', '出院患者四级手术比例',    40, 0.68, 1, 34, 'SURG_L4_DISCH_RATIO'),
  ('year', DATE '2026-01-01', 'PER_BED_DAY_REV',     '每床日收入（剔除药耗）',  30, 0.72, 1, 39, 'PER_BED_DAY_REV'),
  ('year', DATE '2026-01-01', 'STAFF_COST_RATIO',    '人员支出占业务支出比重',  30, 0.64, 0, 40, 'STAFF_COST_RATIO'),
  ('year', DATE '2026-01-01', 'ENERGY_PER_WAN_REV',  '万元收入能耗支出',        20, 0.76, 1, 41, 'ENERGY_PER_WAN_REV'),
  ('year', DATE '2026-01-01', 'DOC_NURSE_RATIO',     '医护比',                  20, 0.82, 1, 40, 'DOC_NURSE_RATIO'),
  ('year', DATE '2026-01-01', 'SAT_IP_SCORE',        '住院患者满意度',          20, 0.95, 0, 35, 'SAT_IP_SCORE')
ON CONFLICT (period_type, period_start, code) DO NOTHING;

INSERT INTO dws.exam_indicator
  (period_type, period_start, code, name, full_score, score_rate, direction, owner_dept_id, metric_code)
VALUES
  ('month', DATE '2026-05-01', 'TARGET_RATE', '指标达标率', NULL, 0.742, 1, NULL, 'EXAM_TARGET_RATE'),
  ('month', DATE '2026-06-01', 'TARGET_RATE', '指标达标率', NULL, 0.768, 1, NULL, 'EXAM_TARGET_RATE'),
  ('month', DATE '2026-07-01', 'TARGET_RATE', '指标达标率', NULL, 0.784, 1, NULL, 'EXAM_TARGET_RATE'),
  ('month', DATE '2026-08-01', 'TARGET_RATE', '指标达标率', NULL, 0.796, 1, NULL, 'EXAM_TARGET_RATE'),
  ('month', DATE '2026-09-01', 'TARGET_RATE', '指标达标率', NULL, 0.812, 1, NULL, 'EXAM_TARGET_RATE'),
  ('month', DATE '2026-10-01', 'TARGET_RATE', '指标达标率', NULL, 0.824, 1, NULL, 'EXAM_TARGET_RATE')
ON CONFLICT (period_type, period_start, code) DO NOTHING;

-- 上年(2025)对照行：使 stats delta 可算（审计 N11 修复）
-- delta 锚点回推：总分 786−"+18分"=768；四维 86.2−2.4 / 78.6−4.2 / 74.8−1.8 / 91.2−0.6 (pct)
INSERT INTO dws.exam_indicator
  (period_type, period_start, code, name, full_score, score_rate, direction, owner_dept_id, metric_code)
VALUES
  ('year', DATE '2025-01-01', 'TOTAL_SCORE',      '国考预估得分',   1000, 0.7680, 0, NULL, 'EXAM_SCORE'),
  ('year', DATE '2025-01-01', 'DIM_QUALITY',      '医疗质量得分率',  NULL, 0.8380, 0, NULL, 'EXAM_DIM_SCORE_RATE'),
  ('year', DATE '2025-01-01', 'DIM_EFFICIENCY',   '运营效率得分率',  NULL, 0.7440, 0, NULL, 'EXAM_DIM_SCORE_RATE'),
  ('year', DATE '2025-01-01', 'DIM_GROWTH',       '持续发展得分率',  NULL, 0.7300, 0, NULL, 'EXAM_DIM_SCORE_RATE'),
  ('year', DATE '2025-01-01', 'DIM_SATISFACTION', '满意度得分率',    NULL, 0.9060, 0, NULL, 'EXAM_DIM_SCORE_RATE'),
  -- 达标率上年同月行：82.4 − "+3.6%"(pct) = 78.8，同比 delta 可算
  ('month', DATE '2025-10-01', 'TARGET_RATE', '指标达标率', NULL, 0.7880, 0, NULL, 'EXAM_TARGET_RATE')
ON CONFLICT (period_type, period_start, code) DO NOTHING;
-- rows: 23（年行 2026×11 + 2025×5；月行 2026×6 + 2025-10×1）
-- 锚点: §13.1 stats 786分/82.4%/86.2/78.6/74.8/91.2 + 全六行 delta 字面可复算 + table 6 行 + chart 6 点
-- 依赖提醒：STAFF_COST_RATIO/DOC_NURSE_RATIO(L8a)、ENERGY_PER_WAN_REV(L8e)、SAT_IP_SCORE(L8c)
--           的 metric_def 行由 L8 供稿入 1002；独跑本段而未并入时 FK 失败（open-items O2）。

-- ============================================================================
-- §0405  ads.dept_rank_day —— d30 科室效能快照（派生表达式实算，禁手抄）
-- 源：dws.dept_oper_day（L5 约定列）；参评集=level=2 AND category IN ('med','surg')
-- 公式：§10 v2（审计 R3-MAJOR1 重调权重）——100×(0.25·norm(cmi)+0.02·norm(surg_cnt)
--       +0.01·(1−norm(alos))+0.67·bed_use_rate+0.20·norm(profit))，LEAST 截顶 100；
--       norm=当期参评集 min-max（surg_cnt 强制 ::numeric，bigint 整除会塌缩 n_surg）；
--       profit 取 drg_profit 口径（与本行 profit 展示列同源，见 columns.md / open-items O5）
-- 权重校准锚（实播验证）：骨科 96.10 rank1 / 心内 93.12 rank2 / 心胸 91.09 rank4
--       （契约 §14.1 样例 94.2/92.8，±5% 带内且序一致）；
--       床效 0.67 主导=底分语义（全员床用 0.85~0.99 提供 ~60 基线，cmi/surg/profit 拉开位次）
-- eff_delta：前一 d30 窗（截止 2026-09-28）同式实算取差——首期前值即真值非留空
-- ============================================================================
WITH win(p0, p1) AS (
  VALUES
    (DATE '2026-08-30', DATE '2026-09-28'),  -- prev：前一 30 天窗（仅用于算 eff_delta）
    (DATE '2026-09-29', DATE '2026-10-28')   -- cur ：as_of=BASE_DATE=10-28，对齐 drg_dept_period d30
),
agg AS (
  SELECT w.p0, w.p1, d.id AS dept_id,
         COALESCE(SUM(dd.surg_cnt), 0)::numeric                              AS surg_cnt,  -- ::numeric 防 bigint 整除塌缩 n_surg（R3 修复）
         SUM(dd.drg_profit)                                                  AS profit,
         SUM(dd.cmi * dd.case_cnt) / NULLIF(SUM(dd.case_cnt), 0)              AS cmi,
         SUM(dd.alos * dd.discharge_cnt) / NULLIF(SUM(dd.discharge_cnt), 0)   AS alos,
         AVG(dd.bed_use_rate)                                                AS bed_use_rate
  FROM win w
  JOIN dws.dept_oper_day dd ON dd.date BETWEEN w.p0 AND w.p1
  JOIN dim.department   d  ON d.id = dd.dept_id
                          AND d.level = 2 AND d.category IN ('med','surg')
  GROUP BY w.p0, w.p1, d.id
),
nrm AS (
  SELECT p0, dept_id, cmi, surg_cnt, alos, profit, bed_use_rate,
         (cmi      - MIN(cmi)      OVER w) / NULLIF(MAX(cmi)      OVER w - MIN(cmi)      OVER w, 0) AS n_cmi,
         (surg_cnt - MIN(surg_cnt) OVER w) / NULLIF(MAX(surg_cnt) OVER w - MIN(surg_cnt) OVER w, 0) AS n_surg,
         (alos     - MIN(alos)     OVER w) / NULLIF(MAX(alos)     OVER w - MIN(alos)     OVER w, 0) AS n_alos,
         (profit   - MIN(profit)   OVER w) / NULLIF(MAX(profit)   OVER w - MIN(profit)   OVER w, 0) AS n_profit
  FROM agg
  WINDOW w AS (PARTITION BY p0)
),
score AS (
  SELECT p0, dept_id,
         ROUND(cmi, 4) AS cmi, surg_cnt, ROUND(alos, 2) AS alos, ROUND(profit, 2) AS profit,
         CASE WHEN n_cmi IS NOT NULL AND n_surg IS NOT NULL AND n_alos IS NOT NULL
                   AND n_profit IS NOT NULL AND bed_use_rate IS NOT NULL
              THEN LEAST(ROUND(100 * (0.25 * n_cmi + 0.02 * n_surg + 0.01 * (1 - n_alos)
                                + 0.67 * bed_use_rate + 0.20 * n_profit), 2), 100)
         END AS eff_score
  FROM nrm
)
INSERT INTO ads.dept_rank_day
  (date, period, dept_id, cmi, surg_cnt, alos, profit, eff_score, eff_delta, rank_no)
SELECT DATE '2026-10-28', 'd30', c.dept_id, c.cmi, c.surg_cnt, c.alos, c.profit,
       c.eff_score,
       ROUND(c.eff_score - p.eff_score, 2),
       ROW_NUMBER() OVER (ORDER BY c.eff_score DESC NULLS LAST, c.dept_id)
FROM score c
LEFT JOIN score p
       ON p.dept_id = c.dept_id AND p.p0 = DATE '2026-08-30'
WHERE c.p0 = DATE '2026-09-29'
ON CONFLICT (date, period, dept_id) DO NOTHING;
-- rows: ~20（参评集=有当期 dept_oper_day 行的 level=2 med/surg 科室；含急诊科/重症医学科，
--       与 L5 eff_score 参评口径一致）/ 锚点: §14.1 dept_ranking 供数 + schema §12 校验#4
--       （cmi/alos/surg 与 dept_oper_day d30 窗口聚合天然一致——本表即由其派生）

-- ============================================================================
-- §0406  ads.work_item —— 院级重点工作 5 行（契约 §3.5 原样，2026-10 填报期）
-- ============================================================================
INSERT INTO ads.work_item
  (id, name, progress_pct, workitem_status, owner_dept_id, period_type, period_start, created_at, updated_at)
OVERRIDING SYSTEM VALUE
VALUES
  (1, '三甲复评准备',       75, 'doing',   34, 'month', DATE '2026-10-01',
     TIMESTAMPTZ '2026-03-02 09:00:00+08', TIMESTAMPTZ '2026-10-28 09:00:00+08'),
  (2, 'DRG精细化管理',      60, 'doing',   38, 'month', DATE '2026-10-01',
     TIMESTAMPTZ '2026-04-15 09:00:00+08', TIMESTAMPTZ '2026-10-28 09:00:00+08'),
  (3, '智慧医院建设',       40, 'doing',   42, 'month', DATE '2026-10-01',
     TIMESTAMPTZ '2026-05-20 09:00:00+08', TIMESTAMPTZ '2026-10-28 09:00:00+08'),
  (4, '学科建设提升计划',   90, 'doing',   34, 'month', DATE '2026-10-01',
     TIMESTAMPTZ '2026-02-10 09:00:00+08', TIMESTAMPTZ '2026-10-28 09:00:00+08'),
  (5, 'DIP支付方式改革',    30, 'pending', 38, 'month', DATE '2026-10-01',
     TIMESTAMPTZ '2026-08-01 09:00:00+08', TIMESTAMPTZ '2026-10-28 09:00:00+08')
ON CONFLICT DO NOTHING;   -- pg-standards 边角1：裸 DO NOTHING 同时兜 id 与 (name,period) UQ 冲突
-- rows: 5 / 锚点: §3.5 契约原值（id/name/progress 逐字）+ owner 补录（契约未下发字段）
--       status 键映射：进行中→doing、待启动→pending

-- ============================================================================
-- §0407  ads.radar_score —— 六维能力双序列（契约 §12.1 radar 锚点）
-- ============================================================================
INSERT INTO ads.radar_score (period_type, period_start, radar_dim, ours_score, region_score)
VALUES
  ('month', DATE '2026-10-01', 'scale',        86, 72),
  ('month', DATE '2026-10-01', 'revenue',      82, 70),
  ('month', DATE '2026-10-01', 'efficiency',   78, 68),
  ('month', DATE '2026-10-01', 'quality',      88, 76),
  ('month', DATE '2026-10-01', 'satisfaction', 90, 78),
  ('month', DATE '2026-10-01', 'research',     74, 58)
ON CONFLICT (period_type, period_start, radar_dim) DO NOTHING;
-- rows: 6 / 锚点: §12.1 radar.series 本院 [86,82,78,88,90,74] vs 区域 [72,70,68,76,78,58]
--       （radar_dim 序与 dict sort 对齐；合成口径未定 version=0 手工值，公约 U5）

-- ============================================================================
-- §V  自洽校验（SELECT 断言式查询；全部应返回 pass/期望计数）
-- ============================================================================

-- V1. dept_rank_day 结构自查：行数=参评科室数、rank_no 唯一递增、eff_score 界内
SELECT 'V1_rank_shape' AS check_name,
       COUNT(*)                                            AS rows,
       COUNT(eff_score)                                    AS scored_rows,
       COUNT(DISTINCT rank_no) = COUNT(*)                  AS rank_unique,
       bool_and(eff_score IS NULL OR (eff_score BETWEEN 0 AND 100)) AS score_in_range
FROM ads.dept_rank_day
WHERE date = DATE '2026-10-28' AND period = 'd30';

-- V2. schema §12 校验#4：ranking 窗口聚合与 dept_oper_day 重算一致（±0，本表即派生自它）
SELECT 'V2_rank_vs_dws' AS check_name,
       bool_and(ABS(r.surg_cnt - x.surg_cnt_re) <= 0
                AND ABS(r.profit - x.profit_re) < 1) AS pass
FROM ads.dept_rank_day r
JOIN (
  SELECT dept_id, SUM(surg_cnt) AS surg_cnt_re, SUM(drg_profit) AS profit_re
  FROM dws.dept_oper_day
  WHERE date BETWEEN DATE '2026-09-29' AND DATE '2026-10-28'
    AND dept_id IN (SELECT id FROM dim.department WHERE level = 2 AND category IN ('med','surg'))
  GROUP BY dept_id
) x ON x.dept_id = r.dept_id
WHERE r.date = DATE '2026-10-28' AND r.period = 'd30';

-- V3. 锚点复核：契约原值是否落库（spot check）
SELECT 'V3_anchors' AS check_name,
       (SELECT bool_and(ours_val IS NOT NULL) FROM dws.benchmark_peer)          AS bench_6rows,
       (SELECT score_rate * full_score FROM dws.exam_indicator
         WHERE period_type='year' AND period_start='2026-01-01' AND code='TOTAL_SCORE') AS exam_score_786,  -- 期望 786.00
       (SELECT score_rate FROM dws.exam_indicator
         WHERE period_type='month' AND period_start='2026-10-01' AND code='TARGET_RATE') AS target_oct,     -- 期望 0.824
       (SELECT ours_score FROM ads.radar_score
         WHERE period_start='2026-10-01' AND radar_dim='research')              AS radar_research;        -- 期望 74

-- V4. exam_indicator 行域自查：6 重点指标行 + 10 聚合年行(2026×5+2025×5) + 7 达标率月行(2026-05~10×6+2025-10) = 23
SELECT 'V4_exam_rows' AS check_name,
       COUNT(*) FILTER (WHERE period_type='year'  AND metric_code NOT IN ('EXAM_SCORE','EXAM_DIM_SCORE_RATE')) AS indicator_rows,  -- 期望 6
       COUNT(*) FILTER (WHERE period_type='year'  AND metric_code     IN ('EXAM_SCORE','EXAM_DIM_SCORE_RATE')) AS agg_rows,        -- 期望 10
       COUNT(*) FILTER (WHERE period_type='month')                                                       AS month_rows           -- 期望 7
FROM dws.exam_indicator;

-- V5. exam delta 可算性自查（N11）：当前年 vs 上年 各 delta 应复现契约字面
SELECT 'V5_exam_delta' AS check_name,
       ROUND((c.score_rate - p.score_rate) * c.full_score, 0)       AS score_delta,   -- 期望 18
       ROUND((q.score_rate - r.score_rate) * 100, 1)                AS target_delta   -- 期望 3.6
FROM dws.exam_indicator c
JOIN dws.exam_indicator p ON p.code = c.code AND p.period_type = 'year' AND p.period_start = '2025-01-01'
CROSS JOIN dws.exam_indicator q
CROSS JOIN dws.exam_indicator r
WHERE c.period_type = 'year' AND c.period_start = '2026-01-01' AND c.code = 'TOTAL_SCORE'
  AND q.code = 'TARGET_RATE' AND q.period_type = 'month' AND q.period_start = '2026-10-01'
  AND r.code = 'TARGET_RATE' AND r.period_type = 'month' AND r.period_start = '2025-10-01';
