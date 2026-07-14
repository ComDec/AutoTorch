# AutoTorch

Persistent, user-approved SSH access to NYU Torch for terminals, IDEs, and
coding agents.

AutoTorch completes Torch's cached Microsoft device-login flow, starts one
durable OpenSSH ControlMaster, and lets every later
`ssh torch` process reuse it. A low-priority macOS guardian monitors the master
without interrupting the user. When NYU requires a genuinely new Duo approval,
AutoTorch notifies the user instead of hanging an agent or trying to bypass MFA.

## Why coding agents need it

An autonomous coding session cannot safely answer a device-code or Duo prompt.
AutoTorch separates authentication from agent work:

1. The user completes NYU/MFA once so the browser has a trusted cached session.
2. Later `autotorch connect` runs enter the device code, select the default
   signed-in NYU account, confirm Continue, and submit to SSH automatically.
3. AutoTorch verifies and preserves the SSH master.
4. Agents use `ssh -o BatchMode=yes torch ...` through the existing master.
5. If the master dies, agent commands fail quickly and the guardian requests
   user action only when necessary.

The bundled [`torch-hpc` Codex skill](skills/torch-hpc/SKILL.md) adds the NYU
Torch operating rules an agent needs: connection preflight, login-node limits,
Slurm account discovery, CPU/GPU job submission, storage placement, modules,
Apptainer, and evidence-based troubleshooting.

## Security boundary

- AutoTorch may open Microsoft's official device-login page, type the
  short-lived device code, select the already signed-in default NYU account,
  and accept Microsoft's Continue confirmation.
- It never stores or types an NYU password and cannot fabricate a new Duo
  factor. If the cached session expires, the browser remains visible for the
  real NYU/MFA challenge and AutoTorch uses the configured fallback wait.
- Automatic typing runs only when Safari, Chrome, or Edge is foregrounded and
  its active tab is on a Microsoft login domain. Otherwise the device code is
  copied for manual paste.
- The background guardian never opens a browser or steals focus.
- Torch does not support SSH keys; a new transport may always require user MFA.

## Requirements

- macOS
- NYU campus network or NYU VPN
- A valid NYU HPC account
- An active Slurm project allocation for job submission
- OpenSSH and Expect

## First-time setup (recommended)

New users can install AutoTorch, configure the `torch` SSH alias, install the
Codex skill, and start the Microsoft device-login flow with one interactive
command:

```bash
git clone https://github.com/ComDec/AutoTorch.git
cd AutoTorch
./scripts/bootstrap-macos.sh
```

The setup asks for your NYU NetID, backs up an existing `~/.ssh/config`, writes
an idempotent AutoTorch-managed block at the top, creates the protected control
socket directory, runs `autotorch doctor`, and asks whether to connect now.

On the first connection, macOS may ask whether your terminal may control
System Events or the browser. Allowing it lets AutoTorch enter the short-lived
device code, select the default signed-in NYU account, and confirm the login.
As soon as Microsoft reaches its success page, AutoTorch submits to SSH—there
is no fixed 60-second delay. If keyboard-control permission is denied,
AutoTorch safely puts the code in the clipboard and continues watching the
Microsoft page without taking focus, so completed authorization is still
submitted immediately.

The permission belongs to the app that launches AutoTorch. For example, a
connection started in Ghostty needs **Ghostty** enabled under System Settings →
Privacy & Security → Accessibility. A connection launched by a coding-agent
app may have a different permission and can safely fall back to the clipboard.

Non-interactive configuration is also supported:

```bash
autotorch setup --netid YOUR_NETID --persist 24h --no-connect
```

## Manual SSH configuration

Create the control-socket directory:

```bash
mkdir -p ~/.ssh/cm
chmod 700 ~/.ssh/cm
```

Add this block to `~/.ssh/config`, replacing `YOUR_NETID`:

```sshconfig
Host torch
  HostName login.torch.hpc.nyu.edu
  User YOUR_NETID
  StrictHostKeyChecking no
  UserKnownHostsFile /dev/null
  LogLevel ERROR
  ForwardAgent yes

  ControlMaster auto
  ControlPath ~/.ssh/cm/%C
  ControlPersist 24h
  ServerAliveInterval 30
  ServerAliveCountMax 6
  TCPKeepAlive yes
```

The host-key settings match NYU's current multi-login-node recommendation.
Do not copy them to unrelated SSH hosts.

## Run from the repository without installing

Run directly from the repository:

```bash
chmod +x autotorch libexec/autotorch-auth.exp libexec/autotorch-browser-assist
./autotorch doctor
./autotorch connect
```

With a cached signed-in NYU session, AutoTorch completes the browser flow and
submits to SSH immediately. `--wait` applies only when automatic UI verification
falls back to manual completion:

```bash
./autotorch connect --wait 45
./autotorch connect --manual
```

Confirm that a coding agent can enter without an interactive prompt:

```bash
./autotorch agent-check
ssh -o BatchMode=yes -o NumberOfPasswordPrompts=0 torch 'hostname'
```

