-- ============================================================================
-- lane L8 newdom-hr-research — DDL 段（migrations 0111 / 0214 / 0215 / 0309）
-- 依据：conventions.md §2/§5/§6、plan.md §3/§4 L8a·L8b、database-schema.md v1.1 §9
-- 口径：金额一律 numeric(14,2) 元；率 numeric(7,4) 0~1；日期 date；枚举 CHECK+dict 同源。
-- 分区就绪：四表均不在公约 §5.2 分区预案清单；hr_cost_month / research_paper_period
--          的 PK 仍含时间键（period_start），生产期如需按月 RANGE 可直接启用。
-- 依赖：L1 sys.dict / sys.metric_def；L2 dim.department / dim.staff。
-- ============================================================================

-- 单文件可独立 apply（审计 B1）：schema 幂等创建，汇编器按序执行时为空操作
CREATE SCHEMA IF NOT EXISTS dim;
CREATE SCHEMA IF NOT EXISTS dwd;
CREATE SCHEMA IF NOT EXISTS dws;

-- ----------------------------------------------------------------------------
-- file: migrations/0111_dim_discipline.sql  lane: L8b  verdict: 新建(G6)
-- contract: api-contract §8.1 disciplines 表（name/level/leader）
-- depends : dim.department / dim.staff (L2)
-- partition: 无（实体维表）
-- 说明：id=0 为哨兵行"非重点学科归口"（对齐 §5.1 dept_id=0 约定），供
--       research_project.discipline_id / research_paper_period.discipline_id
--       承接未归口行；哨兵行 discipline_level 必为 NULL（CHECK 钉死）。
-- ----------------------------------------------------------------------------
CREATE TABLE dim.discipline (
  id               bigint       GENERATED ALWAYS AS IDENTITY,
  code             varchar(20)  NOT NULL,            -- 学科码（CARDIO/ORTHO/RESP；哨兵='NONE'）
  name             varchar(64)  NOT NULL,            -- 学科名（契约 disciplines.name；哨兵='非重点学科归口'）
  discipline_level varchar(16),                       -- dict: discipline_level；NULL 仅 id=0 哨兵行
  dept_id          bigint       NOT NULL,             -- 依托科室（重点学科的落地科室）；哨兵行=0
  leader_id        bigint,                            -- 学科带头人 → dim.staff(id)；NULL=未配置（§5.5 理由1）
  sort             int          NOT NULL DEFAULT 0,  -- 展示序
  active           bool         NOT NULL DEFAULT true,
  CONSTRAINT pk_discipline PRIMARY KEY (id),
  CONSTRAINT uq_discipline_code UNIQUE (code),
  CONSTRAINT fk_discipline_department FOREIGN KEY (dept_id)   REFERENCES dim.department (id),
  CONSTRAINT fk_discipline_leader     FOREIGN KEY (leader_id) REFERENCES dim.staff (id),
  CONSTRAINT ck_discipline_level CHECK (
    (id = 0  AND discipline_level IS NULL)
    OR (id <> 0 AND discipline_level IN ('national_key','provincial_key','hospital_key')))
);
COMMENT ON TABLE  dim.discipline IS '重点学科维表（契约 §8.1 disciplines 行的 name/level/leader 源）；id=0 哨兵承接非重点归口';
COMMENT ON COLUMN dim.discipline.discipline_level IS 'dict:discipline_level（national_key/provincial_key/hospital_key）；NULL 只允许 id=0 哨兵行（§5.5 理由3 哨兵语义）';
COMMENT ON COLUMN dim.discipline.dept_id          IS '依托科室；disciplines 行的 projects/funds/papers/transfer 经此映射 metric_value.dept_id 读取';
COMMENT ON COLUMN dim.discipline.leader_id        IS '学科带头人 → dim.staff；契约 leader 文案=name+职称由 API 拼接；NULL=未配置';

