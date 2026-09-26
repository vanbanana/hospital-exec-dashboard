-- ============================================================================
-- lane: L2 dim-public  种子（确定性 / 幂等 / 锚点量级）
-- 锚点：BASE_DATE='2026-10-28'（scale-decision v2 §0，取代旧 2026-09-26）；种子窗 2025-01-01~2026-12-31
-- 确定性：本文件无 random()/无当前时间函数；伪随机分散一律 md5(<主键/序号>) 取模
--        （公约 §5.6 允许路径），姓名用姓氏×名字池按序号组合（非真实姓名库）。
-- 幂等：全部 INSERT ... ON CONFLICT (...) DO NOTHING；UPDATE 均幂等。
-- 拆分落仓：按 plan §3 段序——[D1]~[D10] → backend/seed/1101_dim_*.sql 段；
--          dict key 行已由 L1 seed/1001_dict.sql 汇编播种（本 lane 值域与 CHECK 同源，
--          不旁路插入；label 修订建议见 open-items.md）。
-- 依赖：L1 sys.dict（枚举语义）、本文件内 dim.campus→building→department→staff。
-- ============================================================================

-- ============================================================================
-- [D1] dim.date —— 2024-01-01 ~ 2027-12-31 全域（1,461 行，公约 §1.5）
-- ============================================================================
INSERT INTO dim.date (date, year, month, day, week, weekday, is_weekend, is_holiday, holiday_name)
SELECT d::date,
       extract(year  from d)::smallint,
       extract(month from d)::smallint,
       extract(day   from d)::smallint,
       extract(week  from d)::smallint,
       extract(isodow from d)::smallint,
       extract(isodow from d) >= 6,
       false, NULL
FROM generate_series('2024-01-01'::date, '2027-12-31'::date, interval '1 day') AS g(d)
ON CONFLICT (date) DO NOTHING;

-- 法定节假日标记：2024/2025 按国务院已发布放假安排；2026/2027 官方安排未核定，暂全
-- false（见 open-items O8，发布后滚动 UPDATE，勿改历史行）。
WITH h(hname, d0, d1) AS (VALUES
  ('元旦',   '2024-01-01'::date, '2024-01-01'::date),
  ('春节',   '2024-02-10'::date, '2024-02-17'::date),
  ('清明',   '2024-04-04'::date, '2024-04-06'::date),
  ('劳动节', '2024-05-01'::date, '2024-05-05'::date),
  ('端午',   '2024-06-10'::date, '2024-06-10'::date),
  ('中秋',   '2024-09-15'::date, '2024-09-17'::date),
  ('国庆',   '2024-10-01'::date, '2024-10-07'::date),
  ('元旦',   '2025-01-01'::date, '2025-01-01'::date),
  ('春节',   '2025-01-28'::date, '2025-02-04'::date),
  ('清明',   '2025-04-04'::date, '2025-04-06'::date),
  ('劳动节', '2025-05-01'::date, '2025-05-05'::date),
  ('端午',   '2025-05-31'::date, '2025-06-02'::date),
  ('中秋',   '2025-10-01'::date, '2025-10-08'::date),
  ('国庆',   '2025-10-01'::date, '2025-10-08'::date)
)
UPDATE dim.date t
   SET is_holiday = true, holiday_name = h.hname
  FROM h
 WHERE t.date BETWEEN h.d0 AND h.d1;
-- rows: 1,461 / 锚点: 2024-01-01~2027-12-31 全域（公约 §1.5 口径）

-- ============================================================================
-- [D2] dim.campus —— 2 行
-- ============================================================================
INSERT INTO dim.campus (code, name, sort) VALUES
  ('main','本部院区',10),
  ('east','东院区',20)
ON CONFLICT (code) DO NOTHING;
-- rows: 2 / 锚点: v1.1 种子（east 预留未启用，无科室挂接）

-- ============================================================================
-- [D3] dim.building —— 7 行（契约 §14.1 四楼锚点原值；其余三栋 L2 自配）
-- ============================================================================
INSERT INTO dim.building (code, name, func_type, campus_code, map_anchor) VALUES
  ('mz' , '门诊楼', 'outpt', 'main', '{"x":32,"y":58}'::jsonb),
  ('wk' , '外科楼', 'inpt' , 'main', '{"x":50,"y":30}'::jsonb),
  ('jz' , '急诊楼', 'emerg', 'main', '{"x":66,"y":42}'::jsonb),
  ('yj' , '医技楼', 'tech' , 'main', '{"x":60,"y":66}'::jsonb),
  ('zyb', '住院部', 'inpt' , 'main', '{"x":44,"y":52}'::jsonb),
  ('tcc', '停车场', 'other', 'main', '{"x":84,"y":76}'::jsonb),
  ('xzl', '行政楼', 'adm'  , 'main', '{"x":18,"y":26}'::jsonb)
ON CONFLICT (code) DO NOTHING;
-- rows: 7 / 锚点: v1.1 种子名录；契约 §14.1 仅下发 mz/wk/jz/yj 四楼

-- ============================================================================
-- [D4] dim.department —— 81 行 = 哨兵×1 + 行政×12(L1) + 业务科室×32(L2) + 医疗组×36(L3)
-- id 显式定值（OVERRIDING SYSTEM VALUE）：1~18 临床（骨科=1 对齐 §14 大屏示例序）、
-- 19~24 平台、25~32 医技、33~44 行政、1001~1036 医疗组（父 id 见 parent_id）
-- 科室名录口径：calibration §4.3 全量契约实体 + 6 必配医技 + 12 行政（plan §4 L2）
-- ============================================================================
INSERT INTO dim.department
  (id, code, name, category, dept_domain, clinic_line, level, parent_id,
   hss_code, staff_quota, campus_code, building_code, sort)
