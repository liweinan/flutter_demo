#!/usr/bin/env bash
# 本机联调：使用本地镜像 postgres:15-alpine（需已存在于 docker images）与本机 cargo 启动 API，
# 避免依赖从 Docker Hub 拉取 rust/postgres 构建镜像。
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONTAINER_NAME="${CONTAINER_NAME:-flutter_demo_db}"
IMAGE="${IMAGE:-postgres:15-alpine}"
HOST_PG_PORT="${HOST_PG_PORT:-5433}"
export DATABASE_URL="${DATABASE_URL:-postgresql://demo:demo@127.0.0.1:${HOST_PG_PORT}/demo}"
export BIND_ADDR="${BIND_ADDR:-127.0.0.1:8080}"

docker rm -f "$CONTAINER_NAME" 2>/dev/null || true
docker run -d --name "$CONTAINER_NAME" \
  -e POSTGRES_USER=demo \
  -e POSTGRES_PASSWORD=demo \
  -e POSTGRES_DB=demo \
  -p "${HOST_PG_PORT}:5432" \
  "$IMAGE"

for _ in $(seq 1 30); do
  if docker exec "$CONTAINER_NAME" pg_isready -U demo -d demo >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

docker exec -i "$CONTAINER_NAME" psql -U demo -d demo <"$ROOT/db/init/001_demo.sql"

STATIC_UI="${STATIC_UI_ROOT:-$ROOT/frontend/dist}"
cd "$ROOT/server"
exec env DATABASE_URL="$DATABASE_URL" BIND_ADDR="$BIND_ADDR" STATIC_UI_ROOT="$STATIC_UI" \
  RUST_LOG="${RUST_LOG:-demo_api=info,tower_http=info}" \
  "$(command -v cargo)" run --release
