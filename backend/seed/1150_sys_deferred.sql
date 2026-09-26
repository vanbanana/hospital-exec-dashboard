-- ============================================================================
-- lane L1 sys-org  种子·延迟段（确定性/幂等）——种子相位Ⅱ末
-- file: seed_2_deferred.sql（拆自原 seed.sql；依赖 L2 dim.department 种子已落库）
--
-- 执行序（跨相位边，audit-implementability M1 收口项）：
--   sys.user 账号行在相位Ⅰ由 seed_1_main.sql 落库（dept_id=NULL）；
--   本文件排在 L2 dim 域种子之后执行，把 3 个科室归属账号回填到真实科室 id。
--   FK fk_user_department（0113，RESTRICT）不阻塞本段——dept_id 可空，
--   且回填值必为已存在的 dim.department(id)。
--
-- 幂等：纯 UPDATE 重跑零副作用；DO 守卫块在 L2 科室未播种（误序执行）时
--       显式 WARNING，替代"文件注释级约定"的静默漏回填。
-- ============================================================================

UPDATE sys.user u SET dept_id = d.id FROM dim.department d
 WHERE u.username = 'dept_leader' AND d.name = '骨科' AND d.level = 2;
UPDATE sys.user u SET dept_id = d.id FROM dim.department d
 WHERE u.username = 'med_director' AND d.name = '医务部' AND d.level = 1;
UPDATE sys.user u SET dept_id = d.id FROM dim.department d
 WHERE u.username = 'fin_director' AND d.name = '财务部' AND d.level = 1;
-- rows: user dept_id 回填 3（dept_leader→骨科/GK=1、med_director→医务部/YWB=34、
--       fin_director→财务部/CWB=39）；锚点: O2 收口、契约 §2.1 科室归属

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM sys.user
              WHERE username IN ('dept_leader','med_director','fin_director')
                AND dept_id IS NULL) THEN
    RAISE WARNING 'sys-org seed_2: 科室归属账号 dept_id 仍为 NULL——'
                  'L2 dim.department 种子未执行或科室名失配（误序执行？）';
  END IF;
END $$;
