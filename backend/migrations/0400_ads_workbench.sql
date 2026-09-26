-- ============================================================================
-- L6 ads-workbench — 对标/国考/工作台集市 DDL（迁移序号 0305、0306、0405~0407）
-- 事实源：conventions.md v1.0 + schema/plan.md §3/§4-L6 + database-schema.md v1.1 §6/§10
-- 依赖：dim.department（含 id=0 哨兵）/ sys.metric_def / sys.dict（radar_dim、period_type）
CREATE SCHEMA IF NOT EXISTS dws;   -- B1 防线：dws 属主 L5(0301~)，本 lane 0305/0306 紧随但独跑需兜底
CREATE SCHEMA IF NOT EXISTS ads;   -- B1 防线：ads 属主 L7(0401~)，本 lane 0405~0407 乱序/独跑需兜底
-- 通用约定：金额 numeric(14,2) 单位元；率 numeric(7,4) 存 0~1；
--          周期一律 period_type+period_start(date) 二元组（ads.dept_rank_day 例外：
--          继承 v1.1 的 date=as_of 截止日 + period=窗口类型码，见 columns.md）；
--          评分 numeric(6,2) 0~100；方向 direction smallint {-1,0,1}。
-- 写纪律：dws/ads 由派生流水线独占写入（演示期=本种子），仿真器/ETL 禁直写。
-- ============================================================================

-- ----------------------------------------------------------------------------
-- file: migrations/0305_dws_benchmark_peer.sql   lane: L6   verdict: 新建(G17)
-- contract: api-contract §12.1 benchmarks[]（compare 页对标明细）
-- partition: 不列入分区预案（对标快照，行量极小）
-- ----------------------------------------------------------------------------
CREATE TABLE dws.benchmark_peer (
  period_type   varchar(8)    NOT NULL,              -- 周期粒度（dict:period_type 子集）
  period_start  date          NOT NULL,              -- 周期首日（year→YYYY-01-01）
  metric_code   varchar(40)   NOT NULL,              -- 指标码 FK；值量纲随 metric_def.value_kind
  name          varchar(64)   NOT NULL,              -- 契约展示名（含口径括注，如"年门急诊量（万人次）"）
  ours_val      numeric(18,4) NOT NULL,              -- 本院值（规范量纲：cnt=个 / rate=0~1 / days=天 / idx=原值）
  region_avg    numeric(18,4) NOT NULL,              -- 区域同级均值（同量纲）
  bench_val     numeric(18,4) NOT NULL,              -- 标杆值（同量纲）
  CONSTRAINT pk_benchmark_peer PRIMARY KEY (period_type, period_start, metric_code),
  CONSTRAINT fk_benchmark_peer_metric FOREIGN KEY (metric_code) REFERENCES sys.metric_def(code),
  CONSTRAINT ck_benchmark_peer_period  CHECK (period_type IN ('month','quarter','year')),
  CONSTRAINT ck_benchmark_peer_nonneg  CHECK (ours_val >= 0 AND region_avg >= 0 AND bench_val >= 0)
);
COMMENT ON TABLE  dws.benchmark_peer IS '院级对标明细：compare benchmarks[] 唯一事实源；gap=ours−region 由 API 按 value_kind+disp_unit 换算后出参，不落库（公约 §6.3）';
COMMENT ON COLUMN dws.benchmark_peer.name IS '契约 §12.1 benchmarks[].name 原样落列——口径括注（"年…/万人次"）不可由 metric_def.name 机械拼装，G17 列集外加列（open-items O4）';
COMMENT ON COLUMN dws.benchmark_peer.ours_val IS '规范量纲存储：率 0~1（0.284 非 28.4）、人次原值（108900 非 10.89 万）；万/百分号由 API 层换算；种子为 dws 全年窗派生表达式（审计 M7 + 裁决书 §6.5：不直写契约字面，年口径=全年 Σ）';
CREATE INDEX idx_benchmark_peer_metric ON dws.benchmark_peer (metric_code); -- FK 列索引惯例（公约 §5.3）；单指标跨期对标史

