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
RUN apk add --no-cache ca-certificates wget && adduser -D edss
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
RUN npm ci
COPY index.html vite.config.ts tsconfig.json ./
COPY src/ ./src/
# VITE_USE_MOCK 为 build-time 注入:0=dist 走真链路(client.ts 同源 /api/v1/*)
ARG VITE_USE_MOCK=0
ENV VITE_USE_MOCK=$VITE_USE_MOCK
RUN npm run build

FROM nginx:1.27-alpine AS web
COPY deploy/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=fe-build /src/dist /usr/share/nginx/html
EXPOSE 80
