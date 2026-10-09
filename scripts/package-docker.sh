#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
output="${1:?Usage: GO=/path/to/go scripts/package-docker.sh /absolute/output-directory}"
[[ "$output" == /* ]] || { echo 'Output directory must be absolute' >&2; exit 2; }
[[ ! -e "$output" ]] || { echo 'Output directory already exists' >&2; exit 1; }
go_bin="${GO:-go}"
[[ "$(uname -m)" == x86_64 ]] || { echo 'This delivery targets linux/amd64' >&2; exit 1; }
mkdir -p "$output/build/backend" "$output/build/web" "$output/hospital-edss"
npm ci --no-audit --no-fund
npm run build
(
  cd backend
  CGO_ENABLED=0 GOOS=linux GOARCH=amd64 "$go_bin" build -trimpath -o "$output/build/backend/edss" ./cmd/server
  CGO_ENABLED=0 GOOS=linux GOARCH=amd64 "$go_bin" build -trimpath -o "$output/build/backend/edss-migrate" ./cmd/migrate
)
cp -a backend/migrations backend/seed "$output/build/backend/"
cp deploy/delivery/Dockerfile.backend "$output/build/backend/Dockerfile"
cp /usr/share/zoneinfo/Asia/Shanghai "$output/build/backend/Shanghai"
cat /usr/share/ca-certificates/mozilla/*.crt > "$output/build/backend/ca-certificates.crt"
cp -a dist "$output/build/web/"
cp deploy/delivery/Dockerfile.web "$output/build/web/Dockerfile"
python3 - "$output/build/web/nginx.conf" <<'PY'
from pathlib import Path
import sys
s=Path('deploy/nginx.conf').read_text()
Path(sys.argv[1]).write_text(s[:s.index('server {',s.index('server {')+1)])
PY
docker build --platform linux/amd64 --network none -t hospital-edss-backend:delivery "$output/build/backend"
docker build --platform linux/amd64 --network none -t hospital-edss-web:delivery "$output/build/web"
docker pull --platform linux/amd64 postgres:16-alpine
cp deploy/delivery/{compose.yml,https.yml,nginx-production.conf,manage.sh,README.md} "$output/hospital-edss/"
chmod +x "$output/hospital-edss/manage.sh"
git archive --format=tar.gz -o "$output/hospital-edss/source.tar.gz" HEAD
docker save hospital-edss-backend:delivery hospital-edss-web:delivery postgres:16-alpine | gzip > "$output/hospital-edss/images.tar.gz"
git rev-parse HEAD > "$output/hospital-edss/SOURCE_COMMIT"
printf '{"architecture":"linux/amd64","runtime_validation":"not_run_by_packaging_script"}\n' > "$output/hospital-edss/VERIFY.json"
(
  cd "$output/hospital-edss"
  sha256sum images.tar.gz source.tar.gz compose.yml https.yml nginx-production.conf manage.sh README.md SOURCE_COMMIT VERIFY.json > SHA256SUMS
)
tar -czf "$output/hospital-edss-docker-amd64.tar.gz" -C "$output" hospital-edss
sha256sum "$output/hospital-edss-docker-amd64.tar.gz" > "$output/hospital-edss-docker-amd64.tar.gz.sha256"
echo "$output/hospital-edss-docker-amd64.tar.gz"
