-- ============================================================================
-- lane: L2 dim-public  DDL（migration 段 0101~0109, 0112）
-- 目标库：PG16（未使用 16 专有特性，PG15 可验证语法）
-- 说明：按 plan.md §3 序号一文件一对象；交付为单文件串联，落仓时按 file: 头拆分为
--       backend/migrations/NNNN_dim_<obj>.sql
-- 依赖：0001 sys.dict（枚举 CHECK 值域与 dict key 同源，公约 §2.4.1）；
--       dim.department.leader_id→dim.staff 构成环 FK，FK 在 0106_dim_staff.sql
--       内 ALTER 补挂（先建 staff 再回填约束），见两文件头注释
-- ============================================================================

CREATE SCHEMA IF NOT EXISTS dim;

-- ============================================================================
-- file: migrations/0101_dim_date.sql  lane: L2  verdict: 继承
-- contract: api-contract §1.4.4（YYYY-MM-DD）/ §3.2（月度轴）   partition: 不适用（维表）
-- 预案：真实期改函数滚动生成 + 年末滚动任务（公约 §5.2 / 未决项 U8）
-- ============================================================================
CREATE TABLE dim.date (
  date         date        NOT NULL,
  year         smallint    NOT NULL,
  month        smallint    NOT NULL,
  day          smallint    NOT NULL,
  week         smallint    NOT NULL,              -- ISO 周序 1~53
  weekday      smallint    NOT NULL,              -- ISO 1=周一..7=周日
  is_weekend   boolean     NOT NULL,
  is_holiday   boolean     NOT NULL DEFAULT false,
  holiday_name varchar(32) NULL,
  CONSTRAINT pk_date PRIMARY KEY (date),
  CONSTRAINT ck_date_month CHECK (month BETWEEN 1 AND 12),
  CONSTRAINT ck_date_day   CHECK (day BETWEEN 1 AND 31),
  CONSTRAINT ck_date_week  CHECK (week BETWEEN 1 AND 53),
  CONSTRAINT ck_date_weekday CHECK (weekday BETWEEN 1 AND 7),
  CONSTRAINT ck_date_holiday_name CHECK (is_holiday OR holiday_name IS NULL)
);

COMMENT ON TABLE  dim.date              IS '日期维表 2024-01-01~2027-12-31 预生成（种子窗 2025-01-01~2026-12-31 的全域扩展，公约 §1.5）；趋势轴/周期首日派生唯一源';
COMMENT ON COLUMN dim.date.date         IS '主键=自然日；周期表 period_start 一律对齐本表 date';
COMMENT ON COLUMN dim.date.week         IS 'ISO-8601 周序（extract(week)），跨年周归 52/53';
COMMENT ON COLUMN dim.date.weekday      IS 'ISO 1=周一..7=周日；API 出参"星期一"文案映射';
COMMENT ON COLUMN dim.date.is_holiday   IS '法定节假日标记（含调休放假日）；2024-2026 按已发布放假安排，2027 未发布暂全 false（见 open-items O8）';
COMMENT ON COLUMN dim.date.holiday_name IS '节假日名（元旦/春节/清明/劳动节/端午/中秋/国庆）；null=非法定节假日（§5.5 理由1）';

-- ============================================================================
-- file: migrations/0102_dim_campus.sql  lane: L2  verdict: 继承
-- contract: api-contract §14.1（单院区演示）   partition: 不适用（维表）
-- ============================================================================
CREATE TABLE dim.campus (
  code varchar(20) NOT NULL,
  name varchar(64) NOT NULL,
  sort int         NOT NULL DEFAULT 0,
  CONSTRAINT pk_campus PRIMARY KEY (code)
);

COMMENT ON TABLE dim.campus IS '院区主档：多院区预留；种子 main=本部、east=东院区（预留未启用）';

