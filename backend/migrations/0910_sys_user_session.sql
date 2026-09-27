-- 0910 sys.user_session 会话表 + 演示账号口令重置(EA)
CREATE TABLE sys.user_session (
  id         bigint GENERATED ALWAYS AS IDENTITY,
  token_hash varchar(64)  NOT NULL,
  user_id    bigint       NOT NULL,
  created_at timestamptz  NOT NULL DEFAULT now(),
  expires_at timestamptz  NOT NULL,
  revoked_at timestamptz  NULL,
  ip         inet         NULL,
  user_agent varchar(200) NULL,
  CONSTRAINT pk_user_session PRIMARY KEY (id),
  CONSTRAINT uq_user_session_token UNIQUE (token_hash),
  CONSTRAINT fk_user_session_user FOREIGN KEY (user_id) REFERENCES sys."user"(id) ON DELETE CASCADE
);
CREATE INDEX idx_user_session_expires ON sys.user_session (expires_at);
CREATE INDEX idx_user_session_user    ON sys.user_session (user_id);

UPDATE sys."user" SET password_hash='$2y$10$hwzDRwlqEjsh35Of7SN5bOuzxQIb844PNnSokFl8665FK3Ge4vEPi'
 WHERE username IN ('president','ops_director','dept_leader');
