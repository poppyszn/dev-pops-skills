# Docker build-and-push template

Reusable workflow (`workflow_call`) that builds a multi-arch image and
pushes it to GHCR with per-app GitHub Actions cache scoping. Stops at
"image is pushed" — deploying it is a separate, explicit step (see
`assets/actions/ssh-compose-deploy` and `references/ssh-compose-deploy.md`).

## What to change when copying this template

- If you have multiple apps in one repo (monorepo), call this workflow
  once per app via a matrix in the calling workflow:
  ```yaml
  jobs:
    build:
      strategy:
        matrix:
          app: [api, web, admin]
      uses: ./.github/workflows/docker-build-push.yml
      with:
        app: ${{ matrix.app }}
        dockerfile: apps/${{ matrix.app }}/Dockerfile
        image-tag: latest-${{ github.ref_name }}
  ```
- Drop `platforms: linux/amd64,linux/arm64` (and the qemu setup step) if
  you only deploy to one architecture — multi-arch builds are slower.
- `cache-from`/`cache-to` scope is `inputs.app` so parallel matrix builds
  don't share (and thrash) a single cache.
- `sbom: true`/`provenance: true` attach a Software Bill of Materials and
  SLSA build provenance to the pushed image (basic supply-chain hygiene,
  viewable via `docker buildx imagetools inspect`). Drop them only if a
  downstream tool can't yet consume the resulting OCI attestation
  manifests.

## The `Compute lowercase image repository` step isn't optional

`github.repository` preserves the repo owner's actual case (e.g.
`VICTOR-CHUKWU/property-management-api`), but GHCR image paths must be
all-lowercase — pushing a tag with any uppercase character fails
outright. This step lowercases it into `env.REPO_LC` before it's used in
any tag. Don't revert to `ghcr.io/${{ github.repository }}-...` even for
"just testing" — it works only by coincidence for all-lowercase
usernames/orgs, and breaks silently (well, loudly, but only in CI, not
locally) for anyone else. Confirmed against a real deploy
(property-management-api/-ui, owner `VICTOR-CHUKWU`).
