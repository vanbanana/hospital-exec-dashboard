-- ============================================================================
-- lane L3 dwd-flow — 确定性种子（migrations 0201~0207 对应种子段）
-- 锚点：plan.md §5；契约 §3.1/§3.2/§4.1/§5.1/§6.1/§9.1/§13.1/§14.1
-- 方法：零随机/零当前时刻函数；伪随机一律 md5(主键) → pg_temp.h01() ∈ [0,1) 派生；
--       LogNormal 用 Box-Muller(z 由 h01 两路 hash 生成)；月度曲线见 VALUES 表。
-- 幂等：自然键表 ON CONFLICT DO NOTHING；流水事实表先导 DELETE 键域（§5.6）。
-- 窗口：2025-01-01 ~ 2026-12-31；BASE_DATE = 2026-10-28 周三（scale-decision §0）。
-- 依赖：sys.dict(L1 可后补——本文件供稿段落幂等)、dim.department/dim.ward(L2 必须先播种)。
-- ============================================================================

\set ON_ERROR_STOP on

-- ---------------------------------------------------------------- §0 工具 --
CREATE OR REPLACE FUNCTION pg_temp.h01(k text) RETURNS numeric
LANGUAGE sql IMMUTABLE AS $f$
  -- 确定性散列 ∈[0,1)：取 md5 前 60bit 为正整数域，规避符号位
  SELECT (('x' || md5(k))::bit(60)::bigint)::numeric / 1152921504606846976.0
$f$;

-- ------------------------------------------------- §1 dict 供稿（交 L1 汇编） --
-- 公约 §2.4：CHECK 与 dict 同值域；本 lane 责任 dict_type 的 key+label 行如下，
-- L1 汇编进 1001_dict.sql 时此处幂等插入不冲突。
INSERT INTO sys.dict (dict_type, dict_key, dict_label, sort, extra) VALUES
  ('ip_event','admit','入院',1,NULL),
  ('ip_event','discharge','出院',2,NULL),
  ('ip_event','transfer','转科',3,NULL),
  ('obs_status','observing','留观中',1,NULL),
  ('obs_status','admitted','转住院',2,NULL),
  ('obs_status','left','离观',3,NULL),
  ('reg_channel','wechat_mp','微信小程序',1,NULL),
  ('reg_channel','kiosk','自助机',2,NULL),
  ('reg_channel','window','人工窗口',3,NULL),
  ('reg_channel','app','官方APP',4,NULL),
  ('reg_channel','phone','电话预约',5,NULL),
  ('ins_type','employee','职工医保',1,NULL),
  ('ins_type','resident','居民医保',2,NULL),
  ('ins_type','maternity','生育保险',3,NULL),
  ('ins_type','severe','大病保险',4,NULL),
  ('ins_type','relief','医疗救助',5,NULL),
  ('ins_biz_type','inp','住院结算',1,NULL),
  ('ins_biz_type','op_fund','门诊统筹',2,NULL)
ON CONFLICT (dict_type, dict_key) DO NOTHING;

-- fee_cat 映射 extra：7桶 → 病案首页10大类 / 医保票据14项（calibration §3.5）。
-- L1 已播 label 时仅补 extra，不覆盖 label。
INSERT INTO sys.dict (dict_type, dict_key, dict_label, sort, extra) VALUES
  ('fee_cat','drug','药品',1,'{"mr10":["西药类","中药类(中成药/中草药/饮片)"],"bill14":["西药费","中成药费","中药饮片费"]}'),
  ('fee_cat','material','卫生材料',2,'{"mr10":["耗材类(检查/治疗/手术用一次性材料)"],"bill14":["卫生材料费"]}'),
  ('fee_cat','exam','检查化验',3,'{"mr10":["诊断类(病理/实验室/影像学/临床诊断)"],"bill14":["检查费","化验费"]}'),
  ('fee_cat','treat','治疗诊疗',4,'{"mr10":["综合医疗服务类·一般治疗/护理","治疗类·非手术","康复类","中医类"],"bill14":["治疗费","护理费","一般诊疗费","挂号费","诊察费"]}'),
  ('fee_cat','surg','手术麻醉',5,'{"mr10":["治疗类·手术治疗费(含麻醉费)"],"bill14":["手术费","麻醉费"]}'),
  ('fee_cat','bed','床位',6,'{"mr10":["综合医疗服务类·床位相关"],"bill14":["床位费"]}'),
  ('fee_cat','other','其他',7,'{"mr10":["血液和血液制品类","其他类","按病种收费"],"bill14":["血液费","按病种收费","其他费"]}')
ON CONFLICT (dict_type, dict_key) DO UPDATE SET extra = EXCLUDED.extra;

-- ------------------------------------------- §2 上游维度就绪断言（失败即停） --
DO $$
DECLARE missing text;
BEGIN
  SELECT string_agg(m.name, '、') INTO missing
  FROM (VALUES
    ('心血管内科'),('呼吸与危重症医学科'),('消化内科'),('神经内科'),('内分泌科'),
    ('儿科'),('骨科'),('皮肤科'),('普通外科'),('妇产科'),
    ('泌尿外科'),('神经外科'),('心胸外科'),('耳鼻喉科'),('眼科'),
    ('中医科'),('康复医学科'),('肿瘤科'),('重症医学科'),('急诊科')
  ) AS m(name)
  LEFT JOIN dim.department d ON d.name = m.name AND d.level = 2 AND d.active
  WHERE d.id IS NULL;
  IF missing IS NOT NULL THEN
    RAISE EXCEPTION 'L3 种子依赖科室缺失（dim.department 无 level=2 行）：%，请先执行 L2 维度种子', missing;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM dim.ward WHERE ward_type IN ('general','icu') AND bed_open > 0) THEN
    RAISE EXCEPTION 'dim.ward 无可住床病区（ward_type general/icu 且 bed_open>0），L3 bed_state_day 无法播种';
  END IF;
END $$;

-- -------------------------------------- §3 日级总量临时表 _sd（全表共用锚） --
DROP TABLE IF EXISTS pg_temp._sd;
CREATE TEMP TABLE _sd AS
WITH dd AS (
  SELECT gs::date AS dt, extract(year FROM gs)::int AS y,
         extract(month FROM gs)::int AS m, extract(isodow FROM gs)::int AS dow
  FROM generate_series(date '2025-01-01', date '2026-12-31', interval '1 day') AS gs
),
opc(y,m,tgt) AS (VALUES  -- 门急诊月度人次 = 契约 §3.2/§4.1 trend × E9 升档 ×10（§6.6：月 123,000/日 ~4,200/次均 300 元）
  (2025,1,46000),(2025,2,39000),(2025,3,52000),(2025,4,52000),(2025,5,68000),(2025,6,72000),
  (2025,7,90000),(2025,8,92000),(2025,9,87000),(2025,10,102000),(2025,11,101000),(2025,12,99000),
  (2026,1,54000),(2026,2,46000),(2026,3,68000),(2026,4,70000),(2026,5,85000),(2026,6,90000),
  (2026,7,108000),(2026,8,97000),(2026,9,105000),(2026,10,123000),(2026,11,122000),(2026,12,120000)),
ipc(y,m,tgt) AS (VALUES  -- 出院月度人次 = scale-decision §3 出院序列（锚 ~8,120/月，Little 三角勾稽成立）
  (2025,1,5371),(2025,2,4339),(2025,3,5785),(2025,4,5991),(2025,5,6405),(2025,6,6611),
  (2025,7,7024),(2025,8,7231),(2025,9,6818),(2025,10,7024),(2025,11,6611),(2025,12,6405),
  (2026,1,5900),(2026,2,4970),(2026,3,6410),(2026,4,6820),(2026,5,7240),(2026,6,7450),
  (2026,7,8070),(2026,8,8480),(2026,9,7850),(2026,10,8110),(2026,11,7650),(2026,12,7450)),