OVERRIDING SYSTEM VALUE
VALUES
  -- ---- 院级哨兵（公约 §5.1：HOSP_ALL / category=hosp / domain=admin / level=0） ----
  ( 0,'HOSP_ALL','全院','hosp','admin',NULL,0,NULL,NULL,NULL,'main',NULL,0),

  -- ---- level=2 临床·内科线（category=med / clinic_line=med） ----
  ( 2,'XNK','心血管内科','med','clinical','med',2,NULL,'03.04', 92,'main','zyb', 2),
  ( 6,'HXWZK','呼吸与危重症医学科','med','clinical','med',2,NULL,'03.01', 76,'main','zyb', 6),
  (10,'XHNK','消化内科','med','clinical','med',2,NULL,'03.02',116,'main','zyb',10),
  ( 8,'SJNK','神经内科','med','clinical','med',2,NULL,'03.03',126,'main','zyb', 8),
  (13,'NFMK','内分泌科','med','clinical','med',2,NULL,'03.07', 94,'main','zyb',13),
  ( 3,'ZLK','肿瘤科','med','clinical','med',2,NULL,'19',118,'main','zyb', 3),
  (16,'PFK','皮肤科','med','clinical','med',2,NULL,'13', 48,'main','zyb',16),
  (17,'ZYK','中医科','med','clinical','med',2,NULL,'50', 78,'main','zyb',17),
  -- ---- level=2 临床·专科线（category=med / clinic_line=special） ----
  ( 5,'EK','儿科','med','clinical','special',2,NULL,'07', 64,'main','zyb', 5),
  (18,'KFK','康复医学科','med','clinical','special',2,NULL,'21', 38,'main','zyb',18),
  -- ---- level=2 临床·外科线（category=surg / clinic_line=surg） ----
  ( 1,'GK','骨科','surg','clinical','surg',2,NULL,'04.03', 84,'main','wk', 1),
  ( 7,'PWK','普通外科','surg','clinical','surg',2,NULL,'04.01',140,'main','wk', 7),
  ( 4,'SJWK','神经外科','surg','clinical','surg',2,NULL,'04.02',104,'main','wk', 4),
  (11,'MNWK','泌尿外科','surg','clinical','surg',2,NULL,'04.04', 84,'main','wk',11),
  (12,'XTXK','心胸外科','surg','clinical','surg',2,NULL,'04.05', 90,'main','wk',12),
  ( 9,'FCK','妇产科','surg','clinical','surg',2,NULL,'05',144,'main','wk', 9),
  (14,'EBHK','耳鼻喉科','surg','clinical','surg',2,NULL,'11', 78,'main','wk',14),
  (15,'YK','眼科','surg','clinical','surg',2,NULL,'10', 70,'main','wk',15),
  -- ---- level=2 平台科室（dept_domain=platform；category 映射见 columns.md） ----
  (19,'JZK','急诊科','med','platform',NULL,2,NULL,'20', 86,'main','jz',19),
  (20,'ZZYXK','重症医学科','med','platform',NULL,2,NULL,'28', 68,'main','wk',20),
  (21,'MZK','麻醉科','tech','platform',NULL,2,NULL,'26', 42,'main','wk',21),
  (22,'JRZX','介入中心','tech','platform',NULL,2,NULL,'32.09', 24,'main','yj',22),
  (23,'NJZX','内镜中心','tech','platform',NULL,2,NULL,NULL, 26,'main','yj',23),
  (24,'CSSD','消毒供应中心','nurse','platform',NULL,2,NULL,NULL, 28,'main','wk',24),
  -- ---- level=2 医技科室（dept_domain=tech；6 必配医技+契约 3 名） ----
  (25,'FSK','放射科','tech','tech',NULL,2,NULL,'32', 66,'main','yj',25),
  (26,'FLK','放疗科','tech','tech',NULL,2,NULL,'32.10', 30,'main','yj',26),
  (27,'HYXK','核医学科','tech','tech',NULL,2,NULL,'32.04', 20,'main','yj',27),
  (28,'JYK','医学检验科','tech','tech',NULL,2,NULL,'30', 84,'main','yj',28),
  (29,'BLK','病理科','tech','tech',NULL,2,NULL,'31', 26,'main','yj',29),
  (30,'SXK','输血科','tech','tech',NULL,2,NULL,NULL, 12,'main','yj',30),
  (31,'YXB','药学部','tech','tech',NULL,2,NULL,NULL, 52,'main','yj',31),
  (32,'CSK','超声医学科','tech','tech',NULL,2,NULL,'32.05', 34,'main','yj',32),
  -- ---- level=1 行政职能部门（dept_domain=admin；门诊部挂门诊楼，余行政楼） ----
  (33,'YB','院办公室','adm','admin',NULL,1,NULL,NULL, 14,'main','xzl',33),
  (34,'YWB','医务部','adm','admin',NULL,1,NULL,NULL, 22,'main','xzl',34),
  (35,'HLB','护理部','adm','admin',NULL,1,NULL,NULL, 16,'main','xzl',35),
  (36,'MZB','门诊部','adm','admin',NULL,1,NULL,NULL, 28,'main','mz' ,36),
  (37,'ZKB','质控办','adm','admin',NULL,1,NULL,NULL, 14,'main','xzl',37),
  (38,'YBB','医保办','adm','admin',NULL,1,NULL,NULL, 16,'main','xzl',38),
  (39,'CWB','财务部','adm','admin',NULL,1,NULL,NULL, 32,'main','xzl',39),
  (40,'RLZY','人力资源部','adm','admin',NULL,1,NULL,NULL, 18,'main','xzl',40),
  (41,'HQBZ','后勤保障部','adm','admin',NULL,1,NULL,NULL, 62,'main','xzl',41),
  (42,'XXK','信息科','adm','admin',NULL,1,NULL,NULL, 22,'main','xzl',42),
  (43,'SBK','设备科','adm','admin',NULL,1,NULL,NULL, 20,'main','xzl',43),
  (44,'ZWK','总务科','adm','admin',NULL,1,NULL,NULL, 44,'main','xzl',44),

  -- ---- level=3 医疗组（每临床科 2 组；id=1000+2×父id-1/2，code=父code_G#） ----
  (1001,'GK_G1','骨科一组','surg','clinical',NULL,3, 1,NULL,NULL,'main','wk',1001),
  (1002,'GK_G2','骨科二组','surg','clinical',NULL,3, 1,NULL,NULL,'main','wk',1002),
  (1003,'XNK_G1','心血管内科一组','med','clinical',NULL,3, 2,NULL,NULL,'main','zyb',1003),
  (1004,'XNK_G2','心血管内科二组','med','clinical',NULL,3, 2,NULL,NULL,'main','zyb',1004),
  (1005,'ZLK_G1','肿瘤科一组','med','clinical',NULL,3, 3,NULL,NULL,'main','zyb',1005),
  (1006,'ZLK_G2','肿瘤科二组','med','clinical',NULL,3, 3,NULL,NULL,'main','zyb',1006),
  (1007,'SJWK_G1','神经外科一组','surg','clinical',NULL,3, 4,NULL,NULL,'main','wk',1007),
  (1008,'SJWK_G2','神经外科二组','surg','clinical',NULL,3, 4,NULL,NULL,'main','wk',1008),
  (1009,'EK_G1','儿科一组','med','clinical',NULL,3, 5,NULL,NULL,'main','zyb',1009),
  (1010,'EK_G2','儿科二组','med','clinical',NULL,3, 5,NULL,NULL,'main','zyb',1010),
  (1011,'HXWZK_G1','呼吸与危重症医学科一组','med','clinical',NULL,3, 6,NULL,NULL,'main','zyb',1011),
  (1012,'HXWZK_G2','呼吸与危重症医学科二组','med','clinical',NULL,3, 6,NULL,NULL,'main','zyb',1012),
  (1013,'PWK_G1','普通外科一组','surg','clinical',NULL,3, 7,NULL,NULL,'main','wk',1013),
  (1014,'PWK_G2','普通外科二组','surg','clinical',NULL,3, 7,NULL,NULL,'main','wk',1014),
  (1015,'SJNK_G1','神经内科一组','med','clinical',NULL,3, 8,NULL,NULL,'main','zyb',1015),
  (1016,'SJNK_G2','神经内科二组','med','clinical',NULL,3, 8,NULL,NULL,'main','zyb',1016),
  (1017,'FCK_G1','妇产科一组','surg','clinical',NULL,3, 9,NULL,NULL,'main','wk',1017),
  (1018,'FCK_G2','妇产科二组','surg','clinical',NULL,3, 9,NULL,NULL,'main','wk',1018),
  (1019,'XHNK_G1','消化内科一组','med','clinical',NULL,3,10,NULL,NULL,'main','zyb',1019),
  (1020,'XHNK_G2','消化内科二组','med','clinical',NULL,3,10,NULL,NULL,'main','zyb',1020),
  (1021,'MNWK_G1','泌尿外科一组','surg','clinical',NULL,3,11,NULL,NULL,'main','wk',1021),
  (1022,'MNWK_G2','泌尿外科二组','surg','clinical',NULL,3,11,NULL,NULL,'main','wk',1022),
  (1023,'XTXK_G1','心胸外科一组','surg','clinical',NULL,3,12,NULL,NULL,'main','wk',1023),
  (1024,'XTXK_G2','心胸外科二组','surg','clinical',NULL,3,12,NULL,NULL,'main','wk',1024),
  (1025,'NFMK_G1','内分泌科一组','med','clinical',NULL,3,13,NULL,NULL,'main','zyb',1025),
  (1026,'NFMK_G2','内分泌科二组','med','clinical',NULL,3,13,NULL,NULL,'main','zyb',1026),
  (1027,'EBHK_G1','耳鼻喉科一组','surg','clinical',NULL,3,14,NULL,NULL,'main','wk',1027),
  (1028,'EBHK_G2','耳鼻喉科二组','surg','clinical',NULL,3,14,NULL,NULL,'main','wk',1028),
  (1029,'YK_G1','眼科一组','surg','clinical',NULL,3,15,NULL,NULL,'main','wk',1029),
  (1030,'YK_G2','眼科二组','surg','clinical',NULL,3,15,NULL,NULL,'main','wk',1030),
  (1031,'PFK_G1','皮肤科一组','med','clinical',NULL,3,16,NULL,NULL,'main','zyb',1031),
  (1032,'PFK_G2','皮肤科二组','med','clinical',NULL,3,16,NULL,NULL,'main','zyb',1032),
  (1033,'ZYK_G1','中医科一组','med','clinical',NULL,3,17,NULL,NULL,'main','zyb',1033),
  (1034,'ZYK_G2','中医科二组','med','clinical',NULL,3,17,NULL,NULL,'main','zyb',1034),
  (1035,'KFK_G1','康复医学科一组','med','clinical',NULL,3,18,NULL,NULL,'main','zyb',1035),
  (1036,'KFK_G2','康复医学科二组','med','clinical',NULL,3,18,NULL,NULL,'main','zyb',1036)
