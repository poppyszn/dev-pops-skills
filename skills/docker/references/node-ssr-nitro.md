# Node SSR on Nitro (non-Next.js)

For SSR apps whose server is built by Nitro with the `node-server` preset (TanStack Start, Nuxt, and other Nitro-based frameworks). There's no dedicated asset yet. Start from `assets/frontend-nextjs/Dockerfile` and apply the deltas below, since most of that template is Next-specific.

## Deltas from the Next.js template

| Concern | Next.js template | Nitro |
|---|---|---|
| Build output | `.next/standalone` + `.next/static` + `public` | One self-contained `.output/` directory |
| Run command | `node server.js` | `node .output/server/index.mjs` |
| Bind address | `ENV HOSTNAME=0.0.0.0` (Next reads `HOSTNAME`) | `ENV HOST=0.0.0.0` (Nitro reads `NITRO_HOST`, then `HOST`, and defaults to localhost, which is unreachable from outside the container) |
| Port | `3000` | `ENV PORT=3000` (Nitro reads `NITRO_PORT`, then `PORT`; default 3000) |
| Runtime deps | Traced `node_modules` subset | None. Copy only `.output/`. npm/corepack can be removed from the runner stage, as `node-api` does. |
| Runtime config | `entrypoint.sh` sed-replaces `__NEXT_PUBLIC_*__` placeholders | Usually **no entrypoint**. See below. |

Production stage sketch:

```dockerfile
FROM node:24-alpine AS production
WORKDIR /app
ENV NODE_ENV=production HOST=0.0.0.0 PORT=3000
COPY --from=build --chown=node:node /app/.output ./.output
RUN rm -rf /usr/local/lib/node_modules/npm /usr/local/bin/npm /usr/local/bin/npx
USER node
EXPOSE 3000
HEALTHCHECK --interval=10s --timeout=5s --retries=5 \
    CMD wget --no-verbose --tries=1 --spider http://127.0.0.1:3000/ || exit 1
CMD ["node", ".output/server/index.mjs"]
```

Keep `127.0.0.1` in the healthcheck, not `localhost`, for the same IPv6-first reason documented in `frontend-nextjs.md`.

## Runtime config: skip env-replacement unless values are baked into the client

`env-replacement.md`'s placeholder pattern exists for values **inlined into a client bundle at build time**. A Nitro server that reads and validates `process.env` at runtime (e.g. a zod schema) needs none of it: pass env vars normally. Only add an entrypoint if the client bundle also has build-time `PUBLIC_*` values inlined.

## Environment in compose

A public-facing SSR container should get an explicit `environment:` allowlist, not the shared `env_file: .env`. See `compose.md`.

## Origin

Filed from a real TanStack Start store on Nitro. See `contributions/completed/nitro-ssr-store-and-shared-env-file-gaps.merged.md`. The bind variables were verified against Nitro's node runtime docs (see `sources.md`).
