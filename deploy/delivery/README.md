# EDSS Docker 离线交付包

适用：Linux x86_64 / Docker Desktop（Intel/AMD；Windows 可用 WSL2）。需要 Docker Engine 与 Compose ≥2.24.4、至少 4GB 内存、8GB 可用磁盘。镜像已编译为 linux/amd64；不含 ARM 原生镜像。

## 首次启动

解压后进入 hospital-edss，执行：

```bash
./manage.sh load
./manage.sh initialize
```

打开 http://localhost:8088/workbench 。本机云端验证采用相同端口。首次初始化会执行 18 个迁移与 13 个确定性种子，可能需要几分钟。数据是合成数据，业务时间由仿真时钟提供；不代表实时医院数据。

登录演示账号：president / Edss@2026。科室权限验证账号：dept_leader / Edss@2026。这是公开演示口令；对外共享前必须轮换账号口令并吊销旧会话。数据库口令由 manage.sh 随机生成并写入权限 0600 的 .env，不包含在交付包里。

## 日常使用与升级

```bash
./manage.sh status
./manage.sh stop
./manage.sh up
./manage.sh backup
```

up 仅执行未应用迁移，不重灌种子。initialize 检测到已有迁移台账即拒绝；初始化意外中断时先查 logs，再由维护人员确认后运行 `docker compose --env-file .env -f compose.yml run --rm migrate -seed` 续种。持久卷保存数据库；不要运行 down -v。

升级前停止业务写入并 backup，载入新版镜像后运行 up，再核对登录、业务 API 和数据。备份是 PostgreSQL custom archive；恢复到新库使用 pg_restore --no-owner --exit-on-error --single-transaction，核对内容后再切换。更完整的恢复校验与运维方案位于 source.tar.gz 中的 docs/operations-performance.md。

## 云服务器 / HTTPS

当前包默认仅绑定 127.0.0.1、关闭演示角色切换和仿真控制面、大屏要求登录。数据库与后端无宿主公开端口。本包无需 Node、Go 或联网下载应用依赖。

要公网访问，将包上传你自己的 Linux 云服务器，配置 DNS、安全组和正式证书；在 .env 设置：

```dotenv
BIND_ADDRESS=0.0.0.0
WEB_PORT=80
HTTPS_PORT=443
TLS_CERT_FILE=/absolute/path/fullchain.pem
TLS_KEY_FILE=/absolute/path/privkey.pem
```

先在本地绑定模式下 initialize 并轮换公开账号口令，再执行 `./manage.sh https-up`。HTTPS 模式启用 Secure Cookie，HTTP 重定向到域名的 443；证书文件缺失直接报错。使用 `./manage.sh stop` 停机后，HTTPS 栈应使用 https-up 恢复；不要用普通 up 降回 HTTP。

当前 Codex 云环境无公网端口发布能力、没有部署凭据，Cloudflare 隧道 API 请求被网络策略拒绝；交付包在该环境完成本地容器部署验证，不附带公网地址或永久云托管。

## 包内容与验证

images.tar.gz：web、backend、PostgreSQL 三个离线镜像；source.tar.gz：对应 Git 提交源码；SOURCE_COMMIT：源码版本；SHA256SUMS：完整性校验；compose.yml / https.yml：运行配置；manage.sh：加载、初始化、启停和备份。VERIFY.json 记录本次实际执行的验证；不会把历史压测当成本次结果。

基础镜像包含公共发行版组件，交付不表示容器漏洞扫描已完成。源码重新打包命令：`GO=/path/to/go1.27 scripts/package-docker.sh /absolute/output-directory`。
