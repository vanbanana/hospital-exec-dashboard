# 运维与性能实施手册

> 当前工作树新增能力：周期备份、恢复校验、巡检、请求延迟统计、认证业务压测与查询索引。先记录实施规格，再实现。用户已授权继续推进运行验收；证据登记在 quality-remediation-plan.md。

## 1. 目标与范围

使用合成数据完成工程工作，无需医院数据。保持单体、PostgreSQL 和现有部署，不引入第三方监控库。新增运维工具只使用 Python/Go 标准库及现有 Docker/PostgreSQL 客户端。

本地备份和巡检是单机运维基础，不提供异地容灾或高可用。默认每小时备份、保留最近 48 份的定时器为可安装模板；目标 RPO 为调度间隔加备份耗时，实验室 RTO 实测约 52 秒；RPO 是调度与备份耗时的目标估算，未发生真实数据丢失。云会话使用前台调度，主机 systemd 模板仍须安装。

## 2. 运维配置

复制 deploy/ops.env.example 为被忽略的 .env.ops，或安装到主机 /etc/edss/ops.env。脚本不自动读取配置文件；手动运行先导出配置，systemd 使用 EnvironmentFile。Compose 项目/文件必须对应实际部署：

- EDSS_DEV_PROJECT：实际项目名，默认 edss-dev。
- EDSS_COMPOSE_FILES：仓库相对路径，逗号分隔，默认 deploy/docker-compose.yml。安全部署追加 deploy/docker-compose.production.yml。
- EDSS_ENV_FILE：可选，Compose 的环境文件路径，不把密钥放在命令参数。
- EDSS_DB_NAME：可选的目标库核对值。工具从已渲染的 Compose backend.environment.DATABASE_URL 确定实际库名，不打印 DSN；显式设置时必须与实际库名一致，失配拒绝。仅支持指向本项目 db:5432 的 PostgreSQL URL，外部库须使用独立运维方案。
- EDSS_BACKUP_DIR：默认 backups/automatic；EDSS_BACKUP_KEEP 默认 48，最少 2。生成文件只在该目录管理。
- EDSS_BACKUP_TIMEOUT_SECONDS：默认 1800；EDSS_BACKUP_MIN_FREE_BYTES 默认 1GiB，备份前检查剩余空间。

## 3. 备份、校验与恢复

参数入口保持兼容（无清单历史备份须显式许可）：scripts/backup-db.sh output.dump、scripts/restore-db.sh input.dump new_database。具体实现由 scripts/ops.py 提供。

备份输出自定义格式、0600 权限；临时文件及原子发布防止半份备份被当成成功，禁止覆盖已有目标。dump 旁写 .json 清单，包含格式版本、目标库、UTC 时间、耗时、字节数及 SHA256；源库跟随实际后端配置，显式核对值失配时拒绝备份。归档须可被 pg_restore --list 读取才发布。

自动入口：`python3 scripts/ops.py backup-cycle`（或 make ops-backup）。进程文件锁防并发；记录 backup-status.json 的最近尝试/成功/失败，只有新备份成功后才清理本工具创建且具有匹配清单的旧文件，最少保留两份。失败写结构化日志并返回非零，不能用旧备份冒充本次成功。备份状态更新需可写目录。

恢复先验证 SHA256 与大小、归档格式，再创建全新数据库；目标已存在即拒绝，禁止覆盖源库与默认业务/测试/系统库。pg_restore 单事务及 exit-on-error，失败保留新库供诊断。具有清单的备份如果校验失败不能继续；历史无清单备份需要显式 `EDSS_ALLOW_LEGACY_BACKUP=1`，仍检查归档格式。

`python3 scripts/ops.py verify-db source_database restored_database` 在停止业务写入后比较两库全部 sys/dim/dwd/dws/ads/sim 基础表和 public.schema_migrations：列结构、约束、索引、触发器定义/启用状态、业务 schema 函数摘要、排序后的 JSON 行流 SHA256、行数、序列 last_value/is_called。只输出摘要和差异表名，不输出行内容/口令。结果写入私有报告文件，差异返回非零。这是独立的内容校验入口，不能用 dump 文件校验替代恢复后数据校验。

