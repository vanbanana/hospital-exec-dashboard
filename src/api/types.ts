/**
 * API 契约类型镜像 — docs/api-contract.md v2.0
 * 字段名一律 snake_case 照抄契约；各接口注释标注契约节号。
 */

/* ===== §1 通用约定 ===== */

/** 统一响应包络（§1.1）；api() 当前已拆包直返 data，此类型供接真实 http 层时使用 */
export interface ApiEnvelope<T> {
  code: number
  message: string
  data: T | null
  trace_id: string
  ts: number
}

/** 真分页列表包络（§1.2，仅 §15 远期预留端点使用） */
export interface PageResp<T> {
  list: T[]
  page: number
  size: number
  total: number
}

export type RangeKey = '本月' | '本季' | '本年'
export type DirType = 'up' | 'down' | 'flat'
export type ToneType = 'primary' | 'teal' | 'green' | 'amber' | 'red' | 'navy'
export type AlertLevel = 'urgent' | 'major' | 'minor'

/** 指标条统一数据接口（§1.3-3 WbStatItem） */
export interface WbStatItem {
  label: string
  value: string | number
  unit?: string
  delta?: string
  delta_label?: string
  dir?: DirType
  icon?: string
  tone?: ToneType
  note?: string
}

/** WbTable 列元数据——由服务端下发（§16-1） */
export interface WbTableColumn {
  key: string
  title: string
  width?: string
  align?: 'left' | 'center' | 'right'
  num?: boolean
}

export type WbTableRow = Record<string, string | number>

export interface WbTableData {
  columns: WbTableColumn[]
  rows: WbTableRow[]
}

/* ===== §2 认证与上下文域 ===== */

export type RoleKey = 'president' | 'ops_director' | 'dept_leader'

export interface AuthUser {
  id: number
  username: string
  real_name: string
  title: string
  dept_id: number | null
  dept_name: string
  avatar: string
  role: RoleKey
}

export interface RoleOption {
  role: RoleKey
  name: string
  scope: string
}

export interface AuthProfileResp {
  user: AuthUser
  available_roles: RoleOption[]
  system_date: string
  weekday: string
}

export interface HospitalProfileResp {
  name: string
  english_name: string
  level: string
  motto: string[]
  slogans: string[]
  pillars: string[]
}

/* ===== §3 工作台首页 /workbench/home ===== */

export interface HomeKpiItem extends WbStatItem {
  key: string
}

export interface HomeKpisResp {
  period: string
  list: HomeKpiItem[]
}

export interface HomeTrendSeries {
  unit: string
  current: number[]
  last: number[]
}

/** series 键为指标中文名（门急诊人次/住院人次/手术台次/医疗收入），即 Tab 顺序 */
export interface HomeTrendsResp {
  months: string[]
  series: Record<string, HomeTrendSeries>
}

export interface HomeTop10Item {
  rank: number
  name: string
  value: number
}

export interface HomeTop10Resp {
  metric_name: string
  max_val: number
  list: HomeTop10Item[]
}

export interface HomeIndicator {
  code: string
  name: string
  value: string
  unit?: string
  delta?: string
  dir?: DirType
  icon?: string
  tone?: ToneType
}

export interface HomeIndicatorsResp {
  list: HomeIndicator[]
}

export interface HomeProgressItem {
  id: number
  name: string
  progress: number
  status: string
}

export interface HomeProgressResp {
  list: HomeProgressItem[]
}

export interface HomeAlertItem {
  id: number
  level: AlertLevel
  title: string
  occurred_at: string
  rule_code: string
}

export interface HomeAlertsResp {
  list: HomeAlertItem[]
}

export interface HomeNoticeItem {
  id: number
  text: string
  date: string
  urgent: boolean
}

export interface HomeNoticesResp {
  list: HomeNoticeItem[]
}

/* ===== §4 综合概览 /workbench/overview ===== */

export interface NameValue {
  name: string
  value: number
}

