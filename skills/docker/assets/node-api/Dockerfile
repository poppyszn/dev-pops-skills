# syntax=docker/dockerfile:1

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
RUN npm run build \
    && npm prune --omit=dev

# ---- production: minimal runtime image ----
FROM node:24-alpine AS production
WORKDIR /app
ENV NODE_ENV=production
COPY --from=build /app/dist ./dist
COPY --from=build /app/node_modules ./node_modules
COPY --from=build /app/package.json ./package.json
COPY docker/node-api/entrypoint.sh ./entrypoint.sh
RUN chmod +x ./entrypoint.sh
# npm is a build-time-only tool — the running container only ever execs
# `node <file>.js` (see entrypoint.sh), never npm itself. Its own
# vendored dependencies (tar/brace-expansion/ip-address/undici/etc.)
# otherwise show up as unfixable CVEs in image scans for code that's
# never executed. Confirmed via a live Trivy scan on a real app built
# from this template: removing this dropped image-scan findings from 7
# (1 critical, 6 high) to 0.
RUN rm -rf /usr/local/lib/node_modules/npm /usr/local/bin/npm /usr/local/bin/npx
USER node
EXPOSE 3000
# 127.0.0.1, not localhost: this base image resolves "localhost" to ::1
# (IPv6) first, while a Node server listening on the default host binds
# IPv4 only — so a `localhost` healthcheck gets "connection refused"
# against a perfectly healthy server and the container never leaves
# "starting". Same failure already fixed in the frontend images.
HEALTHCHECK --interval=10s --timeout=5s --retries=5 \
    CMD wget --no-verbose --tries=1 --spider http://127.0.0.1:3000/health || exit 1
ENTRYPOINT ["./entrypoint.sh"]
CMD ["start"]
