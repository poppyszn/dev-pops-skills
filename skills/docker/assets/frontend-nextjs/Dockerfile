# syntax=docker/dockerfile:1

FROM node:24-alpine AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN --mount=type=cache,target=/root/.npm \
    npm ci --prefer-offline --no-audit --no-fund
COPY . .

# Placeholder tokens for every NEXT_PUBLIC_* var used at runtime — real
# values are substituted into the build output by entrypoint.sh at
# container startup, so this image works across every environment.
#
# Shaped as a valid absolute URL (http://placeholder.invalid/__TOKEN__),
# not a bare __TOKEN__ string — see this template's README for why (code
# that calls `new URL(...)` on the value during static prerender throws
# on a non-URL placeholder, and a token in the host position gets
# lowercased by the URL parser, breaking sed's case-sensitive match).
ARG NEXT_PUBLIC_API_URL=http://placeholder.invalid/__NEXT_PUBLIC_API_URL__
ENV NEXT_PUBLIC_API_URL=${NEXT_PUBLIC_API_URL}

RUN npm run build

FROM node:24-alpine AS production
WORKDIR /app
ENV NODE_ENV=production
# Next's standalone server.js does `process.env.HOSTNAME || '0.0.0.0'` to
# pick its bind address — and Docker auto-sets HOSTNAME to the
# container's own ID for every container, with no opt-out. Without this
# override, the server silently binds only to the container's internal
# network IP, never 0.0.0.0/127.0.0.1/localhost — HEALTHCHECK (and any
# depends_on: condition: service_healthy) fails permanently even though
# the app is up and reachable from the host via the published port.
ENV HOSTNAME=0.0.0.0
# Requires next.config.js: { output: "standalone" } — this copies only
# the traced production dependency subset instead of the full
# node_modules, which is what keeps this image small.
# --chown=node:node matters: entrypoint.sh's sed -i runs as the node user
# below, and sed -i writes a temp file next to the target before renaming
# it over the original — root-owned files (COPY's default) make that
# write fail with "Permission denied" at container startup.
COPY --from=build --chown=node:node /app/.next/standalone ./
COPY --from=build --chown=node:node /app/.next/static ./.next/static
COPY --from=build --chown=node:node /app/public ./public
COPY --chown=node:node docker/frontend-nextjs/entrypoint.sh ./entrypoint.sh
RUN chmod +x ./entrypoint.sh
USER node
EXPOSE 3000
# 127.0.0.1, not localhost: even with HOSTNAME=0.0.0.0 above, Node binds
# IPv4 only here — this base image resolves "localhost" to ::1 (IPv6)
# first, so wget hits "Connection refused" against a healthy server.
# Shell form on purpose: `|| exit 1` maps wget's failure codes to 1, the only "unhealthy" code.
# hadolint ignore=DL3025
HEALTHCHECK --interval=10s --timeout=5s --retries=5 \
    CMD wget --no-verbose --tries=1 --spider http://127.0.0.1:3000/ || exit 1
ENTRYPOINT ["./entrypoint.sh"]
CMD ["node", "server.js"]
