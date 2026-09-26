-- ============================================================================
-- lane L1 sys-org  DDL（migration 段 0001~0007）
-- 目标库：PG16（本文件自验于 PG15.15，未使用 16 专有特性）
-- 说明：按 plan.md §3 序号一文件一对象；交付为单文件串联，落仓时按 file: 头拆分为
--       backend/migrations/NNNN_<schema>_<obj>.sql
-- 依赖：本 lane 无上游；sys.user.dept_id→dim.department(id) 的 FK 由独立迁移
--       0113（ddl-fk-deferred.sql）收口，排全部 01xx dim 文件之后
-- ============================================================================

-- ============================================================================
-- file: migrations/0001_sys_dict.sql  lane: L1  verdict: 改造（v1.1 sys.dict 扩 24 dict_type）
-- contract: api-contract §2.2（hospital/profile）+ §1.4 枚举规范   partition: 无（字典表）
-- 说明：dict_type 冻结集见公约 §2.4；CHECK 物理冻结类型全集（69 类 = 57 冻结
--       + 阶段3 增补 12，审核 audit-implementability M5 裁决，来源见 seed [S1b]）
-- ============================================================================
CREATE SCHEMA IF NOT EXISTS sys;  -- sys 为首个 schema（依赖序 sys→dim→…），由本 lane 引导

CREATE TABLE sys.dict (
  dict_type  varchar(40) NOT NULL,
  dict_key   varchar(40) NOT NULL,
  dict_label varchar(64) NOT NULL,
  sort       int         NOT NULL DEFAULT 0,
  extra      jsonb       NULL,
  CONSTRAINT pk_dict PRIMARY KEY (dict_type, dict_key),
  CONSTRAINT ck_dict_dict_type CHECK (dict_type IN (
    'hospital',
    'dept_category','dept_domain','clinic_line',
    'alert_level','alert_status','alert_source','todo_status',
    'surgery_level','surg_status','triage_level','obs_status','ip_event',
    'building_func','ward_type','badge_level','campus_status_type',
    'fee_cat','reg_channel','reg_type',
    'feedback_type','feedback_channel','feedback_status','feedback_score',
    'adverse_cat','mr_grade','incision_class',
    'discipline_level','paper_quartile','project_level','project_status',
    'ins_type','ins_biz_type','ins_run_status','energy_type',
    'datasource_type','datasource_status','role_type','scope_type',
    'staffing_status','title_level','staff_type','roi_level','device_dtype',
    'metric_category','value_kind','period_type','range_type',
    'compare_dim','radar_dim','topic_code',
    'discharge_type','admit_path','rate_type','drg_pay_type','risk_level',
    'drill_type',
    -- 阶段3 增补 12 类（audit M5；原 CHECK-only 值域注册入字典，键值见 seed [S1b]）
    'crit_status','crit_item','inf_site','adverse_level',
    'wo_type','wo_status','material_cat','material_unit','qar_rule',
    'user_status','workitem_status','abx_level'
  ))
);
COMMENT ON TABLE  sys.dict IS '枚举字典+机构信息注册表：业务枚举值域与中文文案唯一来源（契约 §1.4）；dict_type=hospital 行承载 /hospital/profile（契约 §2.2）';
COMMENT ON COLUMN sys.dict.dict_type  IS '字典类型，69 类（公约 §2.4 冻结 57 + 阶段3 增补 12），新增类型走未决项审批';
COMMENT ON COLUMN sys.dict.dict_key   IS '枚举键（库内 CHECK 同源值）';
COMMENT ON COLUMN sys.dict.dict_label IS '展示文案；dict_type=hospital 的标量键（name/english_name/level）直接存配置值';
COMMENT ON COLUMN sys.dict.extra      IS '开放载荷：hospital 数组键（motto/slogans/pillars）存 JSON 数组；fee_cat 存病案10类/医保票据映射（公约 §2.4）';

