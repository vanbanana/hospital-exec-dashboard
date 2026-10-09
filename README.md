# 院长查询与决策支持系统（EDSS）

工作台用于查看指标、比较业务、处理预警和督办工单；大屏用于集中展示院区态势。两个界面共用 Vue / TypeScript 前端、Go API 与 PostgreSQL 数据库。

系统使用持久化合成数据，页面业务日期来自数据库仿真时钟。没有接入真实 HIS/EMR；API 失败时不会用前端假数据补齐业务指标。

## 选择启动方式

| 方式 | 适用场景 | 前置条件 |
| --- | --- | --- |
| 源码开发 | 修改界面或后端、运行测试 | Node.js ≥22.12、npm、Docker Compose ≥2.24.4、Python 3、curl、Bash；首次需要联网 |
| 源码 Docker 构建 | 从源码构建完整应用 | Docker Engine / Compose ≥2.24.4、Python 3、Bash、Make、可用依赖网络；构建脚本默认预检 6GiB 空闲磁盘 |
| 离线 Docker 包 | 直接使用已编译应用 | 另行交付的镜像包；Linux x86_64 或支持 linux/amd64 的 Docker Desktop |

Windows 推荐 Docker Desktop + WSL2，在 WSL2 的 Linux 文件系统解压工程并运行命令；macOS/Linux 使用 Bash 终端。开发脚本使用容器化 Go，无需宿主 Go；直接编译后端另需 Go 1.27。源码 ZIP 不含依赖目录、编译文件或 Docker 镜像。

## 从源码启动

所有命令在工程根目录执行。

### 1. 安装依赖

```bash
npm ci
```

### 2. 启动数据库与 API

```bash
export EDSS_DEV_PROJECT=edss-dev
bash scripts/cloud-dev.sh start
```

脚本启动命名卷数据库、执行迁移并启动 API。仅全新库自动播种，已有库只迁移。看到 `API ready; run npm run dev` 后继续。初始化期间保持 Docker 运行。

默认 API 为 `127.0.0.1:8080`，Vite 代理固定连接此端口；更改 `EDSS_API_PORT` 时须同步 `vite.config.ts`。继续已有环境时，项目名必须使用原来的 `EDSS_DEV_PROJECT`，避免新栈占用相同端口。

### 3. 启动界面

```bash
npm run dev
```

