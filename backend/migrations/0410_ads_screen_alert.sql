-- ============================================================================
-- L7 ads-screen-alert — 大屏/告警集市 DDL（迁移序号 0401~0404 + 0408）
-- 事实源：conventions.md v1.0 + schema/plan.md §3/§4-L7 + database-schema.md v1.1 §5/§8/§9
-- 契约：api-contract §3.6(home/alerts) §3.7(R04~R07) §13.2(settings thresholds) §14.1(screen snapshot)
-- 依赖：sys.metric_def / sys.dict(alert_level·alert_status·alert_source·todo_status·badge_level·
--        campus_status_type) / dim.department(含 id=0 哨兵) / dim.building / dim.staff / sys.user
-- 通用约定：率 numeric(7,4) 存 0~1，campus_status.metrics 率键同归 0~1（audit N3 收敛，
--          API 按 key→value_kind 冻结映射对 *_rate 键 ×100 出参，见 columns.md §3 与 O5）；
--          枚举列一律 dict 值域 CHECK；alert_event 为分区就绪复合 PK (id, occurred_at)。
-- 写纪律：dws/ads 由派生流水线独占写入（演示期=本种子），仿真器/ETL 禁直写（公约 §2.3）。
-- ============================================================================

CREATE SCHEMA IF NOT EXISTS ads;

-- ----------------------------------------------------------------------------
-- file: migrations/0401_ads_alert_rule.sql   lane: L7   verdict: 改造(+eval_json)
-- contract: api-contract §13.2 settings.thresholds[]（7 行映射见 README 映射表）
-- depends : sys.metric_def (L1 0002；CRIT_*/STOCK_TURN_DAYS/EQUIP_RUN_RATE 行由 L8 供稿，见 open-items O3)
-- partition: 不适用（规则元数据，行量极小）
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS ads.alert_rule (
  code        varchar(40)  NOT NULL,                 -- 规则码（契约 §3.6 rule_code / §13.2 行标识）
  name        varchar(64)  NOT NULL,                 -- 规则名（settings 列表 title 兜底；正式 name 由 metric_def.name 出）
  alert_level varchar(8)   NOT NULL,                 -- dict: alert_level（urgent/major/minor）
  metric_code varchar(40)  NULL,                     -- 被测指标 FK；scenario 型规则无指标=NULL
  op          varchar(4)   NULL,                     -- 比较符 > < >= <= = !=；scenario 型 NULL
  threshold   numeric(18,4) NULL,                    -- 阈值（规范量纲：率 0~1、天数、元/人）；scenario 型 NULL
  scope       varchar(12)  NOT NULL DEFAULT 'hospital', -- 扫描粒度 hospital/dept/building
  eval_json   jsonb        NULL,                     -- 窗口表达式 {window,agg,basis,...}；scenario 型载注入参数
  dedup_min   int          NOT NULL DEFAULT 60,      -- 去重分钟：上次关闭后 N 分钟内同目标不再触发
  drill_route jsonb        NULL,                     -- 下钻路由 {page,params}（供 workbench 跳端，契约 §3.7 R04~R06 伴生）
  source      varchar(12)  NOT NULL DEFAULT 'rule',  -- dict: alert_source 子集（rule=指标扫描 / scenario=情景注入）
  enabled     boolean      NOT NULL DEFAULT true,    -- settings 页启用位（契约 enabled；EQUIP_RUN_LOW 契约 enabled=false）
  created_at  timestamptz  NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at  timestamptz  NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT pk_alert_rule PRIMARY KEY (code),
  CONSTRAINT fk_alert_rule_metric FOREIGN KEY (metric_code) REFERENCES sys.metric_def(code),
  CONSTRAINT ck_alert_rule_level  CHECK (alert_level IN ('urgent','major','minor')),
  CONSTRAINT ck_alert_rule_op     CHECK (op IS NULL OR op IN ('>','<','>=','<=','=','!=')),
  CONSTRAINT ck_alert_rule_scope  CHECK (scope IN ('hospital','dept','building')),
  CONSTRAINT ck_alert_rule_source CHECK (source IN ('rule','scenario')),
  CONSTRAINT ck_alert_rule_dedup  CHECK (dedup_min >= 0),
  CONSTRAINT ck_alert_rule_eval   CHECK (eval_json IS NULL OR jsonb_typeof(eval_json) = 'object'),
  -- 结构自洽：rule 型必有指标三元组；scenario 型的注入参数必须落在 eval_json
  CONSTRAINT ck_alert_rule_ruled  CHECK (source = 'scenario' OR (metric_code IS NOT NULL AND op IS NOT NULL AND threshold IS NOT NULL)),
  CONSTRAINT ck_alert_rule_scen   CHECK (source = 'rule' OR eval_json IS NOT NULL)
);
COMMENT ON TABLE  ads.alert_rule IS '告警规则目录：11 条 rule（指标扫描）+ 2 条 scenario（情景注入器）；settings/thresholds 7 行=本表 7 条 rule 行的序列化视图（映射见 README）';
COMMENT ON COLUMN ads.alert_rule.eval_json IS '结构化评估参数，承接契约 rule 文案（"连续 3 日 > 95%"）不可文本化部分：window=ISO8601 回看窗，agg=latest/avg/max/count/consecutive_days/rate/yoy，scenario 型为 {inject_key,params}';
COMMENT ON COLUMN ads.alert_rule.threshold IS '规范量纲：率存 0~1（0.95 非 95）、天数原值、金额元；API ×100/加单位渲染契约 §13.2 rule 文案';
COMMENT ON COLUMN ads.alert_rule.dedup_min IS '告警去重（关闭后抑制窗）；打开态去重由 alert_event 部分唯一索引兜底（同规则同目标唯一打开态）';

