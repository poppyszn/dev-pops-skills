#!/bin/sh
set -e

: "${NEXT_PUBLIC_API_URL:?ERROR: NEXT_PUBLIC_API_URL environment variable is required}"

# Covers .js, .html, and .rsc — Next bakes NEXT_PUBLIC_* values into
# pre-rendered static/RSC output too (any statically-generated page),
# not just client JS chunks. The sed target is the whole placeholder
# URL, not a bare __TOKEN__ (see the Dockerfile's ARG comment for why).
find /app/apps/web -type f \( -name "*.js" -o -name "*.html" -o -name "*.rsc" \) -print0 | xargs -0 sed -i \
  -e "s|http://placeholder.invalid/__NEXT_PUBLIC_API_URL__|${NEXT_PUBLIC_API_URL}|g"

exec "$@"