-- ============================================================================
-- file: migrations/0103_dim_building.sql  lane: L2  verdict: 继承
-- contract: api-contract §14.1 buildings[]（code/name/anchor）   partition: 不适用（维表）
-- ============================================================================
CREATE TABLE dim.building (
  code         varchar(20) NOT NULL,
  name         varchar(64) NOT NULL,
  func_type    varchar(16) NOT NULL,              -- dict: building_func
  campus_code  varchar(20) NOT NULL,
  map_anchor   jsonb       NULL,
  CONSTRAINT pk_building PRIMARY KEY (code),
  CONSTRAINT fk_building_campus FOREIGN KEY (campus_code) REFERENCES dim.campus(code),
  CONSTRAINT ck_building_func_type CHECK (func_type IN ('outpt','inpt','emerg','tech','adm','other')),
  CONSTRAINT ck_building_map_anchor CHECK (
    map_anchor IS NULL OR (
      jsonb_typeof(map_anchor->'x') = 'number' AND jsonb_typeof(map_anchor->'y') = 'number'
      AND (map_anchor->>'x')::numeric BETWEEN 0 AND 100
      AND (map_anchor->>'y')::numeric BETWEEN 0 AND 100))
);

COMMENT ON TABLE  dim.building             IS '楼宇主档：/screen snapshot buildings 浮标底图锚点 + 科室→楼宇映射（R09 楼宇抽屉）';
COMMENT ON COLUMN dim.building.func_type   IS 'dict building_func：outpt/inpt/emerg/tech/adm/other';
COMMENT ON COLUMN dim.building.map_anchor  IS '大屏底图容器百分比锚点 {"x":0~100,"y":0~100}；契约 §14 下发 mz/wk/jz/yj 四楼锚点，其余楼宇锚点为 L2 自配';
COMMENT ON COLUMN dim.building.campus_code IS '所属院区；当前全量 main';

CREATE INDEX idx_building_campus ON dim.building (campus_code);

-- ============================================================================
-- file: migrations/0104_dim_department.sql  lane: L2  verdict: 改造
-- contract: api-contract 全页面 dept 名（唯一事实源）/ §7.1 dept_staffing.quota / §5.1
--           groups 下钻   partition: 不适用（维表）
-- 改造点（公约 §4 #10）：+staff_quota/dept_domain/clinic_line/hss_code；level CHECK 0~3；
--           种子含 id=0 院级哨兵（公约 §5.1）
-- ============================================================================
CREATE TABLE dim.department (
  id            bigint      GENERATED ALWAYS AS IDENTITY,
  code          varchar(24) NOT NULL,
  name          varchar(64) NOT NULL,
  category      varchar(8)  NOT NULL,           -- dict: dept_category（+hosp 哨兵）
  dept_domain   varchar(8)  NOT NULL,           -- dict: dept_domain（calibration §4.2 管理口径轴）
  clinic_line   varchar(8)  NULL,               -- dict: clinic_line（仅临床科室）
  level         smallint    NOT NULL,           -- 0院级哨兵 1行政部门 2业务科室 3医疗组
  parent_id     bigint      NULL,
  hss_code      varchar(8)  NULL,               -- 诊疗科目代码（卫医发〔1994〕27号名录）
  staff_quota   int         NULL,               -- 编制数（契约 §7.1 quota）
  campus_code   varchar(20) NOT NULL,
  building_code varchar(20) NULL,
  leader_id     bigint      NULL,               -- FK→dim.staff，于 0106 建表后 ALTER 补挂
  eff_base      numeric(4,3) NULL,              -- 仿真效率基线 0~1
  sort          int         NOT NULL DEFAULT 0,
  active        boolean     NOT NULL DEFAULT true,
  CONSTRAINT pk_department PRIMARY KEY (id),
  CONSTRAINT uq_department_code UNIQUE (code),
  CONSTRAINT fk_department_parent FOREIGN KEY (parent_id) REFERENCES dim.department(id),
  CONSTRAINT fk_department_campus FOREIGN KEY (campus_code) REFERENCES dim.campus(code),
  CONSTRAINT fk_department_building FOREIGN KEY (building_code) REFERENCES dim.building(code),
  CONSTRAINT ck_department_level CHECK (level BETWEEN 0 AND 3),
  CONSTRAINT ck_department_category CHECK (category IN ('med','surg','tech','nurse','adm','hosp')),
  CONSTRAINT ck_department_domain CHECK (dept_domain IN ('clinical','platform','tech','admin')),
  CONSTRAINT ck_department_clinic_line CHECK (
    (clinic_line IS NULL OR clinic_line IN ('med','surg','special'))
    AND ((dept_domain = 'clinical' AND level = 2) = (clinic_line IS NOT NULL))),
  CONSTRAINT ck_department_parent CHECK ((level = 3) = (parent_id IS NOT NULL)),
  CONSTRAINT ck_department_quota CHECK (staff_quota IS NULL OR staff_quota >= 0),
  CONSTRAINT ck_department_eff_base CHECK (eff_base IS NULL OR (eff_base >= 0 AND eff_base <= 1))
);

