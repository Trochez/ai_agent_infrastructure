# AI Agent Infrastructure

Portable, repairable project bootstrap for the architecture:

`Hermes → ai-supervisor-submit → ai-supervisor-run → ai-opencode-exec → oc.sh <profile> → OpenCode + OMO → evidence → GO/RETRY/BLOCKED`

It also installs a project-local OpenViking knowledge layer and makes Hermes ensure it is available before project work.

## Quick start

```bash
git clone git@github.com:Trochez/ai_agent_infrastructure.git /tmp/ai_agent_infrastructure
cd /path/to/your/project
/tmp/ai_agent_infrastructure/install.sh
```

One-line interactive bootstrap from the destination project:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Trochez/ai_agent_infrastructure/main/install.sh)
```

Or non-interactive when secrets are already exported:

```bash
export OMNIROUTE_API_KEY='...'
export NVIDIA_API_KEY='...'
/path/to/ai_agent_infrastructure/install.sh --yes
```

The installer is safe to rerun. It detects healthy components, repairs managed drift, backs up managed files before replacement, never copies session databases, and verifies the complete installation.

See [GUIDE.md](GUIDE.md).
