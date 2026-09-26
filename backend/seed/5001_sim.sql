-- ============================================================================
-- lane: L9 sim ｜ file: seed/5001_sim.sql
-- 种子框架行：确定性（全字面量，无 random()/now()）、幂等（ON CONFLICT DO NOTHING）
-- 锚点：BASE_DATE = 2026-10-28，virtual_now = 2026-10-28 09:00:00+08
-- 备注：本域缓建（P1），种子仅保证"部署即合法启动"，生成模型参数为框架占位值。
-- ============================================================================

-- sim.clock：单行哨兵。幂等键 id=1。
INSERT INTO sim.clock (id, virtual_now, speed, paused, base_date, updated_at)
VALUES (1, '2026-10-28 09:00:00+08', 1, false, '2026-10-28', '2026-10-28 09:00:00+08')
ON CONFLICT (id) DO NOTHING;

-- sim.profile：关键 key 框架行（缺 key panic 口径 → 键必须先存在；值为骨架，仿真器动工时按生成模型细化）。
-- dept_share 置空对象：科室权重分布属 L2 维度就绪后由生成器展开，此处仅占位保 key。
INSERT INTO sim.profile (key, val, updated_at) VALUES
  ('base_date',        '"2026-10-28"',                          '2026-10-28 09:00:00+08'),
  ('outpt_daily_base', '{"value": 4200, "unit": "人次/日"}',      '2026-10-28 09:00:00+08'),
  ('weekday_factor',   '[1.05, 0.98, 1.00, 1.00, 1.02, 0.90, 0.85]', '2026-10-28 09:00:00+08'),
  ('dept_share',       '{}',                                     '2026-10-28 09:00:00+08'),
  ('scenarios',        '[]',                                     '2026-10-28 09:00:00+08')
ON CONFLICT (key) DO NOTHING;

-- sim.job_log：播种引导记录一行（证明流水线日志链可用；确定性字面量）。
-- 无自然唯一键 → 显式 id=1 + OVERRIDING SYSTEM VALUE 保证幂等。
INSERT INTO sim.job_log (id, job, virtual_date, started_at, finished_at, rows_cnt, job_status, err)
OVERRIDING SYSTEM VALUE
VALUES (1, 'SeedLoader', '2026-10-28', '2026-10-28 09:00:00+08', '2026-10-28 09:00:00+08', 7, 'success', NULL)
ON CONFLICT (id) DO NOTHING;
-- 显式 id 种子后推进序列（audit r2 N2）：下次插入不撞 PK
SELECT setval(pg_get_serial_sequence('sim.job_log','id'), (SELECT COALESCE(max(id),1) FROM sim.job_log));
-- rows: clock 1 / profile 5 / job_log 1 ｜ 锚点: BASE_DATE=2026-10-28（公约 §1.5）