COMMENT ON TABLE  dim.department             IS '科室/医疗组主数据树（全院科室名唯一事实源）；id=0 为院级哨兵 HOSP_ALL，FK 完整性保证 dept_id=0 汇总行可落库（公约 §5.1）';
COMMENT ON COLUMN dim.department.code        IS '业务编码（拼音缩写）；哨兵=HOSP_ALL；医疗组=<父科室>_G1/G2';
COMMENT ON COLUMN dim.department.category    IS 'dict dept_category：大屏图例轴 med内科/surg外科/tech医技/nurse医辅/adm行政/hosp哨兵';
COMMENT ON COLUMN dim.department.dept_domain IS 'dict dept_domain：clinical/platform/tech/admin——calibration §4.2 管理口径四轴（平台=急诊/重症/麻醉/介入/内镜/CSSD）';
COMMENT ON COLUMN dim.department.clinic_line IS 'dict clinic_line：med/surg/special；仅 dept_domain=clinical 的 level=2 科室必填，其余恒 NULL';
COMMENT ON COLUMN dim.department.level       IS '0=院级哨兵 1=行政部门 2=业务科室 3=医疗组（/departments/{id}/groups 的组级行）';
COMMENT ON COLUMN dim.department.parent_id   IS '仅 level=3 医疗组必填（→父科室 id）；level 0~2 恒 NULL（CHECK 强制，§5.5 理由1）';
COMMENT ON COLUMN dim.department.hss_code    IS '诊疗科目代码（卫医发〔1994〕27 号，calibration §4.1）：如 03.04 心血管内科/04.03 骨科/20 急诊/26 麻醉/28 重症；无名录码位（行政/平台中心/哨兵/医疗组）NULL';
COMMENT ON COLUMN dim.department.staff_quota IS '科室编制数（§7.1 quota）；行政/医技/平台为定岗编制；医疗组不单独设编 NULL（§5.5 理由1）';
COMMENT ON COLUMN dim.department.leader_id   IS '科主任/组长 →dim.staff(id)；未配 NULL（§5.5 理由1）；契约 /departments/{id}/groups.leader 与 settings users 骨科主任链共用';
COMMENT ON COLUMN dim.department.eff_base    IS '仿真效率基线 0~1（eff_score 模拟驱动因子）；种子确定性散列赋值，真实环境应 NULL';

CREATE INDEX idx_department_parent       ON dim.department (parent_id);
CREATE INDEX idx_department_domain_level ON dim.department (dept_domain, level);
CREATE INDEX idx_department_building     ON dim.department (building_code);
CREATE INDEX idx_department_leader       ON dim.department (leader_id);
CREATE INDEX idx_department_campus       ON dim.department (campus_code);

-- ============================================================================
-- file: migrations/0105_dim_dept_alias.sql  lane: L2  verdict: 新建（阶段2a增补）
-- contract: 契约/视图/archive 中科室异名归一（calibration §4.3 缺口：骨外科→骨科等）
-- partition: 不适用（维表）
-- ============================================================================
CREATE TABLE dim.dept_alias (
  alias   varchar(64) NOT NULL,
  dept_id bigint      NOT NULL,
  source  varchar(16) NOT NULL DEFAULT 'contract',
  CONSTRAINT pk_dept_alias PRIMARY KEY (alias),
  CONSTRAINT fk_dept_alias_department FOREIGN KEY (dept_id) REFERENCES dim.department(id),
  CONSTRAINT ck_dept_alias_source CHECK (source IN ('contract','view','archive','plan')),
  CONSTRAINT ck_dept_alias_self CHECK (alias <> '')
);

