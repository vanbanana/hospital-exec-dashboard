-- ============================================================================
-- lane L1 sys-org  延迟 FK 收口（migration 0900，自 0113 重命名）
-- file: migrations/0900_sys_user_dept_fk.sql  lane: L1  verdict: 补挂（§3 定档）
-- 目标库：PG16（自验于 PG15.15，未使用 16 专有特性）
--
-- 为什么独立成文件：sys.user 建于 0003，父表 dim.department 建于 0104——
-- 同文件挂 FK 违反迁移序（audit-pg-standards M2 / implementability M1）。
-- 本文件物理排在全部 01xx dim 迁移（0101~0112）之后执行，完成参照完整性收口。
--
-- 终裁语义（plan §3/§8 定档，覆盖初稿 SET NULL）：
--   约束名：fk_user_department —— §2.3 模板 fk_<子表>_<父表>
--   ON DELETE RESTRICT —— 禁止删除仍被账号引用的科室行。
--   理由：契约序列化 dept_id NULL→院级出参，SET NULL 会把科室被删的账号
--   静默升格为院级权限（越权面）；且全库其余 dept FK 均默认 NO ACTION，
--   SET NULL 是永远不触发的歧义特例。科室停用走 active=false，不走 DELETE。
--
-- dept_id=0 哨兵策略（重要，勿误读为豁免）：
--   dim.department.id=0 是真实入库行（code='HOSP_ALL'、name='全院'），
--   本 FK 对它同样生效——"全院"语义由实体行承载，不是 NULL、不是魔法值。
--   API 序列化层负责把库内 0 映射为 JSON null（契约 §2.1 dept_id null=院级）。
--   RESTRICT 同时保护哨兵行不被删除（全院引用面天然阻止）。
--   列级索引 idx_user_dept_id 已在 0003 就位，本迁移不重复建。
-- ============================================================================

ALTER TABLE sys.user
  ADD CONSTRAINT fk_user_department
  FOREIGN KEY (dept_id)
  REFERENCES dim.department (id)
  ON DELETE RESTRICT;

COMMENT ON CONSTRAINT fk_user_department ON sys.user
  IS 'dept_id→dim.department(id)；0=全院哨兵实体行（非豁免），API 层序列化为 null；RESTRICT 防科室删除升格账号权限（§3 定档）';
