-- ============================================================================
-- L5 dws-agg — seed.sql（汇总层种子，对象序号 0301~0304）
-- ----------------------------------------------------------------------------
-- 执行前提：L1(sys.metric_def/dict)、L2(dim.*/含 department id=0 哨兵)、
--           L3(dwd.outpatient_hourly/reg_channel_day/inpatient_move/bed_state_day/
--              emergency_stay/charge_day/insurance_settle_day)、
--           L4(dwd.surgery_case/drg_case)、L8d(dwd.critical_value) 已播种。
-- 锚点：BASE_DATE = DATE '2026-10-28'（周三，scale-decision §0）；种子窗 2025-01-01 ~ 2026-12-31（dim.date 驱动）。
-- 确定性：禁 random()/now()；扰动一律 (('x'||substr(md5(<key>),1,8))::bit(32)::bigint % n)
--        伪随机哈希（公约 §5.6）；本文件不依赖 setseed。
-- 幂等：全部 INSERT ... ON CONFLICT DO NOTHING，重跑安全。
-- 上游列形态：按 plan.md §3 序号表 + database-schema v1.1 + 公约改造点直接引用（不等 L3/L4 落盘）。
-- ============================================================================

-- ============================================================================
-- §3001  dws.hospital_oper_day —— 院级日汇总（730 行 = 全窗 365+365 × campus 'main'）
-- 出参：home/kpis、trends、indicators；overview stats/trend；screen 7 日趋势
-- ============================================================================
WITH op AS (                                   -- dwd.outpatient_hourly(stat_time,visit_cnt,reg_cnt,emerg_flag)
  SELECT stat_time::date AS date,
         SUM(visit_cnt) FILTER (WHERE NOT emerg_flag) AS outpt_cnt,
         SUM(visit_cnt) FILTER (WHERE emerg_flag)     AS emerg_cnt,
         SUM(reg_cnt)                                 AS reg_cnt
  FROM dwd.outpatient_hourly GROUP BY 1
),
mv AS (                                        -- dwd.inpatient_move(event,event_time,los_days)
  SELECT event_time::date AS date,
         COUNT(*) FILTER (WHERE event='admit')                       AS admit_cnt,
         COUNT(*) FILTER (WHERE event='discharge')                   AS discharge_cnt,
         SUM(los_days) FILTER (WHERE event='discharge')              AS los_sum,
         COUNT(*) FILTER (WHERE event='discharge' AND los_days > 30) AS longstay_cnt
  FROM dwd.inpatient_move GROUP BY 1
),
bed AS (                                       -- dwd.bed_state_day(date,bed_open,bed_used)
  SELECT date, SUM(bed_open) AS bed_open, SUM(bed_used) AS bed_used
  FROM dwd.bed_state_day GROUP BY 1
),
sg AS (                                        -- dwd.surgery_case(date,surg_status,surg_level)
  SELECT date,
         COUNT(*) FILTER (WHERE surg_status <> 'sched')                    AS surg_cnt,
         COUNT(*) FILTER (WHERE surg_status <> 'sched' AND surg_level = 4) AS surg_l4_cnt
  FROM dwd.surgery_case GROUP BY 1
),
cal AS (                                       -- 收入锚定系数 k：锚月(2026-10)契约锚 14,800万 ÷ 上游实算（审计 A04 修法）
  SELECT 148000000.0 / NULLIF(SUM(out_fee + in_fee), 0) AS k         -- k=契约锚÷上游实算；上游修锚后 k→1 自动失效
  FROM dwd.charge_day WHERE date BETWEEN DATE '2026-10-01' AND DATE '2026-10-31'
),
cf AS (                                        -- 科室成本系数 [0.9307,0.9997]（哈希，随 dept_id 分布漂移）
  SELECT dept_id,
         0.9307 + (('x' || substr(md5(dept_id::text), 1, 8))::bit(32)::bigint % 70) / 1000.0 AS f
  FROM (SELECT DISTINCT dept_id FROM dwd.charge_day) d
),
cn AS (                                        -- B3/A42：系数按 charge 收入加权自归一 → 成本率钉 0.958、结余率 4.2% 与科室编号无关
  SELECT sum(x.r * cf.f) / sum(x.r) AS mf
  FROM (SELECT dept_id, sum(out_fee + in_fee) AS r FROM dwd.charge_day GROUP BY dept_id) x
  JOIN cf ON cf.dept_id = x.dept_id
),
chg AS (                                       -- dwd.charge_day(date,dept_id,fee_cat,out_fee,in_fee,insurance_fee,self_fee)
  SELECT c.date,
         SUM(c.out_fee + c.in_fee) * cal.k                               AS revenue,
         -- 演示期成本合成：无全院成本事实表，按"科室成本系数"归集（与 dept_oper_day 同式 → Σ科室=院级恒等）
         -- f/mf×0.958：归一后加权成本率恒 95.8% → Oct 结余率=4.2%（结余≈622万，open-items #3 待真实成本源）
         SUM((c.out_fee + c.in_fee) * cf.f / cn.mf * 0.9580) * cal.k     AS cost,
         SUM(c.out_fee + c.in_fee) FILTER (WHERE c.fee_cat = 'drug')     * cal.k AS drug_fee,
         SUM(c.out_fee + c.in_fee) FILTER (WHERE c.fee_cat = 'material') * cal.k AS material_fee,
         SUM(c.insurance_fee) * cal.k                                    AS insurance_settle,
         SUM(c.self_fee)      * cal.k                                    AS self_fee
  FROM dwd.charge_day c JOIN cf ON cf.dept_id = c.dept_id
  CROSS JOIN cn CROSS JOIN cal
  GROUP BY c.date, cal.k
),
drg AS (                                       -- dwd.drg_case(discharge_date,profit,rw,drg_code,surg_date,admit_date)
  SELECT discharge_date AS date,
         SUM(profit)                                                  AS drg_profit,
         SUM(rw) FILTER (WHERE drg_code IS NOT NULL)                  AS rw_sum,
         COUNT(*) FILTER (WHERE drg_code IS NOT NULL)                 AS grouped_cnt,
         AVG(surg_date - admit_date) FILTER (WHERE surg_date IS NOT NULL) AS preop_alos
  FROM dwd.drg_case GROUP BY 1
),
obs AS (                                       -- dwd.emergency_stay(arrive_at,stay_minutes,obs_status)
  -- 在观未结行 stay_minutes=NULL：按 obs_status='observing' 且到诊已过 6h 计入（审计 B2-obs 口径修复）
  -- 切面 = 上游演示态 now = BASE_DATE 09:00（dwd-flow §0205：在观36 中 3 例超时 560/465/370min）
  SELECT arrive_at::date AS date,
         COUNT(*) FILTER (
           WHERE stay_minutes > 360
              OR (obs_status = 'observing' AND arrive_at <= TIMESTAMPTZ '2026-10-28 09:00:00+08' - INTERVAL '6 hours')
         ) AS over6h
  FROM dwd.emergency_stay GROUP BY 1
),
cvt AS (                                       -- dwd.critical_value(report_at,close_at)
  SELECT report_at::date AS date,
         COUNT(*) FILTER (WHERE close_at IS NULL) AS unclosed
  FROM dwd.critical_value GROUP BY 1
)
INSERT INTO dws.hospital_oper_day (
  date, campus_code, outpt_cnt, emerg_cnt, reg_cnt, in_hosp_cnt, admit_cnt, discharge_cnt,
  surg_cnt, surg_l4_cnt, bed_open, bed_used, bed_use_rate, alos, preop_alos, longstay_cnt,
  revenue, cost, profit, drg_profit, drug_fee, drug_ratio, material_fee, material_per_100rev,
  insurance_settle, self_pay_ratio, cmi, emerg_obs_over6h, critical_unclosed, satisfaction, updated_at
)
SELECT
  dd.date, 'main',
  COALESCE(op.outpt_cnt, 0), COALESCE(op.emerg_cnt, 0), COALESCE(op.reg_cnt, 0),
  COALESCE(bed.bed_used, 0),
  COALESCE(mv.admit_cnt, 0), COALESCE(mv.discharge_cnt, 0),
  COALESCE(sg.surg_cnt, 0), COALESCE(sg.surg_l4_cnt, 0),
  COALESCE(bed.bed_open, 0), COALESCE(bed.bed_used, 0),
  COALESCE(ROUND(bed.bed_used::numeric / NULLIF(bed.bed_open, 0), 4), 0),
  ROUND(mv.los_sum::numeric / NULLIF(mv.discharge_cnt, 0), 2),
  ROUND(drg.preop_alos::numeric, 2),
  COALESCE(mv.longstay_cnt, 0),
  COALESCE(chg.revenue, 0),
  ROUND(COALESCE(chg.cost, 0), 2),
  ROUND(COALESCE(chg.revenue, 0) - COALESCE(chg.cost, 0), 2),
  COALESCE(drg.drg_profit, 0),
  COALESCE(chg.drug_fee, 0),
  COALESCE(ROUND(chg.drug_fee / NULLIF(chg.revenue, 0), 4), 0),
  COALESCE(chg.material_fee, 0),
  -- 百元耗材·口径B（剔药）：mat / (rev − drug) × 100；锚点 12.6 与耗占比 17.9% 的冲突见 open-items #2
  COALESCE(ROUND(chg.material_fee / NULLIF(chg.revenue - chg.drug_fee, 0) * 100, 2), 0),
  COALESCE(chg.insurance_settle, 0),
  COALESCE(ROUND(chg.self_fee / NULLIF(chg.insurance_settle + chg.self_fee, 0), 4), 0),
  ROUND(drg.rw_sum / NULLIF(drg.grouped_cnt, 0), 4),
  COALESCE(obs.over6h, 0),
  COALESCE(cvt.unclosed, 0),
  -- 综合满意度：采集型手工值，仿真常量带噪 96.8±0.5（锚点 §9.1 门诊96.4/住院97.2 综合位）
  ROUND(96.8 + (((('x' || substr(md5(dd.date::text), 1, 8))::bit(32)::bigint) % 101) - 50) / 100.0, 2),
  TIMESTAMPTZ '2026-10-28 09:00:00+08'         -- 写时刻=演示切面 now（BASE_DATE 09:00，与上游 emergency_stay 同切面）
