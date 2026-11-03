# State, backend and the lock file

## State

State can contain secrets and is the record of what Terraform owns. It is never committed (the `gitignore` asset excludes `*.tfstate*`, `*.tfplan` and `.terraform/`) and never copied into a skill asset or a bug report.

A new project starts on local state so `init` works before any bucket exists. Move to remote state before a second person, a CI job, or production uses the project.

## Remote state: S3 with native locking

Terraform's S3 backend locks with a lock file in the bucket (`use_lockfile = true`); the DynamoDB table method is deprecated. The templates use **partial configuration** so the `.tf` files stay identical across environments:

- `backend.tf` (from `assets/environments/common/backend.tf.example`, identical everywhere): `backend "s3" { use_lockfile = true, encrypt = true }`
- `backend.hcl` (from `assets/environments/common/backend.hcl.example`, one per environment): `bucket`, `key = "<PROJECT>/<ENVIRONMENT>/terraform.tfstate"`, `region`
- `make init ENV=<name>` passes `-backend-config=backend.hcl` when the file exists.

Prerequisites, created once outside the project's Terraform (or by a separate bootstrap the user approves): a private bucket with versioning on, default encryption, and public access blocked. Creating it is a confirmation. One bucket per project is fine; the key separates environments.

## Migrating local state to the bucket

This changes where state lives, so confirm first and keep a copy of the local state file. Rename `backend.tf.example` to `backend.tf` in every environment (parity requires it everywhere), write each `backend.hcl`, then run `terraform init -migrate-state -backend-config=backend.hcl` per environment, answering yes only after the user agrees. Afterwards `terraform plan` must show no changes.

## Lock file

Commit `.terraform.lock.hcl` in every environment. Run `make lock` after any provider change: it writes hashes for linux (amd64, arm64), macOS (arm64, amd64) and windows once, then copies the file to every environment; without them `init` on a different platform fails with a checksum error. All environments must pin the same provider version; the parity check enforces it. Upgrade deliberately: `terraform -chdir=environments/development init -upgrade`, `make lock ENV=development`, `make check`, then plans.

The Makefile sets `TF_PLUGIN_CACHE_DIR` (default `~/.terraform.d/plugin-cache`, created if missing), so the provider downloads once rather than once per environment. Terraform only uses a cached package that matches a checksum in the lock file, which is why the lock file carries every platform's hashes.

## Common failures

| Symptom | Cause and fix |
|---|---|
| "Error acquiring the state lock" | another run is active, or one crashed. Wait, or after checking nobody is running Terraform ask before `terraform force-unlock <id>` |
| "the cached package ... does not match any of the checksums" | the lock file lacks this platform's hashes: `make lock` |
| "Backend initialization required" | the backend block changed: `init` with `-backend-config=backend.hcl`; `-reconfigure`/`-migrate-state` are confirmations |
| Plan wants to replace everything | wrong `backend.hcl` key, wrong workspace/environment folder, or a renamed resource without a `moved` block |
| Plan shows an unexpected diff after an AWS-side change | decide: accept it into the code, or add `ignore_changes` with a comment (module standard) |

Use `moved` blocks to rename or restructure resources without destroying them.
