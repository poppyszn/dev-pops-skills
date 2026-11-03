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