FROM dim.date dd
LEFT JOIN op  ON op.date  = dd.date
LEFT JOIN mv  ON mv.date  = dd.date
LEFT JOIN bed ON bed.date = dd.date
LEFT JOIN sg  ON sg.date  = dd.date
LEFT JOIN chg ON chg.date = dd.date
LEFT JOIN drg ON drg.date = dd.date
LEFT JOIN obs ON obs.date = dd.date
LEFT JOIN cvt ON cvt.date = dd.date
WHERE dd.date BETWEEN DATE '2025-01-01' AND DATE '2026-12-31'
ON CONFLICT (date, campus_code) DO NOTHING;
-- rows: 730 / 锚点: 使用率≈0.921、ALOS≈6.8、药占比≈0.284、在院≈1,846、月出院≈8,120、月收≈14,800万(元级 148,000,000)


-- ============================================================================
-- §3002a  dws.dept_oper_day —— level=2 科室日汇总（有事实才出行）
-- ============================================================================
WITH op AS (
  SELECT stat_time::date AS date, dept_id, SUM(visit_cnt) AS outpt_cnt
  FROM dwd.outpatient_hourly GROUP BY 1, 2
),
mv AS (
  SELECT event_time::date AS date, dept_id,
         COUNT(*) FILTER (WHERE event='admit')          AS admit_cnt,
         COUNT(*) FILTER (WHERE event='discharge')      AS discharge_cnt,
         SUM(los_days) FILTER (WHERE event='discharge') AS los_sum
  FROM dwd.inpatient_move GROUP BY 1, 2
),
bed AS (
  SELECT date, dept_id, SUM(bed_open) AS bed_open, SUM(bed_used) AS bed_used
  FROM dwd.bed_state_day GROUP BY 1, 2
),
sg AS (
  SELECT date, dept_id,
         COUNT(*) FILTER (WHERE surg_status <> 'sched')                    AS surg_cnt,
         COUNT(*) FILTER (WHERE surg_status <> 'sched' AND surg_level = 4) AS surg_l4_cnt
  FROM dwd.surgery_case GROUP BY 1, 2
),
cal AS (   -- 与 §3001 同一锚定系数（全局同乘 → Σ科室=院级恒等，G4 勾稽不破）
  SELECT 148000000.0 / NULLIF(SUM(out_fee + in_fee), 0) AS k
  FROM dwd.charge_day WHERE date BETWEEN DATE '2026-10-01' AND DATE '2026-10-31'
),
cf AS (    -- 与 §3001 同一科室成本系数 + 收入加权自归一（B3/A42）
  SELECT dept_id,
         0.9307 + (('x' || substr(md5(dept_id::text), 1, 8))::bit(32)::bigint % 70) / 1000.0 AS f
  FROM (SELECT DISTINCT dept_id FROM dwd.charge_day) d
),
cn AS (
  SELECT sum(x.r * cf.f) / sum(x.r) AS mf
  FROM (SELECT dept_id, sum(out_fee + in_fee) AS r FROM dwd.charge_day GROUP BY dept_id) x
  JOIN cf ON cf.dept_id = x.dept_id
),
chg AS (
  SELECT c.date, c.dept_id,
         SUM(c.out_fee + c.in_fee) * cal.k AS revenue,
         SUM((c.out_fee + c.in_fee) * cf.f / cn.mf * 0.9580) * cal.k AS cost,
         SUM(c.out_fee + c.in_fee) FILTER (WHERE c.fee_cat = 'drug')     * cal.k AS drug_fee,
         SUM(c.out_fee + c.in_fee) FILTER (WHERE c.fee_cat = 'material') * cal.k AS material_fee
  FROM dwd.charge_day c JOIN cf ON cf.dept_id = c.dept_id
  CROSS JOIN cn CROSS JOIN cal
  GROUP BY c.date, c.dept_id, cal.k
),
drg AS (
  SELECT discharge_date AS date, dept_id,
         COUNT(*) FILTER (WHERE drg_code IS NOT NULL) AS case_cnt,
         SUM(rw)  FILTER (WHERE drg_code IS NOT NULL) AS rw_sum,
         SUM(profit)                                  AS drg_profit
  FROM dwd.drg_case GROUP BY 1, 2
),
base AS (
  SELECT date, dept_id, dep.category,
         COALESCE(op.outpt_cnt, 0)       AS outpt_cnt,
         COALESCE(bed.bed_used, 0)       AS in_hosp_cnt,
         COALESCE(mv.admit_cnt, 0)       AS admit_cnt,
         COALESCE(mv.discharge_cnt, 0)   AS discharge_cnt,
         COALESCE(sg.surg_cnt, 0)        AS surg_cnt,
         COALESCE(sg.surg_l4_cnt, 0)     AS surg_l4_cnt,
         ROUND(mv.los_sum::numeric / NULLIF(mv.discharge_cnt, 0), 2) AS alos,
         CASE WHEN bed.bed_open IS NULL THEN NULL
              ELSE ROUND(bed.bed_used::numeric / NULLIF(bed.bed_open, 0), 4) END AS bed_use_rate,
         COALESCE(chg.revenue, 0)        AS revenue,
         ROUND(COALESCE(chg.cost, 0), 2) AS cost,
         ROUND(COALESCE(chg.revenue, 0) - COALESCE(chg.cost, 0), 2) AS profit,
         ROUND(COALESCE(drg.drg_profit, 0), 2) AS drg_profit,
         COALESCE(drg.case_cnt, 0)       AS case_cnt,
         ROUND(drg.rw_sum / NULLIF(drg.case_cnt, 0), 4) AS cmi,
         ROUND(chg.material_fee / NULLIF(chg.revenue - chg.drug_fee, 0) * 100, 2) AS material_per_100rev
  FROM op
  FULL JOIN mv  USING (date, dept_id)
  FULL JOIN bed USING (date, dept_id)
  FULL JOIN sg  USING (date, dept_id)
  FULL JOIN chg USING (date, dept_id)
  FULL JOIN drg USING (date, dept_id)
  JOIN dim.department dep ON dep.id = dept_id AND dep.level = 2
),
normed AS (   -- eff_score 输入归一：仅在 med/surg 科室集内做当日 min-max
  SELECT date, dept_id,
         (cmi - MIN(cmi) OVER w) / NULLIF(MAX(cmi) OVER w - MIN(cmi) OVER w, 0)         AS n_cmi,
         (surg_cnt - MIN(surg_cnt) OVER w) / NULLIF(MAX(surg_cnt) OVER w - MIN(surg_cnt) OVER w, 0) AS n_surg,
         (alos - MIN(alos) OVER w) / NULLIF(MAX(alos) OVER w - MIN(alos) OVER w, 0)     AS n_alos,
         (profit - MIN(profit) OVER w) / NULLIF(MAX(profit) OVER w - MIN(profit) OVER w, 0) AS n_profit
  FROM base WHERE category IN ('med', 'surg')
  WINDOW w AS (PARTITION BY date)
)
INSERT INTO dws.dept_oper_day (
  date, dept_id, outpt_cnt, in_hosp_cnt, admit_cnt, discharge_cnt, surg_cnt, surg_l4_cnt,
  alos, bed_use_rate, revenue, cost, profit, drg_profit, case_cnt, cmi, material_per_100rev, eff_score
)
SELECT
  b.date, b.dept_id, b.outpt_cnt, b.in_hosp_cnt, b.admit_cnt, b.discharge_cnt, b.surg_cnt, b.surg_l4_cnt,
  b.alos, b.bed_use_rate, b.revenue, b.cost, b.profit, b.drg_profit, b.case_cnt, b.cmi, b.material_per_100rev,
  CASE WHEN n.n_cmi IS NOT NULL AND n.n_surg IS NOT NULL AND n.n_alos IS NOT NULL
            AND b.bed_use_rate IS NOT NULL AND n.n_profit IS NOT NULL
       THEN ROUND(100 * (0.30 * n.n_cmi + 0.25 * n.n_surg + 0.20 * (1 - n.n_alos)
                         + 0.15 * b.bed_use_rate + 0.10 * n.n_profit), 2)
  END AS eff_score
