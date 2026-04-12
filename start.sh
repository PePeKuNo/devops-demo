#!/usr/bin/env sh

set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
NETWORK_NAME="${NETWORK_NAME:-product-net}"
REGISTRY_CONTAINER="${REGISTRY_CONTAINER:-product-registry}"
REGISTRY_HOST="${REGISTRY_HOST:-localhost:5000}"
POSTGRES_CONTAINER="${POSTGRES_CONTAINER:-product-postgres}"
REDIS_CONTAINER="${REDIS_CONTAINER:-product-redis}"
BACKEND_CONTAINER="${BACKEND_CONTAINER:-product-backend}"
FRONTEND_CONTAINER="${FRONTEND_CONTAINER:-product-frontend}"
POSTGRES_VOLUME="${POSTGRES_VOLUME:-product-postgres-data-v2}"
VERSION="${VERSION:-v2}"
BUILD_DATE="${BUILD_DATE:-$(date -u +"%Y-%m-%dT%H:%M:%SZ")}"
BACKEND_IMAGE="${BACKEND_IMAGE:-$REGISTRY_HOST/product-dashboard-backend:$VERSION}"
FRONTEND_IMAGE="${FRONTEND_IMAGE:-$REGISTRY_HOST/product-dashboard-frontend:$VERSION}"

POSTGRES_DB="${POSTGRES_DB:-products}"
POSTGRES_USER="${POSTGRES_USER:-products}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-products}"
REDIS_URL="${REDIS_URL:-redis://${REDIS_CONTAINER}:6379}"
FRONTEND_BIND_SOURCE="${FRONTEND_BIND_SOURCE:-$ROOT_DIR/frontend/nginx.conf}"

echo "==> Preparing network and volume"
docker network inspect "$NETWORK_NAME" >/dev/null 2>&1 || docker network create "$NETWORK_NAME" >/dev/null
docker volume inspect "$POSTGRES_VOLUME" >/dev/null 2>&1 || docker volume create "$POSTGRES_VOLUME" >/dev/null

echo "==> Removing previous containers"
for container in "$FRONTEND_CONTAINER" "$BACKEND_CONTAINER" "$REDIS_CONTAINER" "$POSTGRES_CONTAINER"; do
  docker rm -f "$container" >/dev/null 2>&1 || true
done

echo "==> Starting local registry"
docker container inspect "$REGISTRY_CONTAINER" >/dev/null 2>&1 || \
  docker run -d --restart always -p 5000:5000 --name "$REGISTRY_CONTAINER" registry:2 >/dev/null
docker start "$REGISTRY_CONTAINER" >/dev/null 2>&1 || true
docker network connect "$NETWORK_NAME" "$REGISTRY_CONTAINER" >/dev/null 2>&1 || true

echo "==> Building backend image for registry"
docker build \
  --build-arg BUILD_DATE="$BUILD_DATE" \
  --build-arg VERSION="$VERSION" \
  --build-arg NODE_ENV=production \
  -t "$BACKEND_IMAGE" \
  "$ROOT_DIR/backend"

echo "==> Pushing backend image to registry"
docker push "$BACKEND_IMAGE"

echo "==> Building frontend image for registry"
docker build \
  --build-arg BUILD_DATE="$BUILD_DATE" \
  --build-arg VERSION="$VERSION" \
  --build-arg NODE_ENV=production \
  -t "$FRONTEND_IMAGE" \
  "$ROOT_DIR/frontend"

echo "==> Pushing frontend image to registry"
docker push "$FRONTEND_IMAGE"

echo "==> Pulling images from registry"
docker pull "$BACKEND_IMAGE"
docker pull "$FRONTEND_IMAGE"

echo "==> Starting PostgreSQL with named volume"
docker run -d \
  --name "$POSTGRES_CONTAINER" \
  --network "$NETWORK_NAME" \
  -e POSTGRES_DB="$POSTGRES_DB" \
  -e POSTGRES_USER="$POSTGRES_USER" \
  -e POSTGRES_PASSWORD="$POSTGRES_PASSWORD" \
  -v "$POSTGRES_VOLUME:/var/lib/postgresql/data" \
  postgres:16-alpine >/dev/null

echo "==> Starting Redis with tmpfs"
docker run -d \
  --name "$REDIS_CONTAINER" \
  --network "$NETWORK_NAME" \
  --tmpfs /data:rw,noexec,nosuid,size=64m \
  redis:7-alpine >/dev/null

echo "==> Waiting for PostgreSQL"
until docker exec "$POSTGRES_CONTAINER" pg_isready -U "$POSTGRES_USER" -d "$POSTGRES_DB" >/dev/null 2>&1; do
  sleep 2
done

echo "==> Waiting for Redis"
until docker exec "$REDIS_CONTAINER" redis-cli ping >/dev/null 2>&1; do
  sleep 1
done

echo "==> Starting backend with PostgreSQL and Redis"
docker run -d \
  --name "$BACKEND_CONTAINER" \
  --network "$NETWORK_NAME" \
  -p 3000:3000 \
  -e PORT=3000 \
  -e POSTGRES_HOST="$POSTGRES_CONTAINER" \
  -e POSTGRES_PORT=5432 \
  -e POSTGRES_DB="$POSTGRES_DB" \
  -e POSTGRES_USER="$POSTGRES_USER" \
  -e POSTGRES_PASSWORD="$POSTGRES_PASSWORD" \
  -e REDIS_URL="$REDIS_URL" \
  --tmpfs /tmp:rw,noexec,nosuid,size=64m \
  "$BACKEND_IMAGE" >/dev/null

echo "==> Starting frontend with bind mount for nginx config"
docker run -d \
  --name "$FRONTEND_CONTAINER" \
  --network "$NETWORK_NAME" \
  -p 80:8080 \
  -v "$FRONTEND_BIND_SOURCE:/etc/nginx/conf.d/default.conf:ro" \
  "$FRONTEND_IMAGE" >/dev/null

echo "==> Environment is ready"
echo "Registry:   http://localhost:5000/v2/_catalog"
echo "Frontend:   http://localhost"
echo "Backend:    http://localhost:3000"
echo "Health:     http://localhost:3000/health"
echo "Items:      http://localhost:3000/items"
echo "Stats:      http://localhost:3000/stats"
