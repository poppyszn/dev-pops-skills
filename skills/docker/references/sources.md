# Sources

External facts this skill relies on. Re-check them during an audit. Mark a row `unverified` in the Checked column if it couldn't be confirmed online.

| Fact | Source | Checked |
|---|---|---|
| `node:24-alpine` exists and is supported. Node 24 is Active LTS until 2026-10-20, then Maintenance until 2028-04-30. **Node 26 becomes LTS on 2026-10-28**: plan the default move to `node:26-alpine` after that date. | https://hub.docker.com/_/node , https://github.com/nodejs/Release/blob/main/schedule.json | 2026-09-26 |
| `nginx:1.30-alpine` exists; 1.30 is the stable (even) branch, 1.31 is mainline. | https://hub.docker.com/_/nginx | 2026-09-26 |
| `postgres:16-alpine` exists and is supported; 18 is the newest major. | https://hub.docker.com/_/postgres | 2026-09-26 |
| `redis:7-alpine` exists; 8 is the newest major. Licensing: ≤7.2 BSD-3; 7.4–7.8 RSALv2/SSPLv1 only (not OSI open source); 8.0+ adds AGPLv3 as an option. `7-alpine` tracks 7.4.x, so it is **not** open source. Decide the default deliberately. | https://redis.io/legal/licenses/ | 2026-09-26 |
| Nitro `node-server` output is `.output/server/index.mjs`. Host comes from `NITRO_HOST` then `HOST` (default localhost); port from `NITRO_PORT` then `PORT` (default 3000). | https://nitro.build/deploy/runtimes/node | 2026-09-26 |
| Next.js standalone `server.js` binds to `process.env.HOSTNAME`, which Docker sets to the container ID, hence `ENV HOSTNAME=0.0.0.0`. | Carried over from the templates repo (confirmed with a live repro there) | unverified |
| Compose interpolates `$VAR` inside `env_file` values; `$$` escapes. | Carried over (live repro in the templates repo) | unverified |
| MinIO's GitHub repo `minio/minio` is archived. | https://github.com/minio/minio | 2026-09-26 |
| Adobe S3Mock is active and Apache-2.0; latest release 5.2.3 (2026-09-19), image `adobe/s3mock:5.2.3`. | https://github.com/adobe/S3Mock/releases , https://hub.docker.com/r/adobe/s3mock | 2026-09-26 |
| S3Mock: ports 9090 HTTP / 9191 HTTPS; env `COM_ADOBE_TESTING_S3MOCK_STORE_{INITIAL_BUCKETS,ROOT,RETAIN_FILES_ON_EXIT,REGION}`; path-style only; presigned URLs not validated; not for production; `/favicon.ico` is the always-on readiness endpoint; `/s3mockroot` is required for named volumes (runs as non-root `cnb`). | https://github.com/adobe/S3Mock#readme | 2026-09-26 |
| The `adobe/s3mock:5.2.3` image has `wget` but no `curl`, no built-in HEALTHCHECK, and runs as uid 1000. The documented service block was tested live: healthy, PUT/GET round-trip, data kept across restart, ~237MiB memory. | Local test | 2026-09-26 |
| AWS SDK for JavaScript v3 reads `AWS_ENDPOINT_URL_S3` / `AWS_ENDPOINT_URL` from the environment. | https://docs.aws.amazon.com/sdkref/latest/guide/feature-ss-endpoints.html | 2026-09-26 |
| S3Client `forcePathStyle` defaults to `false` and has no env var. | https://github.com/aws/aws-sdk-js-v3/blob/main/clients/client-s3/src/endpoint/EndpointParameters.ts | 2026-09-26 |
| A port published without a host address listens on all host addresses (`0.0.0.0` and `[::]`); `-p 127.0.0.1:8080:80` restricts it to loopback. | https://docs.docker.com/engine/network/port-publishing/ | 2026-11-01 |
| `docker compose config` renders `127.0.0.1:${API_PORT}:3000` as `host_ip: 127.0.0.1`, passes `IMAGE_TAG` into every image reference, and shows `seed` only under `--profile seed` (run against `compose.production.yml`). | Local test | 2026-11-01 |
| Puppeteer reads `PUPPETEER_SKIP_DOWNLOAD` (skip every browser download at install), `PUPPETEER_EXECUTABLE_PATH` and `PUPPETEER_CACHE_DIR` (default `~/.cache/puppeteer`). | https://pptr.dev/api/puppeteer.configuration | 2026-11-04 |
| Debian bookworm's `chromium` package installs the binary at `/usr/bin/chromium` (no `chromium-browser`). | https://packages.debian.org/bookworm/amd64/chromium/filelist | 2026-11-04 |
