# deploy/ — compose 部署资产

> 拓扑:`web`(nginx:80/443,SPA + `/api` 反代 + `/health` 透出)→ `backend`(edss:8080)→ `db`(postgres:16-alpine,仅内网)。`deploy/Dockerfile` 单文件多 target(`backend`/`web`),build context = 仓库根。

## 冷启动 runbook(edssprod 隔离栈)

与 dev 栈(5432/8080/5173)零冲突:project 钉死 `edssprod`,端口整体平移到 5433/8093/8095/8443。

```bash
# 0. 容器运行时(colima 优先;镜像拉取走 mirror,见"已知坑")
brew install colima docker        # 已有可跳过
colima start --cpu 4 --memory 8
docker version                    # server 应出 colima 的 dockerd

# 1. 自签证书(否则 web 用镜像内兜底自签,也能起)
deploy/certs/gen-selfsigned.sh    # 生成 deploy/certs/edss.{crt,key},gitignore 不入库

# 2. 构建+起栈(project/端口由 edssprod override 钉死,无需额外 env)
docker compose -f deploy/docker-compose.yml -f deploy/docker-compose.edssprod.yml up -d --build

# 3. 等 backend healthy(首次=迁移+种子,约 1-3 分钟)
docker compose -f deploy/docker-compose.yml -f deploy/docker-compose.edssprod.yml ps
docker compose -f deploy/docker-compose.yml -f deploy/docker-compose.edssprod.yml logs -f backend

# 4. 验证矩阵
curl -s -o /dev/null -w '%{http_code}' http://localhost:8093/health                        # 200
curl -s -o /dev/null -w '%{http_code}' http://localhost:8093/login                         # 200(SPA 回落)
curl -s -c /tmp/edss.jar -X POST http://localhost:8093/api/v1/auth/login \
  -H 'Content-Type: application/json' -d '{"username":"admin","password":"Admin@123"}'     # code=0 + Set-Cookie edss_sid
curl -s -b /tmp/edss.jar http://localhost:8093/api/v1/auth/profile                         # code=0
curl -s -b /tmp/edss.jar http://localhost:8093/api/v1/screen/snapshot | head -c 200        # 真数据
curl -sk -o /dev/null -w '%{http_code}' https://localhost:8443/health                      # 200(自签 -k)

# 5. SIM_ENABLED=0 复跑验证 /api/v1/sim/* 全 404(不注册路由,NoRoute→10003)
SIM_ENABLED=0 docker compose -f deploy/docker-compose.yml -f deploy/docker-compose.edssprod.yml up -d backend
curl -s -o /dev/null -w '%{http_code}' http://localhost:8093/api/v1/sim/status             # 404

# 6. 收尾(卷保留=pgdata 留种子;要全新冷启动加 -v)
docker compose -f deploy/docker-compose.yml -f deploy/docker-compose.edssprod.yml down
```

| 宿主端口 | 容器 | 用途 |
| :--- | :--- | :--- |
| 8093 | web:80 | http 入口(SPA+/api 反代) |
| 8443 | web:443 | https 入口(自签) |
| 8095 | backend:8080 | 仅 127.0.0.1 调试透出 |
| 5433 | db:5432 | 仅 127.0.0.1,psql 直连核验 |

## 已知坑(本机实测)

- **docker.io DNS 被污染**:VM 内 `registry-1.docker.io` NXDOMAIN,直连拉取必挂。两条路:daemon `registry-mirrors`(本机 colima 已配 `docker.m.daocloud.io`/`docker.1panel.live`/`docker.nju.edu.cn`),或显式 `docker.m.daocloud.io/library/<img>` 前缀拉后 retag。
- **Docker Desktop daemon 代理坏**:dockerd 被配 `http.docker.internal:3128` 转发 macOS 系统代理,任何 pull 静默挂起(`docker info` 可看 Proxy 字段自诊);colima 无此问题。
- **colima VM DNS**:colima-core 镜像内 `systemd-resolved` 未启用,`/etc/resolv.conf` 悬挂。修复:`colima ssh` 后 `rm -f /etc/resolv.conf && echo 'nameserver 192.168.5.2' | sudo tee /etc/resolv.conf`(192.168.5.2=usernet 网关 DNS 转发)。
- **docker CLI `pull` 挂起**:docker 29.8.1 client 走 `/grpc` 流协商,经 lima socket 转发时卡死;**直连 socket API 正常**:`curl --unix-socket ~/.colima/docker.sock -X POST 'http://localhost/v1.51/images/create?fromImage=<img>'`。compose 的 pull/build/up 不受影响(走 API 路径)。
- **构建期外网**:npm ci 默认 registry 已改 `registry.npmmirror.com`(+`replace-registry-host=always` 覆盖 lockfile 固化 host);apk 默认 `mirrors.aliyun.com`;go mod 已默认 `goproxy.cn`——均可用 build-arg 覆写(`NPM_REGISTRY`/`APK_MIRROR`/`GOPROXY`)。
- **端口占用**:8090-8092 已被并行 lane 的 `edss` 进程占用,故 http 入口选 8093。
