# Sources

External facts this skill relies on. Re-check them during an audit. Mark a row `unverified` in the Checked column if it couldn't be confirmed online.

| Fact | Source | Checked |
|---|---|---|
| gitleaks latest release is v8.30.1, image `zricethezav/gitleaks:v8.30.1` exists; project not archived. | https://github.com/gitleaks/gitleaks/releases , https://hub.docker.com/r/zricethezav/gitleaks | 2026-09-26 |
| `gitleaks-action` needs a license key for organization-owned repos; the key is **free** (the old templates repo wrongly said paid). Personal accounts need none. | https://github.com/gitleaks/gitleaks-action | 2026-09-26 |
| `aquasecurity/trivy-action@v0.36.0` is the latest release. | https://github.com/aquasecurity/trivy-action/releases | 2026-09-26 |
| `github/codeql-action@v4` exists and is current. Workflows need `security-events: write`, plus `contents: read` on private repos. | https://github.com/github/codeql-action#workflow-permissions | 2026-09-26 |
| CodeQL code scanning is free on public repos. Private repos need the paid GitHub Code Security add-on (Advanced Security was split into Code Security and Secret Protection), billed per active committer. | https://docs.github.com/en/billing/concepts/product-billing/github-advanced-security , https://github.com/security/plans | 2026-09-26 |
| `pnpm/action-setup@v6` is current (v6.1.0, not archived). With `version` omitted it uses `packageManager` / `devEngines.packageManager` from `package.json`. It supports pnpm ≤12 (latest pnpm is v12.6.0). | https://github.com/pnpm/action-setup | 2026-09-26 |
| `pnpm audit --audit-level <low\|moderate\|high\|critical>` (default low). | https://pnpm.io/cli/audit | 2026-09-26 |
| A GitHub job that references an environment has OIDC `sub` `repo:ORG/REPO:environment:NAME` whatever branch it runs on, so a trust policy pinned to it is tied to that environment's protection rules. | https://docs.github.com/en/actions/reference/security/oidc | 2026-11-01 |
