# 总体架构设计 — 市中心医院·综合运营决策指挥大屏 (EDSS)

> 版本：v1.1（契约冻结基线）  
> 前置文档：`院长查询与决策支持系统_深度调研与功能需求规格白皮书.md`、`output/2026-09-18-product-definition.md`  
> **核心约束：本项目无真实医院环境，全部数据为模拟生成。API 契约即未来对接真实 HIS/EMR/HRP 的预留接口，前端只依赖契约，永不关心数据来源。**

---

## 1. 技术栈裁剪决策

白皮书要求的技术栈全量落地过重。按"最简稳定、不过度设计"原则裁剪：

| 组件 | 决策 | 理由 |
| :--- | :--- | :--- |
| Vue3 + TS + Vite | ✅ 保留 | 前端基座 |
| Pinia | ✅ 保留 | 前端 ctx 状态中枢 |
| Element Plus | ✅ 保留 | 下钻页/管理页全量使用；大屏**按需白名单**引入 Drawer/Dialog/Select/DatePicker/Message/Notification/Form（督办弹窗与楼宇抽屉必需），其余面板原生 CSS |
| ECharts 5 | ✅ 保留 | 已在 package.json，四象限散点/趋势折线 |
| Vue Router | ✅ 新增 | 下钻跳转必需（当前未装，需 `npm i vue-router@4`）；**包管理器统一 npm**（仓库已有 package-lock.json，禁止 pnpm 双锁并存） |
| Go + Gin | ✅ 保留 | HTTP API 层 |
| GORM v2 | ✅ 保留 | ORM，用于 sys/维度/单条读写；聚合报表统一走 GORM Raw 手写 SQL（不引 sqlx） |
| PostgreSQL 16 | ✅ 保留 | 唯一主库。DIM/DWD/DWS/ADS 分层全部建在同一实例不同 schema |
| Redis | ✅ 保留（瘦身） | 两个用途：① refresh 吊销 + 登录失败计数 ② 大屏热数据旁路缓存（可降级直读 DB）。**不做**全局限流、**不用**分布式锁（单进程 tick 防重用 sync.Mutex/pg advisory lock） |
| TimescaleDB | ⚠️ 暂缓 | 本质是 PG 扩展。我们的时序是"日/小时级运营指标"，PG 原生分区表足够。若后期接真实设备秒级数据再启用，`docker-compose` 镜像换 `timescale/timescaledb` 即可零迁移成本切换 |
| Elasticsearch 8 | ❌ 砍掉 | MVP 无全文检索需求；投诉 NLP 聚类属三期。届时再加，契约不受影响 |
| RabbitMQ | ❌ 砍掉 | 告警派发/仿真节拍用 Go 进程内调度（`robfig/cron`）+ `job` 表即可。抽象 `Dispatcher` 接口，未来可平滑换 MQ |
| Kong | ❌ 砍掉 | 演示环境无需 API 网关；Gin 中间件完成鉴权/CORS/日志。生产部署 Nginx 反代静态资源+API |
| Tiptap 病历编辑器 | ⚠️ 暂缓 | 五级下钻到病历时**只读渲染**结构化病案 JSON 即可，不需要编辑器。确需编辑再引入 |
| Docker Compose | ✅ 保留 | 一键起 pg + redis + backend + frontend(nginx) |

**最终落地栈**：`Vue3 + TS + Vite + Pinia + VueRouter + ElementPlus + ECharts` / `Go + Gin + GORM` / `PostgreSQL16` / `Redis` / `Docker Compose`

---

## 2. 系统拓扑

