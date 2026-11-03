# Static site: S3 + CloudFront for a single-page app

Assets: `assets/modules/static_site`, `assets/modules/static_site_deploy_role`, `assets/environments/static-site/` (`shared/*.tf`, `tfvars/<env>.tfvars`).

Hosts a built single-page app (Vite, CRA and similar) from a private S3 bucket behind CloudFront, and creates the role a GitHub Actions workflow assumes to publish it without stored AWS keys. The workflow itself (build, `aws s3 sync`, invalidation) is in the `cicd` skill's production deploy template.

```text
viewer -> CloudFront (routing function, security headers) -> origin access control -> private S3 bucket
GitHub Actions job (environment: production) -> OIDC -> deploy role -> s3 sync + invalidation
```

## What the template does and why

- **Private bucket, origin access control.** Public access is blocked and the bucket policy lets only this distribution read it (`AWS:SourceArn` condition). It is a regular bucket, not S3 website hosting: origin access control does not work with website endpoints. ACLs are disabled (`BucketOwnerEnforced`), which origin access control requires. A second policy statement denies any non-TLS request.
- **Client-side routing with a CloudFront Function, not custom error responses.** The usual advice (map 403 and 404 to `/index.html` with status 200) is a distribution-wide setting. It also answers a missing `/assets/app.abc123.js` with the app shell and a 200, so a stale tab gets HTML where it expected JavaScript ("Unexpected token <"), and a broken bucket policy shows a healthy-looking page whose scripts all fail. The function (`spa-routing.js`) rewrites only paths whose last segment has no dot to `/index.html`, and never touches anything under `/assets/`. A missing file stays a real 404. This is the rule the app's own nginx config states for the container build, kept on CloudFront.
- **`s3:ListBucket` for CloudFront.** Without it S3 answers 403 for a missing key; with it, a proper 404. CloudFront never lists the bucket (no query string reaches the origin, and `/` is rewritten), so this only fixes the status code.
- **Managed `CachingOptimized` cache policy.** Caches by URL only (no cookies or query strings in the key) and honours the `Cache-Control` set on each object. Its minimum TTL is 1 second, so even a `no-cache` object such as `index.html` can sit at the edge for a second; the deploy's `/*` invalidation covers that. The policy only works as designed if the deploy sets `Cache-Control` on every object: `public, max-age=31536000, immutable` for hashed assets, `no-cache` for everything else. An object with no header is cached for 24 hours.
- **Security headers policy.** HSTS (one year, subdomains off by default), `nosniff`, `X-Frame-Options: DENY`, `Referrer-Policy: no-referrer`. No Content-Security-Policy by default because a policy is specific to the app; pass one with `content_security_policy` when you have it. The old nginx config set only `Referrer-Policy`, so this is an addition, not a regression.
- **Versioning with a short tail.** Versioning keeps the previous build recoverable after `aws s3 sync --delete`; replaced versions expire after 30 days. The deploy never deletes `assets/` (so a browser holding the previous `index.html` can still load its chunks), so that prefix grows by one build per deploy. Prune it by hand now and then; an age-based lifecycle rule would delete chunks the current build still references.
- **Deploy role pinned to the GitHub Environment.** A job that references an environment gets the `sub` claim `repo:<ORG>/<REPO>:environment:<ENV>` whatever branch it runs on, so the trust policy ties the role to that environment and its protection rules (required reviewers, allowed branches). The module rejects `*`, a missing `repo:` prefix, and any subject ending in `:*`. Permissions are three statements: list the bucket, write and delete objects in it, create and read invalidations on the one distribution.

## Values to fill in

Replace every `<ANGLE_BRACKET>` marker in each `terraform.tfvars` (see `references/layout.md` for the workflow).

