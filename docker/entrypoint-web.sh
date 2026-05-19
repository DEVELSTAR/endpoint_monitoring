#!/usr/bin/env bash
set -euo pipefail

wait_for_port() {
  local host="$1"
  local port="$2"

  until nc -z "$host" "$port"; do
    echo "Waiting for $host:$port..."
    sleep 2
  done
}

wait_for_port "${DB_PRIMARY_HOST:-mysql-primary}" "${DB_PRIMARY_PORT:-3306}"
wait_for_port "${DB_LEGACY_HOST:-mysql-legacy}" "${DB_LEGACY_PORT:-3306}"
wait_for_port "${CLICKHOUSE_HOST:-clickhouse}" "${CLICKHOUSE_PORT:-8123}"
wait_for_port "redis" "6379"
wait_for_port "kafka" "9092"

mkdir -p log tmp/pids tmp/cache tmp/sockets
touch log/development.log
rm -f tmp/pids/server.pid

exec bundle exec ruby bin/rails server -b 0.0.0.0 -p 3000
