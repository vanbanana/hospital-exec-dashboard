# 仿真数据方案 — EDSS

> 版本：v1.1（契约冻结基线）
> 目的：无真实医院环境下产出**统计自洽、可演示、可下钻**的运营数据。
> 铁律一：仿真器与未来真实 ETL **写入同一批 dwd 表**；API/前端对来源无感知。
> 铁律二：**仿真器只写 dwd 事实 + sim 控制表，禁止直接写 dws/ads**——剧本钩子也只能注入 dwd 行，数字必须由派生流水线算出来，否则自洽校验失效。

---

## 1. ★ 关键边界：Fact Producer vs Derived Pipeline

```
┌─ Fact Producer（写 dwd；双实现二选一）──────────────────────────┐
│  Sim 模式：internal/simulator                                   │
│    ├─ DayGen     跨虚拟日时批量生成"昨日"整天事实                │
│    └─ Intraday   随 tick 增量写"今日" dwd 行（见 §3 写面清单）   │
│  ETL 模式：外部 ETL/CDC 进程（未来，独立进程不进本二进制）        │
│    └─ HIS/EMR/HRP → ODS → 同结构 dwd                            │
├─ Derived Pipeline（写 dws/ads；两种模式都常驻运行）──────────────┤
│  internal/jobs/                                                 │
│    ├─ DayAgg      dwd→dws→ads.rank 聚合（SQL 两模式共用）        │
│    ├─ TodayKpi    当日事实→ads.today_kpi + ads.campus_status     │
│    └─ AlertScan   按 alert_rule 扫事实→ads.alert_event           │
└─────────────────────────────────────────────────────────────────┘
```

**切换真实化 = 停 Fact Producer（不启 simulator jobs、不注册 /sim 路由），Derived Pipeline 原样运行。** 大屏 KPI/趋势/告警/浮标全部照常——这才是"API/前端零改动"的完整含义。

## 2. 虚拟时钟纪律（sim.clock）

- `virtual_now` 为全院唯一"现在"；**所有业务时间禁止 `time.Now()`**，统一 `pkg/clock.Now(ctx)`（sim=virtual_now，prod=time.Now()）。deadline 校验、occurred_at、留观时长、prev_value 全部走它。
- **请求级快照**：每请求入口读一次 sim.clock 注入 ctx，单请求内多次查询口径不撕裂。
- **tick 单事务**：一次 tick = 推进 clock + upsert 当日 dwd 行 + 跑 TodayKpi/AlertScan 派生，全部在一个 DB 事务内，读者看不到半个 tick。
- **跨日 catch-up**：tick 发现 virtual_now 跨过 04:00（虚拟日界）→ 先对"昨天"跑 DayGen+DayAgg，再推进；连跨多日循环 catch-up。DayGen 幂等（按日 delete+insert 或全 PK upsert）。
- **原子更新**：`UPDATE sim.clock SET virtual_now=virtual_now+?*speed WHERE id=1`；POST /sim/clock 加行锁+bounds 校验（[base_date, 播种末日+1]）→ 35002。
- **时钟跳转→缓存失效**：POST /sim/clock 必须同步失效 `ads:today_kpi:*` 与 snapshot 热缓存，否则跳时间后大屏还显示旧值 30s。
- **边界 auto-pause**：tick 自然推进越过 `播种末日+1` 时自动 `paused=true`（此时段无事实可生成，继续走只会让大屏"安静死掉"）；播种末日=演示有效期，演示前应检查余量。

## 3. 三档节拍

```
┌─ SimTick（每 30s 真实时）──────────────────────────────────────┐
│ 1) 原子推进 virtual_now（speed 倍速）                           │
│ 2) Intraday 写面（增量 upsert"今日" dwd 行）：                  │
│    dwd.outpatient_hourly   截至 virtual_now 的分时行            │
│    dwd.emergency_stay      新到达行 + observing 持续            │
│    dwd.inpatient_move      今日 admit/discharge 事件            │
│    dwd.surgery_case        status 推进 sched→doing→done→pacu    │
│    dwd.bed_state_day       今日行（占用随 move 重算）            │
│    ※ 时钟回跳/快进时"重算并 upsert 截至 virtual_now"            │
│      ——非增量追加，保证跳过时段无洞、幂等                        │
│ 3) 跨日检测 → DayGen+DayAgg（catch-up）                         │
│ 4) Derived：TodayKpi + AlertScan（tick 内按虚拟时间评估）       │
├─ AlertScan 兜底（真实 cron 每 60s）─────────────────────────────┤
│ speed=1 时与 tick 重复无妨（去重键兜底）；speed>1 时主要由 tick  │
├─ DayGen（虚拟日 04:00）─────────────────────────────────────────┤
│ 由 tick 跨日触发（非独立 cron）：生成昨日整天事实→DayAgg        │
├─ ★ ETL 模式调度（无 SimTick，真实 cron 接管派生流水线）──────────┤
│ DayAgg     = 真实 cron 每日 04:10                                │
│ TodayKpi   = 真实 cron 每 5min（对齐源系统批量频率）              │
│ AlertScan  = 真实 cron 每 60s                                    │
└─────────────────────────────────────────────────────────────────┘
```

