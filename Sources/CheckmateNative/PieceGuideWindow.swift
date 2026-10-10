import AppKit
import SwiftUI
import AVFoundation
import CheckmateCore

@MainActor final class GuideAudio: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published var playing = false
    @Published var error: String?
    private var player: AVAudioPlayer?
    func play(_ entry: PieceGuideEntry) {
        stop()
        guard !NativePolicy.silent else { return }
        do {
            let audio = try AVAudioPlayer(contentsOf: NativeResources.url(entry.audio))
            audio.delegate = self
            guard audio.play() else { throw CheckmateError.unavailable("无法播放") }
            player = audio; playing = true; error = nil
        } catch { self.error = "普通话朗读暂时不可用，仍可阅读下方文字。" }
    }
    func stop() { player?.stop(); player = nil; playing = false }
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in self?.playing = false }
    }
}

private struct GuideDiagram: NSViewRepresentable {
    let entry: PieceGuideEntry
    func makeNSView(context: Context) -> BoardView { BoardView(frame: .zero) }
    func updateNSView(_ board: BoardView, context: Context) {
        board.position = entry.board
        board.destinations = entry.destinations
        board.highlights = entry.pawnCaptures.map { Highlight(sq: $0, kind: "no") }
        board.selected = entry.origin
        board.needsDisplay = true
    }
}

private struct PieceGuideContent: View {
    let entries: [PieceGuideEntry]
    @ObservedObject var audio: GuideAudio
    @State private var selected = "king"
    var body: some View {
        HStack(spacing: 0) {
            List(selection: $selected) {
                Section("六种棋子") {
                    ForEach(entries.filter { $0.piece != nil }) { item in
                        Text(item.symbol + "  " + item.title).font(.title3).tag(item.id)
                    }
                }
                Section("特殊规则") {
                    ForEach(entries.filter { $0.piece == nil }) { item in Text(item.title).tag(item.id) }
                }
            }.listStyle(.sidebar).frame(width: 170)
            if let item = entries.first(where: { $0.id == selected }) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text(item.symbol + " " + item.title).font(.largeTitle.bold())
                            Spacer()
                            Button(audio.playing ? "停止朗读" : "普通话朗读", systemImage: audio.playing ? "stop.fill" : "speaker.wave.2.fill") {
                                audio.playing ? audio.stop() : audio.play(item)
                            }.accessibilityIdentifier("guide-narration")
                        }
                        Text(item.summary).font(.title3.weight(.semibold))
                        ForEach(Array(item.rules.enumerated()), id: \.offset) { index, rule in
                            Text("\(index + 1). \(rule)").fixedSize(horizontal: false, vertical: true)
                        }
                        if item.piece != nil {
                            GuideDiagram(entry: item).frame(height: 290)
                            Text(item.piece == "p" ? "图中白兵向上走：圆点是直行落点，红格是斜吃方向（实战须有敌子，吃过路兵除外）。" : "圆点表示空棋盘上的几何走法。实战还要检查阻挡、己方棋子和王的安全。")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        if let error = audio.error { Text(error).foregroundStyle(.red) }
                        Divider()
                        Text("共同规则：白方先走，双方轮流一步；不能吃自己的棋子，不能让自己的王处于将军中。")
                        Link("规则参考：国际棋联 FIDE《国际象棋规则》第 3 条", destination: URL(string: "https://handbook.fide.com/chapter/E012023")!).font(.caption)
                    }.padding(24).textSelection(.enabled)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }.onChange(of: selected) { _, _ in audio.stop() }.onDisappear { audio.stop() }
    }
}

@MainActor final class PieceGuideWindow: NSWindowController, NSWindowDelegate {
    private let audio = GuideAudio()
    init(entries: [PieceGuideEntry]) {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 820, height: 700), styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        super.init(window: window)
        window.title = "棋子走法与特殊规则"
        window.minSize = NSSize(width: 720, height: 580)
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.contentViewController = NSHostingController(rootView: PieceGuideContent(entries: entries, audio: audio))
        window.center()
    }
    required init?(coder: NSCoder) { fatalError() }
    func windowWillClose(_ notification: Notification) { audio.stop() }
}
