#!/usr/bin/env bash
set -Eeuo pipefail
export OC_LAUNCH_BACKEND=direct
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
exec bash "$SCRIPT_DIR/oc_launcher_core.sh" "$@"
