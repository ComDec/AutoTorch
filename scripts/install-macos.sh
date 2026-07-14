#!/usr/bin/env bash

set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
  printf 'This installer currently supports macOS only.\n' >&2
  exit 1
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SUPPORT_DIR="$HOME/Library/Application Support/AutoTorch"
INSTALL_BIN="$SUPPORT_DIR/bin/autotorch"
USER_BIN="$HOME/.local/bin"
PLIST="$HOME/Library/LaunchAgents/com.comdec.autotorch.guardian.plist"
LOG_DIR="$HOME/Library/Logs/AutoTorch"

mkdir -p "$SUPPORT_DIR/bin" "$SUPPORT_DIR/libexec" "$USER_BIN" \
  "$HOME/Library/LaunchAgents" "$LOG_DIR"

install -m 755 "$ROOT/autotorch" "$INSTALL_BIN"
install -m 755 "$ROOT/libexec/autotorch-auth.exp" "$SUPPORT_DIR/libexec/autotorch-auth.exp"
install -m 755 "$ROOT/libexec/autotorch-browser-assist" "$SUPPORT_DIR/libexec/autotorch-browser-assist"
install -m 644 "$ROOT/libexec/autotorch-browser.js" "$SUPPORT_DIR/libexec/autotorch-browser.js"
ln -sfn "$INSTALL_BIN" "$USER_BIN/autotorch"

sed \
  -e "s|__AUTOTORCH_PATH__|$INSTALL_BIN|g" \
  -e "s|__LOG_DIR__|$LOG_DIR|g" \
  "$ROOT/launchd/com.comdec.autotorch.guardian.plist.in" > "$PLIST"

plutil -lint "$PLIST" >/dev/null
launchctl bootout "gui/$UID/com.comdec.autotorch.guardian" >/dev/null 2>&1 || true
launchctl bootstrap "gui/$UID" "$PLIST"

printf 'AutoTorch installed.\n'
printf '  command: %s\n' "$USER_BIN/autotorch"
printf '  guardian: %s\n' "$PLIST"
printf '\nEnsure ~/.local/bin is on PATH, then run:\n'
printf '  autotorch setup\n'
printf '\nFor a complete first-time setup, run ./scripts/bootstrap-macos.sh instead.\n'