-- ----------------------------------------------------------------------------
-- file: migrations/0306_dws_exam_indicator.sql   lane: L6   verdict: 新建(G20)
-- contract: api-contract §13.1 topic=exam（stats 预估分+四维得分率 / chart 达标率序列 / table 重点指标）
-- partition: 不列入分区预案（国考指标集市，行量极小）
-- ----------------------------------------------------------------------------
CREATE TABLE dws.exam_indicator (
  period_type   varchar(8)    NOT NULL,              -- year=年度考核快照行；month=达标率月度序列行
  period_start  date          NOT NULL,              -- 周期首日（year→YYYY-01-01、month→月初）
  code          varchar(40)   NOT NULL,              -- 行标识：指标行=对应 metric_code；聚合行=TOTAL_SCORE/DIM_*/TARGET_RATE
  name          varchar(64)   NOT NULL,              -- 展示名（契约 stats.label / table.rows[].name）
  full_score    int           NULL,                  -- 指标满分·分（率类聚合行无满分=NULL）
  score_rate    numeric(7,4)  NULL,                  -- 得分率/达标率 0~1；API ×100 出 %
  direction     smallint      NOT NULL DEFAULT 0,    -- 趋势方向 1=↑ / 0=→ / -1=↓（契约 trend 符号映射）
  owner_dept_id bigint        NULL,                  -- 责任部门 FK；聚合行多部门共担=NULL
  metric_code   varchar(40)   NULL,                  -- 对应 sys.metric_def 指标码（国考定性项无对应指标=NULL，公约 §3.2）
  CONSTRAINT pk_exam_indicator PRIMARY KEY (period_type, period_start, code),
  CONSTRAINT fk_exam_indicator_metric FOREIGN KEY (metric_code)   REFERENCES sys.metric_def(code),
  CONSTRAINT fk_exam_indicator_owner  FOREIGN KEY (owner_dept_id) REFERENCES dim.department(id),
  CONSTRAINT ck_exam_indicator_period CHECK (period_type IN ('month','year')),
  CONSTRAINT ck_exam_indicator_rate   CHECK (score_rate IS NULL OR (score_rate >= 0 AND score_rate <= 2)),
  CONSTRAINT ck_exam_indicator_full   CHECK (full_score IS NULL OR full_score > 0),
  CONSTRAINT ck_exam_indicator_dir    CHECK (direction IN (-1, 0, 1))
);
COMMENT ON TABLE  dws.exam_indicator IS '三级公立医院绩效考核指标集市：年度指标行（满分/得分率/趋势/责任部门）+ 聚合行（TOTAL_SCORE 预估总分、DIM_* 四维得分率、TARGET_RATE 月度达标率）；topics·exam 唯一事实源';
COMMENT ON COLUMN dws.exam_indicator.code IS '行标识非契约字段：指标行取对应 metric_code 便于溯源；聚合行为固定保留码（TOTAL_SCORE/TARGET_RATE/DIM_QUALITY/DIM_EFFICIENCY/DIM_GROWTH/DIM_SATISFACTION）';
COMMENT ON COLUMN dws.exam_indicator.score_rate IS '0~1 规范量纲；EXAM_SCORE 出参=TOTAL_SCORE 行 score_rate×full_score（0.7860×1000=786 分）；得分率/达标率 API ×100';
COMMENT ON COLUMN dws.exam_indicator.direction IS '本列=趋势方向（公约 §2.4 exam_trend 不设 dict，API 渲染 ↑/→/↓）；与 sys.metric_def.direction（好坏极性）语义不同，勿混用';
CREATE INDEX idx_exam_indicator_code_series ON dws.exam_indicator (code, period_type, period_start); -- 单码时间序列（TARGET_RATE 月度达标率 chart、单指标历史）
CREATE INDEX idx_exam_indicator_metric      ON dws.exam_indicator (metric_code);                     -- FK 列索引惯例（公约 §5.3）
CREATE INDEX idx_exam_indicator_owner       ON dws.exam_indicator (owner_dept_id);                   -- FK 列索引惯例；按责任部门筛指标