COMMENT ON TABLE  dim.dept_alias         IS '科室别名归一表：契约/视图/设计稿出现的非主档科室名→dept_id；API/ETL 落表前的名实体解析器输入';
COMMENT ON COLUMN dim.dept_alias.source  IS '别名出处：contract=api-contract.md / view=src 视图组件 / archive=archive 设计稿 / plan=建模文档简称';
COMMENT ON COLUMN dim.dept_alias.dept_id IS '归一目标科室；主档规范名本身不入本表';

CREATE INDEX idx_dept_alias_dept ON dim.dept_alias (dept_id);

-- ============================================================================
-- file: migrations/0106_dim_staff.sql  lane: L2  verdict: 改造
-- contract: api-contract §7.1（stats/structure/titles/dept_staffing）/ §13.2 users
--           / R10 /staff   partition: 不适用（维表）
-- 改造点（公约 §4 #12）：+title_level（dict）；种子扩编至 2,368 在岗
-- 本文件同时 ALTER 补挂 dim.department.leader_id FK（环 FK 收口）
-- ============================================================================
CREATE TABLE dim.staff (
  id          bigint      GENERATED ALWAYS AS IDENTITY,
  code        varchar(16) NOT NULL,
  name        varchar(32) NOT NULL,
  dept_id     bigint      NOT NULL,
  staff_type  varchar(8)  NOT NULL,             -- dict: staff_type
  title       varchar(32) NOT NULL,             -- 职称全称（主任医师/主管护师…）
  title_level varchar(16) NOT NULL,             -- dict: title_level
  active      boolean     NOT NULL DEFAULT true,
  CONSTRAINT pk_staff PRIMARY KEY (id),
  CONSTRAINT uq_staff_code UNIQUE (code),
  CONSTRAINT fk_staff_department FOREIGN KEY (dept_id) REFERENCES dim.department(id),
  CONSTRAINT ck_staff_type CHECK (staff_type IN ('doc','nur','tec','adm')),
  CONSTRAINT ck_staff_title_level CHECK (title_level IN ('senior_pos','senior_sub','middle','junior'))
);

ALTER TABLE dim.department
  ADD CONSTRAINT fk_department_staff FOREIGN KEY (leader_id) REFERENCES dim.staff(id);

COMMENT ON TABLE  dim.staff              IS '人员主档（在岗 2,368 锚点）：岗位×职称矩阵对回契约 §7.1 titles；R10 人员选择器与 leader_id 共用';
COMMENT ON COLUMN dim.staff.code         IS '工号 S00001~S02368（确定性生成）';
COMMENT ON COLUMN dim.staff.staff_type   IS 'dict staff_type：doc执业医师/nur护理/tec医技/adm行政后勤（契约 §7.1 structure 四桶）';
COMMENT ON COLUMN dim.staff.title        IS '职称全称展示用；归一化层级用 title_level';
COMMENT ON COLUMN dim.staff.title_level  IS 'dict title_level：senior_pos正高/senior_sub副高/middle中级/junior初级及以下（契约 §7.1 titles 矩阵键）';
COMMENT ON COLUMN dim.staff.active       IS '在岗标记；种子全 true=在岗 2,368，离职走 active=false 不删行';

CREATE INDEX idx_staff_dept       ON dim.staff (dept_id);
CREATE INDEX idx_staff_type_level ON dim.staff (staff_type, title_level);

