#!/usr/bin/env bash
set -Eeuo pipefail

install_project_files(){
  log "Installing project-local launchers/profiles"
  mkdir -p "$PROJECT_ROOT/.opencode" "$PROJECT_ROOT/.ai-agent-infrastructure/bin"
  cp "$INSTALLER_ROOT/opencode/profiles/"*.json "$PROJECT_ROOT/.opencode/"
  cp "$INSTALLER_ROOT/opencode/oc_launcher_core.sh" "$PROJECT_ROOT/oc_launcher_core.sh"
  cp "$INSTALLER_ROOT/opencode/oc.sh" "$PROJECT_ROOT/oc.sh"
  cp "$INSTALLER_ROOT/opencode/oc_termly.sh" "$PROJECT_ROOT/oc_termly.sh"
  chmod 0755 "$PROJECT_ROOT/oc.sh" "$PROJECT_ROOT/oc_termly.sh" "$PROJECT_ROOT/oc_launcher_core.sh"
  # Active files start from default and are restored to default after every launcher session.
  cp "$PROJECT_ROOT/.opencode/oh-my-opencode-default.json" "$PROJECT_ROOT/.opencode/oh-my-openagent.json"
  cp "$PROJECT_ROOT/.opencode/oh-my-opencode-default.json" "$PROJECT_ROOT/.opencode/oh-my-opencode.json"
  cp "$PROJECT_ROOT/.opencode/oh-my-opencode-default.json" "$PROJECT_ROOT/oh-my-opencode.json"
  for f in "$PROJECT_ROOT/.opencode/"*.json; do json_validate "$f"; done
}

install_global_control_plane(){
  mkdir -p "$HOME/.local/bin" "$HOME/.config/ai-agent-infrastructure"
  for f in ai-opencode-exec ai-supervisor-run ai-supervisor-submit hermes-project-router; do
    cp "$INSTALLER_ROOT/bin/$f" "$HOME/.local/bin/$f"
    chmod 0755 "$HOME/.local/bin/$f"
  done
  local real
  real="$(type -P hermes || true)"
  [[ -n "$real" ]] || return 1
  # Refuse accidental self-reference if an old shell wrapper happens to be active.
  [[ "$real" != "$HOME/.local/bin/hermes-project-router" ]] || return 1
  printf '%s\n' "$real" > "$HOME/.config/ai-agent-infrastructure/hermes-real"
  chmod 0600 "$HOME/.config/ai-agent-infrastructure/hermes-real"
}

configure_shell_router(){
  local block
  block="$(mktemp)"
  cat > "$block" <<'EOS'
hermes() {
  "$HOME/.local/bin/hermes-project-router" "$@"
}
EOS
  [[ -f "$HOME/.bashrc" || "${SHELL:-}" == *bash* ]] && managed_block "$HOME/.bashrc" hermes-router "$block"
  [[ -f "$HOME/.zshrc" || "${SHELL:-}" == *zsh* ]] && managed_block "$HOME/.zshrc" hermes-router "$block"
  rm -f "$block"
}

configure_opencode_global(){
  local cfg="$HOME/.config/opencode/opencode.json"
  mkdir -p "$(dirname "$cfg")"
  [[ -f "$cfg" ]] || printf '{"$schema":"https://opencode.ai/config.json"}\n' > "$cfg"
  backup_file "$cfg"
  OMNIROUTE_API_KEY="${OMNIROUTE_API_KEY:-sk_omniroute}" python3 - "$cfg" <<'PY'
import json,os,sys,pathlib
p=pathlib.Path(sys.argv[1])
try: d=json.loads(p.read_text())
except Exception: d={"$schema":"https://opencode.ai/config.json"}
plugins=d.get('plugin',[])
if isinstance(plugins,str): plugins=[plugins]
plugins=[x for x in plugins if x not in ('oh-my-opencode','oh-my-openagent')]+['oh-my-openagent']
d['plugin']=plugins
providers=d.setdefault('provider',{})
om=providers.setdefault('omniroute',{})
om.update({'npm':'@ai-sdk/openai-compatible','name':'OmniRoute'})
om['options']={'baseURL':'http://127.0.0.1:20128/v1','apiKey':os.environ.get('OMNIROUTE_API_KEY','sk_omniroute')}
models=om.setdefault('models',{})
for m in ['auto','codex/gpt-5.6-luna','ds/deepseek-v4-flash','auto/pro-coding','auto/pro-reasoning','auto/best-chat','auto/best-fast','auto/best-vision','auto/best-coding','auto/best-reasoning']:
    models.setdefault(m,{'name':m})
tmp=p.with_suffix('.tmp'); tmp.write_text(json.dumps(d,indent=2)+'\n'); tmp.replace(p)
PY
  json_validate "$cfg"
}

