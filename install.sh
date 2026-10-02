#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
export INSTALLER_ROOT="$SCRIPT_DIR"
source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/platform.sh"
source "$SCRIPT_DIR/lib/components.sh"
source "$SCRIPT_DIR/lib/configure.sh"
source "$SCRIPT_DIR/lib/openviking.sh"

PROJECT_ARG="$PWD"; RUN_DEEP=1; AIINFRA_ASSUME_YES=0; OPENVIKING_PORT="${OPENVIKING_PORT:-1933}"
while (($#)); do
  case "$1" in
    --project) PROJECT_ARG="$2"; shift 2;;
    --yes|-y) AIINFRA_ASSUME_YES=1; shift;;
    --non-interactive) AIINFRA_ASSUME_YES=1; export AIINFRA_NONINTERACTIVE=1; shift;;
    --openviking-port) OPENVIKING_PORT="$2"; shift 2;;
    --default-profile) AIINFRA_DEFAULT_PROFILE="$2"; shift 2;;
    --skip-live-smoke) RUN_DEEP=0; shift;;
    --help|-h) cat <<HELP
Usage: install.sh [--project PATH] [--yes] [--non-interactive] [--openviking-port 1933] [--default-profile ogptlw] [--skip-live-smoke]
Default project is current directory. Secrets can be supplied via NVIDIA_API_KEY / OMNIROUTE_API_KEY.
HELP
      exit 0;;
    *) die "Unknown option: $1" 64;;
  esac
done
is_supported_profile "$AIINFRA_DEFAULT_PROFILE" || die "Unsupported profile: $AIINFRA_DEFAULT_PROFILE"
export AIINFRA_ASSUME_YES OPENVIKING_PORT AIINFRA_DEFAULT_PROFILE
PROJECT_ROOT="$(cd "$PROJECT_ARG" && pwd -P)"; export PROJECT_ROOT
STATE="$PROJECT_ROOT/.ai-agent-infrastructure"; mkdir -p "$STATE"; LOG="$STATE/install.log"; exec > >(tee -a "$LOG") 2>&1

# Lock is process-local and self-cleans on exit.
LOCKDIR="$STATE/.install.lock"
if ! mkdir "$LOCKDIR" 2>/dev/null; then
  if [[ -f "$LOCKDIR/pid" ]] && kill -0 "$(cat "$LOCKDIR/pid")" 2>/dev/null; then die "Another installer is active (pid $(cat "$LOCKDIR/pid"))"; fi
  rm -f "$LOCKDIR/pid" 2>/dev/null || true; rmdir "$LOCKDIR" 2>/dev/null || die "Stale installer lock could not be removed: $LOCKDIR"; mkdir "$LOCKDIR"
fi
printf '%s\n' $$ > "$LOCKDIR/pid"; trap 'rm -f "$LOCKDIR/pid" 2>/dev/null || true; rmdir "$LOCKDIR" 2>/dev/null || true' EXIT

log "AI Agent Infrastructure v$AIINFRA_VERSION"
log "Project: $PROJECT_ROOT"
platform_detect; log "Platform: OS=$OS ARCH=$ARCH WSL=$IS_WSL package-manager=${PKG:-none}"

phase(){ local name="$1"; shift; log "=== $name ==="; retry 3 2 "$@" || die "Phase failed after retries: $name"; }
phase core-tools ensure_core_tools
phase node-npm ensure_node_npm
phase bun ensure_bun
export PATH="$HOME/.local/bin:$HOME/.opencode/bin:$HOME/.bun/bin:$PATH"
phase opencode ensure_opencode
phase hermes ensure_hermes
phase termly ensure_termly
phase omniroute ensure_omniroute
phase omo ensure_omo
phase omh ensure_omh

phase project-files install_project_files
phase global-control-plane install_global_control_plane
phase opencode-config configure_opencode_global
phase omh-skills configure_omh_skills
phase hermes-supervisor configure_hermes_supervisor
phase project-agents configure_project_agents
phase shell-router configure_shell_router
phase openviking configure_openviking

# Static verification first. Self-correct once by rerunning managed configuration phases.
if ! "$SCRIPT_DIR/verify.sh" "$PROJECT_ROOT"; then
  warn "Static verification failed; running managed repair pass"
  install_project_files; install_global_control_plane; configure_opencode_global; configure_hermes_supervisor; configure_project_agents; configure_openviking
  "$SCRIPT_DIR/verify.sh" "$PROJECT_ROOT" || die "Verification still failing after repair pass"
fi

if [[ "$RUN_DEEP" == 1 ]]; then
  if ! AIINFRA_DEFAULT_PROFILE="$AIINFRA_DEFAULT_PROFILE" AIINFRA_DEEP_VERIFY=1 "$SCRIPT_DIR/verify.sh" "$PROJECT_ROOT" --deep; then
    warn "Live smoke failed. Most common cause: provider authentication/model not configured."
    if [[ -t 0 ]]; then
      echo "OmniRoute dashboard: http://127.0.0.1:20128"
      echo "Hermes setup/model auth can be repaired with: hermes -p supervisor setup  /  hermes -p supervisor model"
      if confirm "Complete any required provider/OAuth setup now, then retry live smoke?" y; then
        read -r -p "Press Enter after provider setup is complete..." _
        AIINFRA_DEFAULT_PROFILE="$AIINFRA_DEFAULT_PROFILE" AIINFRA_DEEP_VERIFY=1 "$SCRIPT_DIR/verify.sh" "$PROJECT_ROOT" --deep || die "Live smoke still failing; inspect $LOG and provider configuration"
      else
        die "Live smoke is required for a complete installation. Rerun after provider setup."
      fi
    else
      die "Live smoke failed in non-interactive mode. Configure providers/auth and rerun."
    fi
  fi
fi

write_project_marker
log "Installation complete and verified."
log "Project Hermes sessions will ensure OpenViking before launch after opening a new shell (or: source ~/.bashrc / ~/.zshrc)."
log "Default OpenCode profile: $AIINFRA_DEFAULT_PROFILE"
log "Direct OpenCode: bash ./oc.sh [profile]"
log "Termly OpenCode: bash ./oc_termly.sh [profile]"
log "Repair/re-run safely: $SCRIPT_DIR/install.sh --project '$PROJECT_ROOT'"