### sim.clock 字段
| virtual_now | speed（1=实时；60=1秒=1分钟） | paused | base_date |
启动时 virtual_now < base_date → 自动置 base_date。**历史 180 天播种时一次生成**，clock 只影响"今日"。

## 4. 生成模型（保证数字"像真的"）

### 4.1 日内曲线（门急诊分时）
双峰钟形：`f(h)=w1·N(9.5,1.8)+w2·N(14.5,2.0)`，门诊窗 07:30–17:30；急诊分量=均匀+夜间小峰。
`visit_cnt(30min)` = round(base×f(h)×dept_share×noise)；08:30 累计≈全天 28~32% → 屏上"2845"对应日基线 **~9500±**（2845/0.30≈9480，曲线参数按此标定）。
`prev_value` = **昨日同时刻累计**（口径已写入契约 §4）。

### 4.2 星期/季节因子
`weekday_factor=[1.15,1.05,1.00,0.98,0.95,0.55,0.40]`；月趋势 ±5%；噪声 σ≈3%；节假日按周六×0.8。

### 4.3 住院/床位联动（自洽红线）
- `bed_used ≤ bed_open + borrow_in`（借床口径见 schema §4）；`in_hosp=Σward.bed_used`
- 今日在院=昨日在院+admit−discharge±转科平衡
- `los~LogNormal(1.7,0.5)`→科室 ALOS 5~9 天；3~5% longstay
- bed_used>bed_open 时记 borrow_in（弹性床位剧情）

### 4.4 手术
日台次~Poisson(45×星期因子)；四级占比 22~30%；外科系加权。status 随 virtual_now 推进。

### 4.5 费用与 DRG 盈亏（四象限成形核心）
`total_fee=base_rate×rw×dept_factor×LogNormal(0.28)`；`cost=fee×科室成本率(0.85~1.15)`；`profit=insurance_pay−cost_total`。
- 预设科室成本倾向使四象限自然成形：骨科/心内→Q2 高CMI高结余；某外科→Q1 高CMI亏损；普内→Q4 低CMI高结余；个别科→Q3
- material_ratio 外科系 0.35~0.5、内科 0.1~0.2 → IF15 PEEK 融合器穿透剧情
- ~5% spec_flag；~2% readmit15；~0.3% death_flag；surg_level 与 emr_json.operations[].level 同步置位

### 4.6 留观/告警剧情
泊松到达(λ≈0.8/h)+Gamma 停留时长。**剧本钩子**（sim.profile.scenarios）：定时注入 dwd 事实——如每虚拟日 07:30±1h 造 2~3 条 >6h 留观 → AlertScan 自然产出紧急告警；周五外科楼 bed_use 冲 96%。
- `source='scenario'` 类告警（药品库存低/设备待维护——P2 无事实表）由注入器**直接写 alert_event**，payload.stub=true，validate #5 豁免。
- 注：白皮书口径"留观>24h"，本系统阈值 **>6h**（晨会演示密度），有意偏离且规则可配。

### 4.7 指标衍生
聚合 SQL 产出 §9 字典全部 code 的 dws.metric_value；eff_score 按 schema §10。

## 5. 告警引擎语义（冻结）

- 去重键 `(rule_code,target_type,target_id)`：同键存在 open 态事件 → 不新建、只刷新 payload（最新停留时长/触发值）；dedup_min 仅在关闭后抑制再触发。
- DB 兜底：`UNIQUE(rule_code,target_type,target_id) WHERE status IN ('pending','processing')`。
- ack/dispatch 并发互斥：`UPDATE alert_event SET status='processing' WHERE id=? AND status='pending'` 原子转移，失败→33002。
- dispatch 事务边界：alert 状态 + todo 插入 + audit 单事务。

## 6. 播种规模与自洽校验

