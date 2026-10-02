#!/usr/bin/env bash
set -Eeuo pipefail

openviking_paths(){
  OV_BASE="$PROJECT_ROOT/.openviking"
  OV_VENV="$OV_BASE/venv"
  OV_CONFIG="$OV_BASE/config/ov.conf"
  OV_WORKSPACE="$OV_BASE/workspace"
  OV_HOST="${OPENVIKING_HOST:-127.0.0.1}"
  OV_PORT="${OPENVIKING_PORT:-1933}"
  export OV_BASE OV_VENV OV_CONFIG OV_WORKSPACE OV_HOST OV_PORT
}

write_openviking_runtime(){
  mkdir -p "$OV_BASE/config" "$OV_WORKSPACE" "$OV_BASE/scripts" "$PROJECT_ROOT/.ai-agent-infrastructure/bin"

  cat > "$PROJECT_ROOT/.ai-agent-infrastructure/bin/ensure-openviking" <<'EOS'
#!/usr/bin/env bash
set -Eeuo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
PROJECT_ROOT="$(cd "$HERE/../.." && pwd -P)"
OV="$PROJECT_ROOT/.openviking"
[[ -f "$OV/config/ov.conf" ]] || { echo "OpenViking config missing: $OV/config/ov.conf" >&2; exit 1; }
read_cfg(){ python3 - "$OV/config/ov.conf" "$1" <<'PY'
import json,sys
x=json.load(open(sys.argv[1])); v=x
for p in sys.argv[2].split('.'): v=v[p]
print(v)
PY
}
HOST="$(read_cfg server.host)"; PORT="$(read_cfg server.port)"
healthy(){ curl -fsS --max-time 3 "http://$HOST:$PORT/health" | python3 -c 'import json,sys; d=json.load(sys.stdin); raise SystemExit(0 if d.get("healthy") is True else 1)' >/dev/null 2>&1; }
if healthy; then exit 0; fi
echo "OpenViking not healthy; attempting automatic start..." >&2
"$OV/start_openviking.sh" >&2
healthy || { echo "OpenViking could not be started. Check $OV/server.log" >&2; exit 1; }
EOS
  chmod 0755 "$PROJECT_ROOT/.ai-agent-infrastructure/bin/ensure-openviking"

  cat > "$OV_BASE/start_openviking.sh" <<'EOS'
#!/usr/bin/env bash
set -Eeuo pipefail
BASE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"; CFG="$BASE/config/ov.conf"; VENV="$BASE/venv"; PIDF="$BASE/workspace/.openviking.pid"; LOG="$BASE/server.log"
[[ -x "$VENV/bin/openviking-server" ]] || { echo "OpenViking server missing; rerun infrastructure installer" >&2; exit 1; }
read_cfg(){ "$VENV/bin/python" - "$CFG" "$1" <<'PY'
import json,sys
x=json.load(open(sys.argv[1])); v=x
for p in sys.argv[2].split('.'): v=v[p]
print(v)
PY
}
HOST="$(read_cfg server.host)"; PORT="$(read_cfg server.port)"
health(){ curl -fsS --max-time 2 "http://$HOST:$PORT/health" | "$VENV/bin/python" -c 'import json,sys; d=json.load(sys.stdin); raise SystemExit(0 if d.get("healthy") is True else 1)' >/dev/null 2>&1; }
if health; then echo "OpenViking already healthy at http://$HOST:$PORT"; exit 0; fi
if [[ -f "$PIDF" ]]; then p="$(cat "$PIDF" 2>/dev/null || true)"; [[ -n "$p" && -d "/proc/$p" ]] || rm -f "$PIDF"; fi
export OPENVIKING_CONFIG_FILE="$CFG"
nohup "$VENV/bin/openviking-server" --config "$CFG" >"$LOG" 2>&1 & echo $! > "$PIDF"
for _ in $(seq 1 "${HEALTH_TIMEOUT:-45}"); do health && { echo "OpenViking healthy at http://$HOST:$PORT"; exit 0; }; sleep 1; done
echo "OpenViking failed health check; tail:" >&2; tail -80 "$LOG" >&2 || true; exit 1
EOS

  cat > "$OV_BASE/stop_openviking.sh" <<'EOS'
#!/usr/bin/env bash
set -Eeuo pipefail
BASE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"; PIDF="$BASE/workspace/.openviking.pid"
[[ -f "$PIDF" ]] || { echo "OpenViking not running (no pid file)"; exit 0; }
pid="$(cat "$PIDF")"; if ! kill -0 "$pid" 2>/dev/null; then rm -f "$PIDF"; echo "Removed stale pid file"; exit 0; fi
kill "$pid" || true
for _ in $(seq 1 10); do kill -0 "$pid" 2>/dev/null || { rm -f "$PIDF"; echo "OpenViking stopped"; exit 0; }; sleep 1; done
kill -9 "$pid" 2>/dev/null || true; rm -f "$PIDF"; echo "OpenViking force-stopped"
EOS

  cat > "$OV_BASE/scripts/ov-health.sh" <<'EOS'
#!/usr/bin/env bash
set -Eeuo pipefail
BASE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"; CFG="$BASE/config/ov.conf"; PY="$BASE/venv/bin/python"
read_cfg(){ "$PY" - "$CFG" "$1" <<'PY'
import json,sys
x=json.load(open(sys.argv[1])); v=x
for p in sys.argv[2].split('.'): v=v[p]
print(v)
PY
}
H="$(read_cfg server.host)"; P="$(read_cfg server.port)"; health="$(curl -fsS --max-time 3 "http://$H:$P/health")"; ready="$(curl -fsS --max-time 3 "http://$H:$P/ready" 2>/dev/null || echo '{}')"
if [[ "${1:-}" == --json ]]; then printf '{"health":%s,"ready":%s}\n' "$health" "$ready"; else echo "health=$health"; echo "ready=$ready"; fi
"$PY" - "$health" <<'PY'
import json,sys
d=json.loads(sys.argv[1]); raise SystemExit(0 if d.get('healthy') is True else 1)
PY
EOS

  cat > "$OV_BASE/scripts/ov-doctor.sh" <<'EOS'
#!/usr/bin/env bash
set -Eeuo pipefail
BASE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"; export OPENVIKING_CONFIG_FILE="$BASE/config/ov.conf"; exec "$BASE/venv/bin/openviking-server" doctor "$@"
EOS

  cat > "$OV_BASE/ov" <<'EOS'
#!/usr/bin/env bash
set -Eeuo pipefail
BASE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"; CFG="$BASE/config/ov.conf"; PY="$BASE/venv/bin/python"; CLI="$BASE/venv/bin/openviking"
mkdir -p "$HOME/.openviking"
"$PY" - "$CFG" "$HOME/.openviking/ovcli.conf" <<'PY'
import json,sys,pathlib
cfg=json.load(open(sys.argv[1])); s=cfg['server']; out={'server':{'url':f"http://{s['host']}:{s['port']}",'api_key':s.get('root_api_key','')}}
p=pathlib.Path(sys.argv[2]); p.write_text(json.dumps(out,indent=2)+'\n'); p.chmod(0o600)
PY
exec "$CLI" "$@"
EOS

  cat > "$OV_BASE/scripts/ov-context.sh" <<'EOS'
#!/usr/bin/env bash
set -Eeuo pipefail
BASE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"; PROJECT_ROOT="$(cd "$BASE/.." && pwd -P)"; NAME="${PROJECT_NAME:-$(basename "$PROJECT_ROOT")}"; Q="${1:-project context}"; LIMIT="${LIMIT:-10}"
"$PROJECT_ROOT/.ai-agent-infrastructure/bin/ensure-openviking" >/dev/null
exec "$BASE/ov" -o json search "$Q" --uri "viking://resources/$NAME" --node-limit "$LIMIT" --account "${OV_ACCOUNT:-default}" --user "${OV_USER:-agent}"
EOS

  cat > "$OV_BASE/scripts/ov-index.sh" <<'EOS'
#!/usr/bin/env bash
set -Eeuo pipefail
BASE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"; PROJECT_ROOT="$(cd "$BASE/.." && pwd -P)"; NAME="${PROJECT_NAME:-$(basename "$PROJECT_ROOT")}"; "$PROJECT_ROOT/.ai-agent-infrastructure/bin/ensure-openviking" >/dev/null
# OpenViking CLI syntax can evolve; add resources only when supported by installed CLI.
if [[ -f "$PROJECT_ROOT/README.md" ]]; then "$BASE/ov" add-resource "$PROJECT_ROOT/README.md" --uri "viking://resources/$NAME/README.md" 2>/dev/null || true; fi
if [[ -d "$PROJECT_ROOT/docs" ]]; then "$BASE/ov" add-resource "$PROJECT_ROOT/docs" --uri "viking://resources/$NAME/docs" 2>/dev/null || true; fi
EOS

  chmod 0755 "$OV_BASE/start_openviking.sh" "$OV_BASE/stop_openviking.sh" "$OV_BASE/ov" "$OV_BASE/scripts/"*.sh
}