各库使用独立只读可重复读快照，序列不受 MVCC 快照保护；跨库比较仍要求冻结写入。校验可能扫描全部数据，仅在隔离副本或维护窗口执行。业务 API、权限与恢复后写入的正确性另行验收。

## 4. 周期巡检与告警

`python3 scripts/ops.py monitor`（或 make ops-monitor）默认访问本机 API /ready、/stats，并检查备份新鲜度/上次失败、磁盘占用、DB 池占用与等待增长、5xx 增量、按路由的延迟桶增量。所有网络请求有超时，TLS 校验保留；配置 URL 不允许用户名、密码或查询参数。

monitor-state.json 私有原子保存上一拍；started_at 不同或计数下降时重建基线。延迟使用相邻两拍的直方图近似 p95，不冒充精确分位。默认请求至少 20 个才判断错误率/延迟。检查阈值在 ops.env.example 登记。首次样本没有增量窗口，不宣称无慢请求。

异常写 JSON 日志、标明告警项，返回非零使 systemd 服务失败；恢复输出恢复事件。没有内置邮件/Slack/Webhook发送，通知平台可订阅 journal 或服务失败。主机断电时同机巡检也停止，外部存活监控仍需独立部署。

deploy/systemd/ 提供备份（每小时）、巡检（每分钟）和资源快照（每分钟）模板，带执行超时；备份使用持久补调度，巡检/资源采样在重启后恢复节奏。把工作目录和运行用户改为实际专用运维用户（须能访问 Docker），配置 /etc/edss/ops.env，再安装到 /etc/systemd/system/、daemon-reload 和 enable --now 对应 .timer。源码云环境不自动启用。

`python3 scripts/ops.py resources`（或 make ops-resources）收集所选 Compose 正在运行容器的 CPU/内存/IO、主机磁盘与采样时间，输出 JSON；无需公开 Docker 端口。只有相邻采样和固定负载才可分析趋势。

## 5. /stats 新增字段（兼容增补）

仍为内部根级端点，Nginx 不透出，现有字段保持：

| 字段 | 含义 |
| --- | --- |
| started_at | 进程开始 UTC 时间，用于区分重启 |
| latency_bounds_ms | 固定延迟桶上界；最后另有溢出桶 |
| by_route | 方法 + 注册路由模板 → count/errors_5xx/latency_sum_ms/latency_max_ms/latency_buckets |
| runtime | goroutines/heap_alloc_bytes/heap_sys_bytes/gc_cycles |

延迟桶是非累计桶，桶数量为上界数量+1。所有 HTTP 状态均计入延迟，5xx 另计；统计是累计值，进程重启清零。未知路径合并为 __unmatched__，方法归一且路由桶最多 256，避免恶意路径造成无界内存。请求计时覆盖 handler 和会话中间件，日志输出耗时不计入。

## 6. 认证业务压测

改进 cmd/loadbench：保留 -base/-c/-d；新增 -profile public|business（默认 public）、-paths 自定义只读 API 路径、-warmup、-timeout、-rps 总请求启动速率上限、-json 报告文件、-max-error-pct 和 -max-p95-ms。business 混合大屏、综合概览、运营和分页工单。

business 或自定义受保护路径使用 EDSS_LOAD_USERNAME/EDSS_LOAD_PASSWORD 环境变量登录一次并共享 Cookie。账号需有相应权限；登录、探活、预热失败立即退出，避免把拒绝访问当成成功压测。禁止 URL 凭证、查询中携带令牌、跳转外站和关闭 TLS 验证，不在报告输出 Cookie/口令。

请求耗时包括响应体完整读取与包络解码；HTTP200 非零业务码、非 JSON、截断响应、网络错误均算失败。读取请求最大 8MiB，延迟分桶保存，内存随目标数固定，适合长时间运行。分位为桶上界近似值（超出最后桶时用最大值），成功与失败耗时一起统计；成功 RPS 与总 RPS 分开，按实际耗时计算。预热不计入统计。

