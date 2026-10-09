#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
action="${1:-help}"
case "$action" in load|initialize|up|https-up|stop|status|logs|backup) ;; *) echo 'Usage: ./manage.sh load|initialize|up|https-up|stop|status|logs|backup'; exit 2 ;; esac
docker compose version >/dev/null
if [[ ! -f .env ]]; then
  umask 077
  password=$(od -An -N24 -tx1 /dev/urandom | tr -d ' \n')
  printf 'POSTGRES_PASSWORD=%s\nBIND_ADDRESS=127.0.0.1\nWEB_PORT=8088\nHTTPS_PORT=8443\n' "$password" > .env
fi
compose=(docker compose --env-file .env -f compose.yml)
case "$action" in
  load)
    sha256sum -c SHA256SUMS
    gzip -dc images.tar.gz | docker load
    ;;
  initialize)
    "${compose[@]}" up -d --wait db
    fresh=$("${compose[@]}" exec -T db psql -U postgres -d hospital_edss -Atc "SELECT to_regclass('public.schema_migrations') IS NULL")
    [[ "$fresh" == t ]] || { echo 'Initialization refused: existing database. Use up to migrate without reseeding.' >&2; exit 1; }
    "${compose[@]}" run --rm migrate -seed
    "${compose[@]}" up -d --wait backend web
    ;;
  up)
    "${compose[@]}" up -d --wait db
    "${compose[@]}" run --rm migrate
    "${compose[@]}" up -d --wait backend web
    ;;
  https-up)
    compose+=(-f https.yml)
    "${compose[@]}" up -d --wait db
    "${compose[@]}" run --rm migrate
    "${compose[@]}" up -d --wait backend web
    ;;
  stop) "${compose[@]}" stop ;;
  status) "${compose[@]}" ps ;;
  logs) "${compose[@]}" logs --tail 100 ;;
  backup)
    mkdir -p backups
    umask 077
    target="backups/edss-$(date -u +%Y%m%dT%H%M%SZ).dump"
    [[ ! -e "$target" ]] || { echo 'Backup already exists' >&2; exit 1; }
    temporary=$(mktemp backups/.dump.XXXXXX)
    trap 'rm -f "$temporary"' EXIT
    "${compose[@]}" exec -T db pg_dump -U postgres -d hospital_edss -Fc > "$temporary"
    ln "$temporary" "$target"
    rm -f "$temporary"
    sha256sum "$target" > "$target.sha256"
    echo "$target"
    ;;
esac