ON CONFLICT (id) DO NOTHING;

SELECT setval(pg_get_serial_sequence('dim.department','id'),
              GREATEST((SELECT max(id) FROM dim.department), 1));

-- 仿真效率基线：确定性散列 0.800~0.999（仅业务科室与医疗组；哨兵/行政 NULL）
UPDATE dim.department
   SET eff_base = 0.800 + ((('x' || substr(md5(code), 1, 6))::bit(24)::int % 200)::numeric / 1000.0)
 WHERE level IN (2, 3) AND eff_base IS NULL;
-- rows: 81 / 锚点: plan §4 L2 ≈80 行（哨兵1+行政12+科室32+医疗组36）

-- ============================================================================
-- [D5] dim.dept_alias —— 别名→dept_id（契约/视图/archive/plan 四源收录）
-- 注：'内科'/'外科' 为 §5.1 病区分布聚合组标签（多科室集合），不可归一入本表，
--     见 open-items O4；'口腔科'/'小儿门诊部' 无落点科室，见 O5。
-- ============================================================================
INSERT INTO dim.dept_alias (alias, dept_id, source) VALUES
  -- contract：§8.1 学科名"骨外科学"归口、§5.1 分布类目、§4.1 实时文案
  ('骨外科',      1,  'contract'),
  ('ICU',         20, 'contract'),
  ('重症监护',    20, 'contract'),
  ('妇产',        9,  'contract'),
  ('肿瘤',        3,  'contract'),
  ('康复',        18, 'contract'),
  -- view：src/components/DepartmentRanking.vue（旧大屏组件短名）
  ('普外科',      7,  'view'),
  ('心内科',      2,  'view'),
  ('呼吸内科',    6,  'view'),
  -- archive：smart-hospital-cockpit 设计稿楼层/科室标签
  ('泌尿科',      11, 'archive'),
  ('药剂科',      31, 'archive'),
  ('检验化验科',  28, 'archive'),
  ('手术室',      21, 'archive'),
  ('综合手术室',  21, 'archive'),
  -- plan：plan.md §4 L2 必配医技简称与主档规范名的映射
  ('检验科',      28, 'plan'),
  ('超声科',      32, 'plan'),
  ('CSSD',        24, 'plan'),
  ('消毒供应室',  24, 'plan')
ON CONFLICT (alias) DO NOTHING;
-- rows: 18 / 锚点: calibration §4.3 归一决议 + 契约/视图/archive 全量异名