ensure_openviking_venv(){
  if [[ ! -x "$OV_VENV/bin/python" ]]; then
    python3 -m venv "$OV_VENV" || { [[ "${PKG:-}" == apt ]] && pkg_install python3-venv; python3 -m venv "$OV_VENV"; }
  fi
  "$OV_VENV/bin/python" -m pip install --upgrade pip setuptools wheel
  if [[ ! -x "$OV_VENV/bin/openviking-server" ]]; then "$OV_VENV/bin/pip" install 'openviking[bot]'; else "$OV_VENV/bin/pip" install --upgrade 'openviking[bot]'; fi
  [[ -x "$OV_VENV/bin/openviking-server" && -x "$OV_VENV/bin/openviking" ]]
}

write_openviking_config(){
  if [[ -f "$OV_CONFIG" ]]; then
    chmod 600 "$OV_CONFIG" || true
    json_validate "$OV_CONFIG" && return 0
    backup_file "$OV_CONFIG"
  fi
  require_tty_secret NVIDIA_API_KEY "NVIDIA Build API key (hidden): "
  local root_key="${OPENVIKING_ROOT_API_KEY:-}"
  [[ -n "$root_key" ]] || root_key="ovk_$(python3 - <<'PY'
import secrets; print(secrets.token_urlsafe(32))
PY
)"
  export NVIDIA_API_KEY root_key
  python3 - "$OV_CONFIG" <<PY
