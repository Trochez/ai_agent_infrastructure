# AI Agent Infrastructure

Portable, repairable project bootstrap for the architecture:

```text
Hermes (persistent supervisor / router)
  -> ai-supervisor-submit
  -> ai-supervisor-run
  -> ai-opencode-exec
  -> bash ./oc.sh <profile> run ...
  -> OpenCode + OMO
  -> evidence
  -> GO / RETRY / BLOCKED

Project memory:
Hermes / workers -> OpenViking (project-local, auto-started)

Optional mobile terminal:
./oc_termly.sh <profile> -> Termly -> OpenCode
```

## Goal

Run one installer from a project directory. It detects, installs, repairs and verifies the required stack instead of assuming a preconfigured machine.

Managed components:

- OpenCode
- oh-my-openagent / OMO (OpenCode execution harness)
- Hermes Agent
- oh-my-hermes / OMH
- OmniRoute (required by bundled `ogptlw` / `odslw` profiles)
- Termly CLI
- OpenViking project memory with NVIDIA Build
- `ai-supervisor-submit`, `ai-supervisor-run`, `ai-opencode-exec`
- automatic Hermes project router
- project-local OpenCode profiles and launchers

Supported installer hosts: Linux, WSL2 and macOS. On Windows use WSL2, matching OpenCode's recommended Windows path.

## Install into a project

Clone this installer once (it can live anywhere):

```bash
git clone git@github.com:Trochez/ai_agent_infrastructure.git ~/tools/ai_agent_infrastructure
```

Then from the project to configure:

```bash
cd /path/to/project
~/tools/ai_agent_infrastructure/install.sh
```

Or explicitly:

```bash
~/tools/ai_agent_infrastructure/install.sh --project /path/to/project
```

Recommended defaults are used automatically. The installer only pauses for information it cannot safely infer, such as NVIDIA Build credentials or external OAuth/provider setup.

### Fully non-interactive mode

Prepare required secrets/auth first:

```bash
export NVIDIA_API_KEY='...'
export OMNIROUTE_API_KEY='sk_omniroute'   # local OmniRoute default can use this placeholder
~/tools/ai_agent_infrastructure/install.sh --project "$PWD" --non-interactive
```

If Hermes or OmniRoute still require an OAuth/provider login, non-interactive mode intentionally fails rather than claiming a complete installation.

## What the installer does

1. Locks the project against concurrent installer runs.
2. Detects OS/package manager.
3. Installs/repairs core tools (`curl`, `git`, Python >=3.10, venv, Node/npm, Bun).
4. Installs/verifies OpenCode.
5. Installs/verifies Hermes.
6. Installs/verifies Termly.
7. Installs/starts OmniRoute on `127.0.0.1:20128`.
8. Installs/reconciles OMO with OpenCode.
9. Installs/setup/checks OMH and projects shared Agent Skills.
10. Installs project-local `.opencode` profiles from the validated configuration pack.
11. Installs `oc.sh` and `oc_termly.sh`; both share one launcher core. Only launch backend differs.
12. Configures OpenCode plugin + OmniRoute provider without replacing unrelated config.
13. Creates/repairs Hermes `supervisor` profile with `terminal.backend=local`, `terminal.cwd=.` and the automatic routing policy.
14. Installs global control-plane commands under `~/.local/bin`.
15. Installs a managed shell `hermes()` router. In configured projects, any new interactive Hermes session checks/starts OpenViking before Hermes launches.
16. Installs OpenViking project-locally under `.openviking/`, creates secure NVIDIA config, runs `doctor`, starts it, verifies `/health`, and indexes available project docs.
17. Runs static and live end-to-end smoke tests.
18. Writes `.ai-agent-infrastructure/installed.json` only after verification succeeds.

Rerunning the installer is the repair operation. Managed config is merged or rewritten atomically; existing files are backed up before mutable global configuration is changed. Package installs are naturally idempotent/upgradable and are reverified after each phase.

## Daily use

Start Hermes in any configured project:

```bash
cd /path/to/project
hermes
```

After a new shell is opened (or `source ~/.bashrc` / `source ~/.zshrc`), the managed Hermes router finds `.ai-agent-infrastructure/installed.json`, ensures OpenViking is healthy, then invokes the real Hermes binary.

Implementation requests are routed automatically. Read-only questions remain normal Hermes interactions.

### Default OpenCode profile

```text
ogptlw
```

Override for one workflow in natural language:

```text
Implement this using odslw.
```

Or directly:

```bash
bash ./oc.sh odslw
bash ./oc.sh odslw run --dir "$PWD" 'Reply exactly PASS'
```

### Termly

`oc_termly.sh` uses exactly the same profile activation, validation and restoration core as `oc.sh`; only the final launcher is Termly:

```bash
bash ./oc_termly.sh
bash ./oc_termly.sh odslw
```

Termly itself launches OpenCode via `termly start --ai opencode --ai-args ...`.

## OpenViking

Project-local layout:

```text
.openviking/
├── config/ov.conf
├── ov
├── scripts/
│   ├── ov-context.sh
│   ├── ov-doctor.sh
│   ├── ov-health.sh
│   └── ov-index.sh
├── start_openviking.sh
├── stop_openviking.sh
├── venv/
├── workspace/
└── server.log
```

The design follows `Trochez/openviking_everywhere/openviking_nvidia_build_agent_install_flow.md`: Python venv, `openviking[bot]`, NVIDIA OpenAI-compatible embedding/VLM config, local workspace, doctor, server health validation, secure config permissions and automatic context access.

Operations:

```bash
./.openviking/start_openviking.sh
./.openviking/stop_openviking.sh
./.openviking/scripts/ov-health.sh
./.openviking/scripts/ov-doctor.sh
./.openviking/scripts/ov-context.sh 'what changed in this project?'
./.openviking/scripts/ov-index.sh
```

## Verification

Static + service verification:

```bash
~/tools/ai_agent_infrastructure/verify.sh "$PWD"
```

Live Hermes + OpenCode smoke:

```bash
AIINFRA_DEEP_VERIFY=1 ~/tools/ai_agent_infrastructure/verify.sh "$PWD" --deep
```

Repository self-tests:

```bash
./tests/static.sh
./tests/launcher_mock.sh
```

## Recovery

The installer is designed to be rerun after interruption:

```bash
~/tools/ai_agent_infrastructure/install.sh --project "$PWD"
```

It does not use `git reset --hard`, `git clean`, or destructive project deletion. OpenViking data/workspace is retained. Existing config files are not silently discarded.

See `docs/ARCHITECTURE.md`, `docs/INSTALLATION.md` and `docs/TROUBLESHOOTING.md`.