-- ============================================================================
-- [D6] dim.staff —— 2,368 在岗（契约 §7.1 锚点：医812/护1046/技202/行政后勤308）
-- 科室定编：契约 dept_staffing 8 行 quota/actual/doc/nurse 原值锚定（重症/急诊/儿科/
--   心内/骨科/呼危/麻醉/康复），其余科室按全院锚点分摊（编制关注名单非全院排序，
--   口径见 columns.md staff_quota 行与 open-items O1）。
-- 职称矩阵：titles 全量对回契约——doc 42/128/312/330、nur 6/68/368/604、
--   tec 4/22/84/92、adm 0/14/62/232；md5 序分档保证高级称职跨科室均匀分散。
-- ============================================================================
WITH alloc AS (
  SELECT * FROM (VALUES
    -- 契约 §7.1 dept_staffing 8 行（doc/nur 原值）
    ('ZZYXK', 16, 42,  0,  0), ('JZK',  24, 54,  0,  0), ('EK',  20, 38, 0, 0),
    ('XNK',   32, 57,  0,  0), ('GK',   28, 53,  0,  0), ('HXWZK',24, 48, 0, 0),
    ('MZK',   30,  6,  0,  0), ('KFK',  10, 24,  0,  0),
    -- 其余临床科室（13）
    ('PWK',   60, 70,  0,  0), ('FCK',  58, 76,  0,  0), ('SJNK', 52, 66, 0, 0),
    ('XHNK',  48, 60,  0,  0), ('ZLK',  48, 62,  0,  0), ('SJWK', 40, 56, 0, 0),
    ('XTXK',  34, 48,  0,  0), ('NFMK', 36, 52,  0,  0), ('MNWK', 32, 46, 0, 0),
    ('EBHK',  30, 42,  0,  0), ('YK',   28, 36,  0,  0), ('ZYK',  28, 44, 0, 0),
    ('PFK',   22, 22,  0,  0),
    -- 平台（3，JZ/ZZ/MZK 已在契约行）
    ('JRZX',   8,  8,  4,  0), ('NJZX', 12, 10,  0,  0), ('CSSD',  0, 18, 4, 0),
    -- 医技（8）
    ('FSK',   28,  2, 30,  0), ('FLK',  10,  4, 12,  0), ('HYXK',  8,  2, 8, 0),
    ('JYK',   14,  0, 64,  0), ('BLK',  10,  0, 14,  0), ('SXK',   0,  0, 10, 0),
    ('YXB',    0,  0, 48,  0), ('CSK',  22,  0,  8,  0),
    -- 行政（12，全 adm）
    ('YB',     0,  0,  0, 14), ('YWB',   0,  0,  0, 22), ('HLB',   0,  0, 0, 16),
    ('MZB',    0,  0,  0, 28), ('ZKB',   0,  0,  0, 14), ('YBB',   0,  0, 0, 16),
    ('CWB',    0,  0,  0, 32), ('RLZY',  0,  0,  0, 18), ('HQBZ',  0,  0, 0, 62),
    ('XXK',    0,  0,  0, 22), ('SBK',   0,  0,  0, 20), ('ZWK',   0,  0, 0, 44)
  ) AS t(dept_code, doc_cnt, nur_cnt, tec_cnt, adm_cnt)
),
unp AS (
  SELECT dept_code, 'doc'::text AS staff_type, doc_cnt AS cnt FROM alloc WHERE doc_cnt > 0
  UNION ALL SELECT dept_code, 'nur', nur_cnt FROM alloc WHERE nur_cnt > 0
  UNION ALL SELECT dept_code, 'tec', tec_cnt FROM alloc WHERE tec_cnt > 0
  UNION ALL SELECT dept_code, 'adm', adm_cnt FROM alloc WHERE adm_cnt > 0
),
seq AS (
  SELECT d.id AS dept_id, u.dept_code, u.staff_type, u.cnt,
         sum(u.cnt) OVER (ORDER BY u.dept_code, u.staff_type
                          ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) - u.cnt AS base
    FROM unp u JOIN dim.department d ON d.code = u.dept_code
),
gen AS (   -- 每名员工一个全局序号（按 dept_code→staff_type 序展开，确定性）
  SELECT s.dept_id, s.dept_code, s.staff_type, s.base + g.k AS gseq
    FROM seq s CROSS JOIN LATERAL generate_series(1, s.cnt) AS g(k)
),
ranked AS ( -- 岗位内按确定性散列排序 → 职称分档不聚堆
  SELECT g.*,
         row_number() OVER (PARTITION BY staff_type
                            ORDER BY md5('L2-staff|' || g.staff_type || '|' || g.gseq)) AS trank
    FROM gen g
),
titled AS (
  SELECT r.*,
    CASE r.staff_type
      WHEN 'doc' THEN CASE WHEN r.trank <=  42 THEN 'senior_pos'
                           WHEN r.trank <= 170 THEN 'senior_sub'
                           WHEN r.trank <= 482 THEN 'middle' ELSE 'junior' END
      WHEN 'nur' THEN CASE WHEN r.trank <=   6 THEN 'senior_pos'
                           WHEN r.trank <=  74 THEN 'senior_sub'
                           WHEN r.trank <= 442 THEN 'middle' ELSE 'junior' END
      WHEN 'tec' THEN CASE WHEN r.trank <=   4 THEN 'senior_pos'
                           WHEN r.trank <=  26 THEN 'senior_sub'
                           WHEN r.trank <= 110 THEN 'middle' ELSE 'junior' END
      ELSE            CASE WHEN r.trank <=  14 THEN 'senior_sub'
                           WHEN r.trank <=  76 THEN 'middle' ELSE 'junior' END
    END AS title_level
    FROM ranked r
)
INSERT INTO dim.staff (code, name, dept_id, staff_type, title, title_level, active)
SELECT 'S' || lpad(row_number() OVER (ORDER BY t.gseq)::text, 5, '0'),
       -- 姓名 = 姓氏[gseq%20] + 名[(gseq*7+3)%32] + 三分之一概率第二字（确定性组合，非真实姓名库）
       (ARRAY['王','李','张','刘','陈','杨','赵','黄','周','吴','徐','孙','马','朱','胡','郭','何','高','林','郑'])
         [1 + (t.gseq % 20)]
       || (ARRAY['伟','强','磊','军','洋','勇','杰','涛','明','超','志','建','国','文','博','华',
                 '平','刚','永','斌','颖','慧','娟','艳','静','丽','芳','娜','敏','秀','英','兰'])
         [1 + ((t.gseq * 7 + 3) % 32)]
       || CASE WHEN t.gseq % 3 = 0
               THEN (ARRAY['华','生','宁','然','辰','远','航','峰','林','泽','欣','怡','楠','溪','岚','珊'])
                    [1 + ((t.gseq / 3) % 16)]
               ELSE '' END,
       t.dept_id, t.staff_type,
       CASE t.title_level
         WHEN 'senior_pos' THEN CASE t.staff_type WHEN 'doc' THEN '主任医师'   WHEN 'nur' THEN '主任护师'   WHEN 'tec' THEN '主任技师'   ELSE '正高级职称' END
         WHEN 'senior_sub' THEN CASE t.staff_type WHEN 'doc' THEN '副主任医师' WHEN 'nur' THEN '副主任护师' WHEN 'tec' THEN '副主任技师' ELSE '副高级职称' END
         WHEN 'middle'     THEN CASE
                                WHEN t.dept_code = 'YXB' AND t.staff_type = 'tec' THEN '主管药师'
                                WHEN t.dept_code = 'YXB' AND t.staff_type = 'doc' THEN '主治医师'
                                WHEN t.staff_type = 'doc' THEN '主治医师'
                                WHEN t.staff_type = 'nur' THEN '主管护师'
                                WHEN t.staff_type = 'tec' THEN '主管技师' ELSE '中级职称' END
         ELSE                     CASE
                                WHEN t.dept_code = 'YXB' AND t.staff_type = 'tec' THEN '药师'
                                WHEN t.staff_type = 'doc' THEN '住院医师'
                                WHEN t.staff_type = 'nur' THEN '护师'
                                WHEN t.staff_type = 'tec' THEN '技师' ELSE '初级职称' END
       END,
       t.title_level, true
  FROM titled t
ON CONFLICT (code) DO NOTHING;

