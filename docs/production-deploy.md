# 部署与恢复手册

> 2026-10-09 静态对齐。production 是安全部署配置，数据仍为 demo。无需医院数据即可验证部署、权限和恢复；真实医院接入/对账不纳入验收。现状见 [current-state.md](current-state.md)，后续标准见 [engineering-acceptance.md](engineering-acceptance.md)。

## 1. 本地开发（云环境）

需要 Docker、Node >=22.12、npm 与 Python 3。宿主没有 Go SDK 时使用官方 golang:1.27 容器。

```bash
npm ci --cache /tmp/edss-npm-cache --registry=https://registry.npmjs.org --replace-registry-host=always
scripts/cloud-dev.sh start
npm run dev -- --host 127.0.0.1
# 完整后端测试会初始化独立写域库；首次种子较慢。
scripts/cloud-dev.sh test
```

start 只在 schema_migrations 缺席的全新库灌演示种子，正常重启只迁移。初始化中断时检查日志后显式 scripts/cloud-dev.sh seed 继续；绝不能对真实库执行 seed。项目默认 edss-dev，命名卷 edss-dev_pgdata 保留；接续已有环境使用对应 EDSS_DEV_PROJECT（本会话 edss-remediation）；不使用 down -v。

cloud-dev.sh 仅管理本项目内网 db 的 hospital_edss 演示库，拒绝其他 DATABASE_URL，防止将自动演示初始化用于外部数据库。其他目标库使用手动迁移和部署流程。

云代理证书经 SSL_CERT_FILE 只读挂载给 Go；镜像构建另叠加 docker-compose.cloud.yml 使用 BuildKit proxy_ca，保持 TLS 验证。

## 2. 演示容器栈

基础栈默认不灌种子。全新演示库只在首次显式设置 SEED_ON_BOOT=1 初始化，之后设置 0。

```bash
SEED_ON_BOOT=1 docker compose -f deploy/docker-compose.yml -f deploy/docker-compose.edssprod.yml up -d --build
SEED_ON_BOOT=0 docker compose -f deploy/docker-compose.yml -f deploy/docker-compose.edssprod.yml up -d
```

HTTP 8093 / HTTPS 8443；镜像内自签证书仅演示使用。演示覆盖不挂空证书目录。

## 3. 生产安全配置

将 .env.production.example 复制为被忽略的 .env.production，填写 POSTGRES_PASSWORD 及 TLS_CERT_FILE/TLS_KEY_FILE。使用正式证书。密码包含 DSN 保留字符时提供 URL 编码后的 DATABASE_URL；基础 compose 使用 DATABASE_URL 优先，否则按密码组装内网 DSN。

前置条件是数据库已有经核对的合成业务数据。全新空库仅迁移仍不能通过 ready，web 不会启动。先用开发脚本或演示配置在隔离库初始化种子，再备份恢复到新库并显式设置 DATABASE_URL；production 强制不播种，数据仍标为 demo。此过程不要求医院数据。

```bash
docker compose -f deploy/docker-compose.yml -f deploy/docker-compose.production.yml --env-file .env.production up -d --build
```

生产覆盖固定 SEED_ON_BOOT=0、SIM_ENABLED=0、DEMO_ROLE_SWITCH=0、AUTH_COOKIE_SECURE=1、SCREEN_PUBLIC=0；无法通过 .env 意外开启演示闸。缺口令在配置解析时失败；缺证书文件在启动时失败。HTTP 跳转 HTTPS，web 等待 backend healthy。backend 调试端口只绑定回环，PG 不发布端口。

基础 compose 空 SEED_ON_BOOT 保持空值，启动判等 1 才灌种子。生产绝不使用空值表达关闭。

生产拒绝域未定义的全院读取；scope_type=dept 按科室过滤工单与人员；非管理用户服务端强制姓名脱敏。未知角色与新注册但未授权路由默认拒绝。不要将隐私展示开关当作访问权限。

业务时间仍由 sim.clock.virtual_now 提供：禁用仿真控制面不会使数据自动更新。数据模式标识为 demo；常驻生成、同步与派生管线未实现，后续若纳入范围须使用合成场景验收，不等待真实医院接口。

