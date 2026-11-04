# Composite actions fail to load: a `${{ secrets.* }}` expression in a `run:` comment

> **Status: applied 2026-11-04** in cicd 3.2.1 and project-infra 3.1.3. The three comments are reworded in both actions and their vendored copies; cicd's Verification and `references/gotchas.md` cover `run:` bodies in actions, comments included; this repo's CI runs `scripts/check-run-expressions.sh` over every workflow and action.

**Where it was found:** a pnpm + Nx monorepo (NestJS API, SSR storefront, static
admin) with a pull-based develop deploy, assembled with project-infra using the
vendored `git-sync-deploy` and `ssh-compose-deploy` composite actions.

**Confirmed bug in this repo's templates today:** yes, in both actions.

**Reproduction**

```sh
grep -n 'secrets\.' skills/cicd/assets/actions/*/action.yml
# git-sync-deploy/action.yml:109:        # (e.g. ${{ secrets.SSH_PORT }} when that secret was never set) —
# ssh-compose-deploy/action.yml:107:        # (e.g. ${{ secrets.SSH_PORT }} when that secret was never set) —
```

GitHub evaluates `${{ }}` anywhere in a `run:` body, including inside shell
comments. The `secrets` context does not exist in a composite action, so the
runner refuses to load it, and the calling job fails before any step runs:

```
Unrecognized named-value: 'secrets'. Located at position 1 within expression: secrets.SSH_PORT
Failed to load .../.github/actions/git-sync-deploy/action.yml
```

The same file also has a comment containing `${{ inputs.ssh-host }}`
(`ssh-compose-deploy/action.yml:61`). It loads, but the input's value is pasted
into the script source, which is the injection pattern the cicd skill forbids.
The cicd Verification step ("no `${{ }}` inside `run:` scripts") would have caught
it only if it parsed `run:` bodies of the vendored actions, not just workflows.

**Suggested fix:** reword the three comments without braces (for example "the
SSH_PORT secret", "not an inline expression"). Extend the Verification check to
parse every `run:` body in `.github/actions/*/action.yml` as well as workflows,
and add the case to `references/gotchas.md`.