SELECT setval(pg_get_serial_sequence('dim.staff','id'),
              GREATEST((SELECT max(id) FROM dim.staff), 1));
-- rows: 2,368 / 锚点: 契约 §7.1（医812/护1046/技202/行政308；高职占比 12.0%≈正副高 284/2368（契约矩阵口径，scale 复核轮 M8 修正））

-- ============================================================================
-- [D7] department.leader_id 回填（环 FK 收口：先 staff 后回填）
-- level 1/2：本科室最优职称员工（临床科室优先医师）；level 3 医疗组：父科室医师序列
--            第 rn+1 名（rn=组在父科室内序），保证与科主任不同人且均为高年资。
-- ============================================================================
UPDATE dim.department d
   SET leader_id = (
     SELECT s.id FROM dim.staff s
      WHERE s.dept_id = d.id
      ORDER BY (CASE WHEN s.staff_type = 'doc' THEN 0 ELSE 1 END),
               (CASE s.title_level WHEN 'senior_pos' THEN 0
                                   WHEN 'senior_sub' THEN 1
                                   WHEN 'middle'     THEN 2 ELSE 3 END),
               s.code
      LIMIT 1)
 WHERE d.level IN (1, 2) AND d.leader_id IS NULL;

UPDATE dim.department g
   SET leader_id = (
     SELECT s.id FROM dim.staff s
      WHERE s.dept_id = g.parent_id AND s.staff_type = 'doc'
      ORDER BY (CASE s.title_level WHEN 'senior_pos' THEN 0
                                   WHEN 'senior_sub' THEN 1
                                   WHEN 'middle'     THEN 2 ELSE 3 END),
               s.code
      LIMIT 1
     OFFSET (SELECT count(*) FROM dim.department g2
              WHERE g2.parent_id = g.parent_id AND g2.level = 3 AND g2.id < g.id) + 1)
 WHERE g.level = 3 AND g.leader_id IS NULL;

-- ============================================================================
-- [D8] dim.drg_group —— 60 组（CHS-DRG 样例谱系；base_rate 按险种年度统一 6,880.00 元）
-- RW 谱系 0.38~12.86 覆盖契约 §13.1 六段桶（<0.5/0.5-1/1-2/2-5/5-10/≥10 均能产例）；
-- risk_level 按 CHS-DRG 分组器死亡风险分档，low 组支撑低风险组死亡率指标。
-- ============================================================================
INSERT INTO dim.drg_group
  (code, name, adrg_code, mdc, rw, base_rate, region_fee_avg, region_los_avg, risk_level, pay_type)
