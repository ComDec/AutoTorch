#!/usr/bin/env bash

set -u

host="${1:-torch}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

if command -v autotorch >/dev/null 2>&1; then
  cli="$(command -v autotorch)"
elif [[ -x "$REPO_ROOT/autotorch" ]]; then
  cli="$REPO_ROOT/autotorch"
else
  printf 'torch.preflight=error\n' >&2
  printf 'torch.reason=autotorch-not-found\n' >&2
  printf 'Install AutoTorch or run this skill from the AutoTorch repository.\n' >&2
  exit 3
fi

target="$(ssh -G "$host" 2>/dev/null | awk '$1 == "hostname" { print $2; exit }')"
user="$(ssh -G "$host" 2>/dev/null | awk '$1 == "user" { print $2; exit }')"
control_path="$(ssh -G "$host" 2>/dev/null | awk '$1 == "controlpath" { print $2; exit }')"

printf 'local.alias=%s\n' "$host"
printf 'local.target=%s\n' "${target:-unknown}"
printf 'local.user=%s\n' "${user:-unknown}"
printf 'local.control_path=%s\n' "${control_path:-none}"

"$cli" agent-check --host "$host"
