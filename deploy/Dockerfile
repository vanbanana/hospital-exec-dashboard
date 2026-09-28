# EDSS 单文件多 target 构建——build context 一律为仓库根
#   backend: Go API(edss + edss-migrate,alpine 运行时)
#   web:     前端 dist + nginx 静态/反代

# ---- backend ----
FROM golang:1.25-alpine AS be-build
# 本机网络 proxy.golang.org 不可达,构建期默认走国内代理(可 --build-arg 覆写)
ARG GOPROXY=https://goproxy.cn,direct
ENV GOPROXY=$GOPROXY
WORKDIR /src
COPY backend/go.mod backend/go.sum ./
RUN go mod download
COPY backend/ .
RUN CGO_ENABLED=0 go build -trimpath -o /out/edss ./cmd/server \
 && CGO_ENABLED=0 go build -trimpath -o /out/edss-migrate ./cmd/migrate

FROM alpine:3.20 AS backend
# tzdata+TZ 双必备:pgx 把 timestamptz 扫进 time.Local,alpine 默认 UTC——
# deadline/system_date/weekday/occurred_at 等 Go 侧日历与格式推导会漂 -8h;
# 与 db 服务 TZ/simLoc 同钉东八区
ARG APK_MIRROR=mirrors.aliyun.com
RUN sed -i "s|dl-cdn.alpinelinux.org|$APK_MIRROR|g" /etc/apk/repositories \
 && apk add --no-cache ca-certificates wget tzdata && adduser -D edss
ENV TZ=Asia/Shanghai
COPY --from=be-build /out/edss /out/edss-migrate /usr/local/bin/
# migrate 的 -dir/-seeddir 默认相对 cwd,镜像内固定在 /app 下
COPY backend/migrations /app/migrations
COPY backend/seed /app/seed
WORKDIR /app
USER edss
EXPOSE 8080
# 用 CMD 而非 ENTRYPOINT:compose 的 command(migrate && exec edss)需要整体替换启动行;
# 若为 ENTRYPOINT,command 会沦为 edss 的 argv 被静默忽略,migrate 永远不跑
CMD ["edss"]

# ---- web ----
FROM node:20-alpine AS fe-build
WORKDIR /src
COPY package.json package-lock.json ./
# npmjs.org 直连不可达同 GOPROXY 口径:registry 默认 npmmirror,replace-registry-host=always
# 覆盖 lockfile 内已固化的 registry.npmjs.org resolved URL(否则 npm ci 仍打原站)
ARG NPM_REGISTRY=https://registry.npmmirror.com
ENV npm_config_registry=$NPM_REGISTRY npm_config_replace_registry_host=always
RUN npm ci
COPY index.html vite.config.ts tsconfig.json ./
COPY src/ ./src/
# public/ 原样进 dist 根(头像等静态资产)——漏拷则 /assets/workbench/* 在镜像内 404
COPY public/ ./public/
# VITE_USE_MOCK 为 build-time 注入:0=dist 走真链路(client.ts 同源 /api/v1/*)
ARG VITE_USE_MOCK=0
ENV VITE_USE_MOCK=$VITE_USE_MOCK
RUN npm run build

FROM nginx:1.27-alpine AS web
# 兜底自签:nginx.conf 443 block 常驻引 /etc/nginx/certs/edss.{crt,key}——文件缺席 nginx 拒起,
# 故镜像内置一份占位自签;部署真证书经 compose 卷(deploy/certs)挂载覆盖
ARG APK_MIRROR=mirrors.aliyun.com
RUN sed -i "s|dl-cdn.alpinelinux.org|$APK_MIRROR|g" /etc/apk/repositories \
 && apk add --no-cache openssl && mkdir -p /etc/nginx/certs \
 && openssl req -x509 -nodes -newkey rsa:2048 -days 3650 \
      -keyout /etc/nginx/certs/edss.key -out /etc/nginx/certs/edss.crt \
      -subj "/CN=localhost" -addext "subjectAltName=DNS:localhost,IP:127.0.0.1"
COPY deploy/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=fe-build /src/dist /usr/share/nginx/html
EXPOSE 80 443
