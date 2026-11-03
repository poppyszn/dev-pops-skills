#!/usr/bin/env bash
# Builds a scratch project from the terraform skill's assets, once per template
# (ec2, ecs, static-site), and runs what a scaffolded project runs: terraform fmt -check, the
# environment parity check, and terraform validate in every environment.
# Needs terraform on PATH and network access to download the aws provider.
# Skips cleanly when the terraform skill is not in this checkout.
set -euo pipefail

repo="$(cd "$(dirname "$0")/.." && pwd)"
assets="$repo/skills/terraform/assets"

if [ ! -d "$assets" ]; then
  echo "skip: skills/terraform/assets not found"
  exit 0
fi

terraform fmt -check -recursive "$assets"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

for kind in ec2 ecs static-site; do
  proj="$work/$kind/terraform"
  mkdir -p "$proj/scripts"
  cp -r "$assets/modules" "$proj/"
  cp "$assets/project/check-env-parity.sh" "$proj/scripts/"
  for tfvars in "$assets/environments/$kind/tfvars/"*.tfvars; do
    env="$(basename "$tfvars" .tfvars)"
    mkdir -p "$proj/environments/$env"
    cp "$assets/environments/common/providers.tf" "$assets/environments/$kind/shared/"*.tf "$proj/environments/$env/"
    cp "$tfvars" "$proj/environments/$env/terraform.tfvars"
  done

  echo "== $kind: parity"
  "$proj/scripts/check-env-parity.sh"

  for dir in "$proj/environments/"*/; do
    echo "== $kind: validate $(basename "$dir")"
    terraform -chdir="$dir" init -backend=false -input=false >/dev/null
    terraform -chdir="$dir" validate
  done
done