FROM base b
LEFT JOIN normed n ON n.date = b.date AND n.dept_id = b.dept_id
ON CONFLICT (date, dept_id) DO NOTHING;


-- ============================================================================
-- §3002b  dws.dept_oper_day —— level=3 医疗组行（仅 drg_case 可得列有值，余 NULL）
-- ============================================================================
INSERT INTO dws.dept_oper_day (
  date, dept_id, outpt_cnt, in_hosp_cnt, admit_cnt, discharge_cnt, surg_cnt, surg_l4_cnt,
  alos, bed_use_rate, revenue, cost, profit, drg_profit, case_cnt, cmi, material_per_100rev, eff_score
)
SELECT
  dc.discharge_date AS date,
  dc.group_id       AS dept_id,          -- 医疗组即 dim.department level=3 行
  NULL, NULL, NULL,
  COUNT(*)          AS discharge_cnt,    -- 组级出院 = drg 病案口径（含未入组）
  NULL, NULL,
  ROUND(AVG(dc.los_days)::numeric, 2) AS alos,
  NULL, NULL, NULL, NULL,
  ROUND(SUM(dc.profit), 2) AS drg_profit,
  COUNT(*) FILTER (WHERE dc.drg_code IS NOT NULL) AS case_cnt,
  ROUND(SUM(dc.rw) FILTER (WHERE dc.drg_code IS NOT NULL)
        / NULLIF(COUNT(*) FILTER (WHERE dc.drg_code IS NOT NULL), 0), 4) AS cmi,
  NULL, NULL
FROM dwd.drg_case dc
JOIN dim.department g ON g.id = dc.group_id AND g.level = 3
GROUP BY dc.discharge_date, dc.group_id
ON CONFLICT (date, dept_id) DO NOTHING;
-- rows 3002 合计预估: ~2.9万（≈731d × [~30 科室 + ~10 活跃组]，随上游密度浮动）
-- 锚点: home/top10 当月出院降序可复现（心内680/骨科612…的相对序）；compare inpt 列有值