rvc(y,m,wan) AS (VALUES  -- 医疗总收入月度·万元 = scale-decision §2 收入序列（住院71%+门诊25%占96%，其他4%在 charge_day 外）
  (2025,1,7876),(2025,2,6924),(2025,3,9104),(2025,4,9763),(2025,5,10558),(2025,6,11033),
  (2025,7,11988),(2025,8,11653),(2025,9,11196),(2025,10,12624),(2025,11,12289),(2025,12,11827),
  (2026,1,8950),(2026,2,8060),(2026,3,10800),(2026,4,11650),(2026,5,12450),(2026,6,12980),
  (2026,7,13940),(2026,8,13550),(2026,9,13080),(2026,10,14800),(2026,11,14240),(2026,12,13720)),
dw AS (
  SELECT dt, y, m, dow,
    -- 门急诊星期因子：周一峰、周末谷（契约 §5.1 双峰分布×星期形态）
    (ARRAY[1.16,1.08,1.02,1.00,0.96,0.70,0.52])[dow] * (0.94 + 0.12*pg_temp.h01('sd.op.'||dt::text)) AS w_op,
    -- 急诊星期因子：周末略高、昼夜连续
    (ARRAY[0.92,0.94,0.96,0.98,1.00,1.10,1.14])[dow] * (0.92 + 0.16*pg_temp.h01('sd.em.'||dt::text)) AS w_em,
    -- 出院星期因子：周日低谷
    (ARRAY[0.98,1.02,1.00,1.00,1.04,1.02,0.94])[dow] * (0.93 + 0.14*pg_temp.h01('sd.ip.'||dt::text)) AS w_ip,
    (ARRAY[1.00,1.00,1.00,1.00,1.00,0.97,0.94])[dow] * (0.95 + 0.10*pg_temp.h01('sd.rv.'||dt::text)) AS w_rv
  FROM dd
)
SELECT dw.dt, dw.y, dw.m, dw.dow,
  round(o.tgt * dw.w_op / sum(dw.w_op) OVER (PARTITION BY dw.y,dw.m))::int AS op_em_cnt,
  round(i.tgt * dw.w_ip / sum(dw.w_ip) OVER (PARTITION BY dw.y,dw.m))::int AS disch_cnt,
  r.wan * 10000.0 * dw.w_rv / sum(dw.w_rv) OVER (PARTITION BY dw.y,dw.m)  AS rev_amt,
  o.tgt AS op_em_tgt_m
FROM dw
JOIN opc o ON o.y=dw.y AND o.m=dw.m
JOIN ipc i ON i.y=dw.y AND i.m=dw.m
JOIN rvc r ON r.y=dw.y AND r.m=dw.m;

ALTER TABLE _sd ADD COLUMN op_cnt int, ADD COLUMN em_cnt int,
                ADD COLUMN reg_total int, ADD COLUMN out_amt numeric(14,2), ADD COLUMN in_amt numeric(14,2),
                ADD COLUMN other_amt numeric(14,2),
                ADD COLUMN frac_c numeric(12,9), ADD COLUMN frac_p numeric(12,9);
UPDATE _sd s SET frac_c = x.c, frac_p = x.p
FROM (SELECT dt,
             sum(disch_cnt) OVER (PARTITION BY y,m ORDER BY dt) * 1.0
               / sum(disch_cnt) OVER (PARTITION BY y,m) AS c,
             (sum(disch_cnt) OVER (PARTITION BY y,m ORDER BY dt) - disch_cnt) * 1.0
               / sum(disch_cnt) OVER (PARTITION BY y,m) AS p
      FROM pg_temp._sd) x WHERE x.dt = s.dt;  -- F8：月内出院累计份额（尾量科室按月总量差分分配，不塌成 0）
UPDATE _sd SET
  em_cnt    = round(op_em_cnt * 0.092)::int,          -- 急诊占比 9.2%（E9 后：10月急诊 ~11,300/月）
  op_cnt    = op_em_cnt - round(op_em_cnt * 0.092)::int,
  reg_total = round(op_em_cnt * 1.048)::int,           -- 挂号≈就诊+退号余量
  out_amt   = op_em_cnt * 300.0,                       -- 门诊收入 = 人次×300元（E9 真源级勾稽：10月≈3,700万=25%，锚 3,690万±0.3%）
  in_amt    = rev_amt * 0.71,                          -- 住院医疗收入=71%（B2 拆出后纯住院≈10,530万，次均≈12,900）
  other_amt = rev_amt - op_em_cnt * 300.0 - rev_amt * 0.71;  -- 其他收入=总锚−门−住（≈4%，落 charge 'other' 桶，open-item#3）
UPDATE pg_temp._sd s SET other_amt = o.clip * m.omf      -- 门诊高峰日 0.29rev−out 可为负 → 日级截断再按月锚重归一
FROM (SELECT y, m, sum(rev_amt - out_amt - in_amt) / nullif(sum(GREATEST(other_amt, 0)), 0) AS omf
      FROM pg_temp._sd GROUP BY y, m) m,
     (SELECT dt, GREATEST(other_amt, 0) AS clip FROM pg_temp._sd) o
WHERE o.dt = s.dt AND m.y = s.y AND m.m = s.m;
UPDATE pg_temp._sd SET other_amt = 0 WHERE other_amt IS NULL;

-- ----------------------------------- §4 科室画像临时表 _sdept（契约份额锚点） --
-- op_sh   门诊人次份额权重（§5.1 门急诊表 cnt 值，未列科室按量级补）
-- avg_fee 门诊次均费用·元（§5.1 avg 列）；ex_r 专家门诊占比估计（锚 全院≈25%，§5.1 3114/12482）
-- ip_sh   出院人次份额权重（scale-decision §4 科室表：8 科室≈全院 8,120；未列科室残余量级）
-- ifac    住院次均倍率（dept 次均≈13,000×ifac，裁决带 12,400~16,240 元）
-- drg/mat_in/out 费用分类内药物/耗材份额（§5.1 drug 列 + §6.1 dept_table drug_ratio/mat_ratio）
-- opf_sh  门诊统筹结算份额（§13.1 outp_fund 科室表 cases）
DROP TABLE IF EXISTS pg_temp._sdept;
CREATE TEMP TABLE _sdept AS
WITH m(name, op_sh, avg_fee, ex_r, ip_sh, ifac, alos, drg_in, mat_in, drg_out, mat_out, opf_sh) AS (VALUES
 -- ip_sh：R3 top10 重分配——TOP8 合计 7,185 + 消化 380/泌尿 340 + 尾量 10 科室 215 = 8,120/月
 ('心血管内科',        1286,352,0.24,1250,1.05, 9.2, 0.26,0.16, 0.30,0.06,  912),
 ('呼吸与危重症医学科',1158,318,0.22, 990,1.05,10.4, 0.30,0.09, 0.34,0.05,  596),
 ('消化内科',          1042,296,0.26, 380,1.02, 7.4, 0.32,0.10, 0.36,0.06,  512),
 ('神经内科',           968,342,0.28, 800,1.10,11.2, 0.34,0.07, 0.33,0.05,  684),
 ('内分泌科',           826,274,0.27,  30,1.00, 7.8, 0.34,0.08, 0.38,0.05,  986),
 ('儿科',               792,198,0.30, 655,1.00, 4.8, 0.20,0.05, 0.24,0.03,  150),
 ('骨科',               716,412,0.30,1120,1.03, 8.6, 0.13,0.30, 0.22,0.10,  180),
 ('皮肤科',             654,186,0.18,  10,0.98, 6.2, 0.38,0.10, 0.44,0.06,  120),
 ('普通外科',           560,380,0.28, 920,1.02, 7.8, 0.17,0.22, 0.28,0.08,  210),
 ('妇产科',             520,330,0.30, 715,1.00, 5.2, 0.18,0.14, 0.30,0.06,  160),
 ('泌尿外科',           430,360,0.30, 340,1.05, 6.9, 0.16,0.24, 0.26,0.08,  170),
 ('神经外科',           290,520,0.38,  45,1.16,13.5, 0.14,0.20, 0.30,0.08,   60),
 ('心胸外科',           260,560,0.35,  30,1.16, 9.8, 0.15,0.22, 0.28,0.09,   55),
 ('耳鼻喉科',           380,240,0.24,  25,0.98, 5.6, 0.14,0.12, 0.26,0.05,  140),
 ('眼科',               340,260,0.20,  15,0.98, 4.2, 0.12,0.10, 0.24,0.05,  130),
 ('中医科',             430,310,0.22,  15,0.98, 9.4, 0.40,0.06, 0.52,0.05,  468),
 ('康复医学科',         260,290,0.18,  25,0.99,15.8, 0.12,0.14, 0.20,0.08,   90),
 ('肿瘤科',             410,480,0.32, 735,1.14,12.6, 0.40,0.10, 0.44,0.08,  240),
 ('重症医学科',           0,  0,0.40,  12,1.15, 8.4, 0.18,0.18, 0.00,0.00,    0),
 ('急诊科',               0,  0,0.00,   8,1.00, 3.5, 0.22,0.08, 0.00,0.00,    0))
