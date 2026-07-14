#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE="$ROOT/skills/torch-hpc"
SKILLS_HOME="${CODEX_HOME:-$HOME/.codex}/skills"
DESTINATION="$SKILLS_HOME/torch-hpc"
force=0

if [[ "${1:-}" == "--force" ]]; then
  force=1
elif [[ $# -gt 0 ]]; then
  printf 'Usage: %s [--force]\n' "$0" >&2
  exit 2
fi

if [[ -e "$DESTINATION" && "$force" -ne 1 ]]; then
  printf 'A torch-hpc skill already exists at %s\n' "$DESTINATION" >&2
  printf 'Review it, then rerun with --force to replace its contents.\n' >&2
  exit 1
fi

mkdir -p "$DESTINATION"
rsync -a --delete "$SOURCE/" "$DESTINATION/"

printf 'Installed torch-hpc skill at %s\n' "$DESTINATION"
printf 'Restart Codex if the skill is not discovered immediately.\n'
