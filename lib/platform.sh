#!/usr/bin/env bash
set -Eeuo pipefail

platform_detect(){
  OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
  ARCH="$(uname -m)"
  IS_WSL=0
  grep -qi microsoft /proc/version 2>/dev/null && IS_WSL=1 || true
  PKG=""
  if [[ "$OS" == linux ]]; then
    command -v apt-get >/dev/null && PKG=apt
    command -v dnf >/dev/null && PKG=dnf
    command -v pacman >/dev/null && PKG=pacman
    command -v zypper >/dev/null && PKG=zypper
  elif [[ "$OS" == darwin ]]; then
    command -v brew >/dev/null && PKG=brew
  fi
  export OS ARCH IS_WSL PKG
}

sudo_cmd(){
  if [[ "$(id -u)" -eq 0 ]]; then "$@"; return; fi
  command -v sudo >/dev/null || return 127
  sudo "$@"
}

pkg_install(){
  local pkgs=("$@")
  case "${PKG:-}" in
    apt) sudo_cmd apt-get update -y && sudo_cmd apt-get install -y "${pkgs[@]}" ;;
    dnf) sudo_cmd dnf install -y "${pkgs[@]}" ;;
    pacman) sudo_cmd pacman -Sy --needed --noconfirm "${pkgs[@]}" ;;
    zypper) sudo_cmd zypper --non-interactive install "${pkgs[@]}" ;;
    brew) brew install "${pkgs[@]}" ;;
    *) return 127 ;;
  esac
}

ensure_core_tools(){
  local missing=()
  for c in curl git python3; do command -v "$c" >/dev/null || missing+=("$c"); done
  if ((${#missing[@]})); then
    case "${PKG:-}" in
      apt) pkg_install curl git python3 python3-venv python3-pip build-essential ;;
      dnf) pkg_install curl git python3 python3-pip gcc gcc-c++ make ;;
      pacman) pkg_install curl git python python-pip base-devel ;;
      zypper) pkg_install curl git python3 python3-pip gcc gcc-c++ make ;;
      brew) pkg_install curl git python ;;
      *) return 1 ;;
    esac
  fi
  python3 - <<'PY'
import sys
assert sys.version_info >= (3,10), f"Python >=3.10 required, got {sys.version}"
PY
}

ensure_node_npm(){
  if command -v node >/dev/null && command -v npm >/dev/null; then
    node -e 'process.exit(Number(process.versions.node.split(".")[0])>=18?0:1)' && return 0 || true
  fi
  case "${PKG:-}" in
    apt) pkg_install nodejs npm ;;
    dnf) pkg_install nodejs npm ;;
    pacman) pkg_install nodejs npm ;;
    zypper) pkg_install nodejs npm ;;
    brew) pkg_install node ;;
    *) return 1 ;;
  esac
  command -v node >/dev/null && command -v npm >/dev/null
}

ensure_bun(){
  command -v bun >/dev/null && command -v bunx >/dev/null && return 0
  curl -fsSL https://bun.sh/install | bash
  export PATH="$HOME/.bun/bin:$PATH"
  command -v bun >/dev/null && command -v bunx >/dev/null
}
