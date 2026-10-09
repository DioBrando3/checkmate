#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
case $(hostname) in *mbp16*|*MBP16*|macbook-pro*) ;; *) echo 'Run native UI tests on mbp16 only.' >&2; exit 1;; esac
checkmate_evidence=${CHECKMATE_EVIDENCE_DIR:-$(mktemp -d /tmp/checkmate-ui.XXXXXX)}
mkdir -p "$checkmate_evidence"
checkmate_data=$(mktemp -d /tmp/checkmate-ui-state.XXXXXX)
CHECKMATE_BUNDLE_ID=ai.xiaolai.checkmate.native-automation CHECKMATE_APP_NAME=CheckmateAutomation bash build.sh > "$checkmate_evidence/build.log" 2>&1
CHECKMATE_AUTOMATION=1 build/CheckmateAutomation.app/Contents/MacOS/CheckmateNative --automation --data-dir "$checkmate_data" --fullscreen-scenario "$checkmate_evidence" > "$checkmate_evidence/app.log" 2>&1 &
checkmate_pid=$!
trap 'kill "$checkmate_pid" 2>/dev/null || true' EXIT
for ((i=0;i<35;i++)); do [[ -f "$checkmate_evidence/fullscreen-results.json" ]] && break; sleep 1; done
python3 - "$checkmate_evidence/fullscreen-results.json" <<'PY'
import json,sys
result=json.load(open(sys.argv[1]));print(json.dumps(result));assert result['passed'],result
PY
printf '%s\n' "$checkmate_evidence"
