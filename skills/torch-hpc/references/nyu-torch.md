# NYU Torch operational reference

Verified against the official NYU Research Technology documentation on
2026-07-14. Recheck the linked pages when current quotas, resource policies, or
GPU availability materially affect the task.

## Access and identity

- Torch requires an NYU HPC account.
- Job submission also requires at least one active Slurm account associated
  with an active project allocation.
- Discover accounts on Torch with `my_slurm_accounts`; supply the selected
  account through `--account=` for every `srun` or `sbatch` submission.
- Connect from the NYU campus network or NYU VPN.
- Torch does not support SSH public-key authentication. A new SSH transport uses
  Microsoft device login plus Duo; AutoTorch reuses one authenticated transport.

Recommended alias, extended with AutoTorch multiplexing:

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

The official documentation disables strict host-key checking because the login
name resolves across multiple login nodes. Do not generalize that setting to
unrelated SSH hosts.

## Login nodes and Slurm

- Use login nodes for lightweight orchestration only.
- Run compute work on allocated nodes.
- Every submission needs `--account=ACCOUNT`.
- Request GPUs with `--gres=gpu:N`.
- Request a specific GPU family only when required, for example
  `--constraint='h200'` or a documented alternative list.
- Avoid manually selecting partitions except for an intentional preemptible
  workflow.
- Request only the CPU, memory, GPU, and wall time the workload needs.
- Checkpoint preemptible jobs so they can resume after cancellation.

Interactive template:

```bash
srun \
  --account=ACCOUNT \
  --cpus-per-task=2 \
  --mem=8G \
  --time=01:00:00 \
  --pty /bin/bash
```

GPU template:

```bash
srun \
  --account=ACCOUNT \
  --gres=gpu:1 \
  --cpus-per-task=4 \
  --mem=32G \
  --time=02:00:00 \
  --pty /bin/bash
```

Batch lifecycle:

```bash
sbatch job.sbatch
squeue -u "$USER"
sacct -j JOB_ID --format=JobID,State,Elapsed,ExitCode
seff JOB_ID
```

## Storage choices

| Location | Intended use | Key limits and behavior |
|---|---|---|
| `$HOME` (`/home/$USER`) | Code, configuration, small durable files | 50 GB, 30,000 inodes, backed up daily |
| `$SCRATCH` (`/scratch/$USER`) | Large temporary job data, caches, checkpoints | 5 TB, 5,000,000 inodes, no backup; files not accessed for 60 days may be purged |
| `$ARCHIVE` (`/archive/$USER`) | Compressed long-term results | 2 TB, 20,000 inodes, backed up; available on login nodes, not compute jobs |
| Research Project Space | Shared durable project data | Backed up and not subject to Scratch purging; allocation is project-specific |
| `/scratch/work/public` | Shared public datasets and examples | Read-only; some datasets require an agreement |

Keep important source outside Scratch. Do not change access times to avoid the
purge policy. Watch both byte quotas and inode counts with `myquota`.

Torch is approved only for moderate-risk data. Do not store PII, ePHI, CUI, or
other high-risk data there.

## Software environments

- Inspect environment modules with `module avail`, `module spider`, and
  `module list` before installing software.
- NYU recommends Apptainer containers and writable overlays for custom
  environments.
- Do not run Docker or root-dependent workflows on Torch.
- Run containers and package-heavy work on compute nodes, not login nodes.
- Avoid large Conda installations in `$HOME`, where small files can exhaust the
  inode quota. Prefer the documented Apptainer/overlay pattern.
- Example software recipes are available at `/scratch/work/public/examples/`.

## Agent-safe connection state machine

```text
Control master healthy
  -> use ssh -o BatchMode=yes torch ...

Control master missing
  -> guardian may try one non-interactive reconnect
  -> if Microsoft/Duo is required, stop
  -> notify user to run autotorch connect
  -> resume agent work only after autotorch agent-check succeeds
```

## Official documentation

- Start here: https://services.rt.nyu.edu/docs/hpc/getting_started/intro/
- Connecting and 2FA: https://services.rt.nyu.edu/docs/hpc/connecting_to_hpc/connecting_to_hpc/
- Slurm accounts: https://services.rt.nyu.edu/docs/hpc/getting_started/Slurm_Accounts/intro_slurm_accounts/
- Submitting jobs: https://services.rt.nyu.edu/docs/hpc/submitting_jobs/slurm_submitting_jobs/
- Storage: https://services.rt.nyu.edu/docs/hpc/storage/intro_and_data_management/
- Tools and software: https://services.rt.nyu.edu/docs/hpc/tools_and_software/intro/
- Containers: https://services.rt.nyu.edu/docs/hpc/containers/intro/
- Open OnDemand: https://ood.torch.hpc.nyu.edu
- Support: hpc@nyu.edu
