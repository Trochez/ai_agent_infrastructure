# Installation and operation guide

## Scope

The installer configures the folder where it is executed as an AI engineering project. Linux, WSL2 and macOS are supported by the Bash installer; Windows should run it through WSL2 using `install.ps1`.

The machine layer installs or repairs: Git/curl/Python/Node/Bun, OpenCode, Hermes Agent, oh-my-openagent (OMO Ultimate), oh-my-hermes (OMH), OmniRoute and Termly.

The project layer installs: OpenCode/OMO model profiles, `oc.sh` and `oc_termly.sh`, the Hermes supervisor bridge, evidence/workflow directories, project rules, and a local OpenViking server.

## Principles

- Idempotent: rerunning converges to the same managed state.
- Atomic managed writes: temporary file + rename.
- Self-healing: validation failures trigger one repair pass.
- Evidence-driven: implementations end GO / RETRY / BLOCKED.
- No hidden credentials in Git.
- No direct OpenCode launch from the supervisor execution path.
- `ogptlw` is the default; an explicit user request such as “use odslw” applies only to that workflow.
- Commit/push happen only when explicitly authorized in the user's task.

## Install

From the destination project:

```bash
/path/to/ai_agent_infrastructure/install.sh
```

Useful options:

```text
--project PATH
--yes
--non-interactive
--repair
--verify-only
--default-mode MODE
--openviking-port PORT
--skip-termly
```

Interactive prompts are limited to credentials/consent that cannot safely be inferred. NVIDIA and OmniRoute keys are read silently and stored in project/user files with mode 600.

## OpenViking

OpenViking is installed under `.ai/openviking`:

- `config/ov.conf`
- `venv/`
- `workspace/`
- `start.sh`, `stop.sh`, `health.sh`, `doctor.sh`
- `ensure-running.sh`
- `context.sh`, `index.sh`, `ov`

Hermes project instructions require `.ai/openviking/ensure-running.sh` before project work. If the service is down it is started automatically. If the installation/configuration is absent Hermes reports the exact blocker and asks to rerun `./install.sh --repair`.

Defaults follow the NVIDIA Build flow:
- server: `127.0.0.1:1933`
- embeddings: `nvidia/nv-embed-v1`, dimension 4096
- VLM: `nvidia/nemotron-nano-12b-v2-vl`
- API base: `https://integrate.api.nvidia.com/v1`

## Launch OpenCode

```bash
./oc.sh                 # ogptlw TUI
./oc.sh odslw           # odslw TUI
./oc.sh run --dir "$PWD" 'prompt'          # default ogptlw
./oc.sh odslw run --dir "$PWD" 'prompt'    # explicit profile
./oc_termly.sh odslw    # same profile/config logic, opened by Termly
```

`oc.sh` and `oc_termly.sh` are installed from exactly the same source bytes. Behavior changes only by executable basename.

## Hermes

The installer creates/repairs a sticky `supervisor` profile with `terminal.cwd="."`. Read-only questions remain conversational. Implementation requests are routed through the supervisor workflow.

Normal use:

```bash
cd /path/to/project
hermes
```

Example:

```text
Implement the attached plan using odslw. Do not commit.
```

## Verify / repair

```bash
./verify-ai-infrastructure.sh
/path/to/ai_agent_infrastructure/install.sh --repair
```

## Security

Do not commit:
- `.ai/openviking/config/ov.conf`
- OmniRoute API key file
- OpenCode databases/sessions/caches
- server logs/workspaces/venvs

The installer scans its own distributable source for likely secret material before reporting success.

## Distribution integrity

The public `install.sh` reconstructs the payload from `payload.parts/partNN`, verifies the resulting `payload.tar.gz` SHA-256, and only then extracts/executes it.

Payload SHA-256: `629547aee16d83688fe80d774c955945ed63918754d4c71feb6774e7adda2884`

The payload contains the auditable source scripts, profiles, tests and templates used by the installer.
