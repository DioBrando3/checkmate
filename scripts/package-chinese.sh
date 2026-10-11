#!/bin/bash
# Produce the Chinese fork's ad-hoc signed DMG. This does not notarize it.
set -euo pipefail
cd "$(dirname "$0")/.."
source Version.env
source ChineseVersion.env
case "$CHECKMATE_CHINESE_RELEASE" in *[!a-zA-Z0-9._-]*|"") echo 'Invalid release version' >&2; exit 1;; esac
[[ "$CHECKMATE_CHINESE_RELEASE" == "$CHECKMATE_VERSION"-zh.* ]] || { echo 'Chinese release must match Version.env' >&2; exit 1; }

CHECKMATE_CONFIGURATION=release bash scripts/build-chinese.sh
python3 scripts/check-package.py build/CheckmateChinese.app --chinese

checkmate_output="$PWD/build/chinese-release/$CHECKMATE_CHINESE_RELEASE"
mkdir -p "$checkmate_output"
checkmate_staging=$(mktemp -d "${TMPDIR:-/tmp}/checkmate-zh.XXXXXX")
trap 'rm -rf "$checkmate_staging"' EXIT
ditto build/CheckmateChinese.app "$checkmate_staging/CheckmateChinese.app"
ln -s /Applications "$checkmate_staging/Applications"
cp docs/install.zh-Hans.txt "$checkmate_staging/安装说明.txt"
cp LICENSE "$checkmate_staging/LICENSE.txt"
cp THIRD_PARTY_NOTICES.md "$checkmate_staging/第三方许可.txt"

checkmate_dmg="CheckmateChinese-$CHECKMATE_CHINESE_RELEASE-universal.dmg"
hdiutil create -volname "Checkmate 中文版 $CHECKMATE_CHINESE_RELEASE" \
    -srcfolder "$checkmate_staging" -format UDZO -ov "$checkmate_output/$checkmate_dmg"
hdiutil verify "$checkmate_output/$checkmate_dmg"
(cd "$checkmate_output" && shasum -a 256 "$checkmate_dmg" > SHA256SUMS.txt)
echo "Created $checkmate_output/$checkmate_dmg (ad-hoc signed; NOT Apple notarized)"
