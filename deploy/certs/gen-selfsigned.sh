#!/bin/sh
# 生成 nginx 443 server block 消费的本地自签证书(edss.crt/edss.key)。
# 仅演示用:CN=localhost,SAN 含 localhost/127.0.0.1;生成物被 .gitignore 拦下不入库。
set -eu
cd "$(dirname "$0")"

openssl req -x509 -nodes -newkey rsa:2048 -days 825 \
  -keyout edss.key -out edss.crt \
  -subj "/CN=localhost" \
  -addext "subjectAltName=DNS:localhost,IP:127.0.0.1"

chmod 600 edss.key
echo "ok: $(pwd)/edss.crt + edss.key (825 天, CN=localhost)"
