#!/usr/bin/env bash
set -Eeuo pipefail

DEFAULT_MODE="ogptlw"
PATH_CONFIG="${OC_PATH_CONFIG:-./.opencode}"
REQUESTED_FIRST_ARG="${1:-}"
case "$REQUESTED_FIRST_ARG" in
  nogpt|gpt|gptlw|ogptlw|nv|dsfv4|dslw|odslw|ofree|onv|lw) MODO="$REQUESTED_FIRST_ARG"; shift ;;
  "") MODO="$DEFAULT_MODE" ;;
  *) MODO="$DEFAULT_MODE" ;;
esac
OPENCODE_ARGS=("$@")

DESTINO_OPENAGENT_DOT="$PATH_CONFIG/oh-my-openagent.json"
DESTINO_OPENCODE_DOT="$PATH_CONFIG/oh-my-opencode.json"
DESTINO_ROOT="./oh-my-opencode.json"
DEFAULT_ORIGEN="$PATH_CONFIG/oh-my-opencode-default.json"

case "$MODO" in
  nogpt) ORIGEN="$PATH_CONFIG/oh-my-opencode-nogpt.json" ;;
  gpt) ORIGEN="$PATH_CONFIG/oh-my-opencode-gpt.json" ;;
  gptlw) ORIGEN="$PATH_CONFIG/oh-my-opencode-gpt-lowcost.json" ;;
  ogptlw) ORIGEN="$PATH_CONFIG/oh-my-opencode-ogptlw.json" ;;
  nv) ORIGEN="$PATH_CONFIG/oh-my-opencode-nv.json" ;;
  dsfv4) ORIGEN="$PATH_CONFIG/oh-my-opencode-ocdsfv4.json" ;;
  dslw) ORIGEN="$PATH_CONFIG/oh-my-opencode-dslw.json" ;;
  odslw) ORIGEN="$PATH_CONFIG/oh-my-opencode-odslw.json" ;;
  ofree) ORIGEN="$PATH_CONFIG/oh-my-opencode-ofree.json" ;;
  onv) ORIGEN="$PATH_CONFIG/oh-my-opencode-onv.json" ;;
  lw) ORIGEN="$PATH_CONFIG/oh-my-opencode-lowcost.json" ;;
  *) MODO="$DEFAULT_MODE"; ORIGEN="$PATH_CONFIG/oh-my-opencode-ogptlw.json" ;;
esac

[[ -f "$ORIGEN" ]] || { echo "❌ Missing profile: $ORIGEN" >&2; exit 1; }
command -v opencode >/dev/null || { echo "❌ opencode not in PATH" >&2; exit 1; }
command -v python3 >/dev/null || { echo "❌ python3 not in PATH" >&2; exit 1; }

for f in "$ORIGEN" "$DEFAULT_ORIGEN"; do python3 -m json.tool "$f" >/dev/null || { echo "❌ Invalid JSON: $f" >&2; exit 1; }; done

cp "$ORIGEN" "$DESTINO_OPENAGENT_DOT"
cp "$ORIGEN" "$DESTINO_OPENCODE_DOT"
cp "$ORIGEN" "$DESTINO_ROOT"

MODELO_LANZAMIENTO="$(python3 - "$DESTINO_OPENCODE_DOT" <<'PY'
import json,sys
c=json.load(open(sys.argv[1],encoding='utf-8'))
m=c.get('model') or c.get('agents',{}).get('sisyphus',{}).get('model')
if not m: raise SystemExit('No primary model found in active profile')
print(m)
PY
)"

echo "------------------------------------------------"
echo "🔍 VERIFICACIÓN DE SESIÓN:"
echo "🧩 Modo solicitado: $MODO"
echo "📂 Archivo fuente: $ORIGEN"
echo "🤖 Modelo para sesión OpenCode: $MODELO_LANZAMIENTO"
if ((${#OPENCODE_ARGS[@]})); then printf '🔧 <%s>\n' "${OPENCODE_ARGS[@]}"; else echo "🔧 Argumentos OpenCode: ninguno (TUI)"; fi
echo "------------------------------------------------"

cleanup(){
  if [[ -f "$DEFAULT_ORIGEN" ]]; then
    cp "$DEFAULT_ORIGEN" "$DESTINO_OPENAGENT_DOT" || true
    cp "$DEFAULT_ORIGEN" "$DESTINO_OPENCODE_DOT" || true
    cp "$DEFAULT_ORIGEN" "$DESTINO_ROOT" || true
    echo; echo "✅ Sesión cerrada. Perfil original restaurado."
  fi
}
trap cleanup EXIT INT TERM

if [[ "${OC_LAUNCH_BACKEND:-direct}" == termly ]]; then
  command -v termly >/dev/null || { echo "❌ termly not in PATH" >&2; exit 1; }
  if [[ "${OPENCODE_ARGS[0]:-}" == run ]]; then
    AI_ARGS=(run --model "$MODELO_LANZAMIENTO" "${OPENCODE_ARGS[@]:1}")
  else
    AI_ARGS=(--model "$MODELO_LANZAMIENTO" "${OPENCODE_ARGS[@]}")
  fi
  printf -v TERM_ARGS '%q ' "${AI_ARGS[@]}"
  echo "🚀 Iniciando OpenCode con Termly..."
  echo "🧩 Perfil efectivo: $MODO"
  termly start --ai opencode --ai-args "$TERM_ARGS"
else
  echo "🚀 Iniciando OpenCode..."
  echo "🧩 Perfil efectivo: $MODO"
  if [[ "${OPENCODE_ARGS[0]:-}" == run ]]; then
    echo "⚙️ Modo OpenCode: RUN no interactivo"
    opencode run --model "$MODELO_LANZAMIENTO" "${OPENCODE_ARGS[@]:1}"
  else
    echo "🖥️ Modo OpenCode: TUI"
    opencode --model "$MODELO_LANZAMIENTO" "${OPENCODE_ARGS[@]}"
  fi
fi