CREATE INDEX IF NOT EXISTS idx_alert_rule_enabled ON ads.alert_rule (enabled, source);  -- 扫描器规则面装载 / settings 列表（source='rule'）
CREATE INDEX IF NOT EXISTS idx_alert_rule_metric  ON ads.alert_rule (metric_code);    -- metric_def FK 索引惯例（公约 §5.3）

-- ----------------------------------------------------------------------------
-- file: migrations/0402_ads_alert_event.sql   lane: L7   verdict: 继承+分区就绪
-- contract: api-contract §3.6 home/alerts 5 列 / §14.1 screen alerts.list + status.alert_open
--           / §3.7 R04 ack·R05 dispatch·R06 close 生命周期
-- depends : ads.alert_rule / dim.department / dim.building / sys.user(ack_by)
-- partition: 生产期按月 RANGE(occurred_at)；>1y 归档 ads.alert_event_archive（预案）。
--            PK 复合 (id,occurred_at) 是分区挂接前提（公约 §5.2）；
--            todo_order 以 (alert_id,alert_occurred_at) 复合 FK 对齐（见 open-items O4）。
--             ✅ 分区去重决策（audit M6，规模裁决轮定稿，open-items O10）：
--             "打开态唯一"在分区表上不可由 PG 唯一索引保证（须含分区键），拆为两层——
--             ① 库级幂等去重：uq_alert_event_dedup (rule_code,target_type,target_id,
--                occurred_at) 含分区键 → 分区合法，防同规则同目标同时刻重复落库；
--             ② 跨时刻"仅一打开态"：应用层 upsert 契约——advisory lock 串行化后经
--                idx_alert_event_target 命中打开行则刷 payload、否则 INSERT。
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS ads.alert_event (
  id            bigint       GENERATED ALWAYS AS IDENTITY,
  rule_code     varchar(40)  NOT NULL,                 -- 触发规则 FK
  alert_level   varchar(8)   NOT NULL,                 -- dict: alert_level；触发时刻规则级别快照（规则调级不改历史）
  title         varchar(200) NOT NULL,                 -- 契约 alerts[].title / home title
  dept_id       bigint       NULL,                     -- 涉事科室 FK；NULL=院级/跨科事件（API 出参 dept='全院'）
  building_code varchar(20)  NULL,                     -- 涉事楼宇 FK；NULL=非楼宇域事件
  target_type   varchar(32)  NOT NULL,                 -- 去重对象类型：building/dept/ward/device/drug/hospital（开放枚举，键域见 columns.md）
  target_id     varchar(64)  NOT NULL,                 -- 去重对象键（dim code / 'HOSP_ALL'）；多对象取首要，全集在 payload
  payload       jsonb        NULL,                     -- {value,unit,evidence,stub,stay_list,...} 事件载荷（契约 §3.7 detail）
  drill_route   jsonb        NULL,                     -- 下钻路由快照（冗余自 rule，防规则改路由后历史失真）
  alert_status  varchar(12)  NOT NULL DEFAULT 'pending', -- dict: alert_status（pending/processing/done/closed）
  source        varchar(12)  NOT NULL,                 -- dict: alert_source（rule/scenario/test）
  occurred_at   timestamptz  NOT NULL,                 -- 触发时刻；home 出参 date 化，screen 出参 ISO 全时刻（序列化差异见 README）
  ack_at        timestamptz  NULL,                     -- 确认时刻（R04 ack 写入）
  ack_by        bigint       NULL,                     -- 确认人 FK→sys.user（R04 出参 ack_by）
  done_at       timestamptz  NULL,                     -- 办结时刻（整改工单 done 后回填）
  closed_at     timestamptz  NULL,                     -- 关闭时刻（R06 close 写入）
  close_note    text         NULL,                     -- 关闭说明（R06 close_reason）
  created_at    timestamptz  NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT pk_alert_event PRIMARY KEY (id, occurred_at),
  CONSTRAINT fk_alert_event_rule     FOREIGN KEY (rule_code)     REFERENCES ads.alert_rule(code),
  CONSTRAINT fk_alert_event_dept     FOREIGN KEY (dept_id)       REFERENCES dim.department(id),
  CONSTRAINT fk_alert_event_building FOREIGN KEY (building_code) REFERENCES dim.building(code),
  CONSTRAINT fk_alert_event_ackby    FOREIGN KEY (ack_by)        REFERENCES sys.user(id),
  CONSTRAINT ck_alert_event_level  CHECK (alert_level IN ('urgent','major','minor')),
  CONSTRAINT ck_alert_event_status CHECK (alert_status IN ('pending','processing','done','closed')),
  CONSTRAINT ck_alert_event_source CHECK (source IN ('rule','scenario','test')),
  -- 生命周期列强一致：状态↔时刻列同步（公约 §5.5 真空语义）
  CONSTRAINT ck_alert_event_life   CHECK (
    (alert_status = 'pending'    AND ack_at IS NULL AND done_at IS NULL AND closed_at IS NULL) OR
    (alert_status = 'processing' AND ack_at IS NOT NULL AND done_at IS NULL AND closed_at IS NULL) OR
    (alert_status = 'done'       AND done_at IS NOT NULL AND closed_at IS NULL) OR
    (alert_status = 'closed'     AND closed_at IS NOT NULL)),
  -- 非事实来源（scenario/test 注入）强制 stub 豁免标记（v1.1 冻结约定：payload.stub=true）
  CONSTRAINT ck_alert_event_stub   CHECK (
    source = 'rule' OR (payload IS NOT NULL AND (payload->>'stub')::boolean IS TRUE))
);
COMMENT ON TABLE  ads.alert_event IS '告警事件流：home/alerts 列表、screen 跑马灯与 status.alert_open 计数唯一事实源；打开态=pending+processing';
COMMENT ON COLUMN ads.alert_event.alert_level IS 'dict alert_level 与规则级别同源但为快照：契约 §14.1 事件级可与现行规则级不一致（ICU_USE_90 事件 major/规则 urgent，open-items O2）';
COMMENT ON COLUMN ads.alert_event.target_type IS '去重粒度键：uq_alert_event_dedup 保证同 (rule,target,occurred_at) 幂等；"同目标仅一条打开事件"由应用层 upsert 契约保证（v1.1 冻结语义，M6/O10）';
COMMENT ON COLUMN ads.alert_event.payload IS '事件载荷：value=触发值（规范量纲）/evidence=回溯描述符或事实行 id/stay_list=涉事清单/stub=true=仿真注入豁免校验（open-items O6）';

