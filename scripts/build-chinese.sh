#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
source ChineseVersion.env
python3 scripts/publish-chinese-course.py
CHECKMATE_APP_NAME=CheckmateChinese CHECKMATE_BUNDLE_ID=ai.xiaolai.checkmate.zh-Hans bash build.sh
checkmate_chinese_plist="$PWD/build/CheckmateChinese.app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleName Checkmate 中文版' "$checkmate_chinese_plist"
/usr/libexec/PlistBuddy -c 'Add :CFBundleDisplayName string Checkmate 中文版' "$checkmate_chinese_plist"
/usr/libexec/PlistBuddy -c 'Add :CFBundleDevelopmentRegion string zh_CN' "$checkmate_chinese_plist"
/usr/libexec/PlistBuddy -c 'Add :CFBundleLocalizations array' "$checkmate_chinese_plist"
/usr/libexec/PlistBuddy -c 'Add :CFBundleLocalizations:0 string zh-Hans' "$checkmate_chinese_plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $CHECKMATE_CHINESE_BUILD_NUMBER" "$checkmate_chinese_plist"
/usr/libexec/PlistBuddy -c "Add :CheckmateChineseRelease string $CHECKMATE_CHINESE_RELEASE" "$checkmate_chinese_plist"
/usr/libexec/PlistBuddy -c 'Set :NSMicrophoneUsageDescription 在国际象棋练习中听取你的问题。离线课程与规则朗读不需要麦克风。' "$checkmate_chinese_plist"
codesign --force --sign - build/CheckmateChinese.app
codesign --verify --deep --strict build/CheckmateChinese.app
echo 'Built build/CheckmateChinese.app (local Chinese edition)'
