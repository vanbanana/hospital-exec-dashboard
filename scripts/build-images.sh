#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
targets=("$@")
[[ ${#targets[@]} -gt 0 ]] || targets=(backend web)
compose=(docker compose --project-name "${EDSS_BUILD_PROJECT:-edss-build}" -f deploy/docker-compose.yml)
[[ -z "${EDSS_ENV_FILE:-}" ]] || compose+=(--env-file "$EDSS_ENV_FILE")
# Cloud trust is a build secret; no certificate enters the final image.
[[ -z "${SSL_CERT_FILE:-}" ]] || compose+=(-f deploy/docker-compose.cloud.yml)
for target in "${targets[@]}"; do
  case "$target" in backend|web) ;; *) echo 'Only backend and web targets are supported' >&2; exit 2 ;; esac
done
for target in "${targets[@]}"; do
  python3 - <<'PY'
import os, shutil, sys
try:
    required = int(os.environ.get('EDSS_BUILD_MIN_FREE_BYTES', str(6 * 1024**3)))
    if required < 1: raise ValueError()
except ValueError:
    sys.exit('EDSS_BUILD_MIN_FREE_BYTES must be a positive integer')
free = shutil.disk_usage('.').free
if free < required:
    sys.exit(f'Build refused: {free} free bytes; {required} required')
PY
  # Serial targets avoid concurrent Go/npm layers exhausting small cloud disks.
  "${compose[@]}" build "$target"
  if [[ "$target" == backend ]]; then
    image=$("${compose[@]}" config --format json | python3 -c 'import json,sys; print(json.load(sys.stdin)["services"]["backend"]["image"])')
    docker run --rm --network none "$image" sh -c '
      test "$(id -u)" -ne 0
      for file in /app/migrations/*.sql /app/seed/*.sql; do
        test -r "$file" || exit 1
      done
    '
  fi
done