-- ============================================================================
-- §3003  dws.drg_dept_period —— 病组×科室×周期（month 全窗 + d30 快照）
-- 出参：topics·drg stats/科室表/RW 分布图；screen drg_quadrant 底数
-- ============================================================================
WITH src AS (                                   -- 只取入组病例（未入组不入病组汇总）
  SELECT dc.discharge_date, dc.dept_id, dc.drg_code, dc.rw, dc.total_fee, dc.cost_total,
         dc.insurance_pay, dc.material_fee, dc.los_days, dc.profit,
         CASE WHEN dc.death_flag THEN 1 ELSE 0 END AS death_i
  FROM dwd.drg_case dc
  WHERE dc.drg_code IS NOT NULL
),
agg AS (
  SELECT grain.period_type, grain.period_start, grain.dept_id, grain.drg_code,
         COUNT(*)                            AS case_cnt,
         AVG(grain.rw)                       AS rw_avg,
         SUM(profit)                         AS total_profit,
         AVG(profit)                         AS profit_avg,
         AVG(total_fee)                      AS fee_avg,
         AVG(cost_total)                     AS cost_avg,
         AVG(insurance_pay)                  AS insure_avg,
         AVG(los_days)                       AS los_avg,
         SUM(material_fee) / NULLIF(SUM(total_fee), 0) AS material_ratio,
         AVG(total_fee / NULLIF(g.region_fee_avg, 0)) AS cost_idx,   -- 每病例费用/区域组例均，再平均
         AVG(los_days::numeric / NULLIF(g.region_los_avg, 0)) AS time_idx,
         COUNT(*) FILTER (WHERE grain.rw >= 2)::numeric / COUNT(*) AS rw2_ratio,
         CASE WHEN g.risk_level = 'low'
              THEN SUM(death_i)::numeric / COUNT(*) END AS lowrisk_mortality
  FROM (
    -- month 粒度 × 科室
    SELECT 'month'::varchar(8) AS period_type, date_trunc('month', discharge_date)::date AS period_start,
           dept_id, drg_code, rw, total_fee, cost_total, insurance_pay, material_fee, los_days, profit, death_i
    FROM src
    UNION ALL
    -- month 粒度 × 全院哨兵
    SELECT 'month', date_trunc('month', discharge_date)::date, 0::bigint, drg_code,
           rw, total_fee, cost_total, insurance_pay, material_fee, los_days, profit, death_i
    FROM src
    UNION ALL
    -- d30 粒度 × 科室（as_of=BASE_DATE，period_start=as_of−29）
    SELECT 'd30', DATE '2026-09-29', dept_id, drg_code,
           rw, total_fee, cost_total, insurance_pay, material_fee, los_days, profit, death_i
    FROM src
    WHERE discharge_date BETWEEN DATE '2026-09-29' AND DATE '2026-10-28'
    UNION ALL
    -- d30 粒度 × 全院哨兵
    SELECT 'd30', DATE '2026-09-29', 0::bigint, drg_code,
           rw, total_fee, cost_total, insurance_pay, material_fee, los_days, profit, death_i
    FROM src
    WHERE discharge_date BETWEEN DATE '2026-09-29' AND DATE '2026-10-28'
  ) grain
  JOIN dim.drg_group g ON g.code = grain.drg_code
  GROUP BY grain.period_type, grain.period_start, grain.dept_id, grain.drg_code, g.risk_level
)
INSERT INTO dws.drg_dept_period (
  period_type, period_start, dept_id, drg_code, case_cnt, rw_avg, cmi_equiv,
  total_profit, profit_avg, fee_avg, cost_avg, insure_avg, los_avg,
  material_ratio, cost_idx, time_idx, rw2_ratio, lowrisk_mortality, quadrant
)
SELECT
  period_type, period_start, dept_id, drg_code, case_cnt,
  ROUND(rw_avg, 4), ROUND(rw_avg, 4),               -- 单元格内 cmi_equiv = Σrw/cnt = rw_avg
  ROUND(total_profit, 2), ROUND(profit_avg, 2), ROUND(fee_avg, 2), ROUND(cost_avg, 2),
  ROUND(insure_avg, 2), ROUND(los_avg, 2),
  ROUND(material_ratio, 4), ROUND(cost_idx, 4), ROUND(time_idx, 4), ROUND(rw2_ratio, 4),
  ROUND(lowrisk_mortality, 4),
  CASE WHEN rw_avg >= 1.0 AND total_profit >= 0 THEN 2
       WHEN rw_avg >= 1.0 AND total_profit <  0 THEN 1
       WHEN rw_avg <  1.0 AND total_profit >= 0 THEN 4
       ELSE 3 END AS quadrant
FROM agg
ON CONFLICT (period_type, period_start, dept_id, drg_code) DO NOTHING;
-- rows 预估: ~6.5k（24 月 × [院0+~18科] × ~15 病组 + d30 ~340）
-- 锚点: 院级 CMI≈1.08、费用指数≈0.92、时间指数≈0.95、RW≥2≈0.102、低风险死亡≈0.0002、
--       d30 科室象限可推出 §14.1 五点（骨科+124.6万/神外−12.8万 等）


-- ============================================================================
-- §3004  dws.metric_value —— 长尾指标（推导类 INSERT…SELECT + 手工类确定值）
-- 禁双写：不写宽表已有列的同粒度指标（columns.md 收窄边界表）
-- ============================================================================

-- ---------- D1. 推导类：无宽表落点的比率/均值（月粒度） ----------
-- (a) 手术系：SURG_L34_RATIO / MIN_INVASIVE_RATIO（dept0 + 科室）
WITH sg AS (
  SELECT date_trunc('month', date)::date AS p, dept_id,
         COUNT(*) FILTER (WHERE surg_status <> 'sched') AS tot,
         COUNT(*) FILTER (WHERE surg_status <> 'sched' AND surg_level >= 3) AS l34,
         COUNT(*) FILTER (WHERE surg_status <> 'sched' AND min_invasive)    AS mi
  FROM dwd.surgery_case GROUP BY 1, 2
)
INSERT INTO dws.metric_value (metric_code, date, dept_id, group_id, value, extra)
SELECT metric_code, p, dept_id, 0, ROUND(ratio, 4), NULL
FROM (
  SELECT 'SURG_L34_RATIO' AS metric_code, p, dept_id, l34::numeric / NULLIF(tot, 0) AS ratio FROM sg
  UNION ALL SELECT 'SURG_L34_RATIO', p, 0, SUM(l34) / NULLIF(SUM(tot), 0) FROM sg GROUP BY p
  UNION ALL SELECT 'MIN_INVASIVE_RATIO', p, dept_id, mi::numeric / NULLIF(tot, 0) FROM sg
  UNION ALL SELECT 'MIN_INVASIVE_RATIO', p, 0, SUM(mi) / NULLIF(SUM(tot), 0) FROM sg GROUP BY p
) u WHERE ratio IS NOT NULL
ON CONFLICT (metric_code, dept_id, group_id, date) DO NOTHING;
-- 锚点: 三四级≈0.586、微创≈0.423

