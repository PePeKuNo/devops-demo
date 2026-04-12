#!/usr/bin/env sh

set -eu

APP_VOLUMES="${APP_VOLUMES:-product-postgres-data-v2 product-backend-node-modules-dev}"

for volume in $APP_VOLUMES; do
  if ! docker volume inspect "$volume" >/dev/null 2>&1; then
    echo "Volume: $volume"
    echo "  status: missing"
    echo
    continue
  fi

  mountpoint="$(docker volume inspect -f '{{ .Mountpoint }}' "$volume")"
  size_kib="$(docker run --rm -v "$volume:/volume:ro" alpine:3.21 sh -c 'du -sk /volume | cut -f1')"
  containers="$(docker ps -a --filter "volume=$volume" --format '{{.Names}}')"

  echo "Volume: $volume"
  echo "  mountpoint: $mountpoint"
  echo "  size_kib: $size_kib"

  if [ -n "$containers" ]; then
    echo "  containers: $(printf '%s\n' "$containers" | awk 'BEGIN { first = 1 } NF { if (!first) { printf ", " } printf "%s", $0; first = 0 } END { print "" }')"
  else
    echo "  containers: none"
  fi

  echo
done
