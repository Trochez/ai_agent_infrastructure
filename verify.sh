#!/usr/bin/env bash
set -Eeuo pipefail
ARG1="${1:-$PWD}"; ARG2="${2:-}"
if [[ "$ARG1" == --deep ]]; then ROOT="$PWD"; DEEP=1; else ROOT="$(cd "$ARG1" && pwd -P)"; DEEP="${AIINFRA_DEEP_VERIFY:-0}"; [[ "$ARG2" == --deep ]] && DEEP=1; fi
fail=0
ok(){ echo "PASS $*"; }
bad(){ echo "FAIL $*" >&2; fail=1; }
need(){ command -v "$1" >/dev/null 2>&1 && ok "command:$1" || bad "command:$1"; }
for c in git curl python3 opencode hermes omh bun bunx node npm termly omniroute; do need "$c"; done
for f in oc.sh oc_termly.sh oc_launcher_core.sh .opencode/oh-my-opencode-default.json .opencode/oh-my-opencode-ogptlw.json .openviking/config/ov.conf .openviking/start_openviking.sh .ai-agent-infrastructure/bin/ensure-openviking; do [[ -e "$ROOT/$f" ]] && ok "file:$f" || bad "file:$f"; done
for s in "$ROOT/oc.sh" "$ROOT/oc_termly.sh" "$ROOT/oc_launcher_core.sh" "$ROOT/.openviking/start_openviking.sh" "$ROOT/.ai-agent-infrastructure/bin/ensure-openviking" "$HOME/.local/bin/ai-opencode-exec" "$HOME/.local/bin/ai-supervisor-run" "$HOME/.local/bin/ai-supervisor-submit"; do [[ -f "$s" ]] && bash -n "$s" && ok "syntax:$s" || bad "syntax:$s"; done
for j in "$ROOT"/.opencode/*.json "$ROOT/.openviking/config/ov.conf"; do [[ -f "$j" ]] && python3 -m json.tool "$j" >/dev/null && ok "json:$j" || bad "json:$j"; done
if [[ -x "$ROOT/.ai-agent-infrastructure/bin/ensure-openviking" ]]; then "$ROOT/.ai-agent-infrastructure/bin/ensure-openviking" && ok openviking-health || bad openviking-health; fi
if curl -fsS --max-time 3 http://127.0.0.1:20128 >/dev/null 2>&1 || curl -fsS --max-time 3 http://127.0.0.1:20128/v1/models >/dev/null 2>&1; then ok omniroute-http; else bad omniroute-http; fi
if [[ "$DEEP" == 1 && "$fail" == 0 ]]; then
  OC_OUT="$(mktemp)"; H_OUT="$(mktemp)"; H_ERR="$(mktemp)"
  if (cd "$ROOT" && bash ./oc.sh "${AIINFRA_DEFAULT_PROFILE:-ogptlw}" run --dir "$ROOT" 'Reply with exactly AIINFRA_OPENCODE=PASS. Do not use tools.' >"$OC_OUT" 2>&1) && grep -q 'AIINFRA_OPENCODE=PASS' "$OC_OUT"; then ok opencode-live; else cat "$OC_OUT" >&2; bad opencode-live; fi
  if hermes -p supervisor --yolo chat --in "$ROOT" -q 'Reply with exactly AIINFRA_HERMES=PASS. Do not use tools.' >"$H_OUT" 2>"$H_ERR" && grep -q 'AIINFRA_HERMES=PASS' "$H_OUT"; then ok hermes-live; else cat "$H_OUT" >&2; cat "$H_ERR" >&2; bad hermes-live; fi
  rm -f "$OC_OUT" "$H_OUT" "$H_ERR"
fi
((fail==0)) || exit 1
ok ALL