```
┌─────────────────────────────────────────────────────────────────────┐
│  浏览器                                                                │
│  ├─ /screen        大屏（2048×1152 定标缩放，轮询 30s）                  │
│  └─ /metric /dept /drg /cases /alerts ...  下钻页（ElementPlus 管理台）  │
└──────────────┬──────────────────────────────────────────────────────┘
               │ HTTPS/JSON  (唯一契约面：/api/v1/**)
┌──────────────▼──────────────────────────────────────────────────────┐
│  Nginx（生产） / Vite dev proxy（开发）                                 │
└──────────────┬──────────────────────────────────────────────────────┘
┌──────────────▼──────────────────────────────────────────────────────┐
│  Go Backend (单进程单体，内部分层)                                       │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │ API 层  internal/handler    Gin 路由、参数绑定、统一响应封装        │  │
│  │ 业务层  internal/service    指标编排、告警规则、下钻查询、脱敏      │  │
│  │ 读模型  internal/repository 只读 DWS/ADS/sys 查询（组装契约 DTO） │  │
│  │ ──────────── 写侧：双轨制（核心边界） ────────────               │  │
│  │ Fact Producer（写 dwd，二选一）                                  │  │
│  │   internal/simulator   虚拟时钟/日批次/日内回放 —— 仅 sim 模式    │  │
│  │   外部 ETL/CDC 进程     HIS/EMR/HRP→ODS→同结构 dwd —— 真实模式   │  │
│  │ Derived Pipeline（写 dws/ads，两种模式常驻）                     │  │
│  │   internal/jobs        DayAgg / TodayKpi / AlertScan / 兜底cron  │  │
│  └───────────────────────────────────────────────────────────────┘  │
└──────┬───────────────────────────────┬──────────────────────────────┘
       │                               │
┌──────▼─────────────┐      ┌──────────▼──────────┐
│ PostgreSQL 16       │      │ Redis               │
│ schema:             │      │ refresh吊销/热缓存   │
│  sys / dim / dwd /  │      │ /登录失败计数        │
│  dws / ads / sim    │      │                     │
└─────────────────────┘      └─────────────────────┘
```

**关键设计：契约面 vs 数据面分离 + 写侧双轨制**

- 前端只认 `/api/v1` 的 JSON 形状（见 `api-contract.md`）。
- 读侧：API **默认只读 DWS/ADS/sys**（白名单：今日 realtime 指标、L5 病例穿透、告警事实回溯），不关心数据谁写的。
- 写侧：**Fact Producer**（仿真器 ↔ 未来 ETL，互斥二选一）只写 dwd 事实；**Derived Pipeline**（聚合/今日快照/告警扫描）两模式常驻写 dws/ads。切换 = `DATA_SOURCE=etl` 重启 + 清场 TRUNCATE，API/前端零改动（运行手册见 simulation-plan §7）。

---

## 3. 后端内部结构

```
backend/
├── cmd/server/main.go          # 装配：config → db → redis → router → jobs → (sim only) simulator
├── internal/
│   ├── config/                 # env/yaml；DATA_SOURCE=sim|etl 控制装配差异
│   ├── handler/                # gin handler：auth, screen, metric, drg, dept, alert, todo, campus, dict, case, staff, hospital
│   ├── service/                # 业务编排+脱敏出口；依赖 repository 接口
│   ├── repository/             # GORM/SQL 实现；返回 service 层领域模型
│   ├── simulator/              # ★ Fact Producer（仅 DATA_SOURCE=sim 启动）
│   │   ├── clock.go            #   虚拟时钟（sim_clock 表驱动，可倍速）
│   │   ├── gen.go              #   DayGen 日批次生成器（门诊/住院/手术/床位/收费/DRG病例）
│   │   └── intraday.go         #   Intraday 写面：随 tick 增量 upsert 当日 dwd 行
│   ├── jobs/                   # ★ Derived Pipeline（两模式常驻）
│   │   ├── sim_tick.go         #   SimTick：原子推进时钟+Intraday+跨日catch-up（sim 模式）
│   │   ├── day_agg.go          #   DayAgg：dwd→dws→ads.rank 聚合
│   │   ├── today_kpi.go        #   TodayKpi：当日事实→ads.today_kpi/campus_status
│   │   ├── alert_scan.go       #   AlertScan：规则扫描→ads.alert_event（tick内+真实cron兜底）
│   │   └── todo_escalate.go    #   工单逾期置位
│   ├── middleware/             # JWT 鉴权、CORS、trace_id、panic recover、审计日志
│   ├── model/                  # GORM 实体（与 database-schema.md 一一对应）
│   └── pkg/                    # resp 包络、errcode、分页、validator、clock(统一时间源)
├── migrations/                 # golang-migrate SQL 迁移文件（唯一 schema 来源）
├── seed/                       # 维度种子数据（科室/DRG组/楼宇/指标字典/账号）
└── Dockerfile                  # 多阶段构建：golang 编译 → distroless/alpine 运行
```

**分层纪律（防耦合红线）**：