-- ----------------------------------------------------------------------------
-- file: migrations/0405_ads_dept_rank_day.sql   lane: L6   verdict: 继承
-- contract: api-contract §14.1 dept_ranking[] / §12.1 compare 科室表 rank 列
-- partition: 不列入分区预案（快照表，每窗口 ~20 行）
-- ----------------------------------------------------------------------------
CREATE TABLE ads.dept_rank_day (
  date       date          NOT NULL,               -- 快照截止日 as_of（d30 窗口=[date−29, date]）
  period     varchar(8)    NOT NULL DEFAULT 'd30', -- 窗口类型码（dict:period_type 子集；v1.1 列名继承）
  dept_id    bigint        NOT NULL,               -- level=2 科室（med/surg；哨兵行不参与排名）
  cmi        numeric(8,4)  NULL,                   -- 窗口 CMI=Σrw/Σ入组病例；无入组=NULL
  surg_cnt   int           NOT NULL DEFAULT 0,     -- 窗口手术台次（status<>'sched'）
  alos       numeric(6,2)  NULL,                   -- 窗口平均住院日·天；无出院=NULL
  profit     numeric(14,2) NULL,                   -- DRG盈亏·元（窗口 Σdrg_profit；可负不加 CHECK）
  eff_score  numeric(6,2)  NULL,                   -- 科室运行效率分 0~100（schema §10 公式 v2，R3 调权）
  eff_delta  numeric(5,2)  NULL,                   -- 较前一同型窗口分差（首期=NULL；可负）
  rank_no    int           NOT NULL,               -- 当期名次=eff_score 降序（NULL 沉底）
  CONSTRAINT pk_dept_rank_day PRIMARY KEY (date, period, dept_id),
  CONSTRAINT fk_dept_rank_day_dept FOREIGN KEY (dept_id) REFERENCES dim.department(id),
  CONSTRAINT ck_dept_rank_day_period CHECK (period IN ('d30','month')),
  CONSTRAINT ck_dept_rank_day_nonneg CHECK (
    surg_cnt >= 0 AND rank_no >= 1
    AND (cmi IS NULL OR cmi >= 0) AND (alos IS NULL OR alos >= 0)),
  CONSTRAINT ck_dept_rank_day_score  CHECK (eff_score IS NULL OR (eff_score >= 0 AND eff_score <= 100))
);
COMMENT ON TABLE  ads.dept_rank_day IS '科室效能排名快照：窗口聚合 + §10 公式 v2（权重 cmi.25/surg.02/ialos.01/bed.67/profit.20，R3 审计调权）实算 eff_score；/screen dept_ranking（d30）与 compare 科室表 rank 出参源';
COMMENT ON COLUMN ads.dept_rank_day.date IS '窗口截止日（as_of）；与 dws.drg_dept_period(period_type=''d30'', period_start=as_of−29) 同窗口';
COMMENT ON COLUMN ads.dept_rank_day.period IS '窗口类型码（语义=period_type，v1.1 列名保留）；演示期仅 ''d30''';
COMMENT ON COLUMN ads.dept_rank_day.profit IS 'DRG盈亏·元（=窗口 Σdws.dept_oper_day.drg_profit，对齐 §14.1 profit 字段）；eff_score 公式中 norm(profit) 亦取本列口径';
CREATE INDEX idx_dept_rank_day_period_date ON ads.dept_rank_day (period, date DESC); -- 最新快照期定位（screen dept_ranking / compare rank 取 max(date)）
CREATE INDEX idx_dept_rank_day_dept        ON ads.dept_rank_day (dept_id);           -- FK 列索引惯例；单科室排名史

