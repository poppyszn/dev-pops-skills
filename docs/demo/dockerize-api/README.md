# Demo: "Dockerize this NestJS API with Postgres"

One prompt, run twice on the same small NestJS + Prisma + Postgres project: once with the `docker` skill loaded, once with no skills. Both runs were static (no `docker build`, `pull` or `up`), so nothing here has been built or started.

`without-skills/` and `with-skills/` hold only the files each run created or changed. Score them yourself:

```bash
./evals/demo/check-dockerize.sh docs/demo/dockerize-api/with-skills
```

(The script reads the generated files in place; for the `compose config` check, run it against a full project copy.)

## Result

| | Checks passed (of 14) |
|---|---|
| The bare project, before any run | 3 |
| No skills | 11 |
| `docker` skill | 13 |

| Check | No skills | `docker` skill |
|---|---|---|
| Dev dependencies kept out of the runtime image | fail (the report says so itself) | pass |
| A pull-based compose file for deploying | fail (one compose file, built locally) | pass |
| No default password in compose | fail (`app`) | fail (`app`) |
| The other 11 (pinned tags, multi-stage, non-root, healthchecks, `.dockerignore`, `pg_isready`, `service_healthy`, a migrate step, loopback-only database port, valid `compose config`) | pass | pass |

## How to read this

- **The gap is real but modest on this prompt.** A capable model with no skills already does the Dockerfile basics well. The skill's edge here is the deploy path (a pull-based compose file next to the build one) and the runtime image, plus the templates being copied rather than invented.
- **The checklist encodes this repo's own defaults**, so it favours the skills. It cannot show that the output is *better*, only that it matches the defaults.
- **n = 1 per arm, same model, same day.** The "no skills" run was told not to read the skills; that is an instruction, not a sandbox.
- **Both fail the password check.** The local-dev default (`app`) is in the skill's own template too. That is a finding against the skill, not a flaw in the check.
- The skills run also noticed what the template lacks: no Prisma variant (CLI must be a production dependency, OpenSSL on Alpine, `prisma generate` around the prune). That is a candidate for `contributions/`.