打开 [http://localhost:5173](http://localhost:5173)，未登录进入登录页。保持 Vite 终端运行。不要直接打开 index.html，也不要省略数据库/API。

### 4. 登录

| 用户名 | 密码 | 用途 |
| --- | --- | --- |
| `president` | `Edss@2026` | 院级工作台、预警和大屏 |
| `ops_director` | `Edss@2026` | 运营管理角色及授权业务页 |
| `dept_leader` | `Edss@2026` | 科室范围工单与个人偏好 |
| `admin` | `Admin@123` | 管理及仿真 API；无网页仿真控制台 |

菜单和操作按真实账号授权，账号存在不代表能访问所有页面。演示管理身份可切换展示视角；验证真实权限应退出后重新登录目标账号。公开演示密码仅供隔离体验，对外共享前需轮换密码并吊销旧会话。

## 推荐体验流程

1. 用 president 登录，在首页查看 KPI、趋势、排行、预警、通知及待办。
2. 在概览、医疗、运营和对比页使用页面实际提供的统计范围，观察图表变化。科研、患者、质量、资产页采用固定口径。
3. 在首页预警区使用认领、派发或关闭操作。派发时选择承办人并填写要求；到“督办工单”接单，再填写办结结果提交。操作按权限和当前状态开放，会持久化并记录审计。
4. 在“个人偏好”调整默认范围、刷新间隔、声音、金额缩写和姓名脱敏。修改自动保存，失败提示并回退；固定口径页不受默认范围影响。
5. 点击“数据大屏”，体验适配与全屏；点击“返回工作台”回到进入前页面，保留地址中的查询参数。入口按真实会话授权显示。
6. 从头像菜单退出，登录 dept_leader，观察授权页面和科室工单范围。

更详细的操作与实际功能边界见 [使用指南](docs/user-guide.md)。推荐桌面浏览器使用工作台；大屏提供等比适配和填满模式。

## 页面入口

| 页面 | 地址 |
| --- | --- |
| 首页 | `/workbench` |
| 概览 / 医疗 / 运营 | `/workbench/overview`、`/workbench/medical`、`/workbench/operations` |
| 人力 / 科研 / 患者 / 质量 / 资产 | `/workbench/hr`、`/workbench/research`、`/workbench/patient`、`/workbench/quality`、`/workbench/assets` |
| 对比 / 专题 / 系统设置 | `/workbench/compare`、`/workbench/topics`、`/workbench/settings` |
| 工单 / 个人偏好 | `/workbench/tasks`、`/workbench/preferences` |
| 大屏 / 登录 | `/screen`、`/login` |

工作台共 14 个导航页，按 allowed_pages 显示；access 为无可用授权页面时的回退页。顶栏搜索当前禁用。设置中的来源和用户表只读；规则启停与个人偏好可写。五级病历穿透、ChatBI、在线用户管理与医院数据同步未实现。

## 停止、恢复和查看日志

在 Vite 终端按 Ctrl+C 停止前端，后台继续运行。停止开发后台：

```bash
docker stop "${EDSS_DEV_PROJECT:-edss-dev}-api"
docker compose --project-name "${EDSS_DEV_PROJECT:-edss-dev}" -f deploy/docker-compose.yml down
```

恢复使用 `bash scripts/cloud-dev.sh start` 和 `npm run dev`。普通 down 保留命名卷；不要加 -v，否则会删除数据库卷。

```bash
docker logs --tail 100 "${EDSS_DEV_PROJECT:-edss-dev}-api"
curl -fsS http://127.0.0.1:8080/ready
docker compose --project-name "${EDSS_DEV_PROJECT:-edss-dev}" -f deploy/docker-compose.yml ps
```

## 源码 Docker 构建

在未启动开发 API、默认端口可用的环境运行：

```bash
cp .env.example .env
SEED_ON_BOOT=1 make up
```

仅全新演示库首次使用 SEED_ON_BOOT=1，后续执行 `SEED_ON_BOOT=0 make up`，避免重播种重置种子域。打开 [http://localhost](http://localhost)。可在 .env 设置 WEB_PORT=8088，改用对应端口访问。

```bash
make logs
make down
```

make up/down/logs 管理基础 Compose 应用；cloud-dev.sh 的独立开发 API 使用上一节的启停命令。生产安全部署需要正式 TLS、非空数据库密码、已初始化数据并关闭演示开关，按 [部署手册](docs/production-deploy.md) 执行。

## 离线 Docker 包

以下命令仅在另行交付的镜像包中执行，源码 ZIP 本身不能加载镜像：

```bash
cd hospital-edss
bash manage.sh load
bash manage.sh initialize
```

打开 [http://localhost:8088/workbench](http://localhost:8088/workbench)。后续分别使用 `bash manage.sh status`、`logs`、`stop`、`up` 或 `backup`；HTTPS 模式使用 `https-up`。默认按真实会话授权，关闭公开大屏、仿真控制面与演示角色切换。完整说明见 [离线交付手册](deploy/delivery/README.md)。

## 常见问题

| 现象 | 处理 |
| --- | --- |
| Docker 命令失败 | 启动 Docker，检查 docker info 与 docker compose version |
| 脚本 Permission denied | 使用 bash scripts/cloud-dev.sh start；Windows 在 WSL2 内执行 |
| 页面打开但数据报错 | 检查 API /ready、API 日志和 Vite 代理，页面不会用假数据替代失败请求 |
| 5173/8080 被占用 | 停止占用进程或接续原项目，不重复启动相同端口的独立栈 |
| 初始化中断 | 检查日志；确认是本项目合成库后执行 bash scripts/cloud-dev.sh seed，再执行 start；不要对生产库播种 |
| 镜像/npm 下载失败 | 检查网络、可信 registry 与代理 CA，不关闭 TLS 验证 |
| 登录后菜单少 | 对照真实账号授权，科室账号无院级页属于权限行为 |
| 登录被锁定 | 按提示等待锁定窗口，不删除审计数据解锁 |
| 页面日期与电脑不同 | 页面使用合成数据业务日期，与开发日期或本机日期无关 |
| 偏好未影响某页 | 固定口径页不使用默认范围，非管理账号强制脱敏；声音需先点击页面解锁播放 |
| 大屏报未登录/无权限 | 私有大屏先登录有院级权限的账号 |

## 开发检查

```bash
npm run test:unit
npm run build
make ci-mech
python3 tests/deploy-config.py
python3 tests/ops-test.py
bash scripts/cloud-dev.sh test
```

浏览器测试先启动演示后台，执行 `npx playwright install chromium` 和 `npm run test:e2e -- --grep-invert '生产权限模式'`。严格权限测试需要独立后台，见 [验收说明](docs/acceptance.md)。make ci 需要 Make、宿主 Go 与初始化的读/写两库，不包含全部浏览器、部署和恢复检查。

## 工程与文档

| 目录 | 内容 |
| --- | --- |
| src / public | 当前前端源码、图片和字体 |
| backend | Go API、18 个迁移与 13 个合成种子 |
| deploy / scripts | Docker、备份恢复和运维配置 |
| tests / .github | 测试及 CI |
| docs | 使用、接口、架构、数据库和运维文档 |

[文档索引](docs/README.md) · [当前实现与边界](docs/current-state.md) · [API 契约](docs/api-contract.md) · [后端手册](backend/README.md) · [部署与备份恢复](docs/production-deploy.md)

源码交付省略历史参考工程、研究资料和过程记录。当前应用的运行和构建不依赖这些资产。备份、定时器、外部告警及公网托管需要部署者配置；模板不代表已经在接收方环境启用。