-- ----------------------------------------------------------------------------
-- file: migrations/0406_ads_work_item.sql   lane: L6   verdict: 新建(G2)
-- contract: api-contract §3.5 home/progress（院级重点工作进度）
-- partition: 不列入分区预案（行政填报行，行量极小）
-- ----------------------------------------------------------------------------
CREATE TABLE ads.work_item (
  id              bigint       GENERATED ALWAYS AS IDENTITY,
  name            varchar(64)  NOT NULL,               -- 工作项名称
  progress_pct    int          NOT NULL DEFAULT 0,     -- 完成进度 0~100（§1.3 _pct 唯一白名单场景）
  workitem_status varchar(16)  NOT NULL DEFAULT 'pending', -- pending=待启动 / doing=进行中 / done=已完成
  owner_dept_id   bigint       NULL,                   -- 牵头部门 FK；院级共担=NULL
  period_type     varchar(8)   NOT NULL DEFAULT 'month',
  period_start    date         NOT NULL,               -- 填报周期首日（progress 为该期快照值）
  created_at      timestamptz  NOT NULL,
  updated_at      timestamptz  NOT NULL,
  CONSTRAINT pk_work_item PRIMARY KEY (id),
  CONSTRAINT uq_work_item_name_period UNIQUE (name, period_type, period_start),
  CONSTRAINT fk_work_item_owner FOREIGN KEY (owner_dept_id) REFERENCES dim.department(id),
  CONSTRAINT ck_work_item_progress CHECK (progress_pct BETWEEN 0 AND 100),
  CONSTRAINT ck_work_item_status   CHECK (workitem_status IN ('pending','doing','done')),
  CONSTRAINT ck_work_item_period   CHECK (period_type IN ('month','quarter','year'))
);
COMMENT ON TABLE  ads.work_item IS '院级重点工作进度（home/progress 供数）：行政填报/里程碑口径，非派生指标';
COMMENT ON COLUMN ads.work_item.workitem_status IS '契约 status 中文艺名映射：进行中→doing、待启动→pending；dict_type=workitem_status 待登记（open-items O1，联动 L1-O3）';
COMMENT ON COLUMN ads.work_item.period_start IS '进度快照所属填报期首日；同事项跨期续报以 (name,period_type,period_start) 唯一';
CREATE INDEX idx_work_item_period ON ads.work_item (period_type, period_start); -- home/progress 当期列表
CREATE INDEX idx_work_item_owner  ON ads.work_item (owner_dept_id);             -- FK 列索引惯例；按部门筛工作项

-- ----------------------------------------------------------------------------
-- file: migrations/0407_ads_radar_score.sql   lane: L6   verdict: 新建(G17b)
-- contract: api-contract §12.1 radar（本院 vs 区域同级均值 6 维能力）
-- partition: 不列入分区预案（快照表，6 行/期）
-- ----------------------------------------------------------------------------
CREATE TABLE ads.radar_score (
  period_type   varchar(8)   NOT NULL DEFAULT 'month',
  period_start  date         NOT NULL,               -- 周期首日
  radar_dim     varchar(16)  NOT NULL,               -- dict:radar_dim 六维键
  ours_score    numeric(6,2) NOT NULL,               -- 本院得分 0~100
  region_score  numeric(6,2) NOT NULL,               -- 区域同级均值 0~100
  CONSTRAINT pk_radar_score PRIMARY KEY (period_type, period_start, radar_dim),
  CONSTRAINT ck_radar_score_dim    CHECK (radar_dim IN ('scale','revenue','efficiency','quality','satisfaction','research')),
  CONSTRAINT ck_radar_score_period CHECK (period_type IN ('month','quarter','year')),
  CONSTRAINT ck_radar_score_range  CHECK (ours_score BETWEEN 0 AND 100 AND region_score BETWEEN 0 AND 100)
);
COMMENT ON TABLE  ads.radar_score IS '六维能力指数双序列：RADAR_CAP_SCORE 指标唯一事实源（专属表，metric_value 不双写）；indicators[].max=100 为契约固定值不落库';
COMMENT ON COLUMN ads.radar_score.radar_dim IS 'dict:radar_dim 值域（scale/revenue/efficiency/quality/satisfaction/research），出参顺序取 dict.sort';
