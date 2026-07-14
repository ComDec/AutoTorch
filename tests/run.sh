#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/bin" "$TMP/home" "$TMP/state"
export HOME="$TMP/home"
export PATH="$TMP/bin:/usr/bin:/bin"
export AUTOTORCH_STATE_DIR="$TMP/autotorch-state"
export AUTOTORCH_NOTIFY_COOLDOWN=3600
export AUTOTORCH_RECONNECT_COOLDOWN=900
export FAKE_MASTER_STATE="$TMP/state/master"
export FAKE_BROWSER_CALL="$TMP/state/browser-call"

cat > "$TMP/bin/ssh" <<'FAKE_SSH'
#!/usr/bin/env bash
set -u

if [[ "${1:-}" == "-G" ]]; then
  cat <<EOF
user testnetid
hostname login.torch.hpc.nyu.edu
controlmaster auto
controlpath $HOME/.ssh/cm/fake-control
controlpersist 86400
serveraliveinterval 30
serveralivecountmax 6
EOF
  exit 0
fi

if [[ "${1:-}" == "-O" && "${2:-}" == "check" ]]; then
  if [[ -f "$FAKE_MASTER_STATE" ]]; then
    printf 'Master running (pid=4242)\n' >&2
    exit 0
  fi
  exit 255
fi

if [[ "${1:-}" == "-O" && "${2:-}" == "exit" ]]; then
  rm -f "$FAKE_MASTER_STATE"
  printf 'Exit request sent.\n' >&2
  exit 0
fi

case " $* " in
  *" BatchMode=yes "*)
    if [[ -f "$FAKE_MASTER_STATE" ]]; then
      printf 'remote.hostname=torch-login-test\n'
      printf 'remote.user=testnetid\n'
      printf 'remote.home=/home/testnetid\n'
      printf 'remote.scratch=/scratch/testnetid\n'
      printf 'remote.slurm=available\n'
      printf 'remote.my_slurm_accounts=available\n'
      exit 0
    fi
    exit 255
    ;;
esac

printf '(testnetid@login) Authenticate with PIN ABCD1234 at https://microsoft.com/devicelogin and press ENTER.\n'
IFS= read -r _answer || true
touch "$FAKE_MASTER_STATE"
exit 0
FAKE_SSH

cat > "$TMP/bin/browser-helper" <<'FAKE_BROWSER'
#!/usr/bin/env bash
printf '%s %s\n' "$1" "$3" >> "$FAKE_BROWSER_CALL"
if [[ "$3" == "status" && "${FAKE_BROWSER_STATUS_COMPLETE:-0}" == "1" ]]; then
  if [[ ! -e "$FAKE_BROWSER_STATUS_SEEN" ]]; then
    : > "$FAKE_BROWSER_STATUS_SEEN"
    printf 'AUTOTORCH_AUTH_STATE=device\n'
  else
    printf 'AUTOTORCH_AUTH_STATE=success\n'
  fi
elif [[ "$3" == "status" ]]; then
  printf 'AUTOTORCH_AUTH_STATE=other\n'
elif [[ "$3" == "auto" ]]; then
  printf 'AUTOTORCH_AUTH_COMPLETE=1\n'
else
  printf 'AUTOTORCH_AUTH_COMPLETE=0\n'
fi
printf 'Browser helper test double completed.'
FAKE_BROWSER

cat > "$TMP/bin/osascript" <<'FAKE_OSASCRIPT'
#!/usr/bin/env bash
exit 0
FAKE_OSASCRIPT

chmod +x "$TMP/bin/ssh" "$TMP/bin/browser-helper" "$TMP/bin/osascript"
export AUTOTORCH_BROWSER_HELPER="$TMP/bin/browser-helper"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  [[ "$haystack" == *"$needle"* ]] || fail "expected output to contain: $needle"
}

assert_not_contains() {
  local haystack="$1"
  local needle="$2"
  [[ "$haystack" != *"$needle"* ]] || fail "output unexpectedly contained: $needle"
}

bash -n "$ROOT/autotorch"
bash -n "$ROOT/libexec/autotorch-browser-assist"
bash -n "$ROOT/scripts/install-macos.sh"
bash -n "$ROOT/scripts/bootstrap-macos.sh"
bash -n "$ROOT/scripts/uninstall-macos.sh"
if command -v osacompile >/dev/null 2>&1; then
  osacompile -l JavaScript -o "$TMP/autotorch-browser.scpt" "$ROOT/libexec/autotorch-browser.js"
fi

if "$ROOT/libexec/autotorch-browser-assist" https://example.com/device CODE manual >/dev/null 2>&1; then
  fail "browser helper accepted an untrusted login URL"
fi

doctor_output="$($ROOT/autotorch doctor --host torch)"
assert_contains "$doctor_output" "SSH multiplexing is ready"
assert_contains "$doctor_output" "auth helper:          ready"
assert_contains "$doctor_output" "Browser UI typing:"

mkdir -p "$HOME/.ssh"
printf 'Host example\n  HostName example.com\n' > "$HOME/.ssh/config"
setup_output="$($ROOT/autotorch setup --host torch --netid abc123 --persist 24h --no-connect)"
assert_contains "$setup_output" "configured torch for abc123@login.torch.hpc.nyu.edu"
assert_contains "$(cat "$HOME/.ssh/config")" "# >>> AutoTorch managed Torch SSH config >>>"
assert_contains "$(cat "$HOME/.ssh/config")" "User abc123"
assert_contains "$(cat "$HOME/.ssh/config")" "ControlPersist 24h"
assert_contains "$(cat "$HOME/.ssh/config")" "Host example"
backup_count="$(find "$HOME/.ssh" -name 'config.autotorch-backup.*' | wc -l | tr -d ' ')"
[[ "$backup_count" == "1" ]] || fail "setup did not back up an existing SSH config"
$ROOT/autotorch setup --host torch --netid abc123 --persist 24h --no-connect >/dev/null
managed_count="$(grep -c '^# >>> AutoTorch managed Torch SSH config >>>$' "$HOME/.ssh/config")"
[[ "$managed_count" == "1" ]] || fail "setup duplicated its managed SSH block"

