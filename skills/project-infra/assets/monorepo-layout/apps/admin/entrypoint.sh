#!/bin/sh
set -e

strip_quotes() {
  printf '%s' "$1" | sed 's/^["'"'"']//;s/["'"'"']$//'
}

: "${VITE_API_URL:?ERROR: VITE_API_URL environment variable is required}"

_API_URL=$(strip_quotes "${VITE_API_URL}")

find /usr/share/nginx/html -type f -name "*.js" -print0 | xargs -0 sed -i \
  -e "s|__VITE_API_URL__|${_API_URL}|g"

exec "$@"