1. `handler` 只做：参数绑定 → 调 service → `pkg/resp.OK/Fail` 出包络。**禁止写 SQL、禁止拼响应内层字段**。
2. `service` 组合多个 repository，产出契约 DTO。**禁止 import gin**。
3. `repository` 每张表一个文件；聚合查询手写 SQL。**禁止返回 GORM model 给 handler**——service 负责 model→DTO 映射。
4. DTO 结构体与 `api-contract.md` 字段一一对应，DTO 即契约的代码镜像，改 DTO 必须同步改契约文档。

---

## 4. 数据流（模拟期）

```
SimTick (每30s真实时，单事务)
   ├─ 原子推进 sim.clock.virtual_now（speed 倍速）
   ├─ Intraday 增量 upsert 当日 DWD 行（分时/留观/移动/手术状态/床位）
   ├─ 跨虚拟日检测 → DayGen 补昨日事实 → DayAgg 聚合
   ▼
DWD 事实表 ──DayAgg(共用SQL)──► DWS 日汇总 ──► ADS.dept_rank_day
   │
   ├─TodayKpi──► ADS.today_kpi / ADS.campus_status ──→ Redis 热缓存(旁路) ──→ /screen/*
   └─AlertScan──► ADS.alert_event（去重键: rule+target）
```

- **虚拟时钟**：`sim_clock` 表存 `virtual_now`，speed 倍速/暂停/定点回放。所有业务时间走 `pkg/clock.Now(ctx)`，禁止 `time.Now()`。时钟跳转→热缓存同步失效。
- **tick 原子性**：一次 tick 的"推时钟+写事实+跑派生"单事务，读者不见半个 tick；跨多日 catch-up 循环。
- **告警引擎**：tick 内按虚拟时间评估 + 真实 cron 60s 兜底；去重语义见 simulation-plan §5。

## 4.1 工程基线（动工前冻结）

| 项 | 约定 |
| :--- | :--- |
| 日志 | stdlib `log/slog` JSON；trace_id 贯穿请求日志（middleware 生成，包络回写） |
| 优雅停机 | `http.Server.Shutdown(10s)` + 停 cron + 等 tick 事务收尾（sim.job_log 落 finished） |
| DB 连接池 | `SetMaxOpenConns(20)/SetMaxIdleConns(5)/ConnMaxLifetime(30m)` |
| panic recover | middleware recover → `resp.Fail(10000)` + slog 堆栈 + trace_id |
| NoRoute/NoMethod | Gin NoRoute→10003、NoMethod→10004，包络全覆盖 |
| 事务边界 | 多写操作单事务：dispatch=alert状态+todo+audit 一 tx |
| Redis 降级 | 热缓存纯旁路：miss→DB；Redis 挂→直读 DB+降级日志，**不做硬依赖** |
| cron 健壮性 | `cron.WithChain(SkipIfStillRunning, Recover)` + job timeout |
| Gin 版本 | ≥1.7（静态段 /departments/ranking 与参数段 :id 同层注册需此版本） |
| 服务端超时 | `http.Server{ReadTimeout:15s, WriteTimeout:30s, IdleTimeout:60s}`；API p95 预算：常规端点<1s、snapshot/钻取<3s（对齐白皮书"1s响应/3s钻取"） |
| 容器 | 多阶段构建；TZ=Asia/Shanghai；audit ip 走 X-Forwarded-For+trusted proxies |

---

## 5. 安全与合规（演示级）

| 项 | 方案 |
| :--- | :--- |
| 认证 | 账号密码 → JWT access(2h) + refresh(14d)；refresh 轮换用 Redis `GETDEL` 一次性消费 + 30s 宽限窗（实现=旧token→新pair 的 30s 旁路映射，契约 §1） |
| 登录防爆破 | Redis 计数：同账号 5 次失败锁 15 分钟 → 20104（仅登录端点，不做全局限流） |
| 授权 | RBAC：`admin / president / ops_director / viewer` → perm 清单（契约 §12）；路由级中间件校验 |
| 审计 | 写操作（督办派发、ack/close、登录、脱敏访问、sim 时钟）落 `sys_audit_log` |
| 脱敏 | **统一在 service 层出口**（/cases 列表、详情、alert related 单点收敛）；`?unmask=1` 需 `case:unmask`（admin+president）且记审计；仿真期 patient_name 为空时 unmask 返回同 masked 值（语义=审计占位） |
| 传输 | 生产 Nginx TLS；密码 bcrypt；密钥走 env |
| 等保 | **有意偏离**：白皮书要求等保三级+全量动态脱敏，本项目降级为演示级（水印=登录人 emp_no、操作审计、登录节流）——已对上游文档显式偏离，需干系人确认 |

