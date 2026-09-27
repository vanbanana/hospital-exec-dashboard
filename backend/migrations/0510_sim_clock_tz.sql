-- ============================================================================
-- file: migrations/0510_sim_clock_tz.sql  lane: L9 sim
-- ck_clock_window 窗界时区钉死——原表达式 base_date::timestamptz 按会话 TimeZone
-- 解析零点:compose postgres 默认 Etc/UTC 下界点=base_date 00:00Z(东八区 08:00),
-- 放行/拦截语义漂移 8h;改 AT TIME ZONE 钉死上海历,与会话/容器 TZ 无关。
-- ============================================================================
ALTER TABLE sim.clock
  DROP CONSTRAINT ck_clock_window,
  ADD CONSTRAINT ck_clock_window
    CHECK (virtual_now >= (base_date + time '00:00') AT TIME ZONE 'Asia/Shanghai');