export interface OverviewResp {
  range: RangeKey
  stats: WbStatItem[]
  scale_revenue_trend: {
    months: string[]
    outpatient: number[]
    revenue: number[]
    units: { outpatient: string; revenue: string }
  }
  income_structure: {
    unit: string
    list: NameValue[]
  }
  dept_share_top8: {
    metric: string
    unit: string
    list: { name: string; value: number; bar_pct: number }[]
  }
  live_inpatient: { label: string; value: string; tone: ToneType }[]
}

/* ===== §5 医疗业务 /workbench/medical ===== */

export type MedicalTab = '门急诊' | '住院' | '手术'

export interface MedicalTrend {
  title: string
  name: string
  unit: string
  months: string[]
  values: number[]
}

export interface MedicalDistribution {
  title: string
  sub: string
  type: 'bar' | 'pie'
  unit: string
  categories: string[]
  values: number[]
}

export interface MedicalResp {
  tab: MedicalTab
  range: RangeKey
  stats: WbStatItem[]
  trend: MedicalTrend
  distribution: MedicalDistribution
  table: WbTableData
}

/* ===== §6 运营管理 /workbench/operations ===== */

export interface CostControlItem {
  name: string
  value: string
  target: string
  status: string
  pct: number
  /** 红线警示阈值在进度条 0–100 刻度上的相对位置（§6.1 注2） */
  mark_pct: number
}

export interface OperationsResp {
  stats: WbStatItem[]
  revenue_trend: {
    months: string[]
    income: number[]
    cost: number[]
    balance: number[]
  }
  cost_controls: CostControlItem[]
  dept_table: WbTableData
}

/* ===== §7 人力资源 /workbench/hr ===== */

export interface HrResp {
  stats: WbStatItem[]
  structure: {
    unit: string
    list: { name: string; value: number; count: number }[]
  }
  /** 岗位 × 职称矩阵（§7.1 注1） */
  titles: {
    unit: string
    categories: string[]
    series: { name: string; values: number[] }[]
  }
  dept_staffing: WbTableData
}

/* ===== §8 科研教学 /workbench/research ===== */

export interface ResearchResp {
  stats: WbStatItem[]
  project_trend: {
    unit: string
    years: string[]
    national: number[]
    provincial: number[]
    funds: number[]
  }
  paper_distribution: {
    unit: string
    categories: string[]
    values: number[]
  }
  disciplines: WbTableData
}

/* ===== §9 患者服务 /workbench/patient ===== */

export interface PatientResp {
  stats: WbStatItem[]
  satisfaction_trend: {
    unit: string
    months: string[]
    outpatient: number[]
    inpatient: number[]
  }
  channel_distribution: {
    unit: string
    list: NameValue[]
  }
  complaints_praises: WbTableData
}

/* ===== §10 质量与安全 /workbench/quality ===== */

export interface QualityResp {
  stats: WbStatItem[]
  infection_trend: {
    unit: string
    target: number
    months: string[]
    rates: number[]
  }
  adverse_events: {
    unit: string
    categories: string[]
    values: number[]
  }
  rules_compliance: WbTableData
}

/* ===== §11 资产与后勤 /workbench/assets ===== */

export interface StockAlertItem {
  name: string
  /** 库存可用天数（§11.1 注2） */
  days: number
  level: AlertLevel
}

export interface AssetsResp {
  stats: WbStatItem[]
  energy_trend: {
    unit: string
    months: string[]
    total: number[]
    electricity: number[]
    water: number[]
    gas: number[]
  }
  stock_alerts: StockAlertItem[]
  large_equipments: WbTableData
}

/* ===== §12 对比分析 /workbench/compare ===== */

export type CompareDim = 'scale' | 'benefit' | 'efficiency' | 'quality'

export interface CompareResp {
  dimension: CompareDim
  range: RangeKey
  radar: {
    indicators: { name: string; max: number }[]
    series: { name: string; value: number[] }[]
  }
  benchmarks: { name: string; ours: string; region: string; bench: string; gap: string }[]
  table: WbTableData
}

