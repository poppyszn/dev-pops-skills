#!/usr/bin/env bash
# Convenience wrapper: the validator lives with the skill-authoring skill so it
# travels with it when installed.
exec "$(dirname "$0")/../skills/skill-authoring/scripts/validate.sh" "$@"