configure_omh_skills(){
  # Shared Agent Skills projection for OpenCode/other agents. Hermes-native OMH registration is handled by `omh setup`.
  omh install --target agents --scope user || warn "OMH Agent Skills projection failed; Hermes-native OMH remains available"
}

configure_hermes_supervisor(){
  local real; real="$(cat "$HOME/.config/ai-agent-infrastructure/hermes-real")"
  if ! "$real" profile list 2>/dev/null | grep -Eq '(^|[[:space:]*])supervisor([[:space:]]|$)'; then
    "$real" profile create supervisor --clone --description "Supervises project engineering; routes implementation through OpenCode/OMO with evidence-driven GO/RETRY/BLOCKED." || "$real" profile create supervisor --description "AI engineering supervisor"
  fi
  "$real" -p supervisor config set terminal.backend local
  "$real" -p supervisor config set terminal.cwd .
  # Best effort shared skill visibility. OMH setup already owns ~/.omh/skills.
  "$real" -p supervisor config set skills.external_dirs "[\"$HOME/.omh/skills\",\"$HOME/.agents/skills\"]" --force || true
  "$real" profile use supervisor

  local soul="$HOME/.hermes/profiles/supervisor/SOUL.md" block
  mkdir -p "$(dirname "$soul")"; touch "$soul"; block="$(mktemp)"
  cat > "$block" <<'EOS'
## Automatic Project Engineering Router

When a normal interactive request targets a project containing `.ai-agent-infrastructure/installed.json`:

1. Before any operational action, run `<project>/.ai-agent-infrastructure/bin/ensure-openviking`. If OpenViking is unavailable, state that clearly, attempt automatic start, and do not continue operational work until it is healthy.
2. For read-only explanation/research/review, answer normally. Query `<project>/.openviking/scripts/ov-context.sh "<task>"` when project memory could materially improve the answer.
3. For implementation/fix/refactor/configuration/deployment requests, do NOT modify repository files directly. Route complete user intent through `ai-supervisor-submit --repo <git-root-or-project-root>`.
4. Default OpenCode profile is `ogptlw`. If user explicitly names a supported profile (nogpt, gpt, gptlw, ogptlw, nv, dsfv4, dslw, odslw, ofree, onv, lw), pass it as `--opencode-mode <profile>` for that workflow only.
5. Routed execution invariant: Hermes → ai-supervisor-submit → ai-supervisor-run → ai-opencode-exec → `bash ./oc.sh <profile> run ...` → OpenCode+OMO → evidence → GO/RETRY/BLOCKED.
6. OpenCode must never be launched directly by the control plane. `oc.sh` is mandatory.
7. Generic "implement/fix/proceed" does not authorize commit or push. Commit/push only when explicitly requested. Never force-push. Never discard unrelated user work.
8. If prompt contains `INTERNAL_SUPERVISOR_INVOCATION=1` or env `AI_SUPERVISOR_INTERNAL=1`, you are already inside the supervisor loop: never invoke `ai-supervisor-submit`/`ai-supervisor-run` recursively; follow the internal workflow prompt.
EOS
  managed_block "$soul" project-engineering-router "$block"
  rm -f "$block"
}

write_project_marker(){
  mkdir -p "$PROJECT_ROOT/.ai-agent-infrastructure"
  export PROJECT_ROOT AIINFRA_VERSION AIINFRA_DEFAULT_PROFILE
  python3 - "$PROJECT_ROOT/.ai-agent-infrastructure/installed.json" <<'PY'
import json,os,platform,datetime,pathlib
p=pathlib.Path(__import__('sys').argv[1])
d={'schema':'ai-agent-infrastructure/v1','version':os.environ['AIINFRA_VERSION'],'project_root':os.environ['PROJECT_ROOT'],'default_opencode_mode':os.environ['AIINFRA_DEFAULT_PROFILE'],'installed_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'platform':platform.platform()}
t=p.with_suffix('.tmp'); t.write_text(json.dumps(d,indent=2)+'\n'); t.replace(p)
PY
}

configure_project_agents(){
  local agents="$PROJECT_ROOT/AGENTS.md" block
  block="$(mktemp)"
  cat > "$block" <<'EOS'
## AI infrastructure contract
- Project uses Hermes supervisor → OpenCode/OMO execution architecture.
- Before operational work, ensure OpenViking with `.ai-agent-infrastructure/bin/ensure-openviking`.
- Project memory/context: `.openviking/scripts/ov-context.sh "<task>"`.
- OpenCode sessions must be launched through `bash ./oc.sh <profile>`; default `ogptlw`.
- Preserve unrelated changes. No commit/push unless explicitly requested.
EOS
  managed_block "$agents" infrastructure "$block"
  rm -f "$block"
}
