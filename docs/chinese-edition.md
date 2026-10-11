# Checkmate 简体中文版

基于上游 v0.3.4（`cbf14fa123201ea38fc5c35d45fb1675855c144e`）的中文定制版，仓库为 [DioBrando3/checkmate](https://github.com/DioBrando3/checkmate)。

- 简体中文菜单、设置、棋盘提示、课程与题库。
- 40 节课程、864 段中文脚本及对应的本地普通话录音。
- 87 道中文习题，保留原始棋盘、走法、答案与稳定 ID。
- “棋子走法”窗口：六种棋子的空棋盘走法图、王车易位、升变、吃过路兵、将军与逼和；十组规则均可普通话朗读。
- 原来的 Stockfish 引擎、国际棋谱字母、坐标和通信协议保持不变。

中文应用名为 **Checkmate 中文版**，构建包为 `CheckmateChinese.app`，标识为 `ai.xiaolai.checkmate.zh-Hans`。进度保存在 `~/Library/Application Support/ai.xiaolai.checkmate.zh-Hans`，与上游安装版隔离。要继续原来的学习进度，可使用菜单中的导出与导入功能。

## 语音

课程和规则使用 macOS 本地“婷婷”普通话语音，录音随应用打包，可离线播放，不需要账户、网络或麦克风。新录音的实际时长用于课程播放，不沿用英文旁白时长。

在线语音教练的默认回复语言为普通话。在侧边栏选择“对弈练习”，再到“设置 → 语音教练”开启麦克风并手动连接。在线语音依赖 Codex 账户资格、联网和系统麦克风权限；中文版默认关闭启动时自动连接与自动 MCP 启动。本机已验证实际在线中文回复及“轮到你说 · 正在听”状态，其他安装仍须用各自账户完成连接。个人账户凭据和本机设置不随源码发布。

## 开发与重建

直接安装请前往 [Releases](https://github.com/DioBrando3/checkmate/releases/latest) 下载通用 DMG；参见[安装说明](install.zh-Hans.txt)与[中文版发布流程](chinese-releases.md)。当前发行包为临时签名，未经 Apple 公证。

```sh
# 重新录制时需要本机已安装的婷婷普通话语音；按内容哈希复用已有录音。
python3 scripts/build-chinese-course.py
python3 scripts/publish-chinese-course.py
CHECKMATE_AUTOMATION=1 swift test --filter ChineseEditionTests
bash scripts/build-chinese.sh
open build/CheckmateChinese.app
```

`Content/zh-Hans/lessons.txt` 是逐段课程脚本，`puzzles.txt` 是习题文本，`interface.tsv` 是界面翻译表。发布脚本生成独立的 `course.zh-Hans.json`，不覆盖英文课件。原有测试继续使用英文资源，中文专项测试显式加载中文资源并检查两版的棋盘与答案一致性。

走法规则参考 [FIDE 国际象棋规则](https://handbook.fide.com/chapter/E012023)。本地代码和内容修改沿用仓库 GPL-3.0-or-later 许可；原项目和第三方声明随应用保留。本构建使用本机临时签名，不冒充上游正式发布包。

## 本机验证（2026-10-10）

- 完整回归：262 项，5 项项目默认的长期校准和性能测试跳过，0 失败。
- 最后补齐文字后，中文专项 4 项再次通过：40 课、864 段音频、87 题的棋盘与答案一致性，以及 10 组规则录音和六种走法图。
- Apple Silicon 与 Intel 通用构建成功；临时签名严格校验通过。安装目录中的资源可读取，Stockfish 返回合法走法。
- 桌面实测：中文菜单与设置、课程播放、规则朗读和马的八个落点图；在线教练已连接并产生普通话开局讲解，随后进入“轮到你说 · 正在听”状态。该检查验证了服务连接、中文输出及收音就绪，不代表对所有麦克风设备或账户的兼容性测试。
- 完整走法说明见 [国际象棋规则中文速查](chess-rules.zh-Hans.md)。测试日志保存在本地 `evidence/chinese-edition/`。
