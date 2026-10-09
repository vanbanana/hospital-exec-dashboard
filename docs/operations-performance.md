# 运维与性能实施手册

> 本文说明备份、恢复校验、巡检、请求延迟、认证负载工具与查询索引。激活和验收须在目标部署环境执行。

## 1. 目标与范围

使用合成数据完成工程工作，无需医院数据。保持单体、PostgreSQL 和现有部署，不引入第三方监控库。新增运维工具只使用 Python/Go 标准库及现有 Docker/PostgreSQL 客户端。

本地备份和巡检是单机运维基础，不提供异地容灾或高可用。默认每小时备份、保留最近 48 份的定时器为可安装模板；RPO 取决于调度间隔与备份耗时，RTO 须在目标环境实测。前台调度与 systemd 模板均须部署者启用。

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

压测工具只执行 GET 查询；工单 GET 带既有惰性过期维护，登录/续期也写会话审计，不描述为数据库绝对只读。写操作持续容量未包含，独立并发派发和审计失败回滚已另行验证。建议在隔离合成库运行，先固定硬件、数据量和阈值，再至少 30 分钟观测容量；不能在未测量时声明性能提升比例。

## 7. 查询索引与事务汇总

新增 1000_ops_query_indexes.sql，仅加索引：登录失败审计 username/created_at 的条件索引；工单 status/id 与 assignee/id 支持倒序分页。现有 WHERE、角色过滤和排序语义不变。新增 1010 门诊日汇总与 1020 收费日/科室汇总后，共 18 个迁移、60 张业务表。两种汇总经语句级 INSERT/UPDATE/DELETE/TRUNCATE 触发器与源事实同事务维护，非整日门诊窗口仍读原始小时事实；没有 TTL 缓存或手工刷新依赖。

沿现有迁移器单文件事务执行普通 CREATE INDEX，会短暂阻塞目标表写入；维护窗口应用，不能描述为在线无锁迁移。需要在目标库维护窗口应用，并比较相同输入下的查询结果和执行计划。


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

现有服务升级应先备份，再在维护窗口应用 1000/1010/1020 迁移，重建并重启后端，核对 /ready、登录和关键业务 API。恢复、故障与容量需在隔离副本验证。

CI 包含运维边界、脚本语法、日志上限及汇总与原始事实对照检查；实际备份恢复、HTTPS 和持续负载不在每次 CI 自动执行。

## 9. 无 systemd 的前台调度

```bash
EDSS_DEV_PROJECT=edss-dev python3 scripts/ops.py run
```

运行前按本手册导出配置。进程须由部署平台托管，不能同时启用两套备份调度。状态文件在 EDSS_BACKUP_DIR 中使用 0600 权限及原子保存；状态盘写入失败时输出失败事件，继续调度。外部通知和宿主重启自动恢复须另行配置。

构建镜像使用 scripts/build-images.sh 或 make build-images，逐目标预检默认 6GiB 空闲；EDSS_BUILD_MIN_FREE_BYTES 可设置正整数门槛。空间预检不替代磁盘监控。后端非 root 用户必须能读 migrations/seed。

迁移跟踪、内容恢复校验与容量要求见 [工程验收计划](engineering-acceptance.md)。只在声明的数据量、硬件和负载下评价结果，不声称未经验证的最大容量。
