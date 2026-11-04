# Sources

External facts this skill relies on. Re-check them during an audit. Mark a row `unverified` in the Checked column if it couldn't be confirmed online.

| Fact | Source | Checked |
|---|---|---|
| `actions/checkout@v7` exists; latest v7.0.1. | https://github.com/actions/checkout/releases | 2026-09-26 |
| `actions/setup-node@v7` exists; latest v7.0.0. | https://github.com/actions/setup-node/releases | 2026-09-26 |
| `docker/setup-buildx-action@v4`, `docker/setup-qemu-action@v4`, `docker/login-action@v4`, `docker/build-push-action@v7`, `docker/metadata-action@v6` exist and are the current majors. | https://github.com/docker | 2026-09-26 |
| `webfactory/ssh-agent@v0.10.0` is the latest release. | https://github.com/webfactory/ssh-agent/releases | 2026-09-26 |
| `nrwl/nx-set-shas@v5` is current (v5.0.1) and needs `actions: read` + `contents: read`. | https://github.com/nrwl/nx-set-shas#permissions-in-v2 | 2026-09-26 |
| A job-level `permissions:` block replaces the workflow-level one; unlisted permissions become `none`. | https://docs.github.com/en/actions/using-jobs/assigning-permissions-to-jobs | 2026-09-26 |
| None of the actions above are archived. | GitHub API (`repos/<owner>/<repo>`.archived) | 2026-09-26 |
| `nrwl/nx-set-shas` input `main-branch-name` defaults to `main`. | https://github.com/nrwl/nx-set-shas/blob/main/action.yml | 2026-09-26 |
| `npm run <script> --workspaces --if-present` skips workspaces without the script and fails if a present script fails (tested locally with npm 11.16.0). | Local test | 2026-09-26 |
| Latest majors checked 2026-11-01: `actions/cache` v6.1.0, `actions/setup-node` v7.1.0, `aws-actions/configure-aws-credentials` v6.3.0, `pnpm/action-setup` v6.1.0, `actions/checkout` v7.0.1 (the workflows pin the major tag). All exist as tags and none is archived. | https://github.com/actions/cache/releases , https://github.com/aws-actions/configure-aws-credentials/releases , https://github.com/pnpm/action-setup/releases | 2026-11-01 |
| `actions/checkout` authenticates with `http.<origin>/.extraheader` set to `AUTHORIZATION: basic <base64 of x-access-token:token>`; the production sync step passes the same header per command instead of storing the token. | https://github.com/actions/checkout/blob/main/src/git-auth-helper.ts | 2026-11-01 |
| `git clone` into a non-empty directory fails with "destination path ... already exists and is not an empty directory", and `git init` + `fetch` + `reset --hard` into it works, keeping an ignored `.env` (the real sync step was run against a local bare repository, with git 2.50.1). | Local test | 2026-11-01 |
| `git fetch --depth 1 origin <sha>` works against github.com for a reachable commit. Tested only against a local repository; `actions/checkout` fetches SHA refs the same way. | Local test | unverified |
| A job that references an environment gets OIDC `sub` `repo:ORG/REPO:environment:NAME`; the deploy-web job declares `environment: production` and `id-token: write`. | https://docs.github.com/en/actions/reference/security/oidc | 2026-11-01 |
| Standard Linux hosted runner (`ubuntu-latest`): 4 CPU / 16 GB / 14 GB SSD for public repositories, 2 CPU / 8 GB / 14 GB SSD for private ones. | https://docs.github.com/en/actions/reference/runners/github-hosted-runners | 2026-11-04 |
| A step with no `shell:` runs `bash -e {0}` (no pipefail); `shell: bash` runs `bash --noprofile --norc -eo pipefail {0}`. | https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax | 2026-11-04 |
| Cache entries not accessed for 7 days are removed; 10 GB per repository; runs restore caches from the current branch or the default branch, and pull requests also from the base branch. | https://docs.github.com/en/actions/reference/workflows-and-actions/dependency-caching | 2026-11-04 |
| The cache uses zstd when the `zstd` binary is present and gzip otherwise, and adds the compression method to the cache version, so entries saved with one cannot be restored with the other. | https://github.com/actions/toolkit/blob/main/packages/cache/src/internal/cacheUtils.ts (`getCompressionMethod`, `getCacheVersion`) | 2026-11-04 |
| Scheduled workflows run on the latest commit on the default branch; on `pull_request`, `GITHUB_SHA` is the last merge commit of `refs/pull/<n>/merge`. | https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows | 2026-11-04 |
| `docker/bake-action@v7` is current (v7.5.0) and takes `source`, `files`, `targets`, `push`, `set`, `vars`, `sbom`, `provenance`. | https://github.com/docker/bake-action/releases | 2026-11-04 |
| `actions/github-script@v9` is current (v9.0.0); `docker/setup-buildx-action@v4` (v4.4.1) and `docker/login-action@v4` (v4.7.0) are current. | https://github.com/actions/github-script/releases, https://github.com/docker/setup-buildx-action/releases, https://github.com/docker/login-action/releases | 2026-11-04 |
| BuildKit `[worker.oci] max-parallelism` limits the number of build steps run at the same time; setup-buildx passes it through `buildkitd-config-inline`. | https://docs.docker.com/build/buildkit/toml-configuration/ | 2026-11-04 |
| A Bake `matrix` with `name` generates one target per value; a generated name can be passed to `docker buildx bake` to build only that target. | https://docs.docker.com/build/bake/matrices/ (generation); building one generated target by name confirmed by a local build | 2026-11-04 |