-- 幂等去重（M6 决策·分区合法）：同规则同目标同时刻仅一条事件——含分区键 occurred_at，
-- RANGE(occurred_at) 分区后可随迁；"仅一打开态"语义由应用层 upsert 契约保证（O10）
CREATE UNIQUE INDEX IF NOT EXISTS uq_alert_event_dedup ON ads.alert_event (rule_code, target_type, target_id, occurred_at);
CREATE INDEX IF NOT EXISTS idx_alert_event_occurred_at ON ads.alert_event (occurred_at);                  -- M10：occurred_at 范围扫描/分区裁剪兜底（PK 非前导列）
CREATE INDEX IF NOT EXISTS idx_alert_event_status_time ON ads.alert_event (alert_status, occurred_at DESC); -- home/alerts 近N条 + screen alert_open/list
CREATE INDEX IF NOT EXISTS idx_alert_event_dept        ON ads.alert_event (dept_id, alert_status);          -- department FK + 按科筛告警
CREATE INDEX IF NOT EXISTS idx_alert_event_building    ON ads.alert_event (building_code, alert_status);    -- building FK + campus_status 派生谓词
CREATE INDEX IF NOT EXISTS idx_alert_event_target      ON ads.alert_event (rule_code, target_type, target_id, occurred_at); -- 打开态命中扫描（应用层 upsert 支撑，M6）+ dedup_min 触发史
CREATE INDEX IF NOT EXISTS idx_alert_event_ackby       ON ads.alert_event (ack_by);                          -- sys.user FK 索引惯例

