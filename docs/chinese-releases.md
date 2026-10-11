# 中文版 macOS 发行包

中文版发布至 [DioBrando3/checkmate Releases](https://github.com/DioBrando3/checkmate/releases)。`v0.3.4-zh.2` 是首个 Apple 公证中文版本：以应用版本 0.3.4 为基础，中文版 build 11，Apple Silicon / Intel 通用二进制，最低部署版本 macOS 14。

## 签名状态

`v0.3.4-zh.2` 的主程序、MCP 助手和 Stockfish 使用同一 **Developer ID Application** 签名，启用 hardened runtime 与安全时间戳。应用及 DMG 均已获得 Apple 公证并附加票据，通过 Gatekeeper 的 `Notarized Developer ID` 检查。首次运行仍可能出现普通的互联网下载确认。

`codesign --verify` 仅验证签名完整性，不能单独证明已公证。正式发行必须同时通过 `check-package.py --chinese --release` 和 `verify-chinese-dmg.py --require-notarized`。普通源码构建仍采用 ad-hoc 临时签名；旧版 `v0.3.4-zh.1` 也未公证，用户须下载新版 DMG。

## 构建

### Developer ID 签名与 Apple 公证

需要有效的 Developer ID Application 证书（含本机私钥）及可访问 Apple 公证服务的钥匙串凭据。开发测试证书不能替代分发证书。证书和私钥留在本机钥匙串，不提交到 Git 或上传到 Releases。

在本机终端交互配置公证凭据：`xcrun notarytool store-credentials checkmate-notary`。按提示输入 Apple 账号、所属 Team ID 与 App 专用密码；密码不放入命令行、脚本或聊天。也可用 Apple 支持的 App Store Connect API 凭据建立同名钥匙串配置。

```sh
export CHECKMATE_SIGN_ID='你的 Developer ID Application 证书 SHA-1'
export CHECKMATE_NOTARY_PROFILE='checkmate-notary'
bash scripts/notarize-chinese.sh --preflight
bash scripts/notarize-chinese.sh
```

流程会分别签署应用、MCP 助手和 Stockfish，启用 hardened runtime 与安全时间戳，更新引擎签名后的哈希，再向 Apple 提交应用和 DMG。每个提交必须返回 `Accepted`；应用和 DMG 均须附加并校验公证票据，且通过 Gatekeeper 的 `Notarized Developer ID` 检查，才生成最终校验文件。

输出保存在 `build/chinese-notarized/<版本号>.<随机后缀>/`，保留提交状态和验证报告供本机排查。若 Apple 处理超时，先按保存的提交 ID 查询 `xcrun notarytool info <ID> --keychain-profile checkmate-notary`；未接受、未附票据或未通过运行检查的文件不得发布。`verify-chinese-dmg.py --require-notarized` 可对下载回验的 DMG 重做强制公证检查。

此脚本不会自动修改公开 Release。正式公证版采用新的版本号与 build 号，只有通过以上检查后才更新下载说明并发布。

### 临时签名的本地构建

更新 `ChineseVersion.env` 中的中文发行号与 build 号；基础版本与最低 macOS 版本由 `Version.env` 决定。

```sh
bash scripts/package-chinese.sh
```

输出位于 `build/chinese-release/<中文发行号>/`，包括 DMG 和 `SHA256SUMS.txt`。脚本强制使用 Swift release 优化配置，构建 arm64 与 x86_64 两种架构，验证图标、引擎、资源、英文旁白和 874 段中文录音。DMG 内包含应用、Applications 快捷方式、中文安装说明和许可声明。生成目录不提交 Git。

## 发布前验证

```sh
python3 scripts/verify-chinese-dmg.py /实际路径/CheckmateChinese-0.3.4-zh.2-universal.dmg \
  --require-notarized --intel --report evidence/chinese-notarization/dmg-verification.json
```

没有 Rosetta 且不是 Intel Mac 时省略 `--intel`，并在发行说明中注明未执行 Intel 运行验证。

- 对签名后的应用运行 `python3 scripts/check-package.py /签名后的路径/CheckmateChinese.app --chinese --release`。
- 验证应用和 DMG 的公证票据，并分别执行 Gatekeeper 的 `execute` 与 `open` 检查。
- `hdiutil verify` 后只读挂载 DMG，将应用复制到源码目录以外的临时路径，并对副本再次运行包校验。
- 执行 `CHECKMATE_AUTOMATION=1 <副本>/Contents/MacOS/CheckmateNative --package-check <报告路径>`。该模式会读取随包课件并请求随包 Stockfish 返回合法走法，不连接在线语音、不使用麦克风，也不载入个人进度。报告的 `resourceRoot` 必须位于该副本内。
- 在 Apple Silicon 构建机上可用 Rosetta 执行 x86_64 副本检查；这不等于已经在物理 Intel Mac 或最低 macOS 14 上完成测试。
- 退出验证进程并推出 DMG。仅发布通过校验的原始文件，不改动已生成签名的包。

## 上传到 GitHub

提交本次源码并推送唯一版本标签 `v<中文发行号>`。先创建草稿 Release，上传 DMG、对应提交的完整源码归档和 SHA-256 校验文件，下载回验后再公开。只上传生成的发行文件，不上传账户信息、个人数据、构建日志或开发目录。

源码归档由 `git archive` 从该版本提交生成，包括中文内容、音频、固定的 Stockfish 源码归档、神经网络及构建配方。与 DMG 放在同一 Release；GitHub 自动生成的 Source code 归档也指向同一标签。

用户只需下载 DMG。可选地，将校验文件和对应两个归档放在同一目录，运行 `shasum -a 256 -c SHA256SUMS.txt` 检查完整性。在线教练仍需要每位安装者自己的 Codex 登录及服务权限。

## v0.3.4-zh.2 验证记录（2026-10-11）

- Developer ID 签名、hardened runtime、安全时间戳、音频输入权限与全部随包资源检查通过。
- Apple 接受应用提交 `5f4564ac-55f0-47f3-89e0-9f4497b236f9` 和 DMG 提交 `a8550c78-e969-4842-bfd9-a41ed7e4c6b2`；应用审核日志为 `Ready for distribution`，无问题项。
- 应用和 DMG 的公证票据均已附加并验证成功，Gatekeeper 均识别为 `Notarized Developer ID`。
- 从 DMG 复制到独立临时目录的应用，在 Apple Silicon 原生模式与 Rosetta x86_64 模式中均读取 40 节课程，Stockfish 返回合法走法 `d2d4`。
- 874 段中文录音及 864 段原始英文录音逐一校验通过；未修改应用教学或教练功能。
- 未在物理 Intel Mac 或 macOS 14 真机测试；最低版本通过二进制部署目标检查。

## v0.3.4-zh.1 验证记录（2026-10-11）

- release 优化构建完成，应用、MCP 助手和 Stockfish 均包含 arm64 / x86_64 两种架构。
- 中文专项测试 4 项全部通过；40 节课程、87 道习题、10 组规则和 874 段普通话录音齐全。此前应用代码完整回归 262 项，5 项按项目设置跳过，0 失败。
- DMG 校验和、从 DMG 复制出的应用签名、课件和所有中英文录音哈希均通过验证。
- 在 Apple Silicon / macOS 27.0.1 上，复制出的应用分别以原生模式和 Rosetta x86_64 模式读取随包资源，Stockfish 均返回合法走法。
- 未在物理 Intel Mac 或 macOS 14 真机测试；最低系统版本通过二进制部署目标检查。未进行 Apple 公证。