/* ===== §13 专题分析与设置 ===== */

export type TopicKey = 'drg' | 'insurance' | 'exam' | 'outp_fund'

export interface TopicChart {
  title: string
  sub: string
  type: 'bar' | 'line'
  unit: string
  months?: string[]
  categories?: string[]
  values: number[]
}

export interface TopicsResp {
  topic: TopicKey
  range: RangeKey
  stats: WbStatItem[]
  chart: TopicChart
  table: WbTableData & { title: string; sub: string }
}

// 以 type 别名声名（非 interface）：获得隐式索引签名，Item[] 可直接赋给 WbTable 的 Record<string, unknown>[] rows
export type DataSourceItem = {
  name: string
  type: string
  status: string
  sync: string
}

export type ThresholdItem = {
  name: string
  rule: string
  level: AlertLevel
  enabled: boolean
}

export type UserItem = {
  name: string
  role: string
  scope: string
  login: string
  status: string
}

export interface SettingsResp {
  data_sources: DataSourceItem[]
  thresholds: ThresholdItem[]
  users: UserItem[]
  preferences: {
    default_range: RangeKey
    refresh_interval: string
    alert_sound: boolean
    unit_abbreviation: boolean
    privacy_mask: boolean
  }
}

/* ===== §14 辅助形态：科技大屏快照 /screen/snapshot ===== */

/** 整屏运行态势（§14.1 status）；level 契约未穷举（示例 normal） */
export interface ScreenStatus {
  level: string
  text: string
  desc: string
  alert_open: { urgent: number; major: number; minor: number }
}

export type ScreenKpiStatus = 'normal' | 'warn'

/** 屏顶 KPI 项：value 恒等于 spark 末点（§14.1 注6 屏值事实化） */
export interface ScreenKpi {
  code: string
  name: string
  value: number
  unit: string
  prev_value: number
  delta_pct: number
  direction: -1 | 0 | 1
  spark: number[]
  status: ScreenKpiStatus
}

export type DeptCategory = 'surg' | 'med'

export interface DrgPoint {
  dept_id: number
  name: string
  category: DeptCategory
  cmi: number
  /** DRG盈亏，单位万元 */
  profit: number
  case_cnt: number
  quadrant: 1 | 2 | 3 | 4
}

export interface DrgQuadrant {
  period: string
  axis: { x: string; y: string }
  /** 象限分割线：x=盈亏零点，y=CMI 基准 1.0 */
  split: { x: number; y: number }
  points: DrgPoint[]
}

export type BuildingStatus = 'normal' | 'busy' | 'alert'
export type BuildingBadgeLevel = 'info' | 'warn' | 'alert' | 'ok'

export interface ScreenBuilding {
  code: string
  name: string
  status: BuildingStatus
  badge: string
  badge_level: BuildingBadgeLevel
  /** 院区图锚点，百分比坐标（left/top %） */
  anchor: { x: number; y: number }
  /** 楼宇级指标包，键集随楼种（frontend-api §15 末表） */
  metrics: Record<string, number>
}

export interface DeptRankItem {
  rank: number
  dept_id: number
  name: string
  category: DeptCategory
  cmi: number
  surg_cnt: number
  alos: number
  /** DRG结余，单位万元 */
  profit: number
  eff_score: number
}

export interface ScreenAlert {
  id: number
  level: AlertLevel
  title: string
  dept: string
  /** ISO 8601 */
  occurred_at: string
}

export interface ScreenSnapshotResp {
  server_time: string
  status: ScreenStatus
  kpis: ScreenKpi[]
  drg_quadrant: DrgQuadrant
  buildings: ScreenBuilding[]
  dept_ranking: DeptRankItem[]
  alerts: { total_open: number; list: ScreenAlert[] }
  /** series 键 = KPI code，与 kpis[].spark 同源 */
  trends: { days: number; dates: string[]; series: Record<string, number[]> }
}