SELECT d.id AS dept_id, m.*,
       m.op_sh * 1.0 / sum(m.op_sh)  OVER () AS op_n,
       m.ip_sh * 1.0 / sum(m.ip_sh)  OVER () AS ip_n,
       m.ip_sh * m.ifac / sum(m.ip_sh * m.ifac) OVER () AS ipf_n,
       m.opf_sh * 1.0 / sum(m.opf_sh) OVER () AS opf_n
FROM m JOIN dim.department d ON d.name = m.name AND d.level = 2 AND d.active;

DO $$
BEGIN
  IF (SELECT count(*) FROM pg_temp._sdept) <> 20 THEN
    RAISE EXCEPTION '_sdept 科室匹配数=% ≠20，检查 dim.department 名称/level', (SELECT count(*) FROM pg_temp._sdept);
  END IF;
END $$;

-- ============================ 0201 dwd.outpatient_hourly ============================
-- 门诊行：07:00~21:30 双峰曲线（9:30 主峰 σ1.3 / 15:00 次峰 ×0.72 / 19:30 小峰 ×0.26）
-- 急诊行：急诊科独占，24h 连续（20:00 峰 / 9:00 次峰 / 夜间 0.22 底噪）
INSERT INTO dwd.outpatient_hourly
  (stat_time, dept_id, emerg_flag, visit_cnt, reg_cnt, cancel_cnt, appt_cnt, expert_cnt, wait_min_sum, fee_total)
WITH sl AS (
  SELECT s, CASE WHEN t BETWEEN 6.5 AND 21.5 THEN
      exp(-0.5*power((t-9.5)/1.30,2)) + 0.72*exp(-0.5*power((t-15.0)/1.25,2)) + 0.26*exp(-0.5*power((t-19.5)/0.85,2))
    ELSE 0 END AS w
  FROM (SELECT s, s*0.5 AS t FROM generate_series(0,47) AS s) z),
sln AS (SELECT s, w/sum(w) OVER () AS wn FROM sl WHERE w > 0),
esln AS (
  SELECT s, w/sum(w) OVER () AS wn FROM (
    SELECT s, 0.22 + 0.55*exp(-0.5*power((s*0.5-9.0)/3.0,2)) + 0.85*exp(-0.5*power((s*0.5-20.0)/2.4,2)) AS w
    FROM generate_series(0,47) AS s) z),
opd AS (  -- 门诊×科室×日 人次
  SELECT s.dt, d.dept_id, d.avg_fee, d.ex_r,
         round(s.op_cnt * d.op_n * (0.90 + 0.20*pg_temp.h01('oph.d.'||s.dt::text||'|'||d.dept_id::text)))::int AS dv
  FROM pg_temp._sd s CROSS JOIN pg_temp._sdept d WHERE d.op_sh > 0),
opraw AS (  -- 槽位拆分用确定性最大余数法：floor + 按余量序补足，Σvc=dv 精确
  SELECT o.dt, o.dept_id, o.avg_fee, o.ex_r, n.s, o.dv, o.dv * n.wn AS raw,
         o.dt::text||'|'||o.dept_id::text||'|'||n.s::text AS k
  FROM opd o CROSS JOIN sln n),
opalloc AS (
  SELECT dt, dept_id, avg_fee, ex_r, s, k,
         floor(raw)::int + CASE WHEN row_number() OVER
             (PARTITION BY dt, dept_id ORDER BY raw - floor(raw) DESC, raw DESC)
           <= dv - sum(floor(raw)) OVER (PARTITION BY dt, dept_id)
           THEN 1 ELSE 0 END AS vc
  FROM opraw),
emraw AS (
  SELECT s.dt, n.s, s.em_cnt, s.em_cnt * n.wn AS raw,
         s.dt::text||'|E|'||n.s::text AS k,
         e.dept_id
  FROM pg_temp._sd s CROSS JOIN esln n
       CROSS JOIN (SELECT dept_id FROM pg_temp._sdept WHERE name='急诊科') e),
emalloc AS (
  SELECT dt, dept_id, s, k,
         floor(raw)::int + CASE WHEN row_number() OVER
             (PARTITION BY dt ORDER BY raw - floor(raw) DESC, raw DESC)
           <= em_cnt - sum(floor(raw)) OVER (PARTITION BY dt)
           THEN 1 ELSE 0 END AS vc
  FROM emraw),
metr AS (  -- 派生计数用月×科室累计差分：rate×cum 的 floor 差 ⇒ 月总量=⌊rate×Σvc⌋ 精确、日粒度无流失
           -- B1：fee_total 逐日归一到 charge 门诊日额（out_amt/Σraw）——保科室形态、全院收敛 ~299 元（audit-r3 §4 裁决 a）
  SELECT o.dt, o.dept_id, o.s, o.vc, o.avg_fee, false AS ef, sd.out_amt,
         sum(o.vc) OVER (PARTITION BY date_trunc('month',o.dt), o.dept_id ORDER BY o.dt, o.s) AS cum,
         0.030 + 0.030*pg_temp.h01('cdm.'||to_char(o.dt,'YYYYMM')||'|'||o.dept_id::text) AS cr,
         o.ex_r * (0.92 + 0.16*pg_temp.h01('exm.'||to_char(o.dt,'YYYYMM')||'|'||o.dept_id::text)) AS xr,
         0.42 + 0.18*pg_temp.h01('apm.'||to_char(o.dt,'YYYYMM')||'|'||o.dept_id::text) AS ar,
         14.5 + 7.0*pg_temp.h01('wr.'||o.dt::text||'|'||o.dept_id::text) AS wm,
         o.avg_fee * (0.92 + 0.16*pg_temp.h01('fr.'||o.dt::text||'|'||o.dept_id::text)) AS fm
  FROM opalloc o JOIN pg_temp._sd sd ON sd.dt = o.dt
  UNION ALL
  SELECT e.dt, e.dept_id, e.s, e.vc, 430.0, true, sd.out_amt,
         sum(e.vc) OVER (PARTITION BY date_trunc('month',e.dt) ORDER BY e.dt, e.s),
         0.010 + 0.010*pg_temp.h01('cdm.E'||to_char(e.dt,'YYYYMM')),
         0.0,
         0.06 + 0.06*pg_temp.h01('apm.E'||to_char(e.dt,'YYYYMM')),
         8.0 + 8.0*pg_temp.h01('wr.E'||e.dt::text),
         430.0*(0.92 + 0.16*pg_temp.h01('fr.E'||e.dt::text))
  FROM emalloc e JOIN pg_temp._sd sd ON sd.dt = e.dt)
