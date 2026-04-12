#!/usr/bin/env sh

set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
POSTGRES_VOLUME="${POSTGRES_VOLUME:-product-postgres-data-v2}"
BACKUP_DIR="${BACKUP_DIR:-$ROOT_DIR/artifacts/backups}"
TIMESTAMP="$(date -u +"%Y%m%dT%H%M%SZ")"
ARCHIVE_NAME="${POSTGRES_VOLUME}-${TIMESTAMP}.tar.gz"
ARCHIVE_PATH="$BACKUP_DIR/$ARCHIVE_NAME"

mkdir -p "$BACKUP_DIR"

echo "==> Creating backup from volume $POSTGRES_VOLUME"
docker volume inspect "$POSTGRES_VOLUME" >/dev/null 2>&1 || {
  echo "Volume $POSTGRES_VOLUME does not exist." >&2
  exit 1
}

docker run --rm \
  -v "$POSTGRES_VOLUME:/volume:ro" \
  -v "$BACKUP_DIR:/backup" \
  alpine:3.21 \
  sh -c "tar -czf /backup/$ARCHIVE_NAME -C /volume ."

echo "Backup created: $ARCHIVE_PATH"