规模：20 科室（+医疗组）/400 员工/30 病区 1200 床/60 DRG 组/~30 例日×180d≈5.4k 病例/常开告警 4~8 条（1:2:3 配比）。**固定 PRNG 种子**，reseed 幂等（先清事实表再生成）。

`sim validate` 8 条校验（见 database-schema §12）必须全绿才算播种完成。

## 7. 与未来真实 ETL 的切换运行手册

| 步骤 | 操作 |
| :--- | :--- |
| 1 | 新 schema `ods` 建真实贴源表（新增，不改旧表） |
| 2 | **清场**：`TRUNCATE dwd.*, dws.*, ads.alert_event, ads.todo_order, ads.dept_rank_day, ads.today_kpi, ads.campus_status RESTART IDENTITY`（保留 dim/sys/sim 冻结只读）——仿真历史与真实日期 PK 会撞，必须清 |
| 3 | ETL 进程开写 dwd；`DATA_SOURCE=etl` 重启后端（simulator jobs 不启动、/sim 路由不注册、clock 走真实 now） |
| 4 | Derived Pipeline 照常跑，首个 DayAgg 周期后大屏出数 |

**粒度降级策略**：真实 HIS 常见 T+1/小时级批量，DRG 结算延迟数天——"今日累计"语义可能劣化。契约已预留可选字段空间（snapshot 可加 `as_of`）；降级行为定义：today_kpi 无当日事实时 value=0 且 spark 平推，页面自然显示"暂无数据"而非假数。

## 8. 演示剧本（对齐白皮书"晨会"）

1. `POST /sim/clock {virtual_now:今日07:55, speed:12}` → 大屏时钟快进到 ~08:12
2. 剧本钩子已在 ~07:30 注入超 6h 留观 → AlertScan 产出紧急红条、急诊楼徽标转红
3. 院长点"下钻"→ 留观明细 →"督办"→ 指派急诊主任 deadline 明 08:00 → 行内→处理中
4. 穿透链：骨科（#1）→ 脊柱微创组 → IF15 → 亏损病例 → 脱敏病案（admin/president 可 unmask）

---

## 9. 演示运行手册（demo runbook）

### 9.1 初始播种与重置

| 动作 | 机制 |
| :--- | :--- |
| 首次启动 | `entrypoint: server -migrate && server -seed && server` —— `-seed` 幂等（已播种标记跳过），生成维度+180 天事实+派生数据+sim.clock=base_date |
| 手动播种 | `go run ./cmd/server -seed -seed-days 180`（先清 dwd/dws/ads 事实再生成，固定 PRNG 种子可复现） |
| 演示重置 | `POST /sim/reset`（dev/sim 模式）：TRUNCATE 事实+告警+工单+审计 → 重跑 seed → clock 回 base_date。**等价于"恢复开箱状态"** |
| 边界余量 | 播种末日即演示有效期，演示前 `GET /sim/clock` 确认 virtual_now 距末日余量 |

### 9.2 演示前检查单（开场前 5 分钟）

1. `GET /healthz` → db/redis 全 up
2. `POST /sim/reset` → 等 seed 完成（sim.job_log status=done）
3. 大屏机浏览器打开 /screen → 确认 session 有效（refresh 14d 会过期，重登一次）
4. 用 admin 调 `POST /sim/clock` 把 virtual_now 设到剧本起点（如 07:55）
5. 确认剧本钩子已写 sim.profile.scenarios（留观注入在 07:30±1h 窗口内）

### 9.3 演示操作 curl 速查（admin token）

```bash
# 快进/定点
curl -X POST /api/v1/sim/clock -d '{"virtual_now":"2026-09-18T07:55:00+08:00","speed":12}'
# 注入演示告警
curl -X POST /api/v1/sim/alert-test -d '{"rule_code":"OBS_OVER_6H"}'
# 查看时钟
curl /api/v1/sim/clock
# 重置回开箱
curl -X POST /api/v1/sim/reset
```

### 9.4 应急预案

| 事故 | 处置 |
| :--- | :--- |
| 演示中密码连错被锁（20104） | Redis `DEL login:fail:<username>` 立即解锁（或换备用角色账号——检查单要求预先登录好大屏 session，避免现场输密码） |
| 大屏断线 | 顶部红条自动重连；若 >1min，刷新页面（session 在 localStorage） |
| 时钟越过播种边界 auto-pause | `POST /sim/reset` 重新播种 |
| 告警派发点错 | `POST /alerts/{id}/close` 关闭后 `POST /sim/alert-test` 重注 |
