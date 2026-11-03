#!/usr/bin/env bash
# Convenience wrapper: the exporter lives with the skill-authoring skill so
# it travels with it when installed.
exec "$(dirname "$0")/../skills/skill-authoring/scripts/export-portable.sh" "$@"
