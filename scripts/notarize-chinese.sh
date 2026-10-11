#!/bin/bash
# Sign, notarize and staple both the app and its DMG. No credentials in source.
set -euo pipefail
cd "$(dirname "$0")/.."
source Version.env
source ChineseVersion.env
case "${1:-}" in ''|--preflight) ;; *) echo 'Usage: notarize-chinese.sh [--preflight]' >&2; exit 2;; esac
: "${CHECKMATE_SIGN_ID:?Set CHECKMATE_SIGN_ID to your Developer ID Application certificate SHA-1 or full name}"
: "${CHECKMATE_NOTARY_PROFILE:?Set CHECKMATE_NOTARY_PROFILE to your notarytool Keychain profile}"

# Resolve an exact identity; never fall back to the upstream author's certificate.
checkmate_identity=$(python3 - "$CHECKMATE_SIGN_ID" <<'PY'
import re, subprocess, sys
output = subprocess.check_output(['security', 'find-identity', '-v', '-p', 'codesigning'], text=True)
matches = [(sha, name) for sha, name in re.findall(r'\b([0-9A-F]{40}) "([^"]+)"', output)
           if name.startswith('Developer ID Application: ') and sys.argv[1] in (sha, name)]
if len(matches) != 1:
    raise SystemExit('Exactly one valid Developer ID Application identity with a private key is required')
print(matches[0][0])
PY
)
xcrun notarytool history --keychain-profile "$CHECKMATE_NOTARY_PROFILE" --output-format json >/dev/null
[[ "${1:-}" != --preflight ]] || { echo 'Developer ID and Apple notarization authentication verified'; exit 0; }
case "$CHECKMATE_CHINESE_RELEASE" in *[!a-zA-Z0-9._-]*|'') echo 'Invalid release version' >&2; exit 1;; esac
[[ "$CHECKMATE_CHINESE_RELEASE" == "$CHECKMATE_VERSION"-zh.* ]] || { echo 'Version mismatch' >&2; exit 1; }

CHECKMATE_CONFIGURATION=release bash scripts/build-chinese.sh
mkdir -p build/chinese-notarized
checkmate_output=$(mktemp -d "$PWD/build/chinese-notarized/$CHECKMATE_CHINESE_RELEASE.XXXXXX")
checkmate_app="$checkmate_output/CheckmateChinese.app"
ditto build/CheckmateChinese.app "$checkmate_app"
CHECKMATE_SIGN_ID="$checkmate_identity" bash scripts/sign-release.sh "$checkmate_app"
python3 scripts/check-package.py "$checkmate_app" --chinese --release

notarize() {
    local archive=$1 label=$2
    # Save submission IDs/status for inspection and recovery if Apple's service times out.
    if ! xcrun notarytool submit "$archive" --keychain-profile "$CHECKMATE_NOTARY_PROFILE" \
        --wait --timeout 20m --output-format json > "$checkmate_output/$label-notarization.json"; then
        echo "Notarization did not finish successfully. Inspect $checkmate_output/$label-notarization.json; do not publish." >&2
        return 1
    fi
    python3 - "$checkmate_output/$label-notarization.json" <<'PY'
import json, sys
result = json.load(open(sys.argv[1]))
if result.get('status') != 'Accepted':
    raise SystemExit(f"Apple did not accept this submission: {result.get('status')}; ID: {result.get('id')}")
print('Apple accepted submission:', result['id'])
PY
}
staple() {
    local attempt
    for attempt in 1 2 3 4 5; do
        if xcrun stapler staple "$1"; then break; fi
        (( attempt < 5 )) || return 1
        sleep 10
    done
    xcrun stapler validate "$1"
}
ditto -c -k --keepParent "$checkmate_app" "$checkmate_output/CheckmateChinese-notary.zip"
notarize "$checkmate_output/CheckmateChinese-notary.zip" app
staple "$checkmate_app"

checkmate_staging=$(mktemp -d "${TMPDIR:-/tmp}/checkmate-notarized.XXXXXX")
trap 'rm -rf "$checkmate_staging"' EXIT
ditto "$checkmate_app" "$checkmate_staging/CheckmateChinese.app"
ln -s /Applications "$checkmate_staging/Applications"
cp docs/install-notarized.zh-Hans.txt "$checkmate_staging/安装说明.txt"
cp LICENSE "$checkmate_staging/LICENSE.txt"
cp THIRD_PARTY_NOTICES.md "$checkmate_staging/第三方许可.txt"
checkmate_dmg="$checkmate_output/CheckmateChinese-$CHECKMATE_CHINESE_RELEASE-universal.dmg"
hdiutil create -volname "Checkmate 中文版 $CHECKMATE_CHINESE_RELEASE" -srcfolder "$checkmate_staging" -format UDZO "$checkmate_dmg"
codesign --timestamp --sign "$checkmate_identity" "$checkmate_dmg"
notarize "$checkmate_dmg" dmg
staple "$checkmate_dmg"

# This is the publish gate, including a real launch outside the developer checkout.
checkmate_verify_options=(--require-notarized)
if arch -x86_64 /usr/bin/true 2>/dev/null; then checkmate_verify_options+=(--intel); fi
python3 scripts/verify-chinese-dmg.py "$checkmate_dmg" "${checkmate_verify_options[@]}" --report "$checkmate_output/verification.json"
(cd "$checkmate_output" && shasum -a 256 "${checkmate_dmg##*/}" > SHA256SUMS.txt)
echo "Verified Apple-notarized DMG: $checkmate_dmg"