压测工具只执行 GET 查询；工单 GET 带既有惰性过期维护，登录/续期也写会话审计，不描述为数据库绝对只读。写操作持续容量未包含，独立并发派发和审计失败回滚已另行验证。建议在隔离合成库运行，先固定硬件、数据量和阈值，再至少 30 分钟观测容量；本轮不声明测得性能提升比例。

## 7. 查询索引与事务汇总

新增 1000_ops_query_indexes.sql，仅加索引：登录失败审计 username/created_at 的条件索引；工单 status/id 与 assignee/id 支持倒序分页。现有 WHERE、角色过滤和排序语义不变。新增 1010 门诊日汇总与 1020 收费日/科室汇总后，共 18 个迁移、60 张业务表。两种汇总经语句级 INSERT/UPDATE/DELETE/TRUNCATE 触发器与源事实同事务维护，非整日门诊窗口仍读原始小时事实；没有 TTL 缓存或手工刷新依赖。

沿现有迁移器单文件事务执行普通 CREATE INDEX，会短暂阻塞目标表写入；维护窗口应用，不能描述为在线无锁迁移。运行库已在维护窗口应用；原始查询与日汇总执行计划分别保存。首次测试有并发验证负载，不能据此声称精确加速比例。


## 8. 激活步骤与当前验证范围

模板默认 WorkingDirectory=/opt/hospital-exec-dashboard、User=edss-ops，部署时按实际主机调整。为该用户准备 Docker 访问权限及可写的私有备份目录。配置项不含登录口令，Compose 密钥由 EDSS_ENV_FILE 指向的私有文件读取。

```bash
# 在实际部署主机：先调整单位文件的用户和工作目录、ops.env 的项目/库/路径
sudo install -d -m 0750 /etc/edss
sudo install -m 0640 -o root -g edss-ops deploy/ops.env.example /etc/edss/ops.env
sudo install -m 0644 deploy/systemd/edss-*.service deploy/systemd/edss-*.timer /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now edss-backup.timer edss-monitor.timer edss-resources.timer
# 运行状态与告警：
systemctl list-timers 'edss-*'
journalctl -u edss-backup.service -u edss-monitor.service -u edss-resources.service
```

现有服务升级需正常备份、维护窗口迁移 1000/1010/1020、重建/重启后端；本轮已在合成栈执行。非空恢复、数据库中断、备份失败/篡改、互斥/保留和优雅升级已验证；持续容量按整改记录。没有声明最大并发或无干扰加速比例。

CI 新增运维安全边界测试、脚本语法、全服务日志上限及两种汇总与原始事实的独立 SQL 检查。备份/恢复和持续压测为受控运行验收，不在每次 CI 自动执行。托管 CI 本轮未执行。

## 9. 本轮验收目标（执行前固定）

- 合成数据现有规模，认证 GET 混合查询：并发 16，启动速率上限 50 请求/秒，预热 10 秒，持续 30 分钟。每条业务路由错误率 ≤1%、p95 桶上界 ≤1000ms，整体成功吞吐 ≥45 请求/秒；p99 单独报告。降载后连接池可用、堆占用和协程无持续增长。资源采样每分钟。
- 隔离副本通过真实 API 生成非空工单、状态变化、偏好和审计；冻结写入后备份恢复，全部表内容、结构和序列一致，恢复后 API 读写与约束正常。实验室 RTO（恢复至 API 可用）≤5 分钟；小时备份的配置 RPO≤65 分钟，必须区分配置上限与实际已丢数据。
- 备份覆写、旧库覆写、归档篡改、空间阈值拒绝、保留和互斥都实际检查；DB 中断就绪失败和本地告警，恢复后自动恢复；应用优雅重启保留持久化业务。
- 无 systemd 的云环境新增 `ops.py run` 前台调度入口：启动即运行备份/巡检/资源，之后按独立间隔执行，同类任务不重叠，子进程超时、退出码和下一次调度记录到私有状态；SIGTERM 停止调度并限时回收任务。宿主重启自动拉起仍由 systemd/现有进程管理器负责，云会话运行不冒充主机开机激活。
- 界面：移除科研、患者、质量、资产四页无数据语义的时间按钮，并在副标题明确固定统计口径；根级未知路径转工作台，由既有权限守卫决定登录或允许页面。接口不增加虚假的 range 参数。
- 当前 8 分评价仅针对声明的单机合成数据工程规模；完整 E1/E2/E4/E5 清单、异地备份、外部通知、容器扫描和托管 CI 仍分别登记。