SELECT (dt + s * interval '30 minutes')::timestamptz, dept_id, ef, vc,
       vc + cancel, cancel, appt, LEAST(vc, expert),
       round(vc * wm, 1), round(vc * fm * out_amt / nullif(dfr, 0), 2)
FROM (
  SELECT dt, dept_id, s, vc, ef, wm, fm, out_amt,
         sum(vc * fm) OVER (PARTITION BY dt) AS dfr,   -- 当日门急诊原始费额合计（门+急）
         floor(cr*cum)::int - floor(cr*(cum-vc))::int AS cancel,
         floor(ar*cum)::int - floor(ar*(cum-vc))::int AS appt,
         floor(xr*cum)::int - floor(xr*(cum-vc))::int AS expert
  FROM metr) z
WHERE vc > 0
ON CONFLICT (stat_time, dept_id, emerg_flag) DO NOTHING;
-- rows: ~0.40M / 锚点: 门急诊月 123,000（2026-10，E9×10）、年 ~847,000；急诊 ~11,300/月；专家≈25%、候诊≈18min、次均≈300元

-- ============================ 0202 dwd.reg_channel_day ============================
-- 渠道占比 38/24/18/14/6（契约 §9.1）；日级残差并入 wechat_mp 保证 Σcnt=reg_total
INSERT INTO dwd.reg_channel_day (date, channel, reg_cnt)
WITH ch AS (SELECT * FROM (VALUES
    ('wechat_mp',0.38,1),('kiosk',0.24,2),('window',0.18,3),('app',0.14,4),('phone',0.06,5)
  ) AS c(channel,shr,srt)),
sp AS (
  SELECT s.dt, c.channel, c.srt, s.reg_total,
         round(s.reg_total * c.shr * (1 + 0.06*(pg_temp.h01('rch.'||s.dt::text||'|'||c.channel)-0.5)))::int AS cnt
  FROM pg_temp._sd s CROSS JOIN ch c)
SELECT dt, channel, cnt + CASE WHEN srt=1 THEN reg_total - sum(cnt) OVER (PARTITION BY dt) ELSE 0 END
FROM sp
ON CONFLICT (date, channel) DO NOTHING;
-- rows: 731×5 = 3,655 / 锚点: 渠道占比 38/24/18/14/6；月度Σ≈挂号总量

-- ============================ 0203 dwd.inpatient_move ============================
DELETE FROM dwd.inpatient_move
WHERE event_time >= timestamptz '2025-01-01' AND event_time < timestamptz '2027-01-01';

INSERT INTO dwd.inpatient_move (patient_masked, dept_id, ward_code, event, event_time, los_days)
WITH mt AS (  -- 月出院总量（先行聚合——窗口不能跨 CROSS JOIN 后的行算，否则被科室数放大）
  SELECT y, m, sum(disch_cnt)::numeric AS msum FROM pg_temp._sd GROUP BY 1, 2),
ipm AS (  -- 月×科室出院总量：先定月度量再日级差分（F8：尾量科室 ~35例/月摊到各 lvl2 科室，日级 round 会塌成 0）
  SELECT t.y, t.m, d.dept_id, d.alos,
         round(t.msum * d.ip_n * (0.96 + 0.08*pg_temp.h01('ipm.m.'||t.y||'-'||t.m||'|'||d.dept_id::text))) AS m_cnt
  FROM mt t CROSS JOIN pg_temp._sdept d WHERE d.ip_sh > 0),
ipd AS (  -- 出院×科室×日 = 累计差分：cnt(dt)=floor(m_cnt·frac_c)−floor(m_cnt·frac_p)，月度总量精确、日形态跟 disch_cnt
  SELECT s.dt, m.dept_id, m.alos,
         (floor(m.m_cnt * s.frac_c) - floor(m.m_cnt * s.frac_p))::int AS cnt
  FROM pg_temp._sd s JOIN ipm m ON m.y = s.y AND m.m = s.m),
adm AS (  -- 入院流量≈出院前移 7d（≈ALOS 6.8 的整数近似）；窗尾 7d 用当日出院×1.02 近似净增
  SELECT (dt - 7)::date AS dt, dept_id, cnt, 0 AS opening FROM ipd WHERE (dt - 7) >= date '2025-01-01'
  UNION ALL
  SELECT dt, dept_id, round(cnt*1.02)::int, 0 FROM ipd WHERE dt > date '2026-12-24'
  UNION ALL
  -- 开窗存量（G8）：窗首周出院的镜像 admit（窗内不配对 discharge）——表征 2025-01-01 开窗时的在院基线≈Σdisch(Jan1-7)≈1,330
  SELECT date '2025-01-01', dept_id, cnt, 1 FROM ipd WHERE dt BETWEEN date '2025-01-01' AND date '2025-01-07'),
trf AS (  -- 转科事件≈出院的 5%
  SELECT dt, dept_id, round(cnt * (0.04 + 0.03*pg_temp.h01('ipm.t.'||dt::text||'|'||dept_id::text)))::int AS cnt
  FROM ipd),
ev AS (
  SELECT 'discharge' AS ev, i.dt, i.dept_id, g.seq, i.alos,
         (i.dt + interval '9 hours' + ((g.seq*37 + i.dept_id) % 200) * interval '1 minute')::timestamptz AS et
  FROM ipd i CROSS JOIN LATERAL generate_series(1, i.cnt) AS g(seq)
  UNION ALL
  SELECT 'admit', a.dt, a.dept_id, g.seq, NULL,
         (a.dt + (a.opening * (g.seq % 3)) * interval '1 day'
                + interval '8 hours' + ((g.seq*53 + a.dept_id*7) % 600) * interval '1 minute')::timestamptz
  FROM adm a CROSS JOIN LATERAL generate_series(1, a.cnt) AS g(seq)
  UNION ALL
  SELECT 'transfer', t.dt, t.dept_id, g.seq, NULL,
         (t.dt + interval '10 hours' + ((g.seq*41 + t.dept_id*3) % 360) * interval '1 minute')::timestamptz
  FROM trf t CROSS JOIN LATERAL generate_series(1, t.cnt) AS g(seq)),
los AS (  -- Box-Muller 确定性 z；μ_d=ln(alos_d)−σ²/2，σ=0.62；全院按 exp(c) 校正到均值 6.8
  SELECT ev.*,
         exp(ln(ev.alos) - 0.1922
             + 0.62 * sqrt(-2*ln(greatest(pg_temp.h01('la.'||ev.et::text||ev.seq),1e-9)))
                       * cos(2*pi()*pg_temp.h01('lb.'||ev.et::text||ev.seq))) AS los_raw
  FROM ev WHERE ev.ev = 'discharge'),
corr AS (SELECT ln(6.8 / avg(los_raw)) AS c FROM los)
SELECT 'P'||lpad((((('x'||md5(ev.et::text||'|'||ev.dept_id::text||'|'||ev.seq::text))::bit(24)::bigint) % 900000)+100000)::text,6,'0'),
       ev.dept_id,
       (SELECT w.code FROM dim.ward w WHERE w.dept_id = ev.dept_id AND w.ward_type <> 'or'
          ORDER BY w.code LIMIT 1),
       ev.ev, ev.et,
       CASE WHEN ev.ev='discharge'
            THEN GREATEST(1, round(l.los_raw * exp(c.c)))::int END