-- ============================================================================
-- file: migrations/0002_sys_metric_def.sql  lane: L1  verdict: 改造（公约 §3.1 全列改造）
-- contract: api-contract §1.3（指标条 unit）+ 全域指标出参   partition: 无
-- ============================================================================
CREATE TABLE sys.metric_def (
  code         varchar(40) NOT NULL,
  name         varchar(64) NOT NULL,
  disp_unit    varchar(16) NOT NULL,
  value_kind   varchar(8)  NOT NULL,
  category     varchar(20) NOT NULL,
  formula      text        NULL,
  source_table varchar(64) NOT NULL DEFAULT 'manual',
  direction    smallint    NOT NULL,
  warn_low     numeric(18,4) NULL,
  warn_high    numeric(18,4) NULL,
  drill_route  jsonb       NULL,
  owner        varchar(64) NULL,
  version      int         NOT NULL DEFAULT 1,
  period       varchar(8)  NOT NULL,
  api_key      varchar(40) NULL,
  sort         int         NOT NULL DEFAULT 0,
  enabled      bool        NOT NULL DEFAULT true,
  CONSTRAINT pk_metric_def PRIMARY KEY (code),
  CONSTRAINT uq_metric_def_api_key UNIQUE (api_key),
  CONSTRAINT ck_metric_def_value_kind CHECK (value_kind IN ('cnt','amt','rate','idx','mins','days','score')),
  CONSTRAINT ck_metric_def_category   CHECK (category IN ('operation','quality','finance','insurance','hr','research','patient','asset','exam','screen')),
  CONSTRAINT ck_metric_def_direction  CHECK (direction IN (-1, 0, 1)),
  CONSTRAINT ck_metric_def_period     CHECK (period IN ('day','week','month','quarter','year','d30','realtime')),
  CONSTRAINT ck_metric_def_warn       CHECK (warn_low IS NULL OR warn_high IS NULL OR warn_low <= warn_high)
);
COMMENT ON TABLE  sys.metric_def IS '指标字典（一数一源核心）：存储量纲由 value_kind 驱动（amt=元/rate=0~1/score=0~100），展示量纲 disp_unit 仅驱动 API 换算（公约 §3.1）';
COMMENT ON COLUMN sys.metric_def.disp_unit    IS '展示出参单位：万元/元/%/天/分钟/人/人次/台/例/分/次/条/起/件/当量/-（无纲）；换算规则见公约 §3.1 API 换算表';
COMMENT ON COLUMN sys.metric_def.value_kind   IS '存储量纲类别 dict:value_kind；驱动 metric_value.value 的规范量纲与 CHECK 模板';
COMMENT ON COLUMN sys.metric_def.category     IS 'dict:metric_category（10 类）；种子分工：L1=operation/finance/insurance/screen/exam，其余域 lane 自带';
COMMENT ON COLUMN sys.metric_def.formula      IS '人读口径（分子分母+出处节号/文号）';
COMMENT ON COLUMN sys.metric_def.source_table IS '计算来源表；无事实表的手工指标=''manual''（公约 §3.4）';
COMMENT ON COLUMN sys.metric_def.direction    IS '好坏极性：1 升好/-1 降好/0 中性；红绿着色=sign(delta)×direction（公约 §3.3）';
COMMENT ON COLUMN sys.metric_def.warn_low     IS '预警下限，规范量纲（率存 0~1、金额存元）；null=不设';
COMMENT ON COLUMN sys.metric_def.warn_high    IS '预警上限，规范量纲；null=不设';
COMMENT ON COLUMN sys.metric_def.drill_route  IS '下钻指令 {"type":"route","path":"/metric/<code>","label":...}，type 对齐 dict:drill_type；null=不可下钻';
COMMENT ON COLUMN sys.metric_def.owner        IS '业务归口科室名；null=未指定归口（允许项见 §5.5 理由1 之外待定，本列松弛放开）';
COMMENT ON COLUMN sys.metric_def.version      IS '口径版本：公式变更 +1；口径未定手工值=0（公约 §3.4）';
COMMENT ON COLUMN sys.metric_def.period       IS 'dict:period_type，指标主聚合粒度';
COMMENT ON COLUMN sys.metric_def.api_key      IS '契约小写键别名（home/kpis：outpatient/inpatient/surgery/revenue/staff），全局唯一可空';

CREATE INDEX idx_metric_def_category_sort ON sys.metric_def (category, sort);  -- 指标目录按域浏览排序