-- (b) 病案系：SURG_L4_DISCH_RATIO / DRG_ENROLL_RATE / DEATH_RATE / READMIT_15D_RATE / EMR_GRADE_A_RATE
WITH dc AS (
  SELECT date_trunc('month', discharge_date)::date AS p, dept_id,
         COUNT(*)                                                       AS tot,
         COUNT(*) FILTER (WHERE drg_code IS NOT NULL)                   AS grouped,
         COUNT(*) FILTER (WHERE surg_level IS NOT NULL)                AS surg_cases,
         COUNT(*) FILTER (WHERE surg_level = 4)                        AS l4_cases,
         COUNT(*) FILTER (WHERE death_flag)                            AS deaths,
         COUNT(*) FILTER (WHERE readmit15_flag)                        AS readmits,
         COUNT(*) FILTER (WHERE mr_grade = 'A')                        AS grade_a
  FROM dwd.drg_case GROUP BY 1, 2
)
INSERT INTO dws.metric_value (metric_code, date, dept_id, group_id, value, extra)
SELECT m, p, dept_id, 0, ROUND(r, 4), NULL
FROM (
  SELECT 'SURG_L4_DISCH_RATIO' AS m, p, dept_id, l4_cases::numeric / NULLIF(surg_cases, 0) AS r FROM dc
  UNION ALL SELECT 'SURG_L4_DISCH_RATIO', p, 0, SUM(l4_cases) / NULLIF(SUM(surg_cases), 0) FROM dc GROUP BY p
  UNION ALL SELECT 'DRG_ENROLL_RATE',    p, dept_id, grouped::numeric / NULLIF(tot, 0)       FROM dc
  UNION ALL SELECT 'DRG_ENROLL_RATE',    p, 0, SUM(grouped) / NULLIF(SUM(tot), 0)            FROM dc GROUP BY p
  UNION ALL SELECT 'DEATH_RATE',         p, dept_id, deaths::numeric / NULLIF(tot, 0)        FROM dc
  UNION ALL SELECT 'DEATH_RATE',         p, 0, SUM(deaths) / NULLIF(SUM(tot), 0)             FROM dc GROUP BY p
  UNION ALL SELECT 'READMIT_15D_RATE',   p, dept_id, readmits::numeric / NULLIF(tot, 0)      FROM dc
  UNION ALL SELECT 'READMIT_15D_RATE',   p, 0, SUM(readmits) / NULLIF(SUM(tot), 0)           FROM dc GROUP BY p
  UNION ALL SELECT 'EMR_GRADE_A_RATE',   p, dept_id, grade_a::numeric / NULLIF(tot, 0)       FROM dc
  UNION ALL SELECT 'EMR_GRADE_A_RATE',   p, 0, SUM(grade_a) / NULLIF(SUM(tot), 0)            FROM dc GROUP BY p
) u(m, p, dept_id, r) WHERE r IS NOT NULL
-- 列名以 UNION 首支为准（m/p/dept_id/r）
ON CONFLICT (metric_code, dept_id, group_id, date) DO NOTHING;
-- 锚点: 入组率≈0.985、甲级病案≈0.986

-- (c) 费用系：DRUG_RATIO(仅科室行——院级在宽表 drug_ratio 禁双写) / MATERIAL_RATIO(科室+院0)
WITH cg AS (
  SELECT date_trunc('month', date)::date AS p, dept_id,
         SUM(out_fee + in_fee) FILTER (WHERE fee_cat = 'drug')     AS drug_fee,
         SUM(out_fee + in_fee) FILTER (WHERE fee_cat = 'material') AS mat_fee,
         SUM(out_fee + in_fee)                                      AS tot_fee
  FROM dwd.charge_day GROUP BY 1, 2
)
INSERT INTO dws.metric_value (metric_code, date, dept_id, group_id, value, extra)
SELECT m, p, dept_id, 0, ROUND(r, 4), NULL
FROM (
  SELECT 'DRUG_RATIO' AS m, p, dept_id, drug_fee / NULLIF(tot_fee, 0) AS r FROM cg
  UNION ALL SELECT 'MATERIAL_RATIO', p, dept_id, mat_fee / NULLIF(tot_fee, 0) FROM cg
  UNION ALL SELECT 'MATERIAL_RATIO', p, 0, SUM(mat_fee) / NULLIF(SUM(tot_fee), 0) FROM cg GROUP BY p
) u(m, p, dept_id, r) WHERE r IS NOT NULL
ON CONFLICT (metric_code, dept_id, group_id, date) DO NOTHING;
-- 锚点: 耗占比院级≈0.179；科室药占比供 §5.1/§6.1 科室表 drug/mat_ratio 列

-- (d) 门诊系：AVG_WAIT_MIN / REG_CANCEL_RATE / APPT_RATE（院0·月）
INSERT INTO dws.metric_value (metric_code, date, dept_id, group_id, value, extra)
SELECT m, p, 0, 0, ROUND(v, 4), NULL
FROM (
  SELECT 'AVG_WAIT_MIN' AS m, date_trunc('month', stat_time)::date AS p,
         SUM(wait_min_sum) / NULLIF(SUM(visit_cnt), 0) AS v
  FROM dwd.outpatient_hourly GROUP BY 2
  UNION ALL
  SELECT 'REG_CANCEL_RATE', date_trunc('month', stat_time)::date,
         SUM(cancel_cnt)::numeric / NULLIF(SUM(reg_cnt), 0)
  FROM dwd.outpatient_hourly GROUP BY 2
  UNION ALL
  SELECT 'APPT_RATE', date_trunc('month', stat_time)::date,
         SUM(appt_cnt)::numeric / NULLIF(SUM(visit_cnt), 0)
  FROM dwd.outpatient_hourly GROUP BY 2
) u WHERE v IS NOT NULL
ON CONFLICT (metric_code, dept_id, group_id, date) DO NOTHING;
-- 锚点: 候诊≈18min；退号率/预约率为 P2 列（上游播种值若为 0 则率=0，属正常）


