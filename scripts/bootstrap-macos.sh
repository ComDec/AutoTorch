#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALL_BIN="$HOME/Library/Application Support/AutoTorch/bin/autotorch"
SKILL_DIR="${CODEX_HOME:-$HOME/.codex}/skills/torch-hpc"

printf 'AutoTorch first-time setup\n'
printf 'This installs the command and guardian, configures SSH, and starts one\n'
printf 'user-approved Microsoft device login. Password and Duo stay with you.\n\n'

"$ROOT/scripts/install-macos.sh"

if [[ -e "$SKILL_DIR" ]]; then
  printf '\nTorch Codex skill already exists at %s; leaving it unchanged.\n' "$SKILL_DIR"
else
  "$ROOT/scripts/install-skill.sh"
fi

printf '\nConfiguring the SSH alias and persistent control connection...\n'
"$INSTALL_BIN" setup "$@"