-- ============================================================================
-- file: migrations/0107_dim_drg_group.sql  lane: L2  verdict: 改造
-- contract: api-contract §13.1 topic=drg（cost_idx/time_idx/低风险组死亡率/病组表）
-- partition: 不适用（维表）
-- 改造点（公约 §4 #13）：base_los→region_los_avg 区域基准住院日 +region_fee_avg +risk_level
-- ============================================================================
CREATE TABLE dim.drg_group (
  code           varchar(16)  NOT NULL,
  name           varchar(128) NOT NULL,
  adrg_code      varchar(8)   NOT NULL,         -- 核心 ADRG（去并发症细分位）
  mdc            varchar(8)   NOT NULL,         -- 主要诊断大类 MDCA~MDCZ
  rw             numeric(8,4) NOT NULL,         -- 病组权重
  base_rate      numeric(14,2) NOT NULL,        -- 基准费率·元（支付标准=base_rate×rw×机构系数）
  region_fee_avg numeric(14,2) NULL,            -- 区域同级病组均费·元（cost_idx 分母）
  region_los_avg numeric(6,2)  NULL,            -- 区域平均住院日·天（time_idx 分母）
  risk_level     varchar(8)   NOT NULL,         -- dict: risk_level（分组器死亡风险分档）
  pay_type       varchar(4)   NOT NULL DEFAULT 'DRG',  -- dict: drg_pay_type
  CONSTRAINT pk_drg_group PRIMARY KEY (code),
  CONSTRAINT ck_drg_group_rw CHECK (rw > 0),
  CONSTRAINT ck_drg_group_base_rate CHECK (base_rate >= 0),
  CONSTRAINT ck_drg_group_region_fee CHECK (region_fee_avg IS NULL OR region_fee_avg >= 0),
  CONSTRAINT ck_drg_group_region_los CHECK (region_los_avg IS NULL OR region_los_avg >= 0),
  CONSTRAINT ck_drg_group_risk_level CHECK (risk_level IN ('low','mid','midhigh','high')),
  CONSTRAINT ck_drg_group_pay_type CHECK (pay_type IN ('DRG','DIP'))
);

COMMENT ON TABLE  dim.drg_group               IS 'DRG 病组维表 60 组（CHS-DRG 2.0 谱系样例，真实全量 ~634 组；主题页面病组名归一源）';
COMMENT ON COLUMN dim.drg_group.code          IS 'DRG 细分组码（如 IF15 腰椎融合术）；入组失败病例不落本表（drg_case.drg_code NULL+ungrouped_flag，L4）';
COMMENT ON COLUMN dim.drg_group.adrg_code     IS '核心疾病诊断相关组（code 前三位去尾档），ADRG 层汇总用';
COMMENT ON COLUMN dim.drg_group.mdc           IS '主要诊断大类 MDCA~MDCZ（CHS-DRG 26 大类）';
COMMENT ON COLUMN dim.drg_group.rw            IS '病组权重；种子谱系 0.38~12.86 覆盖契约 §13.1 六段分布（含 ≥10 桶供给，见 open-items O3）';
COMMENT ON COLUMN dim.drg_group.base_rate     IS '医保 DRG 基准费率·元；按险种年度统一值（种子 6,880.00）';
COMMENT ON COLUMN dim.drg_group.region_fee_avg IS '区域同级该病组均费·元；费用消耗指数=本院例均费/本值；null=区域基准未发布（§5.5 理由2）';
COMMENT ON COLUMN dim.drg_group.region_los_avg IS '区域平均住院日·天；时间消耗指数=本院例均住院日/本值（v1.1 base_los 改造，G18）';
COMMENT ON COLUMN dim.drg_group.risk_level    IS 'dict risk_level：low/mid/midhigh/high；低风险组死亡率指标的分组识别依据（LOW_RISK_DEATH_RATE）';
COMMENT ON COLUMN dim.drg_group.pay_type      IS 'dict drg_pay_type：DRG/DIP；本院 DRG 结算，DIP 行预留给专题剧情';

CREATE INDEX idx_drg_group_adrg ON dim.drg_group (adrg_code);
CREATE INDEX idx_drg_group_mdc  ON dim.drg_group (mdc);
CREATE INDEX idx_drg_group_risk ON dim.drg_group (risk_level);