## Install AutoTorch and the guardian

```bash
./scripts/install-macos.sh
```

This installs:

- `~/.local/bin/autotorch`
- helpers under `~/Library/Application Support/AutoTorch/`
- `~/Library/LaunchAgents/com.comdec.autotorch.guardian.plist`

The guardian checks every five minutes, attempts a non-interactive reconnect at
most every 15 minutes, and sends at most one disconnection notification per
hour. A reconnect that needs MFA stops immediately.

The installer only installs files. To configure SSH interactively afterward:

```bash
autotorch setup
autotorch agent-check
```

To upgrade an existing install after `git pull`, rerun
`./scripts/install-macos.sh`; it replaces the installed command and helpers but
does not modify `~/.ssh/config`.

Uninstall the command and guardian without changing SSH config or logs:

```bash
./scripts/uninstall-macos.sh
```

## Install the Torch Codex skill

Install the bundled skill into the current Codex home:

```bash
./scripts/install-skill.sh
```

If an older copy already exists, review the diff and then update explicitly:

```bash
./scripts/install-skill.sh --force
```

Invoke it in Codex with `$torch-hpc`, or let it trigger on NYU Torch, Slurm,
Apptainer, or persistent Torch SSH tasks.

## Commands

```bash
autotorch connect                 # establish or reuse the durable master
autotorch setup                   # interactive first-time SSH configuration
autotorch connect --manual        # open page and copy code; no UI typing
autotorch connect --wait 45       # manual/fallback browser window only
autotorch status                  # query the local control master
autotorch agent-check             # verify non-interactive agent access
autotorch stop                    # close the master cleanly
autotorch doctor                  # inspect effective SSH settings
autotorch monitor                 # run one quiet guardian iteration
autotorch --version
```

VS Code, Cursor, `scp`, and `rsync` reuse the same master when they select the
exact alias `torch` and read the same SSH config:

```bash
ssh torch
scp local.txt torch:~/
rsync -av data/ torch:~/data/
```

## Persistence limits

AutoTorch keeps a healthy client connection alive indefinitely, subject to VPN,
laptop, network, login-node, and NYU server policy. It cannot silently cross a
new Microsoft/Duo challenge after a reboot, VPN change, long sleep, login-node
restart, or server-side termination. When the browser's trusted NYU session is
still valid, AutoTorch can recreate the master with zero clicks. A genuinely
new password or MFA challenge remains an institutional security boundary.

`autotorch status` reports whether the local OpenSSH control process exists.
`autotorch connect` and `autotorch agent-check` additionally open a bounded
read-only session, so a control socket that cannot actually run agent commands
is rejected instead of being reported as ready.

## Troubleshooting

Run this first:

```bash
autotorch doctor
```

It reports the resolved executable and helper directories as well as the
effective SSH multiplexing settings. On macOS it also reports whether browser
UI typing is enabled for the app that launched `autotorch`. If an older installation reports
`authentication helper not found at ~/.local/bin/libexec/...`, update the
repository and rerun `./scripts/install-macos.sh`. AutoTorch 0.2.0 and later
resolve the `~/.local/bin/autotorch` symlink before locating helpers.

If the browser opens but the code is not entered, paste the clipboard contents
manually at `https://microsoft.com/devicelogin`, or run:

```bash
autotorch connect --manual --wait 45
```

For automatic typing, open System Settings → Privacy & Security →
Accessibility and enable the terminal app that runs AutoTorch (Terminal,
iTerm2, Ghostty, and coding-agent apps have separate permissions). Then quit
and reopen that terminal before retrying. AutoTorch never requires this
permission for its background guardian.

If SSH cannot reach Torch, confirm NYU VPN/campus network first. AutoTorch
cannot repair a VPN outage or bypass a new Microsoft/Duo challenge.

## Develop and verify

Tests use fake SSH and browser helpers; they never contact Torch or open a real
login page:

```bash
./tests/run.sh
python3 ~/.codex/skills/.system/skill-creator/scripts/quick_validate.py skills/torch-hpc
```

## NYU documentation

- [Getting started](https://services.rt.nyu.edu/docs/hpc/getting_started/intro/)
- [Connecting and two-factor authentication](https://services.rt.nyu.edu/docs/hpc/connecting_to_hpc/connecting_to_hpc/)
- [Slurm job submission](https://services.rt.nyu.edu/docs/hpc/submitting_jobs/slurm_submitting_jobs/)
- [Storage and data management](https://services.rt.nyu.edu/docs/hpc/storage/intro_and_data_management/)
- [Tools and software](https://services.rt.nyu.edu/docs/hpc/tools_and_software/intro/)
- [Apptainer containers](https://services.rt.nyu.edu/docs/hpc/containers/intro/)

## Acknowledgements

AutoTorch began from ideas and an Expect-based prototype in
[wenboluu/Ignition](https://github.com/wenboluu/Ignition), then was reworked
around agent-safe preflight, guarded UI automation, a persistent connection
guardian, and NYU Torch operational guidance.
