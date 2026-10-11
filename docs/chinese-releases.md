# 中文版 macOS 发行包

中文版发布至 [DioBrando3/checkmate Releases](https://github.com/DioBrando3/checkmate/releases)。`v0.3.4-zh.1` 是首个中文安装包版本：以应用版本 0.3.4 为基础，中文版 build 10，Apple Silicon / Intel 通用二进制，最低部署版本 macOS 14。

## 签名状态

当前分支使用 **ad-hoc 临时签名，未经 Apple 公证**，首次打开需要用户在“系统设置 → 隐私与安全性”为本应用选择“仍要打开”。[Apple 官方说明](https://support.apple.com/zh-cn/102445)。这与上游使用 Developer ID 和 Apple 公证的正式发行流程不同。

`codesign --verify` 仅验证包的签名完整性，不代表 Apple 认可或公证。`scripts/check-package.py --release` 的上游正式签名门槛仍保留；本分支打包使用 `--chinese` 检查资源、架构和临时签名，不冒充通过 `--release`。若未来配置了自己的 Developer ID Application 证书及公证凭据，应另行完成签名、公证与 Gatekeeper 验证后更新说明。

## 构建

更新 `ChineseVersion.env` 中的中文发行号与 build 号；基础版本与最低 macOS 版本由 `Version.env` 决定。

```sh
bash scripts/package-chinese.sh
```

输出位于 `build/chinese-release/<中文发行号>/`，包括 DMG 和 `SHA256SUMS.txt`。脚本强制使用 Swift release 优化配置，构建 arm64 与 x86_64 两种架构，验证图标、引擎、资源、英文旁白和 874 段中文录音。DMG 内包含应用、Applications 快捷方式、中文安装说明和许可声明。生成目录不提交 Git。

## 发布前验证

```sh
python3 scripts/verify-chinese-dmg.py \
  build/chinese-release/0.3.4-zh.1/CheckmateChinese-0.3.4-zh.1-universal.dmg \
  --intel --report evidence/chinese-release/dmg-verification.json
```

没有 Rosetta 且不是 Intel Mac 时省略 `--intel`，并在发行说明中注明未执行 Intel 运行验证。

- 对构建包运行 `python3 scripts/check-package.py build/CheckmateChinese.app --chinese`。
- `hdiutil verify` 后只读挂载 DMG，将应用复制到源码目录以外的临时路径，并对副本再次运行包校验。
- 执行 `CHECKMATE_AUTOMATION=1 <副本>/Contents/MacOS/CheckmateNative --package-check <报告路径>`。该模式会读取随包课件并请求随包 Stockfish 返回合法走法，不连接在线语音、不使用麦克风，也不载入个人进度。报告的 `resourceRoot` 必须位于该副本内。
- 在 Apple Silicon 构建机上可用 Rosetta 执行 x86_64 副本检查；这不等于已经在物理 Intel Mac 或最低 macOS 14 上完成测试。
- 退出验证进程并推出 DMG。仅发布通过校验的原始文件，不改动已生成签名的包。

## 上传到 GitHub

提交本次源码并推送唯一版本标签 `v<中文发行号>`。先创建草稿 Release，上传 DMG、对应提交的完整源码归档和 SHA-256 校验文件，下载回验后再公开。只上传生成的发行文件，不上传账户信息、个人数据、构建日志或开发目录。

源码归档由 `git archive` 从该版本提交生成，包括中文内容、音频、固定的 Stockfish 源码归档、神经网络及构建配方。与 DMG 放在同一 Release；GitHub 自动生成的 Source code 归档也指向同一标签。

用户只需下载 DMG。可选地，将校验文件和对应两个归档放在同一目录，运行 `shasum -a 256 -c SHA256SUMS.txt` 检查完整性。在线教练仍需要每位安装者自己的 Codex 登录及服务权限。

## v0.3.4-zh.1 验证记录（2026-10-11）

- release 优化构建完成，应用、MCP 助手和 Stockfish 均包含 arm64 / x86_64 两种架构。
- 中文专项测试 4 项全部通过；40 节课程、87 道习题、10 组规则和 874 段普通话录音齐全。此前应用代码完整回归 262 项，5 项按项目设置跳过，0 失败。
- DMG 校验和、从 DMG 复制出的应用签名、课件和所有中英文录音哈希均通过验证。
- 在 Apple Silicon / macOS 27.0.1 上，复制出的应用分别以原生模式和 Rosetta x86_64 模式读取随包资源，Stockfish 均返回合法走法。
- 未在物理 Intel Mac 或 macOS 14 真机测试；最低系统版本通过二进制部署目标检查。未进行 Apple 公证。
