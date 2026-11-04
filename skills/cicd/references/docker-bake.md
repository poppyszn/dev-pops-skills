# Docker Bake build template

`assets/workflows/docker-bake-push.yml` with `assets/bake/docker-bake.hcl`: builds and pushes several app images from one repository in a single job. Use it instead of a matrix of `docker-build-push.yml` calls when the apps' Dockerfiles share stages (the same dependency install, a shared runtime stage). With one image, keep `docker-build-push.yml`.

## What to change when copying

- Copy `docker-bake.hcl` to the repository root and `docker-bake-push.yml` to `.github/workflows/`.
- In `docker-bake.hcl`, list every app in the matrix (`<APP_A>`, `<APP_B>`…), set `<APPS_DIR>` to the folder holding `<app>/Dockerfile`, and `<FINAL_STAGE>` to the Dockerfile stage the host runs (e.g. `production`).
- Call it like `docker-build-push.yml`: `apps` is a space-separated list of matrix names, `image-tag` the moving tag, `ref` the commit for a rollback or redeploy.
  ```yaml
  build:
    needs: detect
    uses: ./.github/workflows/docker-bake-push.yml
    with:
      apps: ${{ needs.detect.outputs.apps }}
      image-tag: latest-${{ github.ref_name }}
      ref: ${{ needs.detect.outputs.sha }}
  ```
- `max-parallelism` (BuildKit build steps at once): 2 on a hosted runner for a private repository (2 CPUs, 8 GB). On an 8-CPU self-hosted runner, 5 worked well in practice (the deploy it ran went from 10.4 to 5.8 minutes, with the runner's host also serving other jobs). Raise it one step at a time and watch the runner's memory: parallel compiles are what fill it.
- Single-architecture by default (`*.platform=linux/amd64`). For multi-arch, add `docker/setup-qemu-action` and set `*.platform=linux/amd64,linux/arm64`, which is much slower.
- Locally, `docker buildx bake -f docker-bake.hcl <app>` builds one app with no remote cache (`CACHE_SCOPE` empty).

## Why one bake job

Each matrix runner rebuilt (or re-downloaded from cache) the same dependency and runtime stages, and the resulting layers were different blobs per image, so a host pulling several apps downloaded `node_modules` once per app. One builder runs a shared stage once and reuses it for every target, so every image carries the same blobs: the host pulls them once and each extra app adds only its own bundle. For this to work the Dockerfiles must keep the shared stages identical, byte for byte (see the docker skill's `node-api.md`, "Several app images from one repository").

## Cache scopes

`cache-to` writes one GHA scope per app (`<repo>-<app>`). One shared scope for every target sounds tidier but each target's export overwrites the last one's, so only the last app built ever hits it. Shared layers are the same blobs in every scope and are stored once.

Observed limit: after a run that compiled several apps, the next run of the same commit restored only one app's compile step from the cache; the shared stages always hit. The cause was not pinned down. It only costs time on a redeploy of an unchanged commit.

## Deploying only what a push changed

A push deploy that rebuilds every app on every push wastes minutes and restarts services that did not change. Reuse `assets/scripts/detect-affected.sh` (the PR checks' rules) with the commit before the push as the base:

```yaml
detect:
  runs-on: ubuntu-latest
  outputs:
    apps: ${{ steps.detect.outputs.apps }}
  steps:
    - uses: actions/checkout@v7
      with:
        fetch-depth: 0 # the push's base commit must be present
    - id: detect
      env:
        BEFORE_SHA: ${{ github.event.before }}
        ALL_APPS: <APP_A> <APP_B>
      run: |
        if ! git cat-file -e "${BEFORE_SHA}^{commit}" 2>/dev/null; then
          apps="$ALL_APPS" # first push, or a force-push whose old head is gone
        else
          # Not piped: the default step shell has no pipefail (gotchas.md).
          apps=$(bash scripts/detect-affected.sh "$BEFORE_SHA")
        fi
        echo "apps=${apps//$'\n'/ }" >> "$GITHUB_OUTPUT"

build:
  needs: detect
  if: needs.detect.outputs.apps != ''
  # ...
```

- **Diff from `github.event.before`, not `HEAD^`.** A push can carry several commits; `HEAD^..HEAD` sees only the last, so an app changed two commits earlier in the same push is never deployed. It needs `fetch-depth: 0` (or at least the base commit).
- **No usable base deploys everything.** On a branch's first push `before` is all zeros, and after a force-push the old head may no longer exist.
- **An empty list skips every later job** through `if: needs.detect.outputs.apps != ''` on each of them (build, migrate, deploy), so a push that touches no app finishes green after detect.
- **Files outside the apps that every image or the host reads** (the bake file, a shared entrypoint, the deploy compose file) belong in `SHARED` in `detect-affected.sh`, so changing them redeploys everything.
- **`paths-ignore` with `.github/**`** means a push that changes only workflows deploys nothing, including a fix to the deploy workflow itself. Run it by hand after such a merge.