-- ---------- D2. 满意度拆分（manual·survey_sim）：院0 月序列 + 科室住院满意度 ----------
-- 院0：SAT_OP_SCORE 末6月锚定契约曲线 [94.8→96.4]；SAT_IP_SCORE [96.0→97.2]
--     （契约示例月为遗留口径，曲线形状平移至 BASE_DATE 尾部：2026-05 ~ 2026-10）
INSERT INTO dws.metric_value (metric_code, date, dept_id, group_id, value, extra)
SELECT m, p, 0, 0, ROUND(v, 2), '{"source":"survey_sim"}'::jsonb
FROM (
  SELECT 'SAT_OP_SCORE' AS m, p, op_v AS v FROM (
    SELECT p, CASE
      WHEN p >  DATE '2026-10-01' THEN 96.4 + 0.10 * d_fwd
      WHEN p >= DATE '2026-05-01' THEN anchor_v
      ELSE 94.8 - 0.25 * d_back + jit END AS op_v
    FROM (
      SELECT p,
             ((2026 * 12 + 10) - (EXTRACT(YEAR FROM p) * 12 + EXTRACT(MONTH FROM p)))::int AS d_back,
             ((EXTRACT(YEAR FROM p) * 12 + EXTRACT(MONTH FROM p)) - (2026 * 12 + 10))::int AS d_fwd,
             (((('x' || substr(md5(p::text), 1, 8))::bit(32)::bigint) % 21) - 10) / 100.0 AS jit,
             a.anchor_v
      FROM (SELECT generate_series(DATE '2025-01-01', DATE '2026-12-01', INTERVAL '1 month')::date AS p) mm
      LEFT JOIN (VALUES
        (DATE '2026-05-01', 94.8), (DATE '2026-06-01', 95.2), (DATE '2026-07-01', 95.6),
        (DATE '2026-08-01', 95.8), (DATE '2026-09-01', 96.1), (DATE '2026-10-01', 96.4)
      ) a(anchor_d, anchor_v) ON a.anchor_d = p
    ) t
  ) t2
  UNION ALL
  SELECT 'SAT_IP_SCORE', p, ip_v FROM (
    SELECT p, CASE
      WHEN p >  DATE '2026-10-01' THEN 97.2 + 0.05 * d_fwd
      WHEN p >= DATE '2026-05-01' THEN anchor_v
      ELSE 96.0 - 0.20 * d_back + jit END AS ip_v
    FROM (
      SELECT p,
             ((2026 * 12 + 10) - (EXTRACT(YEAR FROM p) * 12 + EXTRACT(MONTH FROM p)))::int AS d_back,
             ((EXTRACT(YEAR FROM p) * 12 + EXTRACT(MONTH FROM p)) - (2026 * 12 + 10))::int AS d_fwd,
             (((('x' || substr(md5(p::text || 'ip'), 1, 8))::bit(32)::bigint) % 21) - 10) / 100.0 AS jit,
             a.anchor_v
      FROM (SELECT generate_series(DATE '2025-01-01', DATE '2026-12-01', INTERVAL '1 month')::date AS p) mm
      LEFT JOIN (VALUES
        (DATE '2026-05-01', 96.0), (DATE '2026-06-01', 96.2), (DATE '2026-07-01', 96.5),
        (DATE '2026-08-01', 96.8), (DATE '2026-09-01', 97.0), (DATE '2026-10-01', 97.2)
      ) a(anchor_d, anchor_v) ON a.anchor_d = p
    ) t
  ) t2
) u
ON CONFLICT (metric_code, dept_id, group_id, date) DO NOTHING;

-- 科室行：SAT_IP_SCORE（compare sat 列口径=住院满意度；按科室名锚定 §12.1 示例值）
INSERT INTO dws.metric_value (metric_code, date, dept_id, group_id, value, extra)
SELECT 'SAT_IP_SCORE', p, d.id, 0,
       ROUND(d.base - 0.12 * ((2026 * 12 + 10) - (EXTRACT(YEAR FROM p) * 12 + EXTRACT(MONTH FROM p)))
             + (((('x' || substr(md5(d.id::text || p::text), 1, 8))::bit(32)::bigint) % 31) - 15) / 100.0, 2),
       '{"source":"survey_sim"}'::jsonb
FROM (SELECT generate_series(DATE '2025-01-01', DATE '2026-12-01', INTERVAL '1 month')::date AS p) mm
CROSS JOIN (
  SELECT d2.id, v2.base FROM dim.department d2
  JOIN (VALUES
    ('心血管内科', 96.2), ('骨科', 95.4), ('呼吸与危重症医学科', 94.8), ('普通外科', 94.2),
    ('神经内科', 93.6), ('肿瘤科', 92.8), ('妇产科', 95.0), ('儿科', 96.0)
  ) v2(dept_name, base) ON v2.dept_name = d2.name AND d2.level = 2
) d
ON CONFLICT (metric_code, dept_id, group_id, date) DO NOTHING;


-- ---------- D3. 科研/教学（manual·年粒度，date=年首日） ----------
-- 院0 年度锚点序列（契约 §8.1 锚点：在研186/新立42/经费3,480万/SCI98/论文166/住培312/结业96.2%/继教98.4%）
INSERT INTO dws.metric_value (metric_code, date, dept_id, group_id, value, extra)
SELECT m, d, 0, 0, v, '{"source":"manual_seed","note":"科研系统P3口径·演示锚点"}'::jsonb
FROM (VALUES
  ('RESEARCH_PROJ_CNT', DATE '2020-01-01',   96), ('RESEARCH_PROJ_CNT', DATE '2021-01-01',  112),
  ('RESEARCH_PROJ_CNT', DATE '2022-01-01',  130), ('RESEARCH_PROJ_CNT', DATE '2023-01-01',  148),
  ('RESEARCH_PROJ_CNT', DATE '2024-01-01',  166), ('RESEARCH_PROJ_CNT', DATE '2025-01-01',  176),
  ('RESEARCH_PROJ_CNT', DATE '2026-01-01',  186),
  ('RESEARCH_NEW_CNT',  DATE '2022-01-01',   40), ('RESEARCH_NEW_CNT',  DATE '2023-01-01',   48),
  ('RESEARCH_NEW_CNT',  DATE '2024-01-01',   56), ('RESEARCH_NEW_CNT',  DATE '2025-01-01',   36),
  ('RESEARCH_NEW_CNT',  DATE '2026-01-01',   42),    -- 口径=当年立项含各级（对齐 L8 dwd.research_project spec：2022=国4+省12+院24 等）；2025=36→2026=42 复现契约 delta"+6项"（审计 M6 销项）
  ('RESEARCH_FUND',     DATE '2020-01-01',  5000000), ('RESEARCH_FUND', DATE '2021-01-01',  8000000),
  ('RESEARCH_FUND',     DATE '2022-01-01', 12000000), ('RESEARCH_FUND', DATE '2023-01-01', 16800000),
  ('RESEARCH_FUND',     DATE '2024-01-01', 22400000), ('RESEARCH_FUND', DATE '2025-01-01', 29400000),
  ('RESEARCH_FUND',     DATE '2026-01-01', 34800000),    -- 3,480万 · 同比 +18.4%≈契约 +18.2%
  ('SCI_PAPER_CNT',     DATE '2020-01-01',   42), ('SCI_PAPER_CNT', DATE '2021-01-01',   55),
  ('SCI_PAPER_CNT',     DATE '2022-01-01',   68), ('SCI_PAPER_CNT', DATE '2023-01-01',   78),
  ('SCI_PAPER_CNT',     DATE '2024-01-01',   84), ('SCI_PAPER_CNT', DATE '2025-01-01',   91),
  ('SCI_PAPER_CNT',     DATE '2026-01-01',   98),
  ('PAPER_CNT',         DATE '2020-01-01',   70), ('PAPER_CNT', DATE '2021-01-01',   88),
  ('PAPER_CNT',         DATE '2022-01-01',  104), ('PAPER_CNT', DATE '2023-01-01',  122),
  ('PAPER_CNT',         DATE '2024-01-01',  140), ('PAPER_CNT', DATE '2025-01-01',  155),
  ('PAPER_CNT',         DATE '2026-01-01',  166),    -- =SCI98+中文核心68，与 L8b paper_distribution Σ=166 自洽
  ('TRAINEE_CNT',       DATE '2023-01-01',  260), ('TRAINEE_CNT', DATE '2024-01-01',  282),
  ('TRAINEE_CNT',       DATE '2025-01-01',  304), ('TRAINEE_CNT', DATE '2026-01-01',  312),
  ('TRAINEE_PASS_RATE', DATE '2024-01-01', 0.942), ('TRAINEE_PASS_RATE', DATE '2025-01-01', 0.955),
  ('TRAINEE_PASS_RATE', DATE '2026-01-01', 0.962),
  ('CME_COVER_RATE',    DATE '2024-01-01', 0.952), ('CME_COVER_RATE', DATE '2025-01-01', 0.968),
  ('CME_COVER_RATE',    DATE '2026-01-01', 0.984),
  ('TRANSFER_AMT',      DATE '2026-01-01', 2750000)   -- 院级成果转化合计=三分行Σ(150+80+45万)；修复轮补播
) u(m, d, v)
ON CONFLICT (metric_code, dept_id, group_id, date) DO NOTHING;