-- ----------------------------------------------------------------------------
-- file: migrations/0214_dwd_hr_cost_month.sql  lane: L8a  verdict: 改造
-- contract: api-contract §7.1 stats 人员经费占比 32.5%（STAFF_COST_RATIO 分子）
-- depends : dim.department (L2)
-- partition: 不在 §5.2 清单；PK 已含 period_start，生产期可按月 RANGE
-- 改造点（相对 v1.1 §9 预留）：
--   month 文本列           → period_type varchar(8) + period_start date（公约 §2.3 二元组）
--   staff_cost numeric(14,2) → staff_cost_amt（新列统一 _amt 后缀）
--   dept_id 新增 FK；非负 CHECK；PK=(period_type,period_start,dept_id)
-- ----------------------------------------------------------------------------
CREATE TABLE dwd.hr_cost_month (
  period_type    varchar(8)     NOT NULL DEFAULT 'month', -- 粒度=月；季/年由聚合推导，不冗余行
  period_start   date           NOT NULL,                 -- 期间首日（月粒度=每月 1 号）
  dept_id        bigint         NOT NULL,                 -- 归属科室（level=1 行政 + level=2 业务科室；不含医疗组）
  staff_cost_amt numeric(14,2)  NOT NULL DEFAULT 0,       -- 人员经费·元（工资+津补贴+社保缴费+绩效，HRP 口径）
  CONSTRAINT pk_hr_cost_month PRIMARY KEY (period_type, period_start, dept_id),
  CONSTRAINT fk_hr_cost_month_department FOREIGN KEY (dept_id) REFERENCES dim.department (id),
  CONSTRAINT ck_hr_cost_month_period CHECK (period_type = 'month'),
  CONSTRAINT ck_hr_cost_month_amt    CHECK (staff_cost_amt >= 0)
);
COMMENT ON TABLE  dwd.hr_cost_month IS '科室人员经费月表（HRP 事实）；STAFF_COST_RATIO 分子。分母"业务支出"= dws.hospital_oper_day.cost（L5），本表不冗余';
COMMENT ON COLUMN dwd.hr_cost_month.period_type    IS '固定 ''month''（CHECK 钉死）；二元组为公约 §2.3 统一形态，预留季度快照扩展位';
COMMENT ON COLUMN dwd.hr_cost_month.staff_cost_amt IS '人员经费·元（权责发生制月度计提）；STAFF_COST_RATIO=Σ本列/Σ业务支出，契约 §7.1=32.5%';

-- ----------------------------------------------------------------------------
-- file: migrations/0215_dwd_research_project.sql  lane: L8b  verdict: 新建(G6)
-- contract: api-contract §8.1 stats（在研186/新立42）、project_trend（national/
--           provincial 年度立项序列）、disciplines.projects 列
-- depends : dim.department / dim.staff (L2)、dim.discipline (0111)
-- partition: 不在 §5.2 清单（存量主档式事实，量级小）；如需分区按 apply_year RANGE
-- ----------------------------------------------------------------------------
CREATE TABLE dwd.research_project (
  id            bigint        GENERATED ALWAYS AS IDENTITY,
  project_code  varchar(24)   NOT NULL,               -- 课题编号（RP<apply_year>-<seq>；申报中=RPA-<seq>）
  name          varchar(128)  NOT NULL,               -- 课题名（种子=资助计划名+编号缀；真实期=立项全称）
  project_level varchar(16)   NOT NULL,               -- dict: project_level（national/provincial/hospital/other）
  project_status varchar(12) NOT NULL DEFAULT 'ongoing', -- dict: project_status（applying/ongoing/closed）
  apply_year    smallint,                             -- 立项年度；project_status='applying' 必为 NULL（未批复）
  start_date    date,                                 -- 开题日期；申报中 NULL
  end_date      date,                                 -- 结题日期；仅 closed 行填，ongoing/applying NULL
  funds_amt     numeric(14,2),                        -- 立项批复经费·元；申报中未批复=NULL（§5.5 理由1）
  dept_id       bigint        NOT NULL,               -- 承担科室（level=2）
  discipline_id bigint        NOT NULL DEFAULT 0,     -- 归口重点学科；0=非重点归口（哨兵）
  leader_id     bigint,                               -- 课题负责人 → dim.staff；NULL=未配置
  CONSTRAINT pk_research_project PRIMARY KEY (id),
  CONSTRAINT uq_research_project_code UNIQUE (project_code),
  CONSTRAINT fk_research_project_department FOREIGN KEY (dept_id)       REFERENCES dim.department (id),
  CONSTRAINT fk_research_project_discipline FOREIGN KEY (discipline_id) REFERENCES dim.discipline (id),
  CONSTRAINT fk_research_project_leader     FOREIGN KEY (leader_id)     REFERENCES dim.staff (id),
  CONSTRAINT ck_research_project_level  CHECK (project_level IN ('national','provincial','hospital','other')),
  CONSTRAINT ck_research_project_pstatus CHECK (project_status IN ('applying','ongoing','closed')),
  CONSTRAINT ck_research_project_amt    CHECK (funds_amt IS NULL OR funds_amt >= 0),
  CONSTRAINT ck_research_project_dates  CHECK (end_date IS NULL OR start_date IS NULL OR end_date >= start_date),
  CONSTRAINT ck_research_project_pstatus_year CHECK (
    (project_status = 'applying' AND apply_year IS NULL)
    OR (project_status <> 'applying' AND apply_year IS NOT NULL))
);
COMMENT ON TABLE  dwd.research_project IS '科研课题主档（一行一课题）；RESEARCH_PROJ_CNT=count(project_status=ongoing)、RESEARCH_NEW_CNT=count(apply_year=当年 含各级)、project_trend=按 apply_year×level 聚合';
COMMENT ON COLUMN dwd.research_project.project_level IS 'dict:project_level；project_trend 仅画 national/provincial 两序列（hospital/other 不上图）';
COMMENT ON COLUMN dwd.research_project.apply_year    IS '立项年度（4位年号）；RESEARCH_NEW_CNT 与 project_trend 的归集键；applying 行 NULL';
COMMENT ON COLUMN dwd.research_project.funds_amt     IS '立项批复经费总额·元（立项年度归集口径，非到账流水）；applying 行未批复=NULL；RESEARCH_FUND=Σ 按 apply_year';
COMMENT ON COLUMN dwd.research_project.discipline_id IS '归口重点学科（dim.discipline）；0=非重点归口哨兵；disciplines.projects=count(ongoing 按本列)';

