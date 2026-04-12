#!/usr/bin/env sh

set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
NETWORK_NAME="${NETWORK_NAME:-product-net}"
POSTGRES_CONTAINER="${POSTGRES_CONTAINER:-product-postgres}"
REDIS_CONTAINER="${REDIS_CONTAINER:-product-redis}"
BACKEND_CONTAINER="${BACKEND_CONTAINER:-product-backend}"
POSTGRES_VOLUME="${POSTGRES_VOLUME:-product-postgres-data-v2}"
BACKEND_DEPS_VOLUME="${BACKEND_DEPS_VOLUME:-product-backend-node-modules-dev}"
POSTGRES_DB="${POSTGRES_DB:-products}"
POSTGRES_USER="${POSTGRES_USER:-products}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-products}"
REDIS_URL="${REDIS_URL:-redis://${REDIS_CONTAINER}:6379}"
BACKEND_SOURCE="${BACKEND_SOURCE:-$ROOT_DIR/backend}"

container_exists() {
  docker container inspect "$1" >/dev/null 2>&1
}

container_running() {
  [ "$(docker inspect -f '{{.State.Running}}' "$1" 2>/dev/null || echo false)" = "true" ]
}

ensure_named_volume() {
  docker volume inspect "$1" >/dev/null 2>&1 || docker volume create "$1" >/dev/null
}

echo "==> Preparing Docker network and named volumes"
docker network inspect "$NETWORK_NAME" >/dev/null 2>&1 || docker network create "$NETWORK_NAME" >/dev/null
ensure_named_volume "$POSTGRES_VOLUME"
ensure_named_volume "$BACKEND_DEPS_VOLUME"

echo "==> Ensuring PostgreSQL is available"
if container_running "$POSTGRES_CONTAINER"; then
  :
elif container_exists "$POSTGRES_CONTAINER"; then
  docker start "$POSTGRES_CONTAINER" >/dev/null
else
  docker run -d \
    --name "$POSTGRES_CONTAINER" \
    --network "$NETWORK_NAME" \
    -e POSTGRES_DB="$POSTGRES_DB" \
    -e POSTGRES_USER="$POSTGRES_USER" \
    -e POSTGRES_PASSWORD="$POSTGRES_PASSWORD" \
    -v "$POSTGRES_VOLUME:/var/lib/postgresql/data" \
    postgres:16-alpine >/dev/null
fi

echo "==> Ensuring Redis is available"
if container_running "$REDIS_CONTAINER"; then
  :
elif container_exists "$REDIS_CONTAINER"; then
  docker start "$REDIS_CONTAINER" >/dev/null
else
  docker run -d \
    --name "$REDIS_CONTAINER" \
    --network "$NETWORK_NAME" \
    --tmpfs /data:rw,noexec,nosuid,size=64m \
    redis:7-alpine >/dev/null
fi

echo "==> Waiting for PostgreSQL"
until docker exec "$POSTGRES_CONTAINER" pg_isready -U "$POSTGRES_USER" -d "$POSTGRES_DB" >/dev/null 2>&1; do
  sleep 2
done

echo "==> Waiting for Redis"
until docker exec "$REDIS_CONTAINER" redis-cli ping >/dev/null 2>&1; do
  sleep 1
done

echo "==> Replacing backend container with development mode"
docker rm -f "$BACKEND_CONTAINER" >/dev/null 2>&1 || true

docker run -d \
  --name "$BACKEND_CONTAINER" \
  --network "$NETWORK_NAME" \
  -p 3000:3000 \
  -w /app \
  -e PORT=3000 \
  -e POSTGRES_HOST="$POSTGRES_CONTAINER" \
  -e POSTGRES_PORT=5432 \
  -e POSTGRES_DB="$POSTGRES_DB" \
  -e POSTGRES_USER="$POSTGRES_USER" \
  -e POSTGRES_PASSWORD="$POSTGRES_PASSWORD" \
  -e REDIS_URL="$REDIS_URL" \
  -v "$BACKEND_SOURCE:/app" \
  -v "$BACKEND_DEPS_VOLUME:/app/node_modules" \
  --tmpfs /tmp:rw,noexec,nosuid,size=64m \
  node:22-alpine \
  sh -lc '
    current_hash="$(sha256sum package-lock.json | awk "{print \$1}")"
    stored_hash="$(cat node_modules/.package-lock.sha256 2>/dev/null || true)"

    if [ ! -d node_modules ] || [ "$current_hash" != "$stored_hash" ]; then
      npm ci
      printf "%s" "$current_hash" > node_modules/.package-lock.sha256
    fi

    exec npm run dev
  ' >/dev/null

echo "==> Development backend is ready"
echo "Backend URL: http://localhost:3000"
echo "Hot reload source: $BACKEND_SOURCE"
echo "Dependencies volume: $BACKEND_DEPS_VOLUME"
echo "Follow logs with: docker logs -f $BACKEND_CONTAINER"
