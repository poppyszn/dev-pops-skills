# Frontend SPA (nginx) Docker template

Static SPA build (Vite/CRA/etc.) served by nginx, with **runtime**
environment injection: real env var values are substituted into the
already-built JS bundle when the container starts, so one image works
across dev/staging/prod without a rebuild.

## What to change when copying this template

- In your app code, reference env values as literal placeholder strings
  matching the `__VITE_API_URL__` convention (e.g. wrap them in your
  build config so the string `__VITE_API_URL__` ends up verbatim in the
  compiled output).
- `entrypoint.sh`: add one `-e "s|__YOUR_VAR__|${_YOUR_VAR}|g"` line and
  a matching `strip_quotes` call per env var you need injected. Add a
  `: "${YOUR_VAR:?...}"` guard for any var that's required.
- If your image serves more than one app/config from a single build
  (a multi-tenant frontend, for example), scope the `find` to a per-app subdirectory
  (`/usr/share/nginx/html/${APP}`) instead of the whole webroot, and
  swap in the matching `nginx.conf` based on an `APP` env var (copy it in
  `entrypoint.sh` before `exec`, since the plain `ENTRYPOINT` override
  below means nginx's own template-processing entrypoint never runs).
- `X-Frame-Options "DENY"` in `nginx.conf` blocks the app from being
  embedded in an iframe anywhere, including your own other apps — relax
  to `SAMEORIGIN` or drop the header if you intentionally embed this app.

## Why `nginx.conf` is a plain file, not a template

The Dockerfile's `ENTRYPOINT` is our own `entrypoint.sh`, not nginx's
official one — which means nginx's built-in `envsubst`-on-templates
mechanism (`/etc/nginx/templates/*.template`) never runs, since only the
official entrypoint invokes it. `nginx.conf` is copied straight to
`/etc/nginx/conf.d/default.conf` as a static file instead. If you need
env vars inside the nginx config itself (not just the JS bundle), run
`envsubst` yourself in `entrypoint.sh` before `exec`, the same way the
JS substitution already works.

## Why sed on the compiled bundle, not a separate config file

This template intentionally does NOT use a separate
`runtime-config.js`/`envsubst` file fetched by the app at runtime. The
sed-into-bundle approach is what's proven across multiple production
frontends; see `references/env-replacement.md` for the full rationale.

## Deploying without a registry

For a `docker/build-on-server/compose.yml` stack that builds this
Dockerfile directly on the target host (no GHCR/registry involved), see
the cicd skill's `references/build-on-server.md`.