# Reproduce the installed layout: the public command is a symlink, while its
# helpers are a sibling of the real binary directory.
mkdir -p "$TMP/installed/app/bin" "$TMP/installed/app/libexec" "$TMP/installed/local/bin"
cp "$ROOT/autotorch" "$TMP/installed/app/bin/autotorch"
cp "$ROOT/libexec/autotorch-auth.exp" "$TMP/installed/app/libexec/autotorch-auth.exp"
chmod +x "$TMP/installed/app/bin/autotorch" "$TMP/installed/app/libexec/autotorch-auth.exp"
ln -s "$TMP/installed/app/bin/autotorch" "$TMP/installed/local/bin/autotorch"
installed_doctor="$($TMP/installed/local/bin/autotorch doctor --host torch)"
installed_libexec="$(cd -P "$TMP/installed/app/libexec" && pwd)"
assert_contains "$installed_doctor" "helper directory:     $installed_libexec"
assert_contains "$installed_doctor" "auth helper:          ready"
installed_connect="$($TMP/installed/local/bin/autotorch connect --host torch --manual --wait 1 vv)"
assert_contains "$installed_connect" "SSH master ready"
$TMP/installed/local/bin/autotorch stop --host torch >/dev/null 2>&1

if "$ROOT/autotorch" status --host torch >/dev/null 2>&1; then
  fail "status should report disconnected before authentication"
fi

monitor_output="$($ROOT/autotorch monitor --host torch)"
[[ -z "$monitor_output" ]] || fail "monitor should be quiet"
[[ ! -f "$FAKE_MASTER_STATE" ]] || fail "non-interactive reconnect must not fake MFA"

connect_output="$($ROOT/autotorch connect --host torch --manual --wait 1 vv)"
assert_contains "$connect_output" "SSH master ready"
assert_not_contains "$connect_output" "ABCD1234"
[[ -f "$FAKE_MASTER_STATE" ]] || fail "connect did not create the master"

browser_output="$(cat "$FAKE_BROWSER_CALL")"
assert_contains "$browser_output" "https://microsoft.com/devicelogin manual"

status_output="$($ROOT/autotorch status --host torch 2>&1)"
assert_contains "$status_output" "Master running"

agent_output="$($ROOT/autotorch agent-check --host torch)"
assert_contains "$agent_output" "remote.hostname=torch-login-test"
assert_contains "$agent_output" "remote.slurm=available"

skill_output="$($ROOT/skills/torch-hpc/scripts/preflight.sh torch)"
assert_contains "$skill_output" "local.target=login.torch.hpc.nyu.edu"
assert_contains "$skill_output" "remote.hostname=torch-login-test"

line_count_before="$(wc -l < "$FAKE_BROWSER_CALL" | tr -d ' ')"
reuse_output="$($ROOT/autotorch connect --host torch)"
assert_contains "$reuse_output" "already connected"
line_count_after="$(wc -l < "$FAKE_BROWSER_CALL" | tr -d ' ')"
[[ "$line_count_before" == "$line_count_after" ]] || fail "reuse unexpectedly reopened browser auth"

stop_output="$($ROOT/autotorch stop --host torch 2>&1)"
assert_contains "$stop_output" "closed the torch SSH master"
[[ ! -f "$FAKE_MASTER_STATE" ]] || fail "stop did not remove the master"

SECONDS=0
automatic_output="$($ROOT/autotorch connect --host torch --wait 300 vv)"
automatic_elapsed="$SECONDS"
assert_contains "$automatic_output" "Browser authentication completed; submitting to SSH immediately"
assert_contains "$automatic_output" "SSH master ready"
(( automatic_elapsed < 5 )) || fail "completed browser auth still waited for --wait"
$ROOT/autotorch stop --host torch >/dev/null 2>&1

export FAKE_BROWSER_STATUS_COMPLETE=1
export FAKE_BROWSER_STATUS_SEEN="$TMP/browser-status-seen"
SECONDS=0
fallback_output="$($ROOT/autotorch connect --host torch --manual --wait 300 vv)"
fallback_elapsed="$SECONDS"
unset FAKE_BROWSER_STATUS_COMPLETE
unset FAKE_BROWSER_STATUS_SEEN
assert_contains "$fallback_output" "Microsoft success detected; submitting to SSH immediately"
assert_contains "$fallback_output" "SSH master ready"
(( fallback_elapsed < 5 )) || fail "fallback success polling still waited for --wait"
$ROOT/autotorch stop --host torch >/dev/null 2>&1

CODEX_HOME="$TMP/codex" "$ROOT/scripts/install-skill.sh" >/dev/null
[[ -f "$TMP/codex/skills/torch-hpc/SKILL.md" ]] || fail "skill installer did not copy SKILL.md"
if CODEX_HOME="$TMP/codex" "$ROOT/scripts/install-skill.sh" >/dev/null 2>&1; then
  fail "skill installer should refuse to overwrite without --force"
fi
CODEX_HOME="$TMP/codex" "$ROOT/scripts/install-skill.sh" --force >/dev/null

printf 'All AutoTorch tests passed.\n'