-- 学科/科室行（契约 disciplines 三行：心血管病学→心内科、骨外科学→骨科、呼吸病学→呼吸科）
INSERT INTO dws.metric_value (metric_code, date, dept_id, group_id, value, extra)
SELECT u.m, DATE '2026-01-01', d.id, 0, u.v, '{"source":"manual_seed"}'::jsonb
FROM dim.department d
JOIN (VALUES
  ('心血管内科',           'RESEARCH_PROJ_CNT', 28), ('骨科',               'RESEARCH_PROJ_CNT', 22),
  ('呼吸与危重症医学科',   'RESEARCH_PROJ_CNT', 18),
  ('心血管内科',           'RESEARCH_FUND',  8200000), ('骨科',             'RESEARCH_FUND',  5400000),
  ('呼吸与危重症医学科',   'RESEARCH_FUND',  4600000),
  ('心血管内科',           'SCI_PAPER_CNT',  22), ('骨科',                  'SCI_PAPER_CNT',  16),
  ('呼吸与危重症医学科',   'SCI_PAPER_CNT',  14),
  ('心血管内科',           'TRANSFER_AMT', 1500000), ('骨科',               'TRANSFER_AMT',  800000),
  ('呼吸与危重症医学科',   'TRANSFER_AMT',  450000)
) u(dept_name, m, v) ON u.dept_name = d.name AND d.level = 2
ON CONFLICT (metric_code, dept_id, group_id, date) DO NOTHING;
-- TRANSFER_AMT 院0 = 三分行合计 2,750,000（275万），院级行按本行播（audit N14 收口：院0=三分行合计）；open-items #4 留存口径注


-- ---------- D4. BIZ_EQUIV（暂定公式 v1：门急诊人次 + 出院×10，公约 §3.4） ----------
INSERT INTO dws.metric_value (metric_code, date, dept_id, group_id, value, extra)
SELECT 'BIZ_EQUIV', date_trunc('month', date)::date, dept_id, 0,
       SUM(COALESCE(outpt_cnt, 0)) + SUM(COALESCE(discharge_cnt, 0)) * 10,
       '{"formula":"outp+disch*10","version":1}'::jsonb
FROM dws.dept_oper_day
WHERE dept_id IN (SELECT id FROM dim.department WHERE level = 2)
GROUP BY 1, 2, 3
ON CONFLICT (metric_code, dept_id, group_id, date) DO NOTHING;


-- ---------- D5. QUALITY_SCORE（compare dim=quality 科室质量综合分；口径未定 version=0 手工合成） ----------
INSERT INTO dws.metric_value (metric_code, date, dept_id, group_id, value, extra)
SELECT 'QUALITY_SCORE', p, d.id, 0,
       ROUND(85 + ((('x' || substr(md5(d.id::text || p::text), 1, 8))::bit(32)::bigint) % 1100) / 100.0, 2),
       '{"source":"manual_seed","note":"合成口径待业务方·version=0"}'::jsonb
FROM (SELECT generate_series(DATE '2025-01-01', DATE '2026-12-01', INTERVAL '1 month')::date AS p) mm
CROSS JOIN dim.department d
WHERE d.level = 2 AND d.category IN ('med', 'surg')
ON CONFLICT (metric_code, dept_id, group_id, date) DO NOTHING;


-- ---------- D6. EXAM 系 —— 已撤出本表 ----------
-- EXAM_SCORE / EXAM_TARGET_RATE / EXAM_DIM_SCORE_RATE 一数一源归 dws.exam_indicator（L6 专属表，
-- metric_def.source_table 已指该表；审计 M4/impl）。metric_value 禁再播，V10 断言兜底防回流。


-- ============================================================================
-- §V  自洽校验（公约 §12 适用条目 + 锚点表对齐）——SELECT 断言式查询，全部应返回 pass=true
--     供 sim validate / 人工复核直接执行；不通过时查上游 lane 种子而非本层表达式
-- ============================================================================

-- V1. 校验#1：Σbed_used = in_hosp_cnt（逐日，±0）
SELECT 'V1_bed_used_eq_in_hosp' AS check_name,
       bool_and(h.bed_used = h.in_hosp_cnt) AS pass
FROM dws.hospital_oper_day h WHERE campus_code = 'main';

-- V2. 校验#2：KPI 屏值 = dwd 当日累计 ±1（BASE_DATE 2026-10-28）
SELECT 'V2_kpi_vs_dwd' AS check_name,
       (h.outpt_cnt + h.emerg_cnt) AS dws_op_daily,
       (SELECT SUM(visit_cnt) FROM dwd.outpatient_hourly WHERE stat_time::date = DATE '2026-10-28') AS dwd_op_daily,
       h.surg_cnt AS dws_surg, (SELECT COUNT(*) FROM dwd.surgery_case WHERE date = DATE '2026-10-28' AND surg_status <> 'sched') AS dwd_surg,
       h.in_hosp_cnt AS dws_inhosp, (SELECT SUM(bed_used) FROM dwd.bed_state_day WHERE date = DATE '2026-10-28') AS dwd_inhosp
FROM dws.hospital_oper_day h WHERE h.date = DATE '2026-10-28' AND h.campus_code = 'main';

-- V3. 校验#3：四象限/病组 profit 合计 ≈ hospital_oper_day.drg_profit 同期（±2%）
SELECT 'V3_quadrant_profit' AS check_name,
       (SELECT SUM(total_profit) FROM dws.drg_dept_period
         WHERE period_type='month' AND period_start = DATE '2026-10-01' AND dept_id = 0) AS period_profit_oct,
       (SELECT SUM(drg_profit) FROM dws.hospital_oper_day
         WHERE date BETWEEN DATE '2026-10-01' AND DATE '2026-10-31' AND campus_code='main') AS day_profit_oct,
       ABS((SELECT SUM(total_profit) FROM dws.drg_dept_period
             WHERE period_type='month' AND period_start = DATE '2026-10-01' AND dept_id = 0)
         - (SELECT SUM(drg_profit) FROM dws.hospital_oper_day
             WHERE date BETWEEN DATE '2026-10-01' AND DATE '2026-10-31' AND campus_code='main'))
       <= 0.02 * ABS((SELECT SUM(drg_profit) FROM dws.hospital_oper_day
                       WHERE date BETWEEN DATE '2026-10-01' AND DATE '2026-10-31' AND campus_code='main')) AS pass;
