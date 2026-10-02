#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

AIINFRA_VERSION="1.0.0"
AIINFRA_STATE_DIR_NAME=".ai-agent-infrastructure"
AIINFRA_MARKER="${AIINFRA_STATE_DIR_NAME}/installed.json"
AIINFRA_DEFAULT_PROFILE="ogptlw"
AIINFRA_SUPPORTED_PROFILES="nogpt gpt gptlw ogptlw nv dsfv4 dslw odslw ofree onv lw"

log(){ printf '[ai-infra] %s\n' "$*"; }
warn(){ printf '[ai-infra][WARN] %s\n' "$*" >&2; }
die(){ printf '[ai-infra][ERROR] %s\n' "$*" >&2; exit "${2:-1}"; }
command_exists(){ command -v "$1" >/dev/null 2>&1; }
now_utc(){ date -u +%Y%m%dT%H%M%SZ; }

retry(){
  local attempts="$1" delay="$2"; shift 2
  local n=1 rc=0
  until "$@"; do
    rc=$?
    if (( n >= attempts )); then return "$rc"; fi
    warn "Attempt $n/$attempts failed (rc=$rc): $* ; retrying in ${delay}s"
    sleep "$delay"
    n=$((n+1))
  done
}

atomic_write(){
  local dest="$1" mode="${2:-0644}" tmp
  mkdir -p "$(dirname "$dest")"
  tmp="$(mktemp "$(dirname "$dest")/.tmp.$(basename "$dest").XXXXXX")"
  cat > "$tmp"
  chmod "$mode" "$tmp"
  mv -f "$tmp" "$dest"
}

backup_file(){
  local f="$1"
  [[ -e "$f" ]] || return 0
  local b="${f}.bak.$(now_utc)"
  cp -a "$f" "$b"
  log "Backup: $b"
}

ensure_line_once(){
  local file="$1" line="$2"
  touch "$file"
  grep -Fqx "$line" "$file" 2>/dev/null || printf '%s\n' "$line" >> "$file"
}

managed_block(){
  local file="$1" name="$2" content_file="$3"
  local begin="# >>> ai-agent-infrastructure:${name} >>>"
  local end="# <<< ai-agent-infrastructure:${name} <<<"
  mkdir -p "$(dirname "$file")"
  touch "$file"
  python3 - "$file" "$begin" "$end" "$content_file" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); begin=sys.argv[2]; end=sys.argv[3]; c=Path(sys.argv[4]).read_text().rstrip()+"\n"
s=p.read_text() if p.exists() else ""
block=begin+"\n"+c+end+"\n"
if begin in s and end in s:
    pre=s.split(begin,1)[0]
    post=s.split(end,1)[1]
    s=pre.rstrip()+"\n\n"+block+post.lstrip("\n")
else:
    s=s.rstrip()+("\n\n" if s.strip() else "")+block
p.write_text(s)
PY
}

json_validate(){ python3 -m json.tool "$1" >/dev/null; }

find_project_root(){
  local start="${1:-$PWD}" p
  p="$(cd "$start" && pwd -P)"
  if command_exists git && git -C "$p" rev-parse --show-toplevel >/dev/null 2>&1; then
    git -C "$p" rev-parse --show-toplevel
  else
    printf '%s\n' "$p"
  fi
}

is_supported_profile(){
  case " $AIINFRA_SUPPORTED_PROFILES " in *" $1 "*) return 0;; *) return 1;; esac
}

require_tty_secret(){
  local var_name="$1" prompt="$2"
  local current="${!var_name:-}"
  [[ -n "$current" ]] && return 0
  [[ -t 0 ]] || die "$var_name is required in non-interactive mode. Export it and rerun."
  local secret
  read -r -s -p "$prompt" secret
  echo
  [[ -n "$secret" ]] || die "$var_name cannot be empty"
  printf -v "$var_name" '%s' "$secret"
  export "$var_name"
}

confirm(){
  local prompt="$1" default="${2:-y}" ans
  if [[ "${AIINFRA_ASSUME_YES:-0}" == 1 ]]; then return 0; fi
  [[ -t 0 ]] || return 1
  if [[ "$default" == y ]]; then read -r -p "$prompt [Y/n] " ans; ans="${ans:-y}"; else read -r -p "$prompt [y/N] " ans; ans="${ans:-n}"; fi
  [[ "$ans" =~ ^[Yy]$ ]]
}