## 4. 备份与恢复

先停业务写入，再备份。脚本从渲染后的 Compose 后端 DSN 选择实际部署库，EDSS_DB_NAME 为可选核对值，保存自定义格式及 SHA256 清单并使用 0600 权限；目标文件存在时拒绝覆盖，命令失败不留下成功备份。

```bash
mkdir -p backups
scripts/backup-db.sh backups/edss.dump
scripts/restore-db.sh backups/edss.dump hospital_edss_restore
# 停业务写入后进行独立内容校验（源库名按实际配置）
python3 scripts/ops.py verify-db hospital_edss hospital_edss_restore
```

恢复目标必须是新数据库，拒绝覆盖 hospital_edss、hospital_edss_w 或 postgres。恢复使用单事务与 exit-on-error。通过非空业务表内容摘要、主外键/序列、关键 API 结果和迁移台账核对后，再由操作员切换 DATABASE_URL。指定其他 Compose 项目时设置 EDSS_DEV_PROJECT。

## 5. 升级与故障恢复

升级序：备份 → edss-migrate（不带 -seed）→ ready → 登录/权限/关键指标检查。迁移有 schema_migrations 追踪、文件事务和 advisory lock；重复执行应 0 applied。数据库重启后 API 可重新连接；ready 失败不能当作健康，web 健康依赖并不替代外部告警。

共享安全部署前轮换公开演示口令，并吊销对应 user_session；用户管理扩展须先定义内部契约，医院数据接入不在范围内。迁移与恢复均先在隔离副本执行。

## 6. 门禁

npm run build；npm run test:unit；npm run test:e2e；python3 tests/deploy-config.py；Go vet/build/test -race；make ci-mech。集成测试数据库缺失即失败。CI 安装 Chromium 并运行演示链路及生产权限模式；后者在 HTTP 下使用 AUTH_COOKIE_SECURE=0，不等于 HTTPS/Secure Cookie 验证。make ci 不含浏览器、配置测试或恢复；完整入口见 [acceptance.md](acceptance.md)。


## 7. 周期运维与性能

新增 [运维性能手册](operations-performance.md) 和 deploy/ops.env.example。安全部署的 EDSS_DEV_PROJECT、EDSS_COMPOSE_FILES、EDSS_ENV_FILE、EDSS_DB_NAME（如设置）必须对应当前栈，特别是已切换到恢复库的场景。

提供 backup-cycle、monitor、resources 命令及 systemd 定时器。异常写 JSON 日志并返回非零；不自动发邮件或外部消息，也不自动安装定时器。正式启用前明确备份目录权限、磁盘预算、日志保留及告警接收渠道。

新 1000 迁移仅加索引，按普通事务建索引会阻塞写入，应在维护窗口执行。/stats 新指标需重启新版后端才能使用；当前运行服务未自动重建。认证压测只在隔离合成库运行，固定硬件、数据量及阈值，实际结果再登记。

镜像必须保证非 root 服务用户可读全部 migrations/seed SQL：Dockerfile COPY 后显式归一目录/文件读取权限，不依赖本地 umask。部署前运行镜像文件访问检查，再验证全新合成库初始化和已有库升级；本轮曾由新增文件 0600 触发迁移 permission denied，须保留回归证据。

## 8. 离线 Docker 交付

交付包包含 linux/amd64 前端、后端、PostgreSQL 镜像，源码归档、SHA256、Compose 和启停／初始化／备份脚本。交付镜像用本地已验证的 Go 静态二进制与前端 dist 构建；Alpine 基础镜像不执行网络 apk，公共 Mozilla 根证书与东八区 zoneinfo 从构建机标准目录复制，云代理 CA 不进入镜像。无需接收方安装 Node/Go 或下载业务依赖。

初次使用随机生成数据库口令，首次 initialize 显式播种合成数据。已有数据库只能迁移，禁止自动重播种。默认 web 仅监听 127.0.0.1；共享云服务器需配置域名、TLS 和可用的部署凭据。真实权限默认启用，演示角色切换关闭，SIM 控制面关闭，大屏需要登录；数据仍为合成数据。公网部署使用正式 TLS 配置和 Secure Cookie，并轮换公开演示账号口令。