-- 注：差源=未入组病例的 profit（period 表只装入组）；±2% 界内为预期

-- V7. 校验#7：Σdrg_case.total_fee ≤ Σcharge_day.in_fee（DRG 病例是住院费用子集）
SELECT 'V7_drgfee_le_infee' AS check_name,
       (SELECT SUM(total_fee) FROM dwd.drg_case) AS drg_total_fee,
       (SELECT SUM(in_fee)   FROM dwd.charge_day) AS charge_in_fee,
       (SELECT SUM(total_fee) FROM dwd.drg_case) <= (SELECT SUM(in_fee) FROM dwd.charge_day) AS pass;

-- V8. 校验#8：drg_case 费用分项合计 = total_fee（±0.01）——上游 L4 责任，本层代为监控
SELECT 'V8_fee_parts' AS check_name,
       COUNT(*) FILTER (WHERE ABS(drug_fee + material_fee + exam_fee + surg_fee + other_fee - total_fee) > 0.01) AS bad_rows
FROM dwd.drg_case;

-- V9. 锚点复核：本层派生值 vs 契约锚点（±10% 界内）
SELECT 'V9_anchors' AS check_name,
       (SELECT ROUND(AVG(bed_use_rate),4) FROM dws.hospital_oper_day
         WHERE date BETWEEN '2026-10-01' AND '2026-10-28')                                  AS bed_use_rate_oct,  -- 期望 ≈0.921
       (SELECT ROUND(AVG(alos),2) FROM dws.hospital_oper_day
         WHERE date BETWEEN '2026-10-01' AND '2026-10-28' AND alos IS NOT NULL)             AS alos_oct,          -- 期望 ≈6.8
       (SELECT ROUND(AVG(drug_ratio),4) FROM dws.hospital_oper_day
         WHERE date BETWEEN '2026-10-01' AND '2026-10-28')                                  AS drug_ratio_oct,    -- 期望 ≈0.284
       (SELECT ROUND(SUM(revenue)) FROM dws.hospital_oper_day
         WHERE date BETWEEN '2026-10-01' AND '2026-10-31')                                  AS revenue_oct,       -- 期望 =148,000,000（scale-decision §2）
       (SELECT ROUND(SUM(discharge_cnt)) FROM dws.hospital_oper_day
         WHERE date BETWEEN '2026-10-01' AND '2026-10-31')                                  AS discharge_oct,     -- 期望 ≈8,120（§3 序列）
       (SELECT ROUND(SUM(profit)/NULLIF(SUM(revenue),0),4) FROM dws.hospital_oper_day
         WHERE date BETWEEN '2026-10-01' AND '2026-10-31')                                  AS margin_oct,        -- 期望 ≈0.042
       (SELECT ROUND(SUM(rw_avg*case_cnt)/NULLIF(SUM(case_cnt),0),4) FROM dws.drg_dept_period
         WHERE period_type='month' AND dept_id=0 AND period_start BETWEEN '2026-01-01' AND '2026-10-01') AS cmi_ytd, -- 期望 ≈1.08
       (SELECT value FROM dws.metric_value WHERE metric_code='MATERIAL_RATIO' AND dept_id=0
         AND date='2026-10-01')                                                            AS material_ratio_oct; -- 期望 ≈0.179

-- V10. 禁双写自查：metric_value 中不得出现宽表已列指标码（院级同粒度）
SELECT 'V10_no_double_write' AS check_name,
       COUNT(*) AS violation_rows
FROM dws.metric_value mv
WHERE mv.dept_id = 0 AND mv.group_id = 0
  AND mv.metric_code IN ('ALOS','BED_USE_RATE','CMI','SELF_PAY_RATIO','DRG_PROFIT','REVENUE','REVENUE_DAILY',
                         'EXAM_SCORE','EXAM_TARGET_RATE','EXAM_DIM_SCORE_RATE');  -- EXAM_* 归 dws.exam_indicator（审计 M4）
-- rows: 预期 0

-- ---------- L1 供稿（阶段3 修复轮）：manual 指标值行收口 ----------
-- traceability M2/M3/M4：INS_BALANCE_RATE/RX_OUTFLOW_RATE 定义在 L1（外源无事实
-- 表→manual），OTHER_INCOME_AMT 本轮 L1 新增定义——三码的 stats 出参值行此前全库
-- 未播。按"谁注册谁兜底"在 L5 文件尾部补值行（跨 lane 供稿先例同 metric_def）。
INSERT INTO dws.metric_value (metric_code, date, dept_id, group_id, value, extra) VALUES
 ('INS_BALANCE_RATE', DATE '2026-10-01', 0, 0,  0.068,   '{"source":"manual_seed","note":"契约 topics=insurance stats 基金结余率 6.8% 锚点；基金收入局端外源"}'::jsonb),
 ('RX_OUTFLOW_RATE',  DATE '2026-10-01', 0, 0,  0.124,   '{"source":"manual_seed","note":"契约 topics=outp_fund stats 处方外流率 12.4% 锚点；处方流转平台外源"}'::jsonb)
ON CONFLICT (metric_code, dept_id, group_id, date) DO NOTHING;
-- rows: 2

-- OTHER_INCOME_AMT 全年各月行（E9/F6 修复：原仅 2026-10 单行）——契约 income_structure
-- "其他收入"是收入结构的独立分量（4%），非 charge_day fee_cat='other'（该类目实算占比~6.8%，口径不同）。
-- 派生式：月值 = 月医疗总收入×4%×k（与 hospital_oper_day.revenue 同锚，Jan-Oct 累计≈4,810万 对回 §6.5）
INSERT INTO dws.metric_value (metric_code, date, dept_id, group_id, value, extra)
SELECT 'OTHER_INCOME_AMT', date_trunc('month', c.date)::date, 0, 0,
       ROUND(SUM(c.out_fee + c.in_fee) * 0.04 * cal.k, 2),
       '{"source":"derived","note":"其他收入=月医疗总收入×4%（契约 income_structure 分量，锚定后；非 charge_day other 类目）"}'::jsonb
FROM dwd.charge_day c
CROSS JOIN (SELECT 148000000.0 / NULLIF(SUM(out_fee + in_fee), 0) AS k
            FROM dwd.charge_day WHERE date BETWEEN DATE '2026-10-01' AND DATE '2026-10-31') cal
GROUP BY 2, cal.k
ON CONFLICT (metric_code, dept_id, group_id, date) DO NOTHING;
-- rows: 24 / 锚点：2026-10 月值≈5,920,000（=148,000,000×4%）；Jan–Oct 累计≈4,810万（scale-decision §6.5）