import json,os,pathlib
p=pathlib.Path(r'''$OV_CONFIG''')
d={
 'server':{'host':r'''$OV_HOST''','port':int(r'''$OV_PORT'''),'root_api_key':r'''$root_key'''},
 'storage':{'workspace':r'''$OV_WORKSPACE''','agfs':{'backend':'local'},'vectordb':{'backend':'local'}},
 'embedding':{'max_concurrent':4,'max_retries':3,'dense':{'provider':'openai','api_base':'https://integrate.api.nvidia.com/v1','api_key':os.environ['NVIDIA_API_KEY'],'model':os.environ.get('OPENVIKING_EMBED_MODEL','nvidia/nv-embed-v1'),'dimension':int(os.environ.get('OPENVIKING_EMBED_DIM','4096'))}},
 'vlm':{'provider':'openai','api_base':'https://integrate.api.nvidia.com/v1','api_key':os.environ['NVIDIA_API_KEY'],'model':os.environ.get('OPENVIKING_VLM_MODEL','nvidia/nemotron-nano-12b-v2-vl'),'max_retries':3}
}
p.parent.mkdir(parents=True,exist_ok=True); p.write_text(json.dumps(d,indent=2)+'\n'); p.chmod(0o600)
PY
  unset NVIDIA_API_KEY root_key
}

configure_openviking(){
  openviking_paths
  mkdir -p "$OV_BASE" "$OV_WORKSPACE"
  ensure_openviking_venv
  write_openviking_config
  write_openviking_runtime
  export OPENVIKING_CONFIG_FILE="$OV_CONFIG"
  if ! "$OV_BASE/scripts/ov-doctor.sh"; then
    warn "OpenViking doctor failed. Configuration/API/model availability may need repair."
    if [[ -t 0 ]] && confirm "Re-enter NVIDIA Build API key and regenerate OpenViking config?" n; then
      rm -f "$OV_CONFIG"
      write_openviking_config
      "$OV_BASE/scripts/ov-doctor.sh"
    else
      return 1
    fi
  fi
  "$OV_BASE/start_openviking.sh"
  "$OV_BASE/scripts/ov-health.sh"
  "$OV_BASE/scripts/ov-index.sh" || true
}
