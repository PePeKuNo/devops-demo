#!/usr/bin/env sh

set -eu

if [ "$#" -ne 1 ]; then
  echo "Usage: ./restore.sh <archive-path>" >&2
  exit 1
fi

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
ARCHIVE_INPUT="$1"
case "$ARCHIVE_INPUT" in
  /*) ARCHIVE_PATH="$ARCHIVE_INPUT" ;;
  *) ARCHIVE_PATH="$ROOT_DIR/$ARCHIVE_INPUT" ;;
esac

NETWORK_NAME="${NETWORK_NAME:-product-net}"
POSTGRES_CONTAINER="${POSTGRES_CONTAINER:-product-postgres}"
POSTGRES_VOLUME="${POSTGRES_VOLUME:-product-postgres-data-v2}"
POSTGRES_DB="${POSTGRES_DB:-products}"
POSTGRES_USER="${POSTGRES_USER:-products}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-products}"

container_exists() {
  docker container inspect "$1" >/dev/null 2>&1
}

container_running() {
  [ "$(docker inspect -f '{{.State.Running}}' "$1" 2>/dev/null || echo false)" = "true" ]
}

if [ ! -f "$ARCHIVE_PATH" ]; then
  echo "Archive not found: $ARCHIVE_PATH" >&2
  exit 1
fi

echo "==> Restoring backup $ARCHIVE_PATH into volume $POSTGRES_VOLUME"
docker network inspect "$NETWORK_NAME" >/dev/null 2>&1 || docker network create "$NETWORK_NAME" >/dev/null
docker volume inspect "$POSTGRES_VOLUME" >/dev/null 2>&1 || docker volume create "$POSTGRES_VOLUME" >/dev/null

WAS_RUNNING=false
if container_running "$POSTGRES_CONTAINER"; then
  WAS_RUNNING=true
  echo "==> Stopping running PostgreSQL container"
  docker stop "$POSTGRES_CONTAINER" >/dev/null
fi

ARCHIVE_DIR="$(dirname "$ARCHIVE_PATH")"
ARCHIVE_FILE="$(basename "$ARCHIVE_PATH")"

docker run --rm \
  -v "$POSTGRES_VOLUME:/volume" \
  -v "$ARCHIVE_DIR:/backup:ro" \
  alpine:3.21 \
  sh -c "find /volume -mindepth 1 -maxdepth 1 -exec rm -rf {} + && tar -xzf /backup/$ARCHIVE_FILE -C /volume"

if container_exists "$POSTGRES_CONTAINER"; then
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

echo "==> Waiting for PostgreSQL after restore"
until docker exec "$POSTGRES_CONTAINER" pg_isready -U "$POSTGRES_USER" -d "$POSTGRES_DB" >/dev/null 2>&1; do
  sleep 2
done

ROW_COUNT="$(docker exec "$POSTGRES_CONTAINER" psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -t -A -c 'SELECT COUNT(*) FROM items;')"
echo "Restore verified. items table rows: $ROW_COUNT"

if [ "$WAS_RUNNING" = false ]; then
  echo "PostgreSQL container was started for verification and remains running."
fi
