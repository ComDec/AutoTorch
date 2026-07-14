#!/usr/bin/env bash

set -euo pipefail

SUPPORT_DIR="$HOME/Library/Application Support/AutoTorch"
USER_LINK="$HOME/.local/bin/autotorch"
PLIST="$HOME/Library/LaunchAgents/com.comdec.autotorch.guardian.plist"

launchctl bootout "gui/$UID/com.comdec.autotorch.guardian" >/dev/null 2>&1 || true

if [[ -L "$USER_LINK" ]]; then
  rm "$USER_LINK"
fi
if [[ -f "$PLIST" ]]; then
  rm "$PLIST"
fi
if [[ -d "$SUPPORT_DIR" ]]; then
  rm -rf "$SUPPORT_DIR"
fi

printf 'AutoTorch and its guardian were removed. SSH config and logs were left untouched.\n'