FROM ev
LEFT JOIN los l ON l.et = ev.et AND l.seq = ev.seq AND l.dept_id = ev.dept_id AND l.ev = ev.ev
CROSS JOIN corr c
ORDER BY ev.et
ON CONFLICT DO NOTHING;
-- rows: 出院 ~165k + 入院 ~165k+存量1.3k + 转科 ~18k ≈ 350k / 锚点: 出院月 8,110（修订锚）、ALOS≈6.8（LogNormal 全局校正）、开窗存量使 admit−discharge 净存≈在院 1,846±3%；F8：尾量科室月级差分分配（TOP8 之外 ~37例/月）

-- ============================ 0204 dwd.bed_state_day ============================
-- 目标占用率日函数 + BASE_DATE 钉 0.921；病区个体因子含 >1 借床侧，借出侧按空闲累计分配；
-- Σborrow_in=Σborrow_out 由构造保证（借出分配上限=借入需求累计）。
INSERT INTO dwd.bed_state_day (date, ward_code, dept_id, bed_open, bed_used, borrow_in, borrow_out)
WITH w0 AS (
  SELECT code, dept_id, ward_type, bed_open
  FROM dim.ward WHERE ward_type IN ('general','icu') AND bed_open > 0),
wp AS (  -- 开放床位 = 编制床 + 机动床：dim Σbed_open(1,968) 确定性补齐到全院锚 2,004（scale-decision §1）
         -- 差额按病区规模最大余数分配；dim 已达锚时 pad=0（自适应）
  SELECT w0.*,
         floor(w0.bed_open * g.gap / g.tot)::int
           + CASE WHEN row_number() OVER (ORDER BY w0.bed_open * g.gap / g.tot
                                               - floor(w0.bed_open * g.gap / g.tot) DESC, w0.code)
                  <= g.gap - sum(floor(w0.bed_open * g.gap / g.tot)) OVER () THEN 1 ELSE 0 END AS pad
  FROM w0, (SELECT GREATEST(0, 2004 - sum(bed_open)) AS gap, nullif(sum(bed_open),0) AS tot FROM w0) g),
w AS (  -- wf 病区固有占用因子：general 0.88~1.08、icu 0.94~1.05（>1 的病区产生借床需求）
  SELECT code, dept_id, ward_type, bed_open + pad AS bed_open,
         CASE ward_type WHEN 'icu' THEN 0.94 + 0.11*pg_temp.h01('bed.w.'||code)
                        ELSE 0.88 + 0.20*pg_temp.h01('bed.w.'||code) END AS wf
  FROM wp),
est AS (  -- 未校正占用估计
  SELECT s.dt, w.code, w.dept_id, w.bed_open,
         w.bed_open * w.wf
           * (1 + 0.010*sin(2*pi()*(extract(doy FROM s.dt)::int - 340)/365.0))   -- 冬季微高
           * (CASE WHEN s.dow >= 6 THEN 0.975 ELSE 1 END)                        -- 周末微降
           * (0.97 + 0.06*pg_temp.h01('bed.d.'||s.dt::text||'|'||w.code)) AS e
  FROM pg_temp._sd s CROSS JOIN w),
tgt AS (  -- 全院日目标占用数；BASE_DATE 显式钉 0.921（其余日期走函数曲线）
  SELECT s.dt,
         round((SELECT sum(bed_open) FROM w) *
               CASE WHEN s.dt = date '2026-10-28' THEN 0.9210
                    ELSE 0.912 + 0.014*sin(2*pi()*(extract(doy FROM s.dt)::int - 335)/365.0)
                        - CASE WHEN s.dow>=6 THEN 0.008 ELSE 0 END
                        + 0.010*(pg_temp.h01('bed.t.'||s.dt::text)-0.5) END)::int AS want
  FROM (SELECT DISTINCT dt, dow FROM pg_temp._sd) s),
used AS (
  SELECT e.dt, e.code, e.dept_id, e.bed_open,
         LEAST(e.bed_open * 1.10,
               GREATEST(0, round(e.e * t.want / nullif(sum(e.e) OVER (PARTITION BY e.dt),0))))::int AS u
  FROM est e JOIN tgt t ON t.dt = e.dt),
adj AS (  -- 按病区取整的残差并入当日空闲最大病区 ⇒ Σu=want 精确（BASE 日钉 1,846）
  SELECT u.dt, u.code, u.dept_id, u.bed_open,
         u.u + CASE WHEN row_number() OVER (PARTITION BY u.dt ORDER BY u.bed_open - u.u DESC,
                                          pg_temp.h01('bed.fx.'||u.dt::text||u.code)) = 1
                    THEN t.want - sum(u.u) OVER (PARTITION BY u.dt) ELSE 0 END AS u
  FROM used u JOIN tgt t ON t.dt = u.dt),
need AS (  -- 借入需求：u>open 的病区；若全院需求>空闲池，按比例收敛保证 Σin≤Σspare
  SELECT u.dt, u.code, u.dept_id, u.bed_open, u.u,
         GREATEST(u.u - u.bed_open, 0) AS want_in,
         GREATEST(u.bed_open - u.u, 0) AS spare,
         sum(GREATEST(u.u - u.bed_open,0)) OVER (PARTITION BY u.dt) AS tot_need,
         sum(GREATEST(u.bed_open - u.u,0)) OVER (PARTITION BY u.dt) AS tot_spare
  FROM adj u),
fin_in AS (
  SELECT n.dt, n.code, n.dept_id, n.bed_open,
         CASE WHEN n.want_in = 0 THEN n.u
              ELSE n.bed_open + floor(n.want_in *
                    CASE WHEN n.tot_need > n.tot_spare THEN 0.95*n.tot_spare/n.tot_need ELSE 1 END)::int
         END AS u2,
         CASE WHEN n.want_in = 0 THEN 0
              ELSE floor(n.want_in *
                    CASE WHEN n.tot_need > n.tot_spare THEN 0.95*n.tot_spare/n.tot_need ELSE 1 END)::int
         END AS bin,
         n.spare, n.tot_need
  FROM need n),
fin AS (
  SELECT f.*, sum(f.bin) OVER (PARTITION BY f.dt) AS tot_bin,
         pg_temp.h01('bed.bo.'||f.dt::text||'|'||f.code) AS rk
  FROM fin_in f),
bo AS (  -- 借出分配：空闲病区按确定性序累计分摊，Σout=Σin 精确成立
  SELECT f.dt, f.code,
         LEAST(f.spare, GREATEST(0, f.tot_bin -
               (sum(f.spare) OVER (PARTITION BY f.dt ORDER BY f.rk
                                   ROWS UNBOUNDED PRECEDING) - f.spare)))::int AS bout
  FROM fin f WHERE f.spare > 0)
SELECT f.dt, f.code, f.dept_id, f.bed_open, f.u2, f.bin, COALESCE(b.bout,0)
FROM fin f LEFT JOIN bo b ON b.dt=f.dt AND b.code=f.code
ON CONFLICT (date, ward_code) DO NOTHING;
-- rows: Σ开放病区(~25~35) × 731d ≈ 2万+ / 锚点: 使用率 92.1%(BASE)、在院≈1,846（依赖 L2 Σbed_open≈2,004）、Σ借入=Σ借出

-- ============================ 0205 dwd.emergency_stay ============================
DELETE FROM dwd.emergency_stay
WHERE arrive_at >= timestamptz '2025-01-01' AND arrive_at < timestamptz '2027-01-01';

