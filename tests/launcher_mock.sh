#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
cp "$ROOT/opencode/oc_launcher_core.sh" "$ROOT/opencode/oc.sh" "$ROOT/opencode/oc_termly.sh" "$T/"
mkdir -p "$T/.opencode" "$T/bin"
cp "$ROOT/opencode/profiles/oh-my-opencode-default.json" "$T/.opencode/"
cp "$ROOT/opencode/profiles/oh-my-opencode-ogptlw.json" "$T/.opencode/"
cat > "$T/bin/opencode" <<'SH'
#!/usr/bin/env bash
printf 'MOCK_OPENCODE %s\n' "$*"
SH
cat > "$T/bin/termly" <<'SH'
#!/usr/bin/env bash
printf 'MOCK_TERMLY %s\n' "$*"
SH
chmod +x "$T/bin/"*
(
 cd "$T"
 PATH="$T/bin:$PATH" bash ./oc.sh ogptlw run --dir "$T" 'hello world' > "$T/direct.out"
 grep -q 'MOCK_OPENCODE run --model omniroute/codex/gpt-5.6-luna' "$T/direct.out"
 PATH="$T/bin:$PATH" bash ./oc_termly.sh ogptlw run --dir "$T" 'hello world' > "$T/termly.out"
 grep -q 'MOCK_TERMLY start --ai opencode --ai-args' "$T/termly.out"
 python3 - <<'PY'
from pathlib import Path
assert Path('.opencode/oh-my-opencode.json').read_bytes()==Path('.opencode/oh-my-opencode-default.json').read_bytes()
PY
)
echo LAUNCHER_MOCK_TEST=PASS
