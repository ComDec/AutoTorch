---
name: torch-hpc
description: Operate NYU Torch HPC safely through AutoTorch's persistent SSH ControlMaster. Use when Codex needs to connect to Torch, troubleshoot SSH or VPN access, configure a coding environment, transfer code or data, inspect storage, discover Slurm accounts, submit or monitor CPU/GPU jobs, use modules or Apptainer, or run coding-agent tasks without triggering repeated Microsoft/Duo authentication.
---

# NYU Torch HPC

Use the authenticated AutoTorch master as the only agent entry point to NYU
Torch. Keep authentication user-approved and keep compute work off login nodes.

## Connection workflow

1. Run the bundled preflight:

   ```bash
   skills/torch-hpc/scripts/preflight.sh torch
   ```

2. If it reports no authenticated master, stop remote work and ask the user to
   run `autotorch connect` locally, finish Microsoft login, and approve Duo.
   Never automate the password or Duo approval.
   For an unconfigured machine, ask the user to run `autotorch setup` first;
   the interactive setup safely backs up and configures `~/.ssh/config`.
3. After preflight succeeds, run every agent SSH command with:

   ```bash
   ssh -o BatchMode=yes -o NumberOfPasswordPrompts=0 -o ConnectTimeout=8 torch '<command>'
   ```

   `BatchMode=yes` prevents a coding agent from hanging on a fresh MFA prompt.
4. Re-run preflight after VPN changes, laptop wake, connection resets, or login
   node maintenance.

## Remote execution boundary

- Treat the Torch login node as a gateway for editing, inspection, transfers,
  compilation of small targets, and Slurm submission.
- Do not run training, benchmarks, large builds, data processing, containers,
  or long-lived services directly on a login node.
- Request a compute allocation with `srun` for interactive work or submit an
  `sbatch` script for durable work.
- Discover the user's valid account with `my_slurm_accounts`. Never guess an
  account or copy an account identifier from an unrelated project.
- Do not specify a partition unless the task deliberately uses Torch's
  documented preemption workflow.

## Coding-agent workflow

1. Inspect before changing anything:

   ```bash
   ssh -o BatchMode=yes torch 'hostname; id; pwd; myquota; my_slurm_accounts'
   ```

2. Place source code and durable configuration under `$HOME` or a backed-up
   project space. Put large temporary datasets, caches, checkpoints, and job
   outputs under `$SCRATCH`.
3. Prefer Git for source synchronization. Use `rsync` or `scp` for artifacts;
   route large transfers through the Torch DTN when appropriate.
4. Inspect available software before installing:

   ```bash
   ssh -o BatchMode=yes torch 'module list; module avail 2>&1 | head -80; command -v apptainer; command -v python'
   ```

5. Prefer Apptainer plus an overlay for reproducible custom environments. Do
   not attempt Docker or root-dependent installation on Torch.
6. Submit the smallest adequate resource request. For example, after replacing
   `ACCOUNT` with an observed value:

   ```bash
   ssh -o BatchMode=yes torch "srun --account=ACCOUNT --cpus-per-task=2 --mem=8G --time=01:00:00 --pty /bin/bash"
   ```

   Add `--gres=gpu:1` for a GPU and use `--constraint` only when the workload
   actually requires a documented GPU type.
7. For unattended work, create an `sbatch` file in the project, submit it, then
   record the job ID. Monitor with `squeue`, `sacct`, and `seff` rather than
   keeping an SSH terminal busy.
8. Return the exact host, paths, account, command, job ID, and validation result
   to the user. Distinguish source inspection from an executed compute job.

## Safety rules

- Never store, print, commit, or transmit NYU passwords, device codes, browser
  cookies, or Duo material.
- Never attempt to bypass MFA or turn a failed interactive login into a hidden
  background loop.
- Never use scripts to change file access times to evade Scratch purging.
- Never place high-risk data such as PII, ePHI, or CUI on Torch; use the NYU
  Secure Research Data Environment instead.
- Avoid destructive remote commands unless the user explicitly authorizes the
  exact scope and a recovery path is understood.
- Use shell quoting that keeps variable expansion on the intended side of the
  SSH boundary.

## Troubleshooting order

1. Run `autotorch status` and `autotorch doctor` locally.
2. Confirm NYU VPN or campus network access.
3. Run the preflight with `BatchMode=yes` behavior.
4. Classify failure as DNS/VPN, TCP/SSH transport, control-socket reuse, MFA,
   account/allocation, Slurm, storage, or compute-job failure.
5. Do not attribute a pre-authentication reset to Duo or the user's password.
6. Use `https://ood.torch.hpc.nyu.edu` as a user-facing shell fallback when SSH
   is unavailable, and contact `hpc@nyu.edu` for persistent service-side issues.

## References

Read [references/nyu-torch.md](references/nyu-torch.md) before making storage,
Slurm, GPU, environment, or data-handling decisions. It contains the current
official NYU links and the operational limits most likely to affect an agent.
