-- ============================================================================
-- lane L7 ads  督办工单打开态唯一约束（migration 0420）
-- file: migrations/0420_todo_open_uq.sql  lane: L7  verdict: 幂等加固（P3-EW）
--
-- 为什么独立成文件：契约 §15.2 幂等口径"同一告警同时至多一张打开工单"需
-- 部分唯一索引兜底；0410 已定稿只加不动，按"已建表只加列/表/索引"演进纪律
-- 独立成迁移。写路径 R05 dispatch 撞键 → 33002（error-codes §3 告警与督办段）。
-- ============================================================================

CREATE UNIQUE INDEX IF NOT EXISTS uq_todo_order_open_alert
    ON ads.todo_order (alert_id, alert_occurred_at)
    WHERE todo_status IN ('open','doing');

COMMENT ON INDEX ads.uq_todo_order_open_alert IS 'R05 幂等：同一告警同时至多一张打开工单(open/doing)；撞键→33002（契约 §15.2）';