-- ============================================================================
-- file: migrations/0003_sys_user.sql  lane: L1  verdict: 改造（+title/avatar/scope_*；role+dept_leader）
-- contract: api-contract §2.1（auth/profile）+ §13.2（settings users）   partition: 无
-- ============================================================================
CREATE TABLE sys.user (
  id            bigint GENERATED ALWAYS AS IDENTITY,
  username      varchar(32)  NOT NULL,
  password_hash varchar(128) NOT NULL,
  real_name     varchar(32)  NOT NULL,
  emp_no        varchar(20)  NOT NULL,
  job_title     varchar(32)  NOT NULL DEFAULT '',
  avatar        varchar(255) NOT NULL DEFAULT '',
  role          varchar(20)  NOT NULL,
  dept_id       bigint       NULL,
  scope_type    varchar(8)   NOT NULL DEFAULT 'all',
  scope_val     varchar(64)  NULL,
  user_status   smallint     NOT NULL DEFAULT 1,
  last_login_at timestamptz  NULL,
  created_at    timestamptz  NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at    timestamptz  NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT pk_user PRIMARY KEY (id),
  CONSTRAINT uq_user_username UNIQUE (username),
  CONSTRAINT uq_user_emp_no   UNIQUE (emp_no),
  CONSTRAINT ck_user_role       CHECK (role IN ('admin','president','ops_director','dept_leader','viewer')),
  CONSTRAINT ck_user_scope_type CHECK (scope_type IN ('all','domain','dept')),
  CONSTRAINT ck_user_scope_val  CHECK ((scope_type = 'all' AND scope_val IS NULL)
                                       OR (scope_type <> 'all' AND scope_val IS NOT NULL)),
  CONSTRAINT ck_user_user_status CHECK (user_status IN (0, 1))
);
COMMENT ON TABLE  sys.user IS '账号与演示角色（契约 §2.1/§13.2 users）；密码 bcrypt 演示口令见 README';
COMMENT ON COLUMN sys.user.password_hash IS 'bcrypt；种子口令仅本地演示用（README 标注，勿入生产）';
COMMENT ON COLUMN sys.user.emp_no        IS '工号（水印用；种子=username）';
COMMENT ON COLUMN sys.user.job_title     IS '职务（契约 user.title，§6.4 改名 job_title）';
COMMENT ON COLUMN sys.user.avatar        IS '头像资源路径（契约 user.avatar）；空串=未配置，API 回默认图';
COMMENT ON COLUMN sys.user.role          IS 'dict:role_type：admin/president/ops_director/dept_leader/viewer';
COMMENT ON COLUMN sys.user.dept_id       IS '所属科室，FK→dim.department(id) 由迁移 0113 挂接；0=全院哨兵行（API 序列化出 null），NULL=未归属科室';
COMMENT ON COLUMN sys.user.scope_type    IS 'dict:scope_type：all 全院/domain 业务域/dept 本科室';
COMMENT ON COLUMN sys.user.scope_val     IS '权限域取值：domain→域键（ops_quality/medical/finance）；dept→科室 code；all→NULL（CHECK 保证）';
COMMENT ON COLUMN sys.user.user_status   IS '1 启用/0 停用（§6.4 列名 user_status；dict:user_status 已登记，键 ''0''/''1''）';
COMMENT ON COLUMN sys.user.last_login_at IS '最近登录；null=从未登录（§5.5 理由1）；settings users.login 由此序列化';

CREATE INDEX idx_user_role    ON sys.user (role);     -- /auth/profile?role= 角色上下文切换
CREATE INDEX idx_user_dept_id ON sys.user (dept_id);  -- FK 列索引惯例（§5.3）；dept_name join

-- ============================================================================
-- file: migrations/0004_sys_notice.sql  lane: L1  verdict: 新建（G1）
-- contract: api-contract §3.7（home/notices）   partition: 无
-- ============================================================================
CREATE TABLE sys.notice (
  id           bigint GENERATED ALWAYS AS IDENTITY,
  title        varchar(200) NOT NULL,
  publish_date date         NOT NULL,
  is_urgent    bool         NOT NULL DEFAULT false,
  created_at   timestamptz  NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT pk_notice PRIMARY KEY (id)
);
COMMENT ON TABLE  sys.notice IS '行政通知/待办（契约 §3.7）；text 字段由 API 将 title 别名出参（§6.4）';
COMMENT ON COLUMN sys.notice.title        IS '通知标题（契约 notices[].text）';
COMMENT ON COLUMN sys.notice.publish_date IS '发布日期（契约 notices[].date，YYYY-MM-DD）';
COMMENT ON COLUMN sys.notice.is_urgent    IS '加急标记（契约 urgent bool，§6.4 改名）';

CREATE INDEX idx_notice_publish_date ON sys.notice (publish_date DESC);  -- home/notices 近 N 条倒序

