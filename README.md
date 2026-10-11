# Checkmate 中文版

面向中文学习者的 macOS 国际象棋练习与教学应用，基于 [xiaolai/checkmate](https://github.com/xiaolai/checkmate) v0.3.4，以 AppKit 和 SwiftUI 构建。

提供简体中文界面、普通话课程旁白、棋子走法图解，以及默认使用普通话交流的在线语音教练。

## 功能

- **中文界面**：菜单、设置、棋盘提示、课程与题库。
- **40 节中文课程**：864 段普通话旁白随应用打包，可离线播放。
- **87 道中文习题**：保留上游棋盘、正确答案、动画和学习进度标识。
- **棋子走法与特殊规则**：王、后、车、象、马、兵的走法图，以及王车易位、兵升变、吃过路兵、将军、将死与逼和；10 组说明均可普通话朗读。
- **离线对弈**：内置 Stockfish 19，支持棋力设置、试走、提示与课程小游戏。
- **棋局复盘**：支持已结束和未结束的棋局、PGN 棋谱与 FEN 局面。
- **在线语音教练**：默认普通话回复，支持讲解当前棋盘并回答语音提问。

## 安装与启动

运行需要 **macOS 14 或更新版本**。应用支持 Apple Silicon 和 Intel Mac。

**[下载最新版 macOS 安装包（DMG）](https://github.com/DioBrando3/checkmate/releases/latest)**，无需 Xcode 或编程工具：

1. 下载名称以 `CheckmateChinese-` 开头、以 `-universal.dmg` 结尾的文件。
2. 打开 DMG，将 **CheckmateChinese.app** 拖到 **Applications（应用程序）**。
3. 推出磁盘映像，从“应用程序”打开 **Checkmate 中文版**。

当前中文发行包采用临时签名，**尚未经过 Apple Developer ID 签名和公证**。如果首次打开时提示无法验证开发者或无法检查恶意软件，请确认来源后，到“系统设置 → 隐私与安全性”点击这款应用旁的“仍要打开”，按提示确认。详见 [Apple 官方说明](https://support.apple.com/zh-cn/102445) 和[完整安装说明](docs/install.zh-Hans.txt)。如果系统提示包含恶意软件、将损坏电脑或文件已损坏，请停止安装并反馈。

Release 同时提供 `SHA256SUMS.txt` 和对应源码。更新前退出旧版，将新版拖入“应用程序”替换即可，学习进度会保留。

### 从源码构建

从源码构建需要完整 Xcode（含 Swift 6 及图标编译工具）和 Python 3.9 或更新版本：

```sh
git clone https://github.com/DioBrando3/checkmate.git
cd checkmate
bash scripts/build-chinese.sh
open build/CheckmateChinese.app
```

构建完成后，可将 `build/CheckmateChinese.app` 拖入“应用程序”。本地构建采用临时签名；此仓库的中文构建入口是 `scripts/build-chinese.sh`。

中文应用显示为 **Checkmate 中文版**，使用独立的应用标识与进度目录，可与上游版本同时安装。仓库已包含中文录音，正常构建无需重新合成语音。

## 开始学习

1. 打开侧边栏，选择中文课程或“随堂练习”。
2. 点击顶部书本按钮，或按 **⌘⇧R**，打开“棋子走法与特殊规则”。
3. 在规则窗口选择棋子，查看落点示意图；点击“普通话朗读”听取讲解。

[完整棋规中文速查](docs/chess-rules.zh-Hans.md) · [中文版修改与构建说明](docs/chinese-edition.md)

## 连接普通话在线教练

离线课程和规则朗读不需要账户、联网或麦克风。在线对话需要本机已登录 Codex、账户支持实时语音服务、网络可用，并允许应用使用麦克风。

1. 在侧边栏选择“对弈练习”。
2. 打开“设置 → 语音教练”，确认“回复语言”为“普通话”。
3. 开启“麦克风”，点击“连接”，并按系统提示授权。
4. 显示“轮到你说 · 正在听”后，即可直接用中文提问，例如：“我是初学者，第一步应该怎么走？”

教练讲话时会暂停收音，说完后继续听取提问。中文版默认关闭启动时自动连接，可在设置中自行开启。在线连接能力取决于当前账户及服务可用性；账户凭据和个人学习进度不属于仓库内容。

## 开发与验证

```sh
# 完整回归测试；自动化模式不调用在线语音或麦克风
CHECKMATE_AUTOMATION=1 swift test

# 中文课程、音频与棋规专项验证
CHECKMATE_AUTOMATION=1 swift test --filter ChineseEditionTests

# 修改中文文本后，重新生成课程资源并构建
python3 scripts/publish-chinese-course.py
bash scripts/build-chinese.sh
```

修改旁白文本后，先运行 `python3 scripts/build-chinese-course.py`，使用本机“婷婷”普通话语音重新生成对应录音，再发布课程资源。录音按内容哈希复用。

- `Content/zh-Hans/`：课程脚本、习题文字、界面翻译表与音频清单。
- `Sources/CheckmateCore/Resources/course/zh-Hans/`：课程及棋规的普通话录音。
- `Sources/`、`Tests/`：应用、MCP 助手与测试。
- `scripts/build-chinese.sh`：中文版构建入口。
- `scripts/package-chinese.sh`：中文版通用 DMG 打包入口（优化构建、资源校验与 SHA-256）。
- `docs/`：棋规、中文定制、开发与发布文档。

本机验证记录：完整测试 262 项，5 项长期校准与性能测试按项目设置跳过，0 失败；中文版安装包、Stockfish、离线旁白及在线普通话教练均已实际验证。详情见[验证说明](docs/chinese-edition.md#本机验证2026-10-10)。

## 上游与许可

感谢 [xiaolai/checkmate](https://github.com/xiaolai/checkmate)。本分支以 v0.3.4 提交 `cbf14fa123201ea38fc5c35d45fb1675855c144e` 为基础，保留原有棋规引擎和英文资源。

原始代码、作者课程内容及本分支修改沿用 **GPL-3.0-or-later**；第三方内容遵循各自许可，见 [LICENSE](LICENSE) 和 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。Stockfish 对应源码及构建说明位于 `ThirdParty/Stockfish/`。课程语音为合成语音。

[上游英文说明](README.en.md) · [开发文档](docs/development.md) · [中文版发布流程](docs/chinese-releases.md) · [上游发布流程](docs/releases.md) · [上游更新日志](CHANGELOG.md)
