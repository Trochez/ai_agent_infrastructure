#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
fail=0
for f in "$ROOT/install.sh" "$ROOT/verify.sh" "$ROOT/lib/"*.sh "$ROOT/bin/"* "$ROOT/opencode/"*.sh; do
  bash -n "$f" || fail=1
done
for f in "$ROOT/opencode/profiles/"*.json "$ROOT/opencode/opencode.base.json"; do
  python3 -m json.tool "$f" >/dev/null || fail=1
done
# launchers must differ only in backend selector line.
python3 - "$ROOT/opencode/oc.sh" "$ROOT/opencode/oc_termly.sh" <<'PY'
from pathlib import Path
import sys
a=Path(sys.argv[1]).read_text().replace('OC_LAUNCH_BACKEND=direct','OC_LAUNCH_BACKEND=X')
b=Path(sys.argv[2]).read_text().replace('OC_LAUNCH_BACKEND=termly','OC_LAUNCH_BACKEND=X')
assert a==b, 'oc.sh and oc_termly.sh diverge beyond backend selector'
PY
# profiles must not contain obvious credentials.
python3 - "$ROOT/opencode/profiles" <<'PY'
from pathlib import Path
import re,sys
bad=[]
for p in Path(sys.argv[1]).glob('*.json'):
 s=p.read_text()
 for pat in [r'ghp_[A-Za-z0-9]{20,}',r'nvapi-[A-Za-z0-9_-]{20,}',r'sk-[A-Za-z0-9]{20,}']:
  if re.search(pat,s): bad.append((p.name,pat))
assert not bad, bad
PY
((fail==0))
echo STATIC_TESTS=PASS