-- ----------------------------------------------------------------------------
-- file: migrations/0403_ads_today_kpi.sql   lane: L7   verdict: 继承(+kpi_status)
-- contract: api-contract §14.1 kpis[]（value/prev_value/delta_pct/direction/status/spark）
--           §4.1 overview live_inpatient 同源形态
-- depends : sys.metric_def / dim.department（含 id=0 哨兵）
-- partition: 不适用（日内滚动快照，每 (metric,dept) 唯一当前行）
-- derive   : audit G9/G10/G13 + 规模裁决 v2——value/spark/yesterday_same_time 一律自 dwd
--            事实层重算，屏值随 BASE_DATE 变化；流量类=当日全日+前一日同口径，存量类=日快照或 09:00 切面，
--            SURG 按 metric_def 注册口径=当日全台次。契约字面（4,200/45）为十月工作日锚点。
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS ads.today_kpi (
  metric_code         varchar(40)  NOT NULL,           -- 指标码 FK；value 量纲随 metric_def.value_kind（§3.1 强约束）
  dept_id             bigint       NOT NULL DEFAULT 0, -- 0=全院哨兵；楼宇级行由楼内归口科室承载（见 open-items O9）
  value               numeric(18,4) NOT NULL,          -- 当前值（规范量纲：率 0~1、人次原值、分钟）
  yesterday_same_time numeric(18,4) NULL,              -- 昨日同时刻值（契约 prev_value）；NULL=昨日无同时刻切面
  delta_pct           numeric(8,4)  NULL,              -- 较昨同时刻增减·百分数（6.3=+6.3%；快照物化，公约 §6.2 认可形态）
  direction           smallint     NOT NULL DEFAULT 0, -- 契约 direction：1=↑ / 0=→ / -1=↓
  kpi_status          varchar(8)   NOT NULL DEFAULT 'normal', -- 契约 kpis[].status（normal/warn）；黄线判定物化，见 open-items O7/O8
  spark               jsonb        NULL,               -- 7 点迷你序列（与 value 同规范量纲；契约 spark 数组，API 按 value_kind 换算出参）
  updated_at          timestamptz  NOT NULL,           -- 快照时刻（派生流水线写入）
  CONSTRAINT pk_today_kpi PRIMARY KEY (metric_code, dept_id),
  CONSTRAINT fk_today_kpi_metric FOREIGN KEY (metric_code) REFERENCES sys.metric_def(code),
  CONSTRAINT fk_today_kpi_dept   FOREIGN KEY (dept_id)   REFERENCES dim.department(id),
  CONSTRAINT ck_today_kpi_dir    CHECK (direction IN (-1, 0, 1)),
  CONSTRAINT ck_today_kpi_status CHECK (kpi_status IN ('normal','warn')),
  CONSTRAINT ck_today_kpi_spark  CHECK (spark IS NULL OR jsonb_typeof(spark) = 'array')
);
COMMENT ON TABLE  ads.today_kpi IS '日内实时 KPI 快照：screen kpis[] 唯一事实源；dept_id=0=院级，归口科室行=楼宇级指标供料（jz→急诊科19 / wk-ICU→重症医学科20 / mz→门诊部36）';
COMMENT ON COLUMN ads.today_kpi.kpi_status IS 'v1.1 外增量列：契约 warn 态依赖"黄线"（床用率>0.85 等），metric_def 仅 warn_high 红线字段无法推导 → 快照物化（open-items O8）';

