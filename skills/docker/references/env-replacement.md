# Env replacement: runtime config injection for frontends

**The problem:** a frontend bundle is built once, but needs different
API URLs / keys per environment (dev, staging, prod). Rebuilding the
image per environment is slow and means the image you tested isn't the
exact image you deploy.

**The pattern these templates use:** bake unique placeholder tokens
(`__VAR_NAME__`) into the bundle at build time, then `sed`-replace them
with real values in `entrypoint.sh` at container startup, before the
real process (`nginx`, `npm start`, etc.) starts. One image, configured
per-container at `docker run` / `docker compose up` time via normal env
vars.

See working examples:
- `assets/frontend-spa-nginx/entrypoint.sh` — Vite/CRA-style static SPA
- `assets/frontend-nextjs/entrypoint.sh` — Next.js `NEXT_PUBLIC_*` vars

## When this pattern applies (and when it doesn't)

Only for values **inlined into a client bundle at build time** (e.g. `NEXT_PUBLIC_*`, Vite `VITE_*`). A server that reads and validates `process.env` at runtime (a Node API, a Nitro SSR server with a zod env schema) doesn't need it: pass env vars normally and skip the entrypoint. See `node-ssr-nitro.md`.

## The five rules every entrypoint here follows

1. **Placeholder convention:** `__ENV_VAR_NAME__` — double-underscore
   wrapped, same name as the env var, so it's greppable in built output.
2. **`strip_quotes` helper** applied to every substituted value — guards
   against `env_file:`-sourced values arriving with quotes still
   attached (a real Docker Compose footgun).
3. **Fail-fast validation** (`: "${VAR:?error message}"`) for every
   required var, before running `sed` — a missing var should be a clear
   startup error, not a silently broken app.
4. **Scope `find` narrowly** — the smallest directory that could contain
   the placeholder (a per-app subfolder if one image serves multiple
   apps) — avoids cross-app collisions and keeps container boot fast.
5. **Always end with `exec "$@"`** — so `CMD` and any extra `docker run`
   arguments still work as expected.

## Why not a separate `runtime-config.js` fetched at runtime?

That's a legitimate alternative (avoids touching bundle files at all,
which is faster on very large builds), but it's not what these
templates use, because it isn't what's proven in the source projects this
repo was extracted from. If you outgrow the sed-based approach (very
large bundles where the sed pass measurably slows container boot),
that's the documented next step — see the repo's `roadmap.md`.