-- ============================================================================
-- file: migrations/0108_dim_ward.sql  lane: L2  verdict: 继承
-- contract: api-contract §5.1 病区床位占用 / §14.1 buildings.metrics.bed_*
-- partition: 不适用（维表）
-- ============================================================================
CREATE TABLE dim.ward (
  code          varchar(20) NOT NULL,
  name          varchar(64) NOT NULL,
  dept_id       bigint      NOT NULL,
  building_code varchar(20) NOT NULL,
  ward_type     varchar(16) NOT NULL,           -- dict: ward_type
  bed_open      int         NOT NULL DEFAULT 0,
  CONSTRAINT pk_ward PRIMARY KEY (code),
  CONSTRAINT fk_ward_department FOREIGN KEY (dept_id) REFERENCES dim.department(id),
  CONSTRAINT fk_ward_building FOREIGN KEY (building_code) REFERENCES dim.building(code),
  CONSTRAINT ck_ward_type CHECK (ward_type IN ('general','icu','obs','or')),
  CONSTRAINT ck_ward_bed_open CHECK (bed_open >= 0)
);

COMMENT ON TABLE  dim.ward             IS '病区主档 31 行：病区占用分布（§5.1 distribution）、ICU_USE_RATE/留观识别、楼宇抽屉 bed_* 与 R09 共用';
COMMENT ON COLUMN dim.ward.ward_type   IS 'dict ward_type：general/icu/obs/or；icu 为 ICU_USE_RATE 与重症告警识别依据（必填）；or=手术室虚拟病区（bed_open=0，仅 join 落点）';
COMMENT ON COLUMN dim.ward.bed_open    IS '开放床位数；全表合计 2,004=契约床位使用率 92.1%×在院 1,846 反推锚点（±0.5 容差）';
COMMENT ON COLUMN dim.ward.dept_id     IS '病区归口科室（level=2）';

CREATE INDEX idx_ward_dept     ON dim.ward (dept_id);
CREATE INDEX idx_ward_building ON dim.ward (building_code);
CREATE INDEX idx_ward_type     ON dim.ward (ward_type);

-- ============================================================================
-- file: migrations/0109_dim_device.sql  lane: L2  verdict: 改造
-- contract: api-contract §11.1 large_equipments / §14.1 医技楼 device_* 指标
-- partition: 不适用（维表）
-- 改造点（公约 §4 #15）：dtype 扩 10 类（dict device_dtype）；种子 68 台=单价≥100万口径；
--          修复轮：PK 形态回归公约 §2.2 实体组定式（id identity PK + code UQ）；
--          下游 dwd.device_run_day.device_code FK→code(UQ) 引用依然合法，无需改下游
-- ============================================================================
CREATE TABLE dim.device (
  id            bigint        GENERATED ALWAYS AS IDENTITY,
  code          varchar(20)   NOT NULL,         -- 设备码 DEV_<dtype>_<nn>
  name          varchar(64)   NOT NULL,
  dtype         varchar(8)    NOT NULL,         -- dict: device_dtype
  dept_id       bigint        NOT NULL,
  building_code varchar(20)   NOT NULL,
  value_yuan    numeric(14,2) NOT NULL,         -- 原值·元（v1.1 保留列名，unit=元）
  active        boolean       NOT NULL DEFAULT true,
  CONSTRAINT pk_device PRIMARY KEY (id),
  CONSTRAINT uq_device_code UNIQUE (code),      -- 下游 device_code FK 引用于此列
  CONSTRAINT fk_device_department FOREIGN KEY (dept_id) REFERENCES dim.department(id),
  CONSTRAINT fk_device_building FOREIGN KEY (building_code) REFERENCES dim.building(code),
  CONSTRAINT ck_device_dtype CHECK (dtype IN ('CT','MRI','DSA','ROBOT','LINAC','PETCT','ENDO','ESWL','US','DR','OTHER')),
  CONSTRAINT ck_device_value CHECK (value_yuan >= 0)
);