-- 历史留观：每日≈急诊人次×16%；BASE_DATE(2026-10-28)：在观 36（其中 3 例 >6h，最长 560min）+ 已离观若干
INSERT INTO dwd.emergency_stay (patient_masked, arrive_at, leave_at, stay_minutes, obs_status, triage_level, dept_id)
WITH ed AS (SELECT dept_id FROM pg_temp._sdept WHERE name='急诊科'),
hist AS (
  SELECT s.dt, g.seq,
         (s.dt + (floor(power(pg_temp.h01('es.a.'||s.dt::text||'|'||g.seq),0.8)*1440))::int * interval '1 minute')::timestamptz AS arrive,
         GREATEST(15, round(exp(5.0 + 0.7 *
             sqrt(-2*ln(greatest(pg_temp.h01('es.l1.'||s.dt::text||'|'||g.seq),1e-9)))
             * cos(2*pi()*pg_temp.h01('es.l2.'||s.dt::text||'|'||g.seq)))::numeric))::int AS mins,
         pg_temp.h01('es.s.'||s.dt::text||'|'||g.seq) AS hs,
         pg_temp.h01('es.g.'||s.dt::text||'|'||g.seq) AS ht
  FROM pg_temp._sd s
  CROSS JOIN LATERAL generate_series(1, round(s.em_cnt*0.16)::int) AS g(seq)
  WHERE s.dt < date '2026-10-28'),
today AS (  -- BASE_DATE(2026-10-28) 演示态：09:00 切面，33 例在观(<6h) + 3 例超时(560/465/370min) + 9 例已离观
  SELECT g.seq,
         CASE WHEN g.seq <= 3
              THEN (timestamptz '2026-10-27 23:40' + (g.seq-1)*interval '95 minutes')
              WHEN g.seq <= 36
              THEN (timestamptz '2026-10-28 03:05' + (g.seq-4)*interval '5.5 minutes'
                    + floor(pg_temp.h01('es.t.'||g.seq)*150)*interval '1 minute')
              ELSE (timestamptz '2026-10-28 00:20' + (g.seq-37)*interval '28 minutes') END AS arrive,
         CASE WHEN g.seq <= 36 THEN 'observing' ELSE 'left' END AS st,
         CASE WHEN g.seq <= 36 THEN NULL::int
              ELSE 60 + floor(pg_temp.h01('es.m.'||g.seq)*120)::int END AS mins,
         pg_temp.h01('es.g.t'||g.seq) AS ht
  FROM generate_series(1,45) AS g(seq))
SELECT 'P'||lpad((((('x'||md5(h.arrive::text||'|'||h.seq))::bit(24)::bigint) % 900000)+100000)::text,6,'0'),
       h.arrive,
       h.arrive + h.mins * interval '1 minute',
       h.mins,
       CASE WHEN h.hs < 0.16 THEN 'admitted' ELSE 'left' END,
       CASE WHEN h.ht < 0.02 THEN 1 WHEN h.ht < 0.10 THEN 2 WHEN h.ht < 0.65 THEN 3 ELSE 4 END,
       (SELECT dept_id FROM ed)
FROM hist h
UNION ALL
SELECT 'P'||lpad((((('x'||md5('T'||t.seq::text))::bit(24)::bigint) % 900000)+100000)::text,6,'0'),
       t.arrive,
       CASE WHEN t.st='observing' THEN NULL ELSE t.arrive + t.mins*interval '1 minute' END,
       t.mins,
       t.st::varchar(12),
       CASE WHEN t.ht < 0.02 THEN 1 WHEN t.ht < 0.10 THEN 2 WHEN t.ht < 0.65 THEN 3 ELSE 4 END,
       (SELECT dept_id FROM ed)
FROM today t
ORDER BY 2
ON CONFLICT DO NOTHING;
-- rows: ~5,000 + 45 / 锚点: BASE_DATE 在观 36（>6h=3、max≈560min）、分诊 3/4 级为主

-- ============================ 0206 dwd.charge_day ============================
-- fee_cat 7 桶；药占比/耗占比每月闭环校正到 0.284/0.179（T=out+in 给定，分量缩放无循环）
INSERT INTO dwd.charge_day (date, dept_id, fee_cat, out_fee, in_fee, insurance_fee, self_fee)
WITH cat AS (SELECT * FROM (VALUES
    ('drug',1),('material',2),('exam',3),('treat',4),('surg',5),('bed',6),('other',7)
  ) AS c(fee_cat,srt)),
base AS (  -- 科室×日 门/住收入：抖动按日归一（Σ_d out0=out_amt 精确，门诊人次×300 勾稽不被科室抖动漂移）
  SELECT s.dt, s.y, s.m, d.dept_id, d.drg_in, d.mat_in, d.drg_out, d.mat_out,
         s.out_amt * d.op_n * (0.90 + 0.20*pg_temp.h01('chg.o.'||s.dt::text||'|'||d.dept_id::text))
           / nullif(sum(d.op_n * (0.90 + 0.20*pg_temp.h01('chg.o.'||s.dt::text||'|'||d.dept_id::text))) OVER (PARTITION BY s.dt),0) AS out0,
         s.in_amt  * d.ipf_n * (0.90 + 0.20*pg_temp.h01('chg.i.'||s.dt::text||'|'||d.dept_id::text))
           / nullif(sum(d.ipf_n * (0.90 + 0.20*pg_temp.h01('chg.i.'||s.dt::text||'|'||d.dept_id::text))) OVER (PARTITION BY s.dt),0) AS in0,
         s.other_amt * d.ipf_n * (0.90 + 0.20*pg_temp.h01('chg.h.'||s.dt::text||'|'||d.dept_id::text))
           / nullif(sum(d.ipf_n * (0.90 + 0.20*pg_temp.h01('chg.h.'||s.dt::text||'|'||d.dept_id::text))) OVER (PARTITION BY s.dt),0) AS oth0
  FROM pg_temp._sd s CROSS JOIN pg_temp._sdept d WHERE d.op_sh > 0 OR d.ip_sh > 0),
raw AS (  -- 未校正分量：drug/material 用科室画像，其余桶按固定剖面分剩余
  SELECT b.dt, b.y, b.m, b.dept_id, c.fee_cat,
         b.out0 * CASE c.fee_cat
           WHEN 'drug'     THEN b.drg_out
           WHEN 'material' THEN b.mat_out
           WHEN 'exam'     THEN (1-b.drg_out-b.mat_out)*0.26
           WHEN 'treat'    THEN (1-b.drg_out-b.mat_out)*0.33
           WHEN 'surg'     THEN (1-b.drg_out-b.mat_out)*0.06
           WHEN 'bed'      THEN (1-b.drg_out-b.mat_out)*0.01
           ELSE (1-b.drg_out-b.mat_out)*0.34 END AS ofee,
         b.in0 * CASE c.fee_cat
           WHEN 'drug'     THEN b.drg_in
           WHEN 'material' THEN b.mat_in
           WHEN 'exam'     THEN (1-b.drg_in-b.mat_in)*0.18
           WHEN 'treat'    THEN (1-b.drg_in-b.mat_in)*0.24
           WHEN 'surg'     THEN (1-b.drg_in-b.mat_in)*0.42
           WHEN 'bed'      THEN (1-b.drg_in-b.mat_in)*0.11
           ELSE 0 END AS ifee,      -- B2：'other' 桶 ifee 置 0——该桶 in_fee 专载其他收入（oth），纯住院医疗摊到其余 6 桶
         CASE WHEN c.fee_cat='other' THEN b.oth0 ELSE 0 END AS oth
  FROM base b CROSS JOIN cat c),