-- ============================================================================
-- file: migrations/0005_sys_data_source.sql  lane: L1  verdict: 新建（G21）
-- contract: api-contract §13.2（settings data_sources）   partition: 无
-- ============================================================================
CREATE TABLE sys.data_source (
  code         varchar(40)  NOT NULL,
  name         varchar(64)  NOT NULL,
  ds_type      varchar(20)  NOT NULL,
  ds_status    varchar(12)  NOT NULL DEFAULT 'connected',
  last_sync_at timestamptz  NULL,
  CONSTRAINT pk_data_source PRIMARY KEY (code),
  CONSTRAINT ck_data_source_ds_type   CHECK (ds_type IN ('biz_rt','biz_hourly','biz_daily','bureau_daily')),
  CONSTRAINT ck_data_source_ds_status CHECK (ds_status IN ('connected','error'))
);
COMMENT ON TABLE  sys.data_source IS '数据源接入状态（契约 §13.2 data_sources）';
COMMENT ON COLUMN sys.data_source.ds_type      IS 'dict:datasource_type：biz_rt 准实时/biz_hourly 小时级/biz_daily 日终批/bureau_daily 局端日终批；契约 type 文案由 dict_label 渲染';
COMMENT ON COLUMN sys.data_source.ds_status    IS 'dict:datasource_status：connected 已连接/error 异常';
COMMENT ON COLUMN sys.data_source.last_sync_at IS '最近同步时刻（契约 sync，API 截断 YYYY-MM-DD HH:mm）；null=从未同步';

CREATE INDEX idx_data_source_ds_status ON sys.data_source (ds_status);  -- 管理端异常源过滤

-- ============================================================================
-- file: migrations/0006_sys_user_pref.sql  lane: L1  verdict: 新建（G21）
-- contract: api-contract §13.2（settings preferences）   partition: 无
-- ============================================================================
CREATE TABLE sys.user_pref (
  id         bigint GENERATED ALWAYS AS IDENTITY,
  user_id    bigint      NOT NULL,
  pref_key   varchar(40) NOT NULL,
  pref_val   jsonb       NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT pk_user_pref PRIMARY KEY (id),
  CONSTRAINT uq_user_pref_user_key UNIQUE (user_id, pref_key),
  CONSTRAINT fk_user_pref_user FOREIGN KEY (user_id) REFERENCES sys.user (id) ON DELETE CASCADE
);
COMMENT ON TABLE  sys.user_pref IS '用户级偏好 KV（契约 §13.2 preferences）；(user_id,pref_key) UQ';
COMMENT ON COLUMN sys.user_pref.pref_key IS '偏好键，开放键集：已知 default_range/refresh_interval/alert_sound/unit_abbreviation/privacy_mask';
COMMENT ON COLUMN sys.user_pref.pref_val IS '偏好值 jsonb（异构：串/布尔/秒数），API 负责契约文案渲染（如 ''month''→本月、300→5 分钟）';

-- ============================================================================
-- file: migrations/0007_sys_audit_log.sql  lane: L1  verdict: 继承·空表（P1，建表不播种）
-- contract: 无直接出参（写操作审计；R03 解密/R04-R08 写操作启用后接入）   partition: 不在分区预案清单
-- ============================================================================
CREATE TABLE sys.audit_log (
  id          bigint GENERATED ALWAYS AS IDENTITY,
  user_id     bigint      NULL,
  username    varchar(32) NOT NULL,
  action      varchar(40) NOT NULL,
  target_type varchar(32) NULL,
  target_id   varchar(64) NULL,
  detail      jsonb       NULL,
  ip          inet        NULL,
  created_at  timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT pk_audit_log PRIMARY KEY (id),
  CONSTRAINT fk_audit_log_user FOREIGN KEY (user_id) REFERENCES sys.user (id) ON DELETE SET NULL
);
COMMENT ON TABLE  sys.audit_log IS '写操作审计（登录/督办派发/告警 ack·close/规则启停/脱敏访问/sim 时钟）；P1 启用，首版空表';
COMMENT ON COLUMN sys.audit_log.user_id     IS '操作人；null=未登录/系统任务（§5.5 理由1）；用户删除后置 NULL 保留轨迹';
COMMENT ON COLUMN sys.audit_log.username    IS '操作人登录名冗余（user 删除后仍可溯源）';
COMMENT ON COLUMN sys.audit_log.action      IS '动作码（login/todo_dispatch/alert_ack/alert_close/rule_toggle/pii_access/sim_clock 等）';
COMMENT ON COLUMN sys.audit_log.target_type IS '目标对象类型；null=无对象动作';
COMMENT ON COLUMN sys.audit_log.target_id   IS '目标对象键（混合类型 varchar(64)，继承 v1.1）';
COMMENT ON COLUMN sys.audit_log.detail      IS '开放载荷（变更前后值/上下文）';
COMMENT ON COLUMN sys.audit_log.ip          IS '来源 IP；null=内部任务';

CREATE INDEX idx_audit_log_created_at ON sys.audit_log (created_at);               -- v1.1 指定；审计时间序检索
CREATE INDEX idx_audit_log_user_time  ON sys.audit_log (user_id, created_at);      -- 按操作人查轨迹
CREATE INDEX idx_audit_log_target     ON sys.audit_log (target_type, target_id);   -- 按对象查变更史