COMMENT ON TABLE  dim.device              IS '大型设备主档 68 台（"单价≥100万"纳入口径，契约 §11.1 stats.large_equipment=68 锚点）；PK=id 实体组定式（修复轮回归 §2.2），code UQ 承下游 device_code FK';
COMMENT ON COLUMN dim.device.code         IS '设备编码 DEV_<dtype>_<nn>；UQ，下游 device_code 列的 FK 目标';
COMMENT ON COLUMN dim.device.dtype        IS 'dict device_dtype：CT/MRI/DSA/ROBOT/LINAC/PETCT/ENDO/ESWL/US/DR/OTHER（v1.1 四类扩十类）';
COMMENT ON COLUMN dim.device.value_yuan   IS '设备原值·元（numeric(14,2) 单位元，公约 §1.1）；≥1e6 为纳入口径而非 CHECK 硬约束';
COMMENT ON COLUMN dim.device.dept_id      IS '使用科室（level=2）；效益归集粒度';
COMMENT ON COLUMN dim.device.active       IS '在用标记；停用/报废 active=false 不删行（设备效益页只统计 active）';

CREATE INDEX idx_device_dept     ON dim.device (dept_id);
CREATE INDEX idx_device_building ON dim.device (building_code);
CREATE INDEX idx_device_dtype    ON dim.device (dtype);
CREATE INDEX idx_device_active   ON dim.device (active);

-- ============================================================================
-- file: migrations/0112_dim_drug.sql  lane: L2  verdict: 继承·缓建（P1）
-- contract: 无消费方（药占比走 dwd.charge_day.fee_cat='drug'；药品明细页未规划）
-- partition: 不适用（维表）——DDL 先行，种子不播（P1 缓建纪律，公约 §4 #18）
-- ============================================================================
CREATE TABLE dim.drug (
  code          varchar(20)   NOT NULL,         -- 院内药品编码
  name          varchar(128)  NOT NULL,         -- 通用名+剂型（如 阿托伐他汀钙片 20mg）
  spec          varchar(64)   NOT NULL,
  dosage_form   varchar(32)   NULL,
  unit          varchar(16)   NOT NULL,
  manufacturer  varchar(128)  NULL,
  atc_code      varchar(16)   NULL,             -- WHO ATC 分类码
  ypid          varchar(32)   NULL,             -- 国家医保药品标准编码（医保信息业务编码）
  is_base_drug  boolean       NOT NULL DEFAULT false,  -- 国家基本药物目录
  is_antibiotic boolean       NOT NULL DEFAULT false,
  abx_level     varchar(16)   NULL,             -- 抗菌药物管理分级
  price         numeric(14,2) NULL,             -- 单价·元
  active        boolean       NOT NULL DEFAULT true,
  CONSTRAINT pk_drug PRIMARY KEY (code),
  CONSTRAINT ck_drug_abx_level CHECK (abx_level IS NULL OR abx_level IN ('unrestricted','restricted','special')),
  CONSTRAINT ck_drug_price CHECK (price IS NULL OR price >= 0),
  CONSTRAINT ck_drug_abx_consistent CHECK (is_antibiotic OR abx_level IS NULL)
);

COMMENT ON TABLE  dim.drug               IS '药品主档（P1 缓建：DDL 先行不播种）；药占比由 fee_cat 供给，启用时点=药事模块（基药/DDDs/创新药剔除）';
COMMENT ON COLUMN dim.drug.ypid          IS '国家医保药品编码（医保办发〔2019〕55 号编码标准），对接医保结算清单';
COMMENT ON COLUMN dim.drug.abx_level     IS '抗菌药物分级：unrestricted非限制/restricted限制使用/special特殊使用（单表枚举走 CHECK 未注册 dict_type，见 open-items O9）';
COMMENT ON COLUMN dim.drug.atc_code      IS 'ATC 解剖学-治疗学-化学分类码，DDDs 统计基础；null=未映射（§5.5 理由2）';
COMMENT ON COLUMN dim.drug.price         IS '单价·元；null=价格未维护（§5.5 理由2）';
