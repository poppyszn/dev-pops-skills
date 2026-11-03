# syntax=docker/dockerfile:1
#
# Adapted from the dev-pops docker skill's assets/node-api/Dockerfile. Build context here is
# the monorepo root (see root compose.yml: `context: ., dockerfile:
# apps/api/Dockerfile`), so COPY paths below are relative to the repo
# root, not this file's own directory.

# ---- deps: install all dependencies (cached) ----
FROM node:24-alpine AS deps
WORKDIR /app
COPY package.json package-lock.json ./
RUN --mount=type=cache,target=/root/.npm \
    npm ci --prefer-offline --no-audit --no-fund

# ---- build: compile TypeScript, then prune to production deps ----
FROM node:24-alpine AS build
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .
RUN npm run build --workspace=apps/api \
    && npm prune --omit=dev

# ---- production: minimal runtime image ----
FROM node:24-alpine AS production
WORKDIR /app
ENV NODE_ENV=production
COPY --from=build /app/apps/api/dist ./dist
COPY --from=build /app/node_modules ./node_modules
COPY --from=build /app/package.json ./package.json
COPY apps/api/entrypoint.sh ./entrypoint.sh
RUN chmod +x ./entrypoint.sh
# npm is a build-time-only tool — see the docker skill's assets/node-api/Dockerfile for the
# full writeup (confirmed via a live Trivy scan: this drops image-scan
# findings from 7 to 0).
RUN rm -rf /usr/local/lib/node_modules/npm /usr/local/bin/npm /usr/local/bin/npx
USER node
EXPOSE 4000
# 127.0.0.1, not localhost: this base image resolves "localhost" to ::1
# (IPv6) first, while a Node server listening on the default host binds
# IPv4 only — so a `localhost` healthcheck gets "connection refused"
# against a perfectly healthy server and the container never leaves
# "starting". Same failure already fixed in the frontend images.
HEALTHCHECK --interval=10s --timeout=5s --retries=5 \
    CMD wget --no-verbose --tries=1 --spider http://127.0.0.1:4000/health || exit 1
ENTRYPOINT ["./entrypoint.sh"]
CMD ["start"]
