-- ============================================================================
-- lane: L9 sim ｜ 判决：3 表全部「继承·缓建」（公约 §4 #55-#57）
-- 部署说明：sim 域整批末位执行；生产部署可按 env 跳过本域（/sim 路由不注册）
-- 契约锚点：api-contract §15 R14 /sim/*（P3 预留，不向 API 暴露）
-- ============================================================================

-- ----------------------------------------------------------------------------
-- file: migrations/0501_sim_clock.sql  lane: L9  verdict: 继承·缓建
-- contract: api-contract §15 R14   partition: 不适用（单行控制表）
-- ----------------------------------------------------------------------------
CREATE TABLE sim.clock (
  id          smallint      NOT NULL DEFAULT 1,
  virtual_now timestamptz   NOT NULL,
  speed       numeric(10,4) NOT NULL DEFAULT 1,
  paused      boolean       NOT NULL DEFAULT false,
  base_date   date          NOT NULL,
  updated_at  timestamptz   NOT NULL DEFAULT statement_timestamp(),
  CONSTRAINT pk_clock PRIMARY KEY (id),
  CONSTRAINT ck_clock_id CHECK (id = 1),
  CONSTRAINT ck_clock_speed CHECK (speed > 0 AND speed <= 1000),
  CONSTRAINT ck_clock_window CHECK (virtual_now >= base_date::timestamptz)
);

COMMENT ON TABLE  sim.clock            IS '虚拟时钟单行表：全库"今日"语义唯一事实源；更新必须原子表达式 virtual_now = virtual_now + ?*speed，tick 与 POST /sim/clock 互斥（行锁）';
COMMENT ON COLUMN sim.clock.speed      IS '时钟倍率，1=实时；上限 1000（error-codes 35002 非法界）';
COMMENT ON COLUMN sim.clock.base_date  IS '演示基准日=2026-10-28；virtual_now 允许区间下界，上界=播种末日+1 由应用层校验';
COMMENT ON COLUMN sim.clock.updated_at IS '最近一次时钟写入墙钟时刻（审计用，非虚拟时间）';

-- ----------------------------------------------------------------------------
-- file: migrations/0502_sim_job_log.sql  lane: L9  verdict: 继承·缓建
-- contract: api-contract §15 R14   partition: 不适用（控制面小表）
-- ----------------------------------------------------------------------------
CREATE TABLE sim.job_log (
  id           bigint      GENERATED ALWAYS AS IDENTITY,
  job          varchar(40) NOT NULL,
  virtual_date date        NOT NULL,
  started_at   timestamptz NOT NULL,
  finished_at  timestamptz NULL,
  rows_cnt     int         NOT NULL DEFAULT 0,
  job_status   varchar(16) NOT NULL,
  err          text        NULL,
  CONSTRAINT pk_job_log PRIMARY KEY (id),
  CONSTRAINT ck_job_log_status CHECK (job_status IN ('running','success','failed')),
  CONSTRAINT ck_job_log_rows CHECK (rows_cnt >= 0),
  CONSTRAINT ck_job_log_time CHECK (finished_at IS NULL OR finished_at >= started_at)
);

COMMENT ON TABLE  sim.job_log              IS '仿真作业日志：DayGen/Intraday/DayAgg/TodayKpi/AlertScan/Validate/SeedLoader 各作业每批次一行';
COMMENT ON COLUMN sim.job_log.job          IS '作业名（生成器/派生流水线组件标识）';
COMMENT ON COLUMN sim.job_log.virtual_date IS '本次作业处理的虚拟日期（非墙钟）';
COMMENT ON COLUMN sim.job_log.finished_at  IS '完成时刻；NULL=进行中（与 job_status=running 互为印证）';
COMMENT ON COLUMN sim.job_log.err          IS '失败详情；成功行恒 NULL';

CREATE INDEX idx_job_log_virtual_date ON sim.job_log (virtual_date);
CREATE INDEX idx_job_log_job_started  ON sim.job_log (job, started_at);
CREATE INDEX idx_job_log_running      ON sim.job_log (job) WHERE job_status = 'running';

-- ----------------------------------------------------------------------------
-- file: migrations/0503_sim_profile.sql  lane: L9  verdict: 继承·缓建
-- contract: api-contract §15 R14   partition: 不适用（参数键值表）
-- ----------------------------------------------------------------------------
CREATE TABLE sim.profile (
  key        varchar(40)  NOT NULL,
  val        jsonb        NOT NULL,
  updated_at timestamptz  NOT NULL DEFAULT statement_timestamp(),
  CONSTRAINT pk_profile PRIMARY KEY (key)
);

COMMENT ON TABLE  sim.profile     IS '仿真参数键值表：生成模型参数与剧本钩子；启动时校验关键 key 存在且 json 合法，缺 key 直接 panic（v1.1 §7 冻结口径）';
COMMENT ON COLUMN sim.profile.val IS '参数载荷：标量/数组/对象均可，结构由消费方 schema 自定（如 dept_share 为 dept_code→权重 map）';
