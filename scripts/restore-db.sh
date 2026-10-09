#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
exec python3 scripts/ops.py restore "${1:?Usage: scripts/restore-db.sh input.dump NEW_DATABASE}" "${2:?NEW_DATABASE is required}"