VALUES
  -- MDCA 神经系统（神经外科/神经内科）
  ('BB21','颅脑肿瘤切除术伴严重并发症','BB2','MDCA', 6.2430,6880.00,136500.00,16.8,'high',    'DRG'),
  ('BB25','颅脑肿瘤切除术不伴并发症',  'BB2','MDCA', 4.8620,6880.00,104200.00,14.2,'midhigh', 'DRG'),
  ('BC29','脑血管病介入治疗',          'BC2','MDCA', 3.5840,6880.00, 92800.00, 9.6,'midhigh', 'DRG'),
  ('BR21','脑出血非手术治疗',          'BR2','MDCA', 1.9240,6880.00, 37200.00,14.6,'midhigh', 'DRG'),
  ('BU21','脑梗死伴并发症',            'BU2','MDCA', 1.4860,6880.00, 24300.00,12.5,'mid',     'DRG'),
  ('BU25','脑梗死不伴并发症',          'BU2','MDCA', 0.9850,6880.00, 17200.00,10.8,'low',     'DRG'),
  -- MDCB 眼（眼科）
  ('CB21','白内障超声乳化吸除+人工晶体植入术','CB2','MDCB', 0.6850,6880.00, 10500.00, 1.8,'low','DRG'),
  -- MDCC 耳鼻咽喉（耳鼻喉科）
  ('DE21','鼻内镜下鼻窦手术',          'DE2','MDCC', 1.2450,6880.00, 21600.00, 5.2,'low',     'DRG'),
  ('DG23','扁桃体/腺样体切除术',       'DG2','MDCC', 0.7240,6880.00, 11800.00, 3.5,'low',     'DRG'),
  -- MDCD 呼吸（呼危）
  ('DB21','肺叶切除术伴并发症',        'DB2','MDCD', 5.1260,6880.00, 88200.00,13.8,'midhigh', 'DRG'),
  ('DB25','肺叶切除术不伴并发症',      'DB2','MDCD', 4.3420,6880.00, 77400.00,12.5,'mid',     'DRG'),
  ('DS31','重症肺炎伴呼吸衰竭',        'DS3','MDCD', 1.8620,6880.00, 33100.00,13.2,'high',    'DRG'),
  ('DS35','肺炎不伴并发症',            'DS3','MDCD', 0.7560,6880.00, 12800.00, 8.0,'low',     'DRG'),
  ('DT21','慢性阻塞性肺病伴并发症',    'DT2','MDCD', 1.1860,6880.00, 19800.00, 9.8,'mid',     'DRG'),
  ('DT25','慢性阻塞性肺病不伴并发症',  'DT2','MDCD', 0.8640,6880.00, 14900.00, 8.4,'low',     'DRG'),
  -- MDCE 循环（心血管内科/心胸外科）
  ('FZ11','心脏移植/心室辅助装置植入', 'FZ1','MDCE',12.8600,6880.00,385000.00,32.5,'high',    'DRG'),
  ('FB21','冠状动脉旁路移植术',        'FB2','MDCE', 8.4620,6880.00,168500.00,17.5,'high',    'DRG'),
  ('FB29','心脏瓣膜置换/成形术',       'FB2','MDCE', 7.1250,6880.00,146800.00,16.2,'high',    'DRG'),
  ('FM31','冠脉支架植入术伴并发症',    'FM3','MDCE', 2.8420,6880.00, 49800.00, 5.8,'mid',     'DRG'),
  ('FM35','冠脉支架植入术不伴并发症',  'FM3','MDCE', 2.3840,6880.00, 44200.00, 4.8,'mid',     'DRG'),
  ('FK21','心脏射频消融术',            'FK2','MDCE', 2.2640,6880.00, 58200.00, 4.2,'mid',     'DRG'),
  ('FT21','急性心肌梗死伴并发症',      'FT2','MDCE', 1.9860,6880.00, 37200.00, 8.8,'high',    'DRG'),
  ('FT25','急性心肌梗死不伴并发症',    'FT2','MDCE', 1.5240,6880.00, 30800.00, 7.4,'mid',     'DRG'),
  ('FU25','心力衰竭不伴并发症',        'FU2','MDCE', 0.9860,6880.00, 18200.00, 9.5,'low',     'DRG'),
  ('FV23','高血压/心绞痛等不伴并发症', 'FV2','MDCE', 0.6240,6880.00, 10600.00, 6.8,'low',     'DRG'),
  -- MDCF 消化（消化内科/普通外科）
  ('GB21','胃恶性肿瘤根治性切除术',    'GB2','MDCF', 4.8260,6880.00, 84500.00,15.2,'midhigh', 'DRG'),
  ('GD21','结直肠恶性肿瘤根治性切除术','GD2','MDCF', 4.2450,6880.00, 77800.00,14.5,'midhigh', 'DRG'),
  ('GB25','胃部分切除术不伴并发症',    'GB2','MDCF', 3.6840,6880.00, 67200.00,12.8,'mid',     'DRG'),
  ('GJ21','上消化道出血内科治疗',      'GJ2','MDCF', 1.1240,6880.00, 18600.00, 8.2,'mid',     'DRG'),
  ('GF23','阑尾切除术',                'GF2','MDCF', 1.0850,6880.00, 15800.00, 5.2,'low',     'DRG'),
  ('GE21','腹股沟疝修补术',            'GE2','MDCF', 0.9240,6880.00, 13800.00, 4.5,'low',     'DRG'),
  ('GK23','消化性溃疡/胃肠炎内科治疗', 'GK2','MDCF', 0.6850,6880.00, 11200.00, 6.2,'low',     'DRG'),
  -- MDCG 肝胆胰（普通外科）
  ('HB21','肝叶切除术',                'HB2','MDCG', 5.6840,6880.00,105800.00,16.2,'high',    'DRG'),
  ('HJ21','急性胰腺炎内科治疗',        'HJ2','MDCG', 1.5860,6880.00, 29200.00,11.5,'midhigh', 'DRG'),
  ('HC23','腹腔镜胆囊切除术',          'HC2','MDCG', 1.3420,6880.00, 21200.00, 5.8,'low',     'DRG'),
  -- MDCH 肌骨（骨科）
  ('IB21','脊柱融合术伴并发症',        'IB2','MDCH', 4.6820,6880.00, 88400.00,13.5,'midhigh', 'DRG'),
  ('IF15','腰椎融合术',                'IF1','MDCH', 3.8450,6880.00, 77800.00,12.8,'mid',     'DRG'),
  ('IC29','髋关节置换术',              'IC2','MDCH', 3.4250,6880.00, 73600.00,11.2,'mid',     'DRG'),
  ('ID21','膝关节置换术',              'ID2','MDCH', 2.9850,6880.00, 66800.00,10.5,'mid',     'DRG'),
  ('IJ21','四肢骨折切开复位内固定术',  'IJ2','MDCH', 1.6850,6880.00, 34800.00, 9.8,'mid',     'DRG'),
  ('IR23','关节镜手术',                'IR2','MDCH', 1.2840,6880.00, 24200.00, 5.5,'low',     'DRG'),
  ('IT23','骨质疏松/骨关节炎内科治疗', 'IT2','MDCH', 0.8240,6880.00, 14800.00, 7.5,'low',     'DRG'),
  -- MDCI 皮肤乳腺（皮肤科/普通外科-乳腺）
  ('JB21','乳腺恶性肿瘤根治性切除术',  'JB2','MDCI', 2.4860,6880.00, 52400.00, 9.8,'mid',     'DRG'),
  ('JW21','皮肤恶性肿瘤切除术',        'JW2','MDCI', 1.8640,6880.00, 38500.00, 8.5,'mid',     'DRG'),
  -- MDCJ 内分泌（内分泌科）
  ('KT21','糖尿病伴严重并发症',        'KT2','MDCJ', 1.1860,6880.00, 20100.00,10.5,'mid',     'DRG'),
  ('KT25','糖尿病不伴并发症',          'KT2','MDCJ', 0.8450,6880.00, 14400.00, 8.8,'low',     'DRG'),
  -- MDCK 泌尿（泌尿外科）
  ('LB21','肾恶性肿瘤根治性切除术',    'LB2','MDCK', 3.6850,6880.00, 73500.00,12.5,'midhigh', 'DRG'),
  ('LD21','经尿道前列腺切除术',        'LD2','MDCK', 1.4850,6880.00, 28400.00, 6.8,'mid',     'DRG'),
  ('LE23','输尿管镜碎石取石术',        'LE2','MDCK', 1.1860,6880.00, 21200.00, 4.5,'low',     'DRG'),
  ('LR23','泌尿系感染内科治疗',        'LR2','MDCK', 0.7850,6880.00, 13600.00, 6.5,'low',     'DRG'),
  -- MDCM 女性生殖（妇产科）
  ('MA21','子宫恶性肿瘤根治性切除术',  'MA2','MDCM', 3.4860,6880.00, 70400.00,12.2,'midhigh', 'DRG'),
  ('MC23','子宫全切/肌瘤切除术',       'MC2','MDCM', 1.8450,6880.00, 34800.00, 7.8,'mid',     'DRG'),
  -- MDCN 妊娠分娩（妇产科）
  ('NB21','剖宫产术',                  'NB2','MDCN', 1.1860,6880.00, 20200.00, 5.5,'low',     'DRG'),
  ('NC23','阴道分娩（顺产）',          'NC2','MDCN', 0.6850,6880.00, 10600.00, 4.2,'low',     'DRG'),
  -- MDCQ 血液/肿瘤（肿瘤科）
  ('QB21','白血病化学治疗',            'QB2','MDCQ', 2.1860,6880.00, 45800.00,12.5,'mid',     'DRG'),
  ('RA29','恶性肿瘤靶向/免疫治疗',     'RA2','MDCQ', 1.5860,6880.00, 30800.00, 6.5,'mid',     'DRG'),
  ('RB23','恶性肿瘤化学治疗',          'RB2','MDCQ', 0.9850,6880.00, 17200.00, 5.8,'mid',     'DRG'),
  -- MDCS 感染 / MDCV 创伤（重症/急诊相关重症组）
  ('SB21','脓毒血症',                  'SB2','MDCS', 2.4860,6880.00, 52400.00,14.5,'high',    'DRG'),
  ('VC21','多发严重创伤救治',          'VC2','MDCV', 3.8650,6880.00, 78600.00,16.8,'high',    'DRG'),
  -- MDCX 其他（康复/未特指住院医疗组）
  ('XR23','康复医疗/其他住院医疗',     'XR2','MDCX', 0.3840,6880.00,  6800.00,12.5,'low',     'DRG')
ON CONFLICT (code) DO NOTHING;
-- rows: 60 / 锚点: plan §4 L2 60 组；risk_level 分布 low20/mid21/midhigh10/high9