| Value | Notes |
|---|---|
| `site_bucket_name` | Unique across all of AWS: `<PROJECT>-<environment>-web`. At most 50 characters. |
| `site_aliases`, `site_acm_certificate_arn` | The custom domain and its certificate, or `[]` and `null` for the `*.cloudfront.net` address. The certificate must be requested **in us-east-1**, whatever `region` is; the module rejects any other region. |
| `site_price_class` | By where the users are. `PriceClass_100` covers the US, Canada, Europe and Israel; add Asia, Africa and the Middle East with `PriceClass_200`; `PriceClass_All` has every edge location. |
| `site_github_allowed_subjects` | The environment form. Run `github/actions-oidc-debugger` once and copy the printed `sub` (see `references/github-oidc-deploy.md`). |
| `site_create_github_oidc_provider` | `true` in exactly one environment per AWS account. |

## Order of work

1. **Request the ACM certificate in us-east-1** and validate it. When DNS is not in Route 53, ACM prints a CNAME record to create at your DNS provider by hand; the certificate is not usable until it validates. (The module takes the certificate ARN instead of creating it for that reason, and so that `providers.tf` stays identical in every environment.)
2. Fill the tfvars, `make check`, `make plan ENV=production`, and have the user review the plan. `apply` is a confirmation, and a new distribution takes several minutes to deploy.
3. **DNS:** create a CNAME from each alias to the `site_distribution_domain_name` output. An apex domain cannot be a CNAME; use a DNS provider that supports ALIAS records, or Route 53.
4. **GitHub environment variables** from the outputs:

   | Output | GitHub variable |
   |---|---|
   | `site_bucket_name` | `WEB_BUCKET` |
   | `site_distribution_id` | `CLOUDFRONT_DISTRIBUTION_ID` |
   | `site_deploy_role_arn` | `AWS_ROLE_ARN` |

   `AWS_REGION` is the `region` value. Do not put anything in a repository-wide variable that should be per-environment.
5. Run the production deploy workflow, then the smoke test below.

## Smoke test

Run after the first deploy and after any change to the distribution (replace the host):

```bash
HOST=https://erp.example.com
curl -sI "$HOST/"                       # 200; cache-control: no-cache; strict-transport-security, x-content-type-options, x-frame-options, referrer-policy present
curl -sI "$HOST/set-password"           # 200 and text/html: a client-side route reloads without a 403
curl -sI "$HOST/assets/does-not-exist.js"   # 404, NOT 200: a missing file is not rewritten to the shell
curl -sI "$HOST/assets/<a real hashed file>.js"   # 200; cache-control: public, max-age=31536000, immutable; content-type javascript
```

A `200` with `text/html` on the third line means custom error responses were added to the distribution by hand; remove them.

## Rollback

Prefer redeploying the previous commit with the production workflow (it rebuilds and re-syncs). Versioning is a last resort: replaced object versions stay for 30 days and can be restored one object at a time from the S3 console or `aws s3api`.

## Composing with an EC2 host

A project with both a static site and a Docker host (the API and a server-rendered storefront) uses one root. Start from the `ec2` kind, then add the site:

1. Append `static-site/shared/main.tf` to `main.tf` and `static-site/shared/outputs.tf` to `outputs.tf`.
2. Append the variables from `static-site/shared/variables.tf` to `variables.tf`, **except `region` and `tags`**, which the `ec2` kind already declares.
3. Append the `# Site` and `# GitHub Actions` sections of `static-site/tfvars/<env>.tfvars` to `terraform.tfvars`, again without the General section.
4. Do this in all three environments, then `make check`.

The two kinds use disjoint variable and module names for this reason (`site_*` prefixes). With an ECS root, set `site_create_github_oidc_provider = false` and apply the ECS environment first: the provider is an account singleton, created once.

## Known trade-offs

- **The bundle is built per environment.** Values such as the API origin are baked in at build time, so the SPA that reaches production was not the exact artifact tested on staging. An alternative is a `config.json` object uploaded beside the build and fetched at startup; this template does not do that.
- **`apply` waits for CloudFront.** A distribution change takes several minutes to propagate; Terraform waits for it.
- **No WAF, logging or geo restriction by default.** `web_acl_arn` attaches a WAFv2 web ACL (created in us-east-1) when one exists.
