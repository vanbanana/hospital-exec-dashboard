#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
exec python3 scripts/ops.py backup "${1:?Usage: scripts/backup-db.sh output.dump}"