-- ============================================================================
-- [D9] dim.ward —— 31 行；bed_open 合计 2,004（=在院1,846÷使用率92.1% 反推锚点）
-- 归口：内科线病区→住院部 zyb，外科线+ICU+手术室→外科楼 wk（§14 告警"外科楼重症
--       监护床位"佐证 ICU 在 wk），留观→急诊楼 jz
-- ============================================================================
INSERT INTO dim.ward (code, name, dept_id, building_code, ward_type, bed_open) VALUES
  ('W_XNK_1','心血管内科一病区',            2,'zyb','general', 90),
  ('W_XNK_2','心血管内科二病区',            2,'zyb','general', 90),
  ('W_HXW_1','呼吸与危重症医学科一病区',    6,'zyb','general', 70),
  ('W_HXW_2','呼吸与危重症医学科二病区',    6,'zyb','general', 50),
  ('W_XHN_1','消化内科一病区',             10,'zyb','general', 60),
  ('W_XHN_2','消化内科二病区',             10,'zyb','general', 50),
  ('W_SJN_1','神经内科一病区',              8,'zyb','general', 80),
  ('W_SJN_2','神经内科二病区',              8,'zyb','general', 60),
  ('W_NFM_1','内分泌科病区',               13,'zyb','general',100),
  ('W_ZLK_1','肿瘤科一病区',                3,'zyb','general', 90),
  ('W_ZLK_2','肿瘤科二病区',                3,'zyb','general', 70),
  ('W_ZYK_1','中医科病区',                 17,'zyb','general', 60),
  ('W_PFK_1','皮肤科病区',                 16,'zyb','general', 20),
  ('W_EK_1' ,'儿科一病区',                  5,'zyb','general', 60),
  ('W_EK_2' ,'儿科二病区',                  5,'zyb','general', 40),
  ('W_KFK_1','康复医学科一病区',           18,'zyb','general', 50),
  ('W_KFK_2','康复医学科二病区',           18,'zyb','general', 46),
  ('W_GK_1' ,'骨科一病区',                  1,'wk' ,'general',100),
  ('W_GK_2' ,'骨科二病区',                  1,'wk' ,'general', 80),
  ('W_PWK_1','普通外科一病区',              7,'wk' ,'general', 80),
  ('W_PWK_2','普通外科二病区',              7,'wk' ,'general', 70),
  ('W_SJW_1','神经外科病区',                4,'wk' ,'general',100),
  ('W_MNW_1','泌尿外科病区',               11,'wk' ,'general', 80),
  ('W_XTX_1','心胸外科病区',               12,'wk' ,'general', 80),
  ('W_FCK_1','妇产科一病区',                9,'wk' ,'general', 80),
  ('W_FCK_2','妇产科二病区',                9,'wk' ,'general', 70),
  ('W_EBH_1','耳鼻喉科病区',               14,'wk' ,'general', 60),
  ('W_YK_1' ,'眼科病区',                   15,'wk' ,'general', 50),
  ('W_ICU_1','重症医学科病区(ICU)',        20,'wk' ,'icu'    , 32),
  ('W_JZLG_1','急诊留观病区',              19,'jz' ,'obs'    , 36),
  ('W_SSS_0','手术室(虚拟病区)',           21,'wk' ,'or'     ,  0)
ON CONFLICT (code) DO NOTHING;
-- rows: 31 / 锚点: Σbed_open=2,004 ↔ 在院1,846/使用率92.1%（plan §5）