-- ----------------------------------------------------------------------------
-- file: migrations/0309_dws_research_paper_period.sql  lane: L8b  verdict: 新建
-- contract: api-contract §8.1 paper_distribution（Q1~Q4/中文核心）、disciplines.papers
-- depends : dim.discipline (0111)
-- partition: 不在 §5.2 清单；PK 首列 period_type+period_start 就绪
-- 说明：dws 层期表——SCI 分区=quartile∈(q1..q4)，cn_core=中文核心（非 SCI）；
--       SCI_PAPER_CNT=Σ(q1..q4)，PAPER_CNT=Σ 全部 quartile。
-- ----------------------------------------------------------------------------
CREATE TABLE dws.research_paper_period (
  period_type   varchar(8) NOT NULL DEFAULT 'year',   -- 粒度=年（契约论文统计均为年度口径）
  period_start  date       NOT NULL,                  -- 年首日（YYYY-01-01）
  quartile      varchar(8) NOT NULL,                  -- dict: paper_quartile（q1/q2/q3/q4/cn_core）
  discipline_id bigint     NOT NULL DEFAULT 0,        -- 归口重点学科；0=非重点归口哨兵（院级行=全量非归口）
  paper_cnt     int        NOT NULL DEFAULT 0,        -- 该期×分区×学科论文篇数
  CONSTRAINT pk_research_paper_period PRIMARY KEY (period_type, period_start, quartile, discipline_id),
  CONSTRAINT fk_paper_period_discipline FOREIGN KEY (discipline_id) REFERENCES dim.discipline (id),
  CONSTRAINT ck_paper_period_period   CHECK (period_type = 'year'),
  CONSTRAINT ck_paper_period_quartile CHECK (quartile IN ('q1','q2','q3','q4','cn_core')),
  CONSTRAINT ck_paper_period_cnt      CHECK (paper_cnt >= 0)
);
COMMENT ON TABLE  dws.research_paper_period IS '论文分区年度汇总（派生层）；paper_distribution=quartile 全学科行，disciplines.papers=单学科 Σ quartile∈(q1..q4)（SCI 口径，对齐 L5 metric_value SCI_PAPER_CNT 科室行）';
COMMENT ON COLUMN dws.research_paper_period.quartile      IS 'dict:paper_quartile；cn_core=中文核心，SCI=q1..q4 四分区（中科院分区口径，一区 Top）';
COMMENT ON COLUMN dws.research_paper_period.discipline_id IS '0=非重点学科归口（dim.discipline 哨兵行）；API 序列化 0→null/过滤';

-- ----------------------------------------------------------------------------
-- 二级索引（取舍与查询面映射见 indexes.md）
-- ----------------------------------------------------------------------------
CREATE INDEX idx_hr_cost_dept_period        ON dwd.hr_cost_month (dept_id, period_start);
CREATE INDEX idx_discipline_dept            ON dim.discipline (dept_id);
CREATE INDEX idx_discipline_leader          ON dim.discipline (leader_id);
CREATE INDEX idx_discipline_level           ON dim.discipline (discipline_level);
CREATE INDEX idx_research_project_pstatus   ON dwd.research_project (project_status);
CREATE INDEX idx_research_project_year_lv   ON dwd.research_project (apply_year, project_level);
CREATE INDEX idx_research_project_dept      ON dwd.research_project (dept_id);
CREATE INDEX idx_research_project_disc      ON dwd.research_project (discipline_id, project_status);
CREATE INDEX idx_research_project_leader    ON dwd.research_project (leader_id);
CREATE INDEX idx_paper_period_disc_period   ON dws.research_paper_period (discipline_id, period_start);