**其他显式偏离登记**（同需干系人确认）：

| 白皮书要求 | 本期决策 | 理由/回归路径 |
| 移动端晨会"掌上运营"、iPad 办公会 | ❌ 不做移动端适配 | 大屏 2048 定标；<1200px 给降级引导页；P3 再议独立移动布局 |
| 督办一键派发企微/钉钉待办 | ❌ 不接外部 IM | 督办在系统内 todo_order 闭环；webhook 出口 P2 预留（契约不变） |

---

## 6. 部署

### 6.1 环境变量清单（`.env.example` 镜像）

| 变量 | 默认 | 说明 |
| :--- | :--- | :--- |
| `ENV` | `dev` | `dev`/`sim`/`prod`；控制 /sim 路由注册与登录页快捷按钮 |
| `DATA_SOURCE` | `sim` | `sim`=启动 simulator jobs；`etl`=不启动（真实 ETL 模式） |
| `PG_DSN` | `postgres://edss:edss@db:5432/edss?sslmode=disable` | |
| `REDIS_ADDR` | `redis:6379` | |
| `JWT_SECRET` | （必填，无默认） | ≥32 字节随机串 |
| `ACCESS_TTL` | `2h` | |
| `REFRESH_TTL` | `336h`(14d) | |
| `SEED_DAYS` | `180` | 首次播种历史天数 |
| `LOG_LEVEL` | `info` | slog 级别 |

**`ENV`×`DATA_SOURCE` 语义矩阵（钉死）**：

| 组合 | /sim 路由 | simulator jobs | 用途 |
| dev+sim | ✓ | ✓ | **本地开发/演示（默认）** |
| sim+sim | ✓ | ✓ | 演示部署 |
| prod+sim | ✗ | ✓ | 预演环境（仿真数据但走生产加固） |
| prod+etl | ✗ | ✗ | **真实化目标态** |
| dev+etl | ✓（注册但 clock=真实 now，写操作报 35001） | ✗ | ETL 联调期调试 |

### 6.2 docker-compose 服务规格

```yaml
services:
  db:       postgres:16  # volume pgdata；healthcheck: pg_isready
  redis:    redis:7      # healthcheck: redis-cli ping
  backend:  build ./backend
            env_file .env
            depends_on: { db: {condition: service_healthy}, redis: {condition: service_healthy} }
            # entrypoint: server -migrate && server -seed && server  （迁移+播种在进程内完成，不用 init 容器）
            healthcheck: GET /healthz
  web:      build ./web (node 构建→nginx 运行)
            ports: "80:80"   # / → 静态; /api → backend:8080
```

### 6.3 nginx 配置要点

```nginx
location /api/ { proxy_pass http://backend:8080; proxy_read_timeout 30s;
                 proxy_set_header X-Forwarded-For $remote_addr; }   # 不缓存
location / { try_files $uri /index.html; }                          # history 路由
location ~* \.(js|css|png|woff2)$ { expires 30d; }                  # hash 静态长缓存
gzip on; gzip_types application/json text/css application/javascript;
# P2 SSE 预留：proxy_buffering off + proxy_read_timeout 3600s
```

开发态：`vite dev :5173` proxy `/api → :8080`；`go run ./cmd/server -migrate -seed`；`docker compose up db redis`。

---

## 7. 分期路线图（对齐白皮书）

| 期 | 内容 | 依赖 |
| :--- | :--- | :--- |
| P1 MVP | 大屏 5 面板全量 + 登录 + 告警列表 + 督办派发 + 五级下钻骨架（院→科→组→病组→病例） | 本套契约 + 仿真器 |
| P2 | 全指标字典页、科室驾驶舱深页、督办工单闭环追踪、SSE 实时推告警 | 契约内已预留字段 |
| P3 | ChatBI 语义层查数（`/metrics/query` DSL 已预留）、月度报告、What-If 沙盘 | 届时评估是否引入 ES/MQ/Tiptap |

**扩舱原则**：砍掉/暂缓的组件全部在契约外——重新引入时不得改动已有 API 形状，只允许"新增端点"或"data 内新增可选字段"。