tgt AS (  -- 月目标总量：O*=Σout0（人次×300）、I*=Σin0（0.71rev 纯住院）、H*=Σoth0（其他收入≈4%）
  SELECT y, m, sum(out0) AS o_t, sum(in0) AS i_t, sum(oth0) AS h_t FROM base GROUP BY 1, 2),
pre AS (  -- 月度双侧联立校正预聚合：桶池合计（i_ot 自然只含 4 个医疗桶——'other' ifee=0 不贡献）
  SELECT y, m,
         sum(ofee+ifee) FILTER (WHERE fee_cat='drug')     AS dg_t,
         sum(ofee+ifee) FILTER (WHERE fee_cat='material') AS mt_t,
         sum(ofee) FILTER (WHERE fee_cat='drug')     AS o_dg,
         sum(ofee) FILTER (WHERE fee_cat='material') AS o_mt,
         sum(ofee) FILTER (WHERE fee_cat NOT IN ('drug','material')) AS o_ot,
         sum(ifee) FILTER (WHERE fee_cat='drug')     AS i_dg,
         sum(ifee) FILTER (WHERE fee_cat='material') AS i_mt,
         sum(ifee) FILTER (WHERE fee_cat NOT IN ('drug','material')) AS i_ot
  FROM raw GROUP BY y, m),
adj0 AS (
  SELECT p.y, p.m, g.o_t, g.i_t, p.o_dg, p.o_mt, p.o_ot, p.i_dg, p.i_mt, p.i_ot,
         0.284 * (g.o_t + g.i_t + g.h_t) / nullif(p.dg_t,0) AS fd,   -- 药占比对 charge 全口径 T（含其他收入）
         0.179 * (g.o_t + g.i_t + g.h_t) / nullif(p.mt_t,0) AS fm
  FROM pre p JOIN tgt g ON g.y = p.y AND g.m = p.m),
adj AS (  -- 闭式解：fd/fm 钉合并池药耗；fo_o 钉 O*、fo_i 钉 I*（纯住院）；oth 单列载其他收入
          --   ⇒ Σout'=O*、Σin'[非other]=I*、Σin'[other]=H*、Σ总=T——五锚同解
  SELECT y, m, fd, fm,
         (o_t - o_dg * fd - o_mt * fm) / nullif(o_ot,0) AS fo_o,
         (i_t - i_dg * fd - i_mt * fm) / nullif(i_ot,0) AS fo_i
  FROM adj0)
SELECT r.dt, r.dept_id, r.fee_cat,
       round(r.ofee * CASE r.fee_cat WHEN 'drug' THEN a.fd WHEN 'material' THEN a.fm ELSE a.fo_o END, 2) AS out_fee,
       round(r.ifee * CASE r.fee_cat WHEN 'drug' THEN a.fd WHEN 'material' THEN a.fm ELSE a.fo_i END
             + r.oth, 2) AS in_fee,   -- oth>0 仅 'other' 行：in_fee['other']=其他收入
       round((r.ofee+r.ifee) * (0.58 + 0.10*(pg_temp.h01('ci.'||r.dt::text||'|'||r.dept_id::text||r.fee_cat)-0.5)), 2),
       round((r.ofee+r.ifee+r.oth) * (0.30 + 0.06*(pg_temp.h01('cs.'||r.dt::text||'|'||r.dept_id::text||r.fee_cat)-0.5)), 2)
FROM raw r JOIN adj a ON a.y=r.y AND a.m=r.m
WHERE r.ofee * CASE r.fee_cat WHEN 'drug' THEN a.fd WHEN 'material' THEN a.fm ELSE a.fo_o END > 0.005
   OR r.ifee * CASE r.fee_cat WHEN 'drug' THEN a.fd WHEN 'material' THEN a.fm ELSE a.fo_i END + r.oth > 0.005
ON CONFLICT (date, dept_id, fee_cat) DO NOTHING;
-- rows: 731×~20科×7桶 ≈ 10万 / 锚点: 药占比 28.4%、耗占比 17.9%、门诊=人次×300=3,690万、纯住院=0.71rev≈10,530万、总锚 14,800万±1%
-- 注：'other' 桶 in_fee=其他收入（≈4%）、out_fee 仍载门诊其他医疗收费；Σin_fee[非other]=纯住院 → open-item#3

-- ============================ 0207 dwd.insurance_settle_day ============================
-- scale-decision 后两专题均为"月度"口径自洽（8,462结算≈8,120出院+跨月延迟；基金9,860万≈住院侧收入11,110万(纯住院10,508万+其他)×88.8%报销率勾稽）
-- inp 锚定月=2026-10（"本月"峰值月）：settle≈8,462、fund≈9,860万、remote≈486、reject≈0.8%
-- op_fund 锚定月=2026-10：结算 6,248 / 统筹支付 486万 / 账户 326万 / 慢特病 1,846；
--   月度序列 May..Oct=[342,386,412,438,456,486] 对齐契约 §13.1 chart 近6月（本月=Oct）
INSERT INTO dwd.insurance_settle_day (date, dept_id, ins_type, biz_type,
                                      settle_cnt, fund_amt, self_amt, account_amt, reject_amt, remote_cnt, chronic_cnt)
WITH mref AS (  -- 月度归一因子：锚定 2026-10（"本月"），其余月沿 disch/in_amt 曲线同比缩放
  SELECT 8462.0    / nullif(sum(disch_cnt),0) AS kc,
         98600000.0 / nullif(sum(in_amt),0)   AS kf
  FROM pg_temp._sd WHERE y = 2026 AND m = 10),
insd AS (  -- 住院结算日总量：锚定月精确命中；其他月随出院/住院收入曲线；2025 同比基线缩 0.86/0.80
  SELECT s.dt,
         round(s.disch_cnt * (SELECT kc FROM mref) * CASE WHEN s.y=2025 THEN 0.86 ELSE 1 END)::int AS cnt,
         s.in_amt * (SELECT kf FROM mref) * CASE WHEN s.y=2025 THEN 0.80 ELSE 1 END AS fund
  FROM pg_temp._sd s),
tins AS (SELECT * FROM (VALUES  -- 险种 × 人次份额 × 基金份额 × 自付份额（§13.1 分险种表反解）
    ('employee',0.5065,0.5761,0.4534),
    ('resident',0.3836,0.3469,0.4745),
    ('maternity',0.0574,0.0426,0.0409),
    ('severe',  0.0338,0.0290,0.0275),
    ('relief',  0.0187,0.0055,0.0038)) AS t(ins_type, csh, fsh, ssh)),
deptw AS (SELECT d.dept_id, t.ins_type, t.csh, t.fsh, t.ssh,
    CASE t.ins_type
      WHEN 'maternity' THEN CASE d.name WHEN '妇产科' THEN 0.85 WHEN '儿科' THEN 0.15 ELSE 0 END
      ELSE d.ip_n END AS w
  FROM pg_temp._sdept d CROSS JOIN tins t WHERE d.ip_sh > 0),
opfm(y,m,fwan) AS (VALUES  -- 门诊统筹基金月度·万元：近6月(May..Oct)=契约 chart 值，本月=Oct=486；2025×0.79
  (2025,1,237),(2025,2,245),(2025,3,257),(2025,4,270),(2025,5,305),(2025,6,325),
  (2025,7,346),(2025,8,360),(2025,9,384),(2025,10,388),(2025,11,393),(2025,12,399),
  (2026,1,300),(2026,2,310),(2026,3,325),(2026,4,335),(2026,5,342),(2026,6,386),
  (2026,7,412),(2026,8,438),(2026,9,456),(2026,10,486),(2026,11,492),(2026,12,498)),
