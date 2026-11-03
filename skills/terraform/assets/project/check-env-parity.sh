#!/usr/bin/env bash
# Fails when the environments under terraform/environments/ have drifted apart.
#   1. Every file except terraform.tfvars and backend.hcl is byte-identical in all environments.
#   2. Every environment's terraform.tfvars sets the same variables.
#   3. Every tfvars entry is a declared variable, and every variable without a
#      default is set.
# Portable to bash 3.2 (macOS): no mapfile, no find -printf.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
envs_dir="$root/environments"
fail=0

envs=()
for d in "$envs_dir"/*/; do
  [ -d "$d" ] && envs+=("$(basename "$d")")
done
if [ "${#envs[@]}" -lt 2 ]; then
  echo "parity: need at least two environments under $envs_dir" >&2
  exit 1
fi
ref="${envs[0]}"

# Files that legitimately differ per environment, plus local-only files.
list_files() {
  (cd "$envs_dir/$1" && find . -type f \
    ! -path './.terraform/*' \
    ! -name 'terraform.tfvars' ! -name 'backend.hcl' \
    ! -name '*.tfstate' ! -name '*.tfstate.*' ! -name '*.tfplan' ! -name 'tfplan' \
    | sort)
}

var_names() {
  grep -E '^[a-z][a-z0-9_]*[[:space:]]*=' "$envs_dir/$1/terraform.tfvars" | sed -E 's/[[:space:]]*=.*//' | sort
}

# Variables declared in variables.tf, one per line; "name" or "name*" when it has a default.
declared() {
  awk '
    /^variable "/ { if (name != "") print name (has ? "*" : ""); split($0, a, "\""); name = a[2]; has = 0 }
    /^  default[[:space:]]*=/ { has = 1 }
    END { if (name != "") print name (has ? "*" : "") }
  ' "$envs_dir/$1/variables.tf" | sort
}

ref_files="$(list_files "$ref")"
ref_vars="$(var_names "$ref")"

for env in "${envs[@]:1}"; do
  if [ "$(list_files "$env")" != "$ref_files" ]; then
    echo "DRIFT: $env has a different set of files than $ref" >&2
    diff <(echo "$ref_files") <(list_files "$env") >&2 || true
    fail=1
  fi
  while IFS= read -r f; do
    [ -f "$envs_dir/$env/$f" ] || continue
    if ! cmp -s "$envs_dir/$ref/$f" "$envs_dir/$env/$f"; then
      echo "DRIFT: $f differs between $ref and $env" >&2
      fail=1
    fi
  done <<< "$ref_files"
  if [ "$(var_names "$env")" != "$ref_vars" ]; then
    echo "DRIFT: $env/terraform.tfvars sets different variables than $ref/terraform.tfvars" >&2
    diff <(echo "$ref_vars") <(var_names "$env") >&2 || true
    fail=1
  fi
done

for env in "${envs[@]}"; do
  declared_all="$(declared "$env" | sed 's/\*$//')"
  required="$(declared "$env" | grep -v '\*$' || true)"
  set_vars="$(var_names "$env")"
  undeclared="$(comm -13 <(echo "$declared_all") <(echo "$set_vars"))"
  unset_required="$(comm -23 <(echo "$required") <(echo "$set_vars"))"
  if [ -n "$undeclared" ]; then
    echo "DRIFT: $env/terraform.tfvars sets undeclared variables: $(echo $undeclared)" >&2
    fail=1
  fi
  if [ -n "$unset_required" ]; then
    echo "DRIFT: $env/terraform.tfvars does not set required variables: $(echo $unset_required)" >&2
    fail=1
  fi
done

if [ "$fail" -eq 0 ]; then
  echo "parity ok: ${envs[*]}"
fi
exit "$fail"
