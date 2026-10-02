#!/usr/bin/env bash
set -Eeuo pipefail

ensure_opencode(){
  if command -v opencode >/dev/null; then log "OpenCode: $(opencode --version 2>/dev/null || true)"; return 0; fi
  log "Installing OpenCode"
  curl -fsSL https://opencode.ai/install | bash
  export PATH="$HOME/.opencode/bin:$HOME/.local/bin:$PATH"
  command -v opencode >/dev/null || return 1
}

ensure_hermes(){
  if command -v hermes >/dev/null; then log "Hermes: $(hermes --version 2>/dev/null || true)"; return 0; fi
  log "Installing Hermes Agent"
  curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash
  export PATH="$HOME/.local/bin:$PATH"
  command -v hermes >/dev/null || return 1
}

ensure_omh(){
  if ! command -v omh >/dev/null; then
    log "Installing oh-my-hermes"
    curl -fsSL https://raw.githubusercontent.com/rlaope/oh-my-hermes/main/install.sh | sh
    export PATH="$HOME/.local/bin:$PATH"
  fi
  command -v omh >/dev/null || return 1
  log "OMH: $(omh --version 2>/dev/null || true)"
  # setup is intended to be repairable/idempotent. If it needs a confirmation, user answers once.
  omh setup || return 1
  omh doctor || return 1
}

ensure_omo(){
  # OMO Ultimate/OpenCode installer is itself idempotent. Use no-tui, do not alter provider auth.
  log "Ensuring oh-my-openagent / OMO for OpenCode"
  if command -v omo-agent-toolkit >/dev/null || [[ -d "$HOME/.cache/opencode/packages/oh-my-openagent@latest" ]] || grep -Rqs 'oh-my-openagent' "$HOME/.config/opencode" 2>/dev/null; then
    log "OMO appears installed; installer will still reconcile plugin registration"
  fi
  bunx oh-my-openagent install --no-tui --claude=no --openai=no --gemini=no --copilot=no --skip-auth || \
    bunx oh-my-openagent install --no-tui --claude=no --gemini=no --copilot=no || return 1
}

ensure_termly(){
  command -v termly >/dev/null && { log "Termly: $(termly --version 2>/dev/null || true)"; return 0; }
  log "Installing Termly"
  npm install -g @termly-dev/cli
  command -v termly >/dev/null
}

ensure_omniroute(){
  if ! command -v omniroute >/dev/null; then
    log "Installing OmniRoute"
    npm install -g omniroute
  fi
  command -v omniroute >/dev/null || return 1

  mkdir -p "$HOME/.local/share/ai-agent-infrastructure"
  if curl -fsS --max-time 2 http://127.0.0.1:20128/v1/models >/dev/null 2>&1 || curl -fsS --max-time 2 http://127.0.0.1:20128 >/dev/null 2>&1; then
    log "OmniRoute already reachable on :20128"
    return 0
  fi

  log "Starting OmniRoute"
  nohup omniroute >"$HOME/.local/share/ai-agent-infrastructure/omniroute.log" 2>&1 &
  printf '%s\n' "$!" > "$HOME/.local/share/ai-agent-infrastructure/omniroute.pid"
  for _ in $(seq 1 30); do
    if curl -fsS --max-time 2 http://127.0.0.1:20128 >/dev/null 2>&1 || curl -fsS --max-time 2 http://127.0.0.1:20128/v1/models >/dev/null 2>&1; then return 0; fi
    sleep 1
  done
  warn "OmniRoute process started but HTTP endpoint did not become ready. See ~/.local/share/ai-agent-infrastructure/omniroute.log"
  return 1
}
