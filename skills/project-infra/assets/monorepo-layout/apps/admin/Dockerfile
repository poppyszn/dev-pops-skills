# syntax=docker/dockerfile:1
#
# Adapted from the dev-pops docker skill's assets/frontend-spa-nginx/Dockerfile. Build
# context is the repo root (root compose.yml: `context: ., dockerfile:
# apps/admin/Dockerfile`).

FROM node:24-alpine AS build
WORKDIR /app
COPY package.json package-lock.json ./
COPY apps/admin/package.json ./apps/admin/package.json
RUN --mount=type=cache,target=/root/.npm \
    npm ci --prefer-offline --no-audit --no-fund
COPY . .
# Placeholder tokens (e.g. __VITE_API_URL__) are baked into the built
# bundle here; real values are substituted at container startup by
# entrypoint.sh, so this same image works across every environment.
RUN npm run build --workspace=apps/admin

FROM nginx:1.30-alpine AS production
COPY apps/admin/nginx.conf /etc/nginx/conf.d/default.conf
COPY apps/admin/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
COPY --from=build /app/apps/admin/dist /usr/share/nginx/html
# 127.0.0.1, not localhost: nginx's `listen 80;` only binds IPv4 by
# default, but this base image resolves "localhost" to ::1 (IPv6) first.
# Shell form on purpose: `|| exit 1` maps wget's failure codes to 1, the only "unhealthy" code.
# hadolint ignore=DL3025
HEALTHCHECK --interval=10s --timeout=3s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://127.0.0.1/healthz || exit 1
ENTRYPOINT ["/entrypoint.sh"]
CMD ["nginx", "-g", "daemon off;"]