cloud-dev 的启动命令改为先构建再 exec 服务二进制，确保 SIGTERM 交给服务器执行优雅停机；开发 SDK 仍在容器内，不作为生产镜像。

运维强化：巡检从清单的备份开始时间计算新鲜度，并重新核对 SHA256；备份文件损坏须告警。默认新鲜度目标改为 3900 秒（65 分钟），不是失败时仍保证不丢数据的承诺。日志轮转默认单服务 10MiB ×3，cloud-dev 的独立 API 也采用此上限；已有容器须重建才应用轮转选项。

实际镜像构建触发云盘满故障：停止并行构建，清理本任务构建缓存与已冻结的临时 SDK 容器，保留数据库和有效备份。改进要求：调度状态文件不可写时输出失败事件、继续调度而不退出；备份/巡检先输出结果再尝试原子保存状态。新增串行镜像构建入口，按目标检查 6GiB 可用空间，不足时在构建前拒绝。验收过程中中断的压测保存为失败证据，恢复后从头执行 30 分钟，不混作完整通过记录。

最终容量验收对象：标准 Dockerfile 构建的 `hospital-edss-backend:quality8`，本机 8080、SIM=1/DEMO_ROLE_SWITCH=1/SCREEN_PUBLIC=1、DB 池 25/5，源码与已通过回归的工作树一致。生产安全栈另行检查 SIM=0/角色切换关闭/公开大屏关闭/Secure Cookie 与 TLS，不把 HTTP 开发链路当 TLS 证据。`scripts/build-images.sh` 是串行带空间门禁的构建入口，Make up/build-images 采用此入口；直接 Docker 构建须由部署平台自行约束空间。

前台调度启动（进程须由部署平台拉起，云会话可以保留执行会话）：

```bash
EDSS_DEV_PROJECT=edss-remediation python3 scripts/ops.py run
# 正式主机可用已有 systemd 三个定时器；不能两套调度同时运行
```

状态：backup-status.json / monitor-state.json / scheduler-state.json 在 EDSS_BACKUP_DIR 内，0600 原子写。状态盘不可写时调度器输出失败事件并继续执行巡检/下次备份，不把未落盘事件当成已持久化。调度/巡检日志应由宿主日志系统保留；云会话日志不提供外部通知或主机重启存活保证。

cloud-dev 调试/测试复用正在运行的健康 DB，不因 Compose 配置漂移自动重建 DB；配置升级由维护窗口的明确 Compose 部署执行。全新合成初始化被 DB 重建中断时，可使用迁移器 -seeddir 选取未完成的规范种子文件恢复，须独立核对全部种子覆盖和 ready。

## 10. 本轮实测结果

完整30分钟认证查询达到固定门槛：83,962次、成功46.60RPS、总错误率0.099%、各路由p95桶上界≤1秒。61表/24序列非空恢复一致，恢复至API就绪52.01秒；备份保护、数据库中断、连接池耗尽及优雅升级通过。故障、资源、初始化与未测边界详见 [本轮证据](quality8-evidence.md)，不是最大容量或高可用承诺。

镜像建议用 `scripts/build-images.sh` 或 `make build-images` 串行构建，逐目标预检默认6GiB空闲；可用 EDSS_BUILD_MIN_FREE_BYTES 配置正整数门槛。EDSS_ENV_FILE 指向私有配置；云代理 CA 继续作为构建secret。后端构建完成后检查非root用户可读迁移/种子文件。空间预检不能替代磁盘监控和容量规划。
