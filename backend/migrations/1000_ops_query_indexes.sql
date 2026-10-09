-- Additive indexes for predicates already used by auth and todo queries.
-- The migration runner wraps each file in a transaction; apply in a maintenance
-- window because ordinary CREATE INDEX blocks writes to its target table.
CREATE INDEX idx_audit_log_login_fail_user_time
    ON sys.audit_log (username, created_at DESC)
    WHERE action = 'login_fail'
      AND detail->>'reason' IS DISTINCT FROM 'banned';

CREATE INDEX idx_todo_order_status_id
    ON ads.todo_order (todo_status, id DESC);

CREATE INDEX idx_todo_order_assignee_id
    ON ads.todo_order (assignee_id, id DESC);