CREATE INDEX IF NOT EXISTS idx_today_kpi_dept ON ads.today_kpi (dept_id); -- department FK 索引 + 科室驾驶舱按科取 KPI

-- ----------------------------------------------------------------------------
-- file: migrations/0404_ads_campus_status.sql   lane: L7   verdict: 继承
-- contract: api-contract §14.1 buildings[]（status/badge/badge_level/metrics）
--           ——契约键名是 badge 非 badge_text（库列名 badge_text 为库侧命名，audit N1）
-- depends : dim.building
-- partition: 不适用（每楼唯一当前行）
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS ads.campus_status (
  building_code varchar(20) NOT NULL,                  -- 楼宇码 FK（mz/wk/jz/yj/zyb/tcc/xzl）
  run_status    varchar(12) NOT NULL DEFAULT 'normal', -- dict: campus_status_type（normal/busy/alert）→ 契约 buildings[].status
  badge_text    varchar(64) NOT NULL DEFAULT '',       -- 徽标文案（"420 人"/"留观超时"）→ 契约键名 badge（列名为库侧命名，audit N1）
  badge_level   varchar(8)  NOT NULL DEFAULT 'info',   -- dict: badge_level（info/ok/warn/alert）→ 契约 badge_level
  metrics       jsonb       NOT NULL DEFAULT '{}',     -- 楼内指标键包（键集 v1.1 冻结，CHECK 白名单兜底）
  updated_at    timestamptz NOT NULL,                  -- 快照时刻
  CONSTRAINT pk_campus_status PRIMARY KEY (building_code),
  CONSTRAINT fk_campus_status_building FOREIGN KEY (building_code) REFERENCES dim.building(code),
  CONSTRAINT ck_campus_status_run   CHECK (run_status IN ('normal','busy','alert')),
  CONSTRAINT ck_campus_status_badge CHECK (badge_level IN ('info','ok','warn','alert')),
  -- v1.1 冻结键集白名单（jsonb − 允许键集 = {} 断言子集性）；未知楼宇仅允许空包
  CONSTRAINT ck_campus_status_keys  CHECK (
    CASE building_code
      WHEN 'mz'  THEN metrics - ARRAY['today_visit','queue_avg_min'] = '{}'::jsonb
      WHEN 'wk'  THEN metrics - ARRAY['bed_use_rate','bed_used','bed_open'] = '{}'::jsonb
      WHEN 'jz'  THEN metrics - ARRAY['obs_cnt','obs_over6h','obs_max_min'] = '{}'::jsonb
      WHEN 'yj'  THEN metrics - ARRAY['device_run','device_alert'] = '{}'::jsonb
      WHEN 'zyb' THEN metrics - ARRAY['bed_use_rate','bed_used','bed_open','in_hosp'] = '{}'::jsonb
      ELSE metrics = '{}'::jsonb
    END)
);
COMMENT ON TABLE  ads.campus_status IS '楼宇浮标状态：screen buildings[] 唯一事实源；run_status 派生规则=urgent 开告警/红线→alert、major/黄线→busy、余 normal（v1.1 冻结）';
COMMENT ON COLUMN ads.campus_status.metrics IS '冻结键集载荷：键值一律规范量纲——率键存 0~1（bed_use_rate=0.96），与 today_kpi.value 同制（audit N3 收敛）；API 按 key→value_kind 冻结映射对 *_rate 键 ×100 出参，见 columns.md §3 与 open-items O5';
COMMENT ON COLUMN ads.campus_status.badge_level IS '视觉严重度（info<ok<warn<alert），独立于 run_status 由派生规则写定';

