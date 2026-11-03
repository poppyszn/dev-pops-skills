# Local S3: Adobe S3Mock (dev and tests only)

For apps that use S3-compatible object storage. Locally and in tests, run **Adobe S3Mock** (`adobe/s3mock`). Deployed environments (develop and production) use a real S3 provider, configured through the same env vars. There's no S3 container in any deploy stack.

**Opt-in:** the compose templates don't include it. Paste the block below into the stacks of apps that need object storage.

## Don't use MinIO

The MinIO GitHub repository (`minio/minio`) is **archived**. Don't introduce it in new work. When reviewing or auditing a project that has it, report it as drift and propose the swap below. The swap is a change to confirm with the user first, not an automatic edit.

## Service block: local dev (`compose.yml`)

```yaml
  s3:
    image: adobe/s3mock:5.2.3
    restart: unless-stopped
    environment:
      COM_ADOBE_TESTING_S3MOCK_STORE_INITIAL_BUCKETS: ${S3_BUCKETS:-app}
      # /s3mockroot is the only root that works with a named volume: the image
      # runs as a non-root user and only this directory is pre-owned by it.
      COM_ADOBE_TESTING_S3MOCK_STORE_ROOT: /s3mockroot
      COM_ADOBE_TESTING_S3MOCK_STORE_RETAIN_FILES_ON_EXIT: "true"
    ports:
      - "${S3_PORT:-9090}:9090"
    volumes:
      - s3-data:/s3mockroot
    healthcheck:
      # The image has wget but no curl. /favicon.ico is S3Mock's always-on
      # readiness endpoint (actuator health is off by default).
      test: ["CMD", "wget", "--spider", "-q", "http://localhost:9090/favicon.ico"]
      interval: 5s
      timeout: 5s
      retries: 10
    deploy:
      resources:
        limits:
          cpus: "0.5"
          memory: 512M   # measured ~237MiB idle; 256M is too tight

volumes:
  s3-data:
```

Add `s3: condition: service_healthy` under the API's `depends_on`.

## Service block: tests (`compose.testing.yml`)

Same service, but ephemeral: drop `restart`, `volumes`, `STORE_ROOT` and `RETAIN_FILES_ON_EXIT`, so every run starts empty. Use `retries: 20` like the other test services.

## App wiring (Node, AWS SDK v3)

S3Mock only supports **path-style** URLs (`http://host:9090/bucket/key`, not `bucket.host`). The SDK defaults to virtual-hosted style, so the client must opt in:

```ts
const s3 = new S3Client({
  region: process.env.AWS_REGION ?? "us-east-1",
  // AWS_ENDPOINT_URL_S3 is read by the SDK automatically. forcePathStyle has
  // no env var equivalent, so it comes from config.
  forcePathStyle: process.env.S3_FORCE_PATH_STYLE === "true",
});
```

`.env.example` (local):
```bash
AWS_ENDPOINT_URL_S3=http://s3:9090   # service name inside compose; http://localhost:9090 from the host
AWS_REGION=us-east-1
AWS_ACCESS_KEY_ID=local              # S3Mock ignores credentials, but the SDK requires some
AWS_SECRET_ACCESS_KEY=local
S3_FORCE_PATH_STYLE=true
S3_BUCKET=app
```

In deployed environments, leave `AWS_ENDPOINT_URL_S3` unset for AWS itself (or set it to the provider's endpoint), and set `S3_FORCE_PATH_STYLE` to whatever the provider needs.

## Limitations to know

- Path-style only (see above).
- Presigned URLs are accepted but **not validated** (expiry, signature and verb aren't checked). Tests can't prove presigned-URL security.
- HTTPS on 9191 uses a self-signed certificate. Prefer plain HTTP on 9090 locally.
- KMS key ARNs are validated, but nothing is encrypted.
- **Not for production:** no real auth.

## Swapping MinIO for S3Mock

| MinIO | S3Mock |
|---|---|
| `minio/minio` image, `server /data` command | `adobe/s3mock:<pinned>`, no command |
| Port 9000 (API), 9001 (console) | Port 9090 (HTTP), 9191 (HTTPS); no web console |
| Buckets created by an `mc` init container or script | `COM_ADOBE_TESTING_S3MOCK_STORE_INITIAL_BUCKETS` (comma-separated) |
| `MINIO_ROOT_USER` / `MINIO_ROOT_PASSWORD` | Not needed; any credentials are accepted |
| Volume at `/data` | Named volume at `/s3mockroot` + `STORE_ROOT` + `RETAIN_FILES_ON_EXIT` |
| Healthcheck on `/minio/health/live` | `wget --spider -q http://localhost:9090/favicon.ico` |

After swapping:
- remove any `mc`/bucket-init service
- update the endpoint env var to port 9090
- confirm the client uses path-style
- run the app's upload/download path end to end

## Verification

- `docker compose up -d --wait` shows the `s3` service healthy.
- Round-trip a file: `curl -fsS -X PUT --upload-file f.txt http://localhost:9090/<bucket>/f.txt`, then `curl -fsS http://localhost:9090/<bucket>/f.txt`.
- Local dev only: `docker compose restart s3`, then the file is still there.
