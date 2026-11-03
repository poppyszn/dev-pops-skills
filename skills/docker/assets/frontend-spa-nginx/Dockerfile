# syntax=docker/dockerfile:1

FROM node:24-alpine AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN --mount=type=cache,target=/root/.npm \
    npm ci --prefer-offline --no-audit --no-fund
COPY . .
# Placeholder tokens (e.g. __VITE_API_URL__) are baked into the built
# bundle here; real values are substituted at container startup by
# entrypoint.sh, so this same image works across every environment.
RUN npm run build

# Pin the newest available nginx-alpine line, not just any 1.x tag — a
# live Trivy scan found 1.27-alpine's OS packages (openssl, libxml2,
# zlib, etc.) badly stale (35 HIGH/CRITICAL CVEs) vs. 0 on 1.30-alpine
# (same digest as nginx:stable-alpine at the time of that scan). Like any
# pin, this one will itself go stale eventually — that's what the weekly
# security.yml schedule is for; re-check before copying this template if
# it's been a while.
FROM nginx:1.30-alpine AS production
COPY docker/frontend-spa-nginx/nginx.conf /etc/nginx/conf.d/default.conf
COPY docker/frontend-spa-nginx/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
COPY --from=build /app/dist /usr/share/nginx/html
# 127.0.0.1, not localhost: nginx's `listen 80;` only binds IPv4 by
# default, but this base image resolves "localhost" to ::1 (IPv6) first
# — wget then fails with "Connection refused" against a healthy server.
HEALTHCHECK --interval=10s --timeout=3s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://127.0.0.1/healthz || exit 1
ENTRYPOINT ["/entrypoint.sh"]
CMD ["nginx", "-g", "daemon off;"]