-- ----------------------------------------------------------------------------
-- file: migrations/0408_ads_todo_order.sql   lane: L7   verdict: 继承（P1 仅 DDL）
-- contract: api-contract §3.7 R05 dispatch 产物 / R07 todos[]（baseline/target/result 字段）
-- depends : ads.alert_event(复合 PK 对齐) / dim.staff / sys.user / sys.metric_def
-- partition: 不列入分区预案（工单表，行量中低）
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS ads.todo_order (
  id                bigint       GENERATED ALWAYS AS IDENTITY,
  alert_id          bigint       NOT NULL,             -- 来源告警（与 alert_occurred_at 复合 FK）
  alert_occurred_at timestamptz  NOT NULL,             -- 告警发生时刻冗余（分区就绪复合 FK 配列，open-items O4）
  title             varchar(200) NOT NULL,             -- 督办标题（R05 task_title）
  assignee_id       bigint       NOT NULL,             -- 承办人 FK→dim.staff
  dispatcher_id     bigint       NOT NULL,             -- 派发人 FK→sys.user
  deadline          timestamptz  NOT NULL,             -- 办结时限；超时未成由系统置 expired（§3.7 R07 语义）
  note              text         NULL,                 -- 派发备注（R05 note）
  todo_status       varchar(12)  NOT NULL DEFAULT 'open', -- dict: todo_status（open→doing→done；逾期置 expired）
  result_note       text         NULL,                 -- 办结说明（R07 result）
  baseline_value    numeric(18,4) NULL,                -- 派发时触发值快照（R07 progress.baseline）
  target_value      numeric(18,4) NULL,                -- 派发时阈值快照（R07 progress.target）
  metric_code       varchar(40)  NULL,                 -- 关联指标 FK；current 值由 metric_code→today_kpi/metric_value 实时组装不落列（v1.1 冻结）
  escalated         boolean      NOT NULL DEFAULT false,  -- 升级标记（逾期升级上级，催办链路）
  created_at        timestamptz  NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at        timestamptz  NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT pk_todo_order PRIMARY KEY (id),
  CONSTRAINT fk_todo_order_alert      FOREIGN KEY (alert_id, alert_occurred_at)
                                      REFERENCES ads.alert_event(id, occurred_at),
  CONSTRAINT fk_todo_order_assignee   FOREIGN KEY (assignee_id)   REFERENCES dim.staff(id),
  CONSTRAINT fk_todo_order_dispatcher FOREIGN KEY (dispatcher_id) REFERENCES sys.user(id),
  CONSTRAINT fk_todo_order_metric     FOREIGN KEY (metric_code)   REFERENCES sys.metric_def(code),
  CONSTRAINT ck_todo_order_status CHECK (todo_status IN ('open','doing','done','expired')),
  CONSTRAINT ck_todo_order_result CHECK (todo_status <> 'done' OR result_note IS NOT NULL)
);
COMMENT ON TABLE  ads.todo_order IS '督办工单（P1）：R05 派发产物 / R07 列表源；演示期空表，写路径随督办工作流启用';
COMMENT ON COLUMN ads.todo_order.metric_code IS 'progress.current 不落列：API 按 metric_code 读 today_kpi/metric_value 最新值组装三点锚点（baseline→current→target）';

CREATE INDEX IF NOT EXISTS idx_todo_order_alert      ON ads.todo_order (alert_id, alert_occurred_at); -- 复合 FK + 告警→工单反查
CREATE INDEX IF NOT EXISTS idx_todo_order_assignee   ON ads.todo_order (assignee_id, todo_status);    -- staff FK + R07 我的工单
CREATE INDEX IF NOT EXISTS idx_todo_order_status_due ON ads.todo_order (todo_status, deadline);       -- 逾期置 expired 系统扫描
CREATE INDEX IF NOT EXISTS idx_todo_order_dispatcher ON ads.todo_order (dispatcher_id);               -- sys.user FK
CREATE INDEX IF NOT EXISTS idx_todo_order_metric     ON ads.todo_order (metric_code);                 -- metric_def FK
