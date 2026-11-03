# Next.js frontend Docker template

Same runtime-env-injection idea as `docker/frontend-spa-nginx`, adapted
for Next.js: `NEXT_PUBLIC_*` vars are baked in as placeholder tokens at
build time via Dockerfile `ARG`/`ENV`, then `sed`-replaced in the
compiled `.next` output by `entrypoint.sh` at container start.

## Requires `output: "standalone"`

This template assumes `next.config.js` sets `output: "standalone"`.
Standalone mode traces your actual production dependency subset instead
of shipping the full `node_modules`, which is what keeps the image
small. Without it, the `COPY --from=build /app/.next/standalone ./`
line in the Dockerfile has nothing to copy and the build will fail —
add `output: "standalone"` to `next.config.js` before using this
template.

## What to change when copying this template

- Add one `ARG`/`ENV` pair in the Dockerfile and one `sed -e` line +
  `:  "${VAR:?...}"` guard in `entrypoint.sh` per `NEXT_PUBLIC_*` var
  your app uses.
- The `find /app/.next -type f \( -name "*.js" -o -name "*.html" -o
  -name "*.rsc" \)` in `entrypoint.sh` already covers server chunks
  (`.next/standalone`), client chunks (`.next/static`), and pre-rendered
  static/RSC pages, all nested under `/app/.next` in the production
  image — no path changes needed there. Don't narrow this back to just
  `*.js`: any statically-generated page bakes the placeholder directly
  into its `.html`/`.rsc` output too, and those are silently skipped by
  a JS-only glob (found the hard way — see the note below).
- **If a placeholder value is ever passed to `new URL(...)` during the
  build** (e.g. code that builds absolute URLs from an env var, invoked
  from a statically-generated page), a bare `__VAR__` token isn't a
  parseable URL and the build fails. Shape the `ARG` default as a valid
  URL with the token in the *path*, not a bare token — e.g.
  `http://placeholder.invalid/__NEXT_PUBLIC_API_URL__` — and match that
  full string in `entrypoint.sh`'s `sed`. Don't put the token in the
  *host* position: the WHATWG URL parser lowercases hostnames, which
  breaks a case-sensitive `sed` match against the original token.

## Note

Only `NEXT_PUBLIC_*` vars can be substituted this way — they're the only
ones present in client-side bundle output at build time. Server-only env
vars should be passed normally via the container's environment; they
don't need placeholder substitution since server code reads
`process.env` directly at runtime.

## `ENV HOSTNAME=0.0.0.0` is required, not decorative

Next's standalone `server.js` binds to `process.env.HOSTNAME || '0.0.0.0'`.
Docker sets `HOSTNAME` to the container's own ID for *every* container,
unconditionally, with no way to opt out from inside the Dockerfile short
of overriding it yourself. Without this line, the server silently binds
only to the container's internal network IP — not `0.0.0.0`, not
`127.0.0.1`, not `localhost`. The app is still reachable from the host
through the published port (Docker's NAT doesn't care what interface the
process bound to), so this is easy to miss in a quick manual check — but
`HEALTHCHECK` and any `depends_on: condition: service_healthy` both probe
from *inside* the container or its network namespace against `localhost`,
and fail permanently. Confirmed with a live repro: `docker exec <container>
sh -c 'wget --spider http://localhost:3000/'` gets "Connection refused"
against a server that's actively serving requests from the host.

Even after adding `HOSTNAME=0.0.0.0`, the Dockerfile's `HEALTHCHECK`
still targets `127.0.0.1:3000`, not `localhost:3000` — Node's bind is
IPv4-only here, but this base image resolves `localhost` to `::1` (IPv6)
first, so a `localhost` healthcheck still fails even once the server is
correctly listening on `0.0.0.0`. Same underlying class of bug as
`docker/frontend-spa-nginx`'s `127.0.0.1` fix, independently confirmed
here for the Next.js image.

## Deploying without a registry

For a `docker/build-on-server/compose.yml` stack that builds this
Dockerfile directly on the target host (no GHCR/registry involved), see
the cicd skill's `references/build-on-server.md`.