-- ============================================================================
-- [D10] dim.device —— 68 台（"单价≥100万"口径锚点，契约 §11.1）
-- 命名纪律：契约 large_equipments 7 行同名设备数量严格对齐（3.0T MRI=2、256排CT=2、
--   高清电子胃肠镜=6、DSA血管造影机=1、直线加速器=1、PET-CT=1、碎石机=1）；
--   同类第二台起用规格差异化命名（口径说明见 open-items O2）。building=使用科室楼。
-- ============================================================================
INSERT INTO dim.device (code, name, dtype, dept_id, building_code, value_yuan, active) VALUES
  -- 放射科（10 台）
  ('DEV_MRI_01','3.0T 核磁共振',          'MRI' ,25,'yj',18500000.00,true),
  ('DEV_MRI_02','3.0T 核磁共振',          'MRI' ,25,'yj',18500000.00,true),
  ('DEV_MRI_03','1.5T 核磁共振',          'MRI' ,25,'yj',12000000.00,true),
  ('DEV_CT_01' ,'256 排 CT',              'CT'  ,25,'yj',16800000.00,true),
  ('DEV_CT_02' ,'256 排 CT',              'CT'  ,25,'yj',16800000.00,true),
  ('DEV_CT_03' ,'64 排 CT',               'CT'  ,25,'yj', 8600000.00,true),
  ('DEV_CT_04' ,'64 排 CT',               'CT'  ,25,'yj', 8200000.00,true),
  ('DEV_DR_01' ,'数字化X线摄影系统(DR)',  'DR'  ,25,'yj', 1850000.00,true),
  ('DEV_DR_02' ,'数字化X线摄影系统(DR)',  'DR'  ,25,'yj', 1650000.00,true),
  ('DEV_DR_03' ,'乳腺钼靶X线机',          'DR'  ,25,'yj', 2400000.00,true),
  -- 急诊科（2 台）
  ('DEV_CT_05' ,'急诊64排CT',             'CT'  ,19,'jz', 8600000.00,true),
  ('DEV_DR_04' ,'急诊数字化X线摄影(DR)',  'DR'  ,19,'jz', 1480000.00,true),
  -- 介入中心（3 台）
  ('DEV_DSA_01','DSA 血管造影机',         'DSA' ,22,'yj',12800000.00,true),
  ('DEV_DSA_02','数字减影血管造影机(DSA)','DSA' ,22,'yj',11500000.00,true),
  ('DEV_DSA_03','杂交手术室DSA系统',      'DSA' ,22,'yj',14200000.00,true),
  -- 放疗科（4 台）
  ('DEV_LINAC_01','直线加速器',           'LINAC',26,'yj',22000000.00,true),
  ('DEV_LINAC_02','螺旋断层放射治疗系统', 'LINAC',26,'yj',26000000.00,true),
  ('DEV_CT_06'  ,'放疗大孔径定位CT',      'CT'  ,26,'yj', 5800000.00,true),
  ('DEV_OTH_02' ,'后装治疗机',            'OTHER',26,'yj', 2600000.00,true),
  -- 核医学科（2 台）
  ('DEV_PETCT_01','PET-CT',               'PETCT',27,'yj',28500000.00,true),
  ('DEV_OTH_03'  ,'SPECT 单光子发射计算机断层显像','OTHER',27,'yj',6800000.00,true),
  -- 内镜中心（8 台）
  ('DEV_ENDO_01','高清电子胃肠镜',        'ENDO',23,'yj', 2800000.00,true),
  ('DEV_ENDO_02','高清电子胃肠镜',        'ENDO',23,'yj', 2800000.00,true),
  ('DEV_ENDO_03','高清电子胃肠镜',        'ENDO',23,'yj', 2800000.00,true),
  ('DEV_ENDO_04','高清电子胃肠镜',        'ENDO',23,'yj', 2800000.00,true),
  ('DEV_ENDO_05','高清电子胃肠镜',        'ENDO',23,'yj', 2800000.00,true),
  ('DEV_ENDO_06','高清电子胃肠镜',        'ENDO',23,'yj', 2800000.00,true),
  ('DEV_ENDO_07','超声内镜系统',          'ENDO',23,'yj', 3600000.00,true),
  ('DEV_ENDO_08','胶囊内镜系统',          'ENDO',23,'yj', 1200000.00,true),
  -- 呼危/耳鼻喉/泌尿 内镜与专科设备（5 台）
  ('DEV_ENDO_09','电子支气管镜系统',      'ENDO', 6,'zyb',2200000.00,true),
  ('DEV_ENDO_10','鼻内镜手术系统',        'ENDO',14,'wk' ,1800000.00,true),
  ('DEV_ENDO_11','输尿管软镜系统',        'ENDO',11,'wk' ,1900000.00,true),
  ('DEV_ESWL_01','体外冲击波碎石机',      'ESWL',11,'wk' ,2400000.00,true),
  ('DEV_OTH_04' ,'钬激光治疗系统',        'OTHER',11,'wk' ,1600000.00,true),
  -- 麻醉科/手术室（3 台）
  ('DEV_ROBOT_01','手术机器人',           'ROBOT',21,'wk',32000000.00,true),
  ('DEV_OTH_05' ,'C型臂X线机',            'OTHER',21,'wk' ,1200000.00,true),
  ('DEV_OTH_06' ,'手术显微镜',            'OTHER',21,'wk' ,2600000.00,true),
  -- 神经外科（3 台）
  ('DEV_OTH_07' ,'神经导航系统',          'OTHER', 4,'wk' ,3200000.00,true),
  ('DEV_OTH_08' ,'神经外科手术显微镜',    'OTHER', 4,'wk' ,3800000.00,true),
  ('DEV_OTH_26' ,'移动式术中三维成像系统(O型臂)','OTHER',4,'wk',8500000.00,true),
  -- 心胸外科（2 台）
  ('DEV_OTH_09' ,'体外循环机(人工心肺机)','OTHER',12,'wk' ,4200000.00,true),
  ('DEV_OTH_10' ,'体外循环机(人工心肺机)','OTHER',12,'wk' ,3800000.00,true),
  -- 重症医学科（4 台）
  ('DEV_DR_05'  ,'床旁数字化X线摄影机(DR)','DR'   ,20,'wk' ,1150000.00,true),
  ('DEV_OTH_11' ,'体外膜肺氧合系统(ECMO)','OTHER',20,'wk' ,2800000.00,true),
  ('DEV_OTH_12' ,'体外膜肺氧合系统(ECMO)','OTHER',20,'wk' ,2800000.00,true),
  ('DEV_OTH_13' ,'主动脉内球囊反搏泵(IABP)','OTHER',20,'wk',1200000.00,true),
  -- 心血管内科（4 台）
  ('DEV_OTH_14' ,'电生理三维标测系统',    'OTHER', 2,'zyb',3600000.00,true),
  ('DEV_OTH_15' ,'血管内超声系统(IVUS)',  'OTHER', 2,'zyb',1800000.00,true),
  ('DEV_OTH_16' ,'主动脉内球囊反搏泵(IABP)','OTHER',2,'zyb',1150000.00,true),
  ('DEV_US_07'  ,'高端心脏彩色多普勒超声','US'   , 2,'zyb',2600000.00,true),
  -- 超声医学科（7 台）
  ('DEV_US_01' ,'高端彩色多普勒超声诊断仪','US'  ,32,'yj', 2400000.00,true),
  ('DEV_US_02' ,'高端彩色多普勒超声诊断仪','US'  ,32,'yj', 2400000.00,true),
  ('DEV_US_03' ,'高端彩色多普勒超声诊断仪','US'  ,32,'yj', 2200000.00,true),
  ('DEV_US_04' ,'高端彩色多普勒超声诊断仪','US'  ,32,'yj', 2200000.00,true),
  ('DEV_US_05' ,'高端彩色多普勒超声诊断仪','US'  ,32,'yj', 2000000.00,true),
  ('DEV_US_06' ,'高端彩色多普勒超声诊断仪','US'  ,32,'yj', 2000000.00,true),
  ('DEV_US_10' ,'便携式高端彩色多普勒超声','US'  ,32,'yj', 1600000.00,true),
  -- 妇产科（3 台）
  ('DEV_US_08' ,'高端妇产彩色多普勒超声', 'US'  , 9,'wk' ,2400000.00,true),
  ('DEV_US_09' ,'高端妇产彩色多普勒超声', 'US'  , 9,'wk' ,2400000.00,true),
  ('DEV_OTH_17' ,'高强度聚焦超声消融系统','OTHER', 9,'wk' ,4200000.00,true),
  -- 医学检验科（3 台）
  ('DEV_OTH_18' ,'全自动生化免疫流水线',  'OTHER',28,'yj', 6500000.00,true),
  ('DEV_OTH_19' ,'全自动生化免疫流水线',  'OTHER',28,'yj', 5800000.00,true),
  ('DEV_OTH_20' ,'液相色谱串联质谱系统',  'OTHER',28,'yj', 3200000.00,true),
  -- 病理科（1 台）
  ('DEV_OTH_21' ,'数字病理切片扫描系统',  'OTHER',29,'yj', 1500000.00,true),
  -- 康复医学科（2 台）
  ('DEV_OTH_22' ,'高压氧舱',              'OTHER',18,'zyb',3800000.00,true),
  ('DEV_OTH_23' ,'下肢康复机器人',        'OTHER',18,'zyb',2200000.00,true),
  -- 眼科（2 台）
  ('DEV_OTH_24' ,'全飞秒激光手术系统',    'OTHER',15,'wk' ,5200000.00,true),
  ('DEV_OTH_25' ,'准分子激光治疗系统',    'OTHER',15,'wk' ,2800000.00,true)
ON CONFLICT (code) DO NOTHING;
-- rows: 68 / 锚点: 契约 §11.1 大型设备=68（dtype 分布 MRI3/CT6/DSA3/ROBOT1/LINAC2/PETCT1/ENDO11/ESWL1/US10/DR5/OTHER25）

-- ============================================================================
-- [D11] dict 供稿（L2 域 key 行，L1 已按公约 §2.4 汇编播种；本段仅登记供稿清单，
--       无 INSERT —— 勿旁路插入，label 修订建议见 open-items.md O10）
-- dept_category: med/surg/tech/nurse/adm/hosp；dept_domain: clinical/platform/tech/admin
-- clinic_line: med/surg/special；building_func: outpt/inpt/emerg/tech/adm/other
-- ward_type: general/icu/obs/or；device_dtype: CT/MRI/DSA/ROBOT/LINAC/PETCT/ENDO/ESWL/US/DR/OTHER
-- title_level: senior_pos/senior_sub/middle/junior；staff_type: doc/nur/tec/adm
-- drg_pay_type: DRG/DIP；risk_level: low/mid/midhigh/high
-- ============================================================================
