// Every app image in one Bake definition (copy to the repository root).
//
// One `docker buildx bake` call builds every selected app on one BuildKit
// builder, so the stages the Dockerfiles share (dependency install, a shared
// runtime stage) run once and every image gets the same layer blobs: a host
// that pulls several apps downloads node_modules once, not once per app.
//
//   docker buildx bake -f docker-bake.hcl api worker   # just these apps
//   docker buildx bake -f docker-bake.hcl              # every app
//
// Tags match docker-build-push.yml: <IMAGE>-<app>:<TAG> and <IMAGE>-<app>:<SHA>.

// ghcr.io/<owner>/<repo>, lowercase. Local builds get a plain local name.
variable "IMAGE" {
  default = "local"
}

// Moving tag, e.g. latest-develop or latest-production.
variable "TAG" {
  default = "dev"
}

// Commit SHA for the pinned tag the host runs; empty skips that tag.
variable "SHA" {
  default = ""
}

// GitHub Actions cache scope prefix; empty disables the remote cache (local builds).
variable "CACHE_SCOPE" {
  default = ""
}

group "default" {
  targets = ["apps"]
}

target "apps" {
  name = app
  matrix = {
    app = [
      "<APP_A>",
      "<APP_B>",
    ]
  }
  context    = "."
  dockerfile = "<APPS_DIR>/${app}/Dockerfile"
  target     = "<FINAL_STAGE>"
  tags       = concat(["${IMAGE}-${app}:${TAG}"], SHA == "" ? [] : ["${IMAGE}-${app}:${SHA}"])
  // One cache scope per app. The shared layers are the same blobs in every
  // scope, so the cache stores them once; a single shared scope would be
  // overwritten by whichever app exported last.
  cache-from = CACHE_SCOPE == "" ? [] : ["type=gha,scope=${CACHE_SCOPE}-${app}"]
  cache-to   = CACHE_SCOPE == "" ? [] : ["type=gha,scope=${CACHE_SCOPE}-${app},mode=max"]
}
