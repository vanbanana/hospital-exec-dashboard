#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
project="${EDSS_DEV_PROJECT:-edss-dev}"
compose=(docker compose --project-name "$project" -f deploy/docker-compose.yml)
[[ -f .env ]] && compose+=(--env-file .env)
command="${1:-start}"
case "$command" in start|seed|test) ;; *) echo 'Usage: scripts/cloud-dev.sh start|seed|test' >&2; exit 2 ;; esac
dsn=$("${compose[@]}" config --format json | python3 -c 'import json,sys; print(json.load(sys.stdin)["services"]["backend"]["environment"]["DATABASE_URL"])')
printf '%s' "$dsn" | python3 -c 'import sys,urllib.parse; u=urllib.parse.urlsplit(sys.stdin.read()); valid=u.scheme in ("postgres","postgresql") and u.hostname=="db" and u.port==5432 and u.path=="/hospital_edss"; valid or sys.exit("cloud-dev only manages the project demo database db:5432/hospital_edss")'
db_id=$("${compose[@]}" ps --status running -q db)
if [[ -z "$db_id" ]]; then
  "${compose[@]}" up -d --wait db
else
  for i in $(seq 1 "${EDSS_READY_TIMEOUT:-180}"); do
    health=$(docker inspect --format '{{.State.Health.Status}}' "$db_id")
    [[ "$health" != healthy ]] || break
    sleep 1
  done
  [[ "$health" == healthy ]] || { echo 'Existing DB is not healthy; inspect service logs' >&2; exit 1; }
fi
ca_args=()
if [[ -n "${SSL_CERT_FILE:-}" ]]; then
  [[ -r "$SSL_CERT_FILE" ]] || { echo 'SSL_CERT_FILE is unreadable' >&2; exit 1; }
  ca_args=(--mount "type=bind,src=$SSL_CERT_FILE,dst=/run/host-ca.pem,readonly" -e SSL_CERT_FILE=/run/host-ca.pem)
fi
go_run=(docker run --rm --network "${project}_default" --mount "type=bind,src=$PWD/backend,dst=/src" -w /src -v "${project}-gomod:/go/pkg/mod" -v "${project}-gobuild:/root/.cache/go-build" -e TZ=Asia/Shanghai -e GOPROXY=https://proxy.golang.org,direct -e GOTOOLCHAIN=local -e GOFLAGS=-mod=readonly -e "DATABASE_URL=$dsn" "${ca_args[@]}")
case "$command" in
  start)
    # An interrupted seed can be resumed explicitly with the seed command.
    fresh=$("${compose[@]}" exec -T db psql -U postgres -d hospital_edss -Atc "SELECT to_regclass('public.schema_migrations') IS NULL")
    if [[ "$fresh" == t ]]; then
      "${go_run[@]}" golang:1.27 go run ./cmd/migrate -seed
    else
      "${go_run[@]}" golang:1.27 go run ./cmd/migrate
    fi
    if docker inspect "${project}-api" >/dev/null 2>&1; then docker rm -f "${project}-api" >/dev/null; fi
    "${go_run[@]:0:2}" -d "${go_run[@]:3}" --name "${project}-api" --log-driver json-file --log-opt max-size=10m --log-opt max-file=3 -p "127.0.0.1:${EDSS_API_PORT:-8080}:8080" -e SCREEN_PUBLIC=1 golang:1.27 sh -c 'go build -o /tmp/edss ./cmd/server && exec /tmp/edss'
    for i in $(seq 1 "${EDSS_READY_TIMEOUT:-180}"); do
      if curl -fsS "http://127.0.0.1:${EDSS_API_PORT:-8080}/ready" >/dev/null 2>&1; then echo 'API ready; run npm run dev'; exit 0; fi
      sleep 1
    done
    echo 'API did not become ready; inspect docker logs (never print credentials).' >&2
    exit 1
    ;;
  seed) "${go_run[@]}" golang:1.27 go run ./cmd/migrate -seed ;;
  test)
    write_dsn=$(printf '%s' "$dsn" | python3 -c 'import sys,urllib.parse; u=urllib.parse.urlsplit(sys.stdin.read()); print(urllib.parse.urlunsplit(u._replace(path="/hospital_edss_w")))')
    exists=$("${compose[@]}" exec -T db psql -U postgres -Atc "SELECT count(*) FROM pg_database WHERE datname='hospital_edss_w'")
    if [[ "$exists" == 0 ]]; then
      "${compose[@]}" exec -T db createdb -U postgres hospital_edss_w
      "${go_run[@]}" -e "DATABASE_URL=$write_dsn" golang:1.27 go run ./cmd/migrate -seed
    else
      "${go_run[@]}" -e "DATABASE_URL=$write_dsn" golang:1.27 go run ./cmd/migrate
    fi
    "${go_run[@]}" -e "DATABASE_URL_W=$write_dsn" golang:1.27 go test -count=1 -race ./...
    ;;
  *) echo 'Usage: scripts/cloud-dev.sh start|seed|test' >&2; exit 2 ;;
esac