opfd AS (  -- 门诊统筹日总量：fund 按月归一；settle≈fund/778元（人均口径见 open-item#5）；account∝fund
  SELECT s.dt,
         f.fwan*10000.0 * (0.94 + 0.12*pg_temp.h01('of.d.'||s.dt::text))
           / sum(0.94 + 0.12*pg_temp.h01('of.d.'||s.dt::text)) OVER (PARTITION BY s.y,s.m) AS fund
  FROM pg_temp._sd s JOIN opfm f ON f.y=s.y AND f.m=s.m),
talloc AS (  -- 第一级：日×险种 人次分配（控制各险种日总量精确）
  SELECT i.dt, t.ins_type, i.cnt AS day_cnt, i.fund, t.csh, t.fsh, t.ssh,
         (floor(i.cnt*t.csh) + CASE WHEN row_number() OVER
             (PARTITION BY i.dt ORDER BY i.cnt*t.csh - floor(i.cnt*t.csh) DESC, t.ins_type)
           <= i.cnt - sum(floor(i.cnt*t.csh)) OVER (PARTITION BY i.dt) THEN 1 ELSE 0 END)::int AS tsc
  FROM insd i CROSS JOIN tins t),
cells AS (  -- 第二级：险种日内摊到科室（w 已在险种内归一/近似）；异地按日级池在职工/居民格内分配
  SELECT a.dt, w.dept_id, a.ins_type, a.tsc AS cnt, a.day_cnt, a.fund, a.fsh, a.ssh,
         a.tsc * w.w / nullif(sum(w.w) OVER (PARTITION BY a.dt, a.ins_type),0) AS c_raw,
         CASE WHEN a.ins_type IN ('employee','resident')
              THEN a.day_cnt * 0.0574 * w.w * a.csh/0.8901
                   / nullif(sum(w.w) OVER (PARTITION BY a.dt, a.ins_type),0)
              ELSE 0 END AS r_raw,   -- 0.0574≈486/8,462；csh/0.8901=职工/居民内占比
         a.fund * a.fsh * w.w * (0.92+0.16*pg_temp.h01('is.f.'||a.dt::text||'|'||w.dept_id::text||a.ins_type)) AS fa,
         a.fund * 0.3177 * a.ssh * w.w * (0.92+0.16*pg_temp.h01('is.s.'||a.dt::text||'|'||w.dept_id::text||a.ins_type)) AS sa
         -- 0.3177 = Σself(3132万)/Σfund(9860万)
  FROM talloc a CROSS JOIN deptw w
  WHERE w.w > 0 AND w.ins_type = a.ins_type AND a.tsc > 0),
alloc AS (
  SELECT c.*,
         (floor(c_raw) + CASE WHEN row_number() OVER
             (PARTITION BY dt, ins_type ORDER BY c_raw - floor(c_raw) DESC, c_raw DESC)
           <= cnt - sum(floor(c_raw)) OVER (PARTITION BY dt, ins_type) THEN 1 ELSE 0 END)::int AS sc,
         (floor(r_raw) + CASE WHEN r_raw > 0 AND row_number() OVER
             (PARTITION BY dt ORDER BY r_raw - floor(r_raw) DESC, r_raw DESC)
           <= round(day_cnt*0.0574) - sum(floor(r_raw)) OVER (PARTITION BY dt) THEN 1 ELSE 0 END)::int AS rc
  FROM cells c),
kept AS (  -- 过滤 sc=0 格会带走份额：金额按 (日,险种) 目标在保留格上重归一
  SELECT a.*, a.fund * a.fsh AS f_tgt, a.fund * 0.3177 * a.ssh AS s_tgt,
         sum(a.fa) FILTER (WHERE a.sc > 0) OVER (PARTITION BY a.dt, a.ins_type) AS fa_kept,
         sum(a.sa) FILTER (WHERE a.sc > 0) OVER (PARTITION BY a.dt, a.ins_type) AS sa_kept
  FROM alloc a),
inp AS (
  SELECT dt, dept_id, ins_type, 'inp'::varchar(8) AS bt, sc, rc,
         fa * f_tgt / nullif(fa_kept,0) AS fa,
         sa * s_tgt / nullif(sa_kept,0) AS sa
  FROM kept WHERE sc > 0),
rows AS (
  SELECT * FROM inp
  UNION ALL
  SELECT o.dt, d.dept_id, t.ins_type, 'op_fund',
         round(o.fund/778.0 * t.csh * d.opf_n * (0.92+0.16*pg_temp.h01('of.c.'||o.dt::text||'|'||d.dept_id::text||t.ins_type)))::int,
         0,
         o.fund * t.fsh * d.opf_n * (0.92+0.16*pg_temp.h01('of.f.'||o.dt::text||'|'||d.dept_id::text||t.ins_type)),
         0
  FROM opfd o CROSS JOIN pg_temp._sdept d
       CROSS JOIN (VALUES ('employee',0.55,0.58),('resident',0.45,0.42)) AS t(ins_type,csh,fsh)
  WHERE d.opf_sh > 0)
SELECT r.dt, r.dept_id, r.ins_type, r.bt,
       r.sc,
       round(r.fa, 2),
       round(CASE WHEN r.bt='inp' THEN r.sa
                  ELSE r.fa * 0.30 * (0.9+0.2*pg_temp.h01('rs.'||r.dt::text||'|'||r.dept_id::text||r.ins_type)) END, 2) AS self_amt,
       round(CASE WHEN r.bt='op_fund'
                  THEN r.fa * 0.671 * (0.9+0.2*pg_temp.h01('ra.'||r.dt::text||'|'||r.dept_id::text||r.ins_type))  -- 326/486≈0.671
                  ELSE 0 END, 2) AS account_amt,
       round(r.fa * (0.007 + 0.002*pg_temp.h01('rj.'||r.dt::text||'|'||r.dept_id::text||r.ins_type)), 2) AS reject_amt,
       r.rc AS remote_cnt,   -- inp 日级池内职工/居民格分摊，月度≈8,462×5.74%≈486
       CASE WHEN r.bt='op_fund'
            THEN LEAST(r.sc, round(r.sc * (0.12 + 0.08*pg_temp.h01('ch.'||r.dt::text||'|'||r.dept_id::text||r.ins_type)
                                   + COALESCE(d2.opf_chron,0)))::int)
            ELSE 0 END AS chronic_cnt   -- ≈1,846/6,248≈29.6% 月度
FROM rows r
LEFT JOIN (SELECT dept_id,
                  CASE name WHEN '内分泌科' THEN 0.34 WHEN '心血管内科' THEN 0.30 WHEN '神经内科' THEN 0.21
                            WHEN '中医科' THEN 0.16 WHEN '呼吸与危重症医学科' THEN 0.12
                            WHEN '消化内科' THEN 0.07 ELSE 0 END AS opf_chron
           FROM pg_temp._sdept) d2 ON d2.dept_id = r.dept_id
WHERE r.sc > 0
ON CONFLICT (date, dept_id, ins_type, biz_type) DO NOTHING;
-- rows: inp 731×~15科×5险≈5.5万 + op_fund 731×~12科×2险≈1.8万 ≈ 7.3万
-- 锚点: inp 月度(2026-10)≈8,462人次/9,860万元；op_fund 月度(2026-10)≈6,248人次/486万元/账户326万/慢特病1,846

DROP TABLE IF EXISTS pg_temp._sdept;
DROP TABLE IF EXISTS pg_temp._sd;
-- ============================================================================
-- 行数预算：outpatient_hourly ~40万 / reg_channel_day 3,655 / inpatient_move ~17万
--          bed_state_day ~2.2万 / emergency_stay ~5千 / charge_day ~10万 / insurance ~7.3万
-- ============================================================================
