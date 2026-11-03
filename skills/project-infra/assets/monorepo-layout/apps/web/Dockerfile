# syntax=docker/dockerfile:1
#
# Adapted from the dev-pops docker skill's assets/frontend-nextjs/Dockerfile for an npm
# workspaces monorepo. Build context is the repo root (root compose.yml:
# `context: ., dockerfile: apps/web/Dockerfile`).
#
# CAVEAT: with npm/pnpm workspaces, Next's `output: "standalone"` nests
# its output under the app's own workspace path inside .next/standalone
# (e.g. .next/standalone/apps/web/server.js, plus a hoisted
# node_modules) rather than flat at .next/standalone/server.js — the
# exact shape depends on your Next.js version and workspace layout.
# Run a real build and `find apps/web/.next/standalone` to confirm the
# actual paths before trusting the COPY lines below verbatim.

FROM node:24-alpine AS build
WORKDIR /app
COPY package.json package-lock.json ./
COPY apps/web/package.json ./apps/web/package.json
RUN --mount=type=cache,target=/root/.npm \
    npm ci --prefer-offline --no-audit --no-fund
COPY . .

# Placeholder tokens for every NEXT_PUBLIC_* var used at runtime — real
# values are substituted into the build output by entrypoint.sh at
# container startup, so this image works across every environment.
# Shaped as a valid absolute URL, not a bare __TOKEN__ — see
# the docker skill's references/frontend-nextjs.md for why.
ARG NEXT_PUBLIC_API_URL=http://placeholder.invalid/__NEXT_PUBLIC_API_URL__
ENV NEXT_PUBLIC_API_URL=${NEXT_PUBLIC_API_URL}

RUN npm run build --workspace=apps/web

FROM node:24-alpine AS production
WORKDIR /app
ENV NODE_ENV=production
# Docker sets HOSTNAME to the container's own ID for every container;
# Next's standalone server.js binds to process.env.HOSTNAME if set, so
# without this override it binds only to the container's internal IP,
# never 0.0.0.0/127.0.0.1/localhost — HEALTHCHECK fails permanently even
# though the app is reachable from the host. See
# the docker skill's references/frontend-nextjs.md for the full writeup.
ENV HOSTNAME=0.0.0.0
# Requires apps/web/next.config.js: { output: "standalone" }.
# --chown=node:node: entrypoint.sh's sed -i runs as the node user below,
# and a root-owned tree (COPY's default) makes that write fail with
# "Permission denied" at container startup.
COPY --from=build --chown=node:node /app/apps/web/.next/standalone ./
COPY --from=build --chown=node:node /app/apps/web/.next/static ./apps/web/.next/static
COPY --from=build --chown=node:node /app/apps/web/public ./apps/web/public
COPY --chown=node:node apps/web/entrypoint.sh ./entrypoint.sh
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
CMD ["node", "apps/web/server.js"]
