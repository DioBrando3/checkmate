import SwiftUI
import CheckmateCore
struct ReviewWorkspaceContent:View {
    @ObservedObject var model:NativeModel
    var body:some View {VStack(spacing:Metrics.sectionGap){
        Image(systemName:"doc.text.magnifyingglass").font(.largeTitle).foregroundStyle(.secondary)
        Text(ChineseText.text("Game review")).font(.largeTitle.bold())
        Text(ChineseText.text("Choose a game or position to explore.")).foregroundStyle(.secondary)
        VStack(spacing:Metrics.smallGap){
            Button(ChineseText.text("Open PGN…")){model.openPGN()}
            Button(ChineseText.text("Paste PGN or FEN")){model.pasteReview()}
            Divider()
            Button(ChineseText.text("Review Current Game")){model.reviewCurrent()}.disabled(model.session.rules.history.isEmpty)
            if !model.session.state.practice.previousGame.isEmpty{Button(ChineseText.text("Review Previous Game")){model.reviewCurrent(previous:true)}}
        }.fixedSize(horizontal:true,vertical:false)
        if model.session.rules.history.isEmpty{Text(ChineseText.text("Play a move to review your current game.")).font(.caption).foregroundStyle(.secondary)}
        if !model.reviews.isEmpty{Text(ChineseText.text("Saved reviews are in the sidebar.")).font(.caption).foregroundStyle(.secondary)}
    }.padding(Metrics.padding).frame(maxWidth:.infinity,maxHeight:.infinity)}
}
struct ReviewDetailContent:View {
    @ObservedObject var review:ReviewController
    @ObservedObject var model:NativeModel
    @State private var allMoves=false
    @ObservedObject var analyzer:ReviewAnalyzer
    @ObservedObject var voice:VoiceCoach
    init(review:ReviewController,model:NativeModel){self.review=review;self.model=model;analyzer=model.reviewAnalyzer;voice=model.voice}
    var body:some View {VStack(alignment:.leading,spacing:Metrics.sectionGap){
        if let d=review.document {
            HStack{
                Button(ChineseText.text("Choose Game…")){model.showReviewWorkspace()}
                Spacer()
                if model.reviewDraft{Button(ChineseText.text("Save Review")){model.saveCurrentReview()}}
                else{Menu(ChineseText.text("Review actions")){Button(ChineseText.text("Delete Saved Review…"),role:.destructive){model.requestDeleteReview(d.id)}.disabled(model.deletingReviewID != nil)}.accessibilityIdentifier("review-document-actions")}
            }
            Text(ChineseText.text(review.branch==nil ? "Review · Original":"Test my idea · Imagined")).font(.caption).foregroundStyle(.secondary)
            Text(ChineseText.text(review.explanation?.title ?? d.title)).font(.title2.bold())
            Text(ChineseText.text(review.explanation?.summary ?? ""))
            if let note=review.explanation?.historyNote{Text(ChineseText.text(note)).foregroundStyle(.secondary)}
            if review.nodeID==0{ForEach(Array((review.explanation?.takeaways ?? []).dropFirst()),id:\.self){Text(ChineseText.text("• "+$0))}}
            if review.branch != nil {Text(ChineseText.text("Either side can make legal moves here. The imported game is preserved."));Button(ChineseText.text("Return to original")){review.clearBranch();model.saveReview()};Button(ChineseText.text("Analyze this idea")){review.analyze(using:model.reviewAnalyzer)}}
            else{HStack{Button(ChineseText.text("Why?")){review.analyze(using:model.reviewAnalyzer)};Button(ChineseText.text("Look deeper")){review.analyze(using:model.reviewAnalyzer,budget:ReviewPolicy.deepBudget)};Button(ChineseText.text("Test my idea")){try? review.beginBranch()}}
                if let pv=review.evidence?.root.lines.first?.pv,!pv.isEmpty{Button(ChineseText.text("Compare best line · before this move")){try? review.previewLine(pv,fromNode:d.nodes[review.nodeID].parent);review.seekBranch(0)}}
            }
            if review.analysisStatus=="pending"{ProgressView(ChineseText.text("Analyzing offline…"))}
            if let evidence=review.evidence{Text(ChineseText.text(evidence.provisional ? "Provisional engine estimate":"Deeper engine comparison")).foregroundStyle(.secondary);DisclosureGroup(ChineseText.text("Engine evidence")){ForEach(Array(evidence.root.lines.enumerated()),id:\.offset){_,line in Text(ChineseText.text(line.san.joined(separator:" ")))};Text(ChineseText.text("\(evidence.engineVersion) · \(evidence.budgetMs) ms · full strength"))}}
            if let error=review.error{Text(ChineseText.text(error)).foregroundStyle(.secondary)}
            DisclosureGroup(ChineseText.text("Verified board facts")){ForEach(review.explanation?.facts ?? []){fact in Text(ChineseText.text(fact.text)).textSelection(.enabled)}}
            Button(ChineseText.text("Analyze whole game offline")){analyzer.startBatch(d)}
            if analyzer.batchDocument==d.id,["pending","deepening"].contains(analyzer.batchStatus){ProgressView(value:Double(analyzer.completed),total:Double(max(1,analyzer.total)));Text(ChineseText.text(analyzer.batchStatus=="deepening" ? "Checking the leading moment more deeply":"\(analyzer.completed) / \(analyzer.total) moves"));Button(ChineseText.text("Cancel analysis")){analyzer.cancelBatch()}}
            if analyzer.batchDocument==d.id,analyzer.batchStatus=="failed"{Text(ChineseText.text("Offline analysis is unavailable for this game. The record remains navigable; try again later.")).foregroundStyle(Color(nsColor:NativeColors.error))}
            else if analyzer.batchDocument==d.id,analyzer.batchStatus=="ready",analyzer.failed>0{Text(ChineseText.text("\(analyzer.failed) of \(analyzer.total) moves could not be analyzed.")).foregroundStyle(.secondary)}
            // Voice status and failures stay visible in review, transcript newest first.
            if voice.connected || !voice.history.isEmpty || voice.status != "Disconnected" {
                Divider();Text(ChineseText.text("Voice coach")).font(.headline);Text(ChineseText.text(voice.status)).foregroundStyle(.secondary)
                ForEach(Array(voice.history.reversed())){entry in VStack(alignment:.leading){Text(ChineseText.text(entry.role=="learner" ? "You":"Coach")).font(.caption).foregroundStyle(.secondary);Text(ChineseText.text(entry.text)).textSelection(.enabled)}}
            }
            Divider();Toggle(ChineseText.text("All moves"),isOn:$allMoves)
            Text(ChineseText.text(allMoves ? "All recorded moves":"Important moments")).font(.headline)
            ForEach(allMoves ? d.mainline:scopedMoments(d).isEmpty ? important(d):scopedMoments(d).map(\.id),id:\.self){id in let n=d.nodes[id];Button(ChineseText.text("\(n.fullmove)\(n.side=="w" ? ".":"...") \(n.san ?? "")")){try? review.select(id);model.saveReview()}.buttonStyle(.plain).foregroundStyle(id==review.nodeID ? .primary:.secondary).accessibilityLabel(ChineseText.text("\(n.fullmove), \(n.side=="w" ? "White":"Black"), \(n.san ?? "")"))}
            if !allMoves{Text(ChineseText.text(scopedMoments(d).isEmpty ? "Start with checks, captures, promotions and the final position. Analyze the game for engine-selected moments.":"Moments selected from legal moves and recorded engine comparisons. Provisional estimates may change with deeper analysis.")).font(.caption).foregroundStyle(.secondary)}
            if !d.nodes[review.nodeID].children.isEmpty{DisclosureGroup(ChineseText.text("Recorded continuations")){ForEach(d.nodes[review.nodeID].children,id:\.self){id in Button(ChineseText.text(d.nodes[id].san ?? "Position")){try? review.select(id)}}}}
            if !review.authoredBranches.isEmpty{DisclosureGroup(ChineseText.text("My imagined lines")){ForEach(review.authoredBranches,id:\.id){branch in Button(ChineseText.text("Idea from position \(branch.root) · \(branch.moves.count) moves")){try? review.openSavedBranch(branch.id)}}}}
            // Availability follows the displayed position, including an imagined line from the parent.
            Divider();HStack{Button(ChineseText.text("Practise here")){model.practiceFromReview()}.disabled(!review.practiceForkAvailable);Button(ChineseText.text("Export PGN…")){model.exportReview()}}
            Button(ChineseText.text("Return to game")){model.returnToGame()}
            if voice.connected{Text(ChineseText.text("Voice connected · only selected verified facts are shared")).font(.caption);Button(ChineseText.text("Narrate verified facts")){voice.narrateReview()};Button(ChineseText.text("Disconnect voice")){voice.disconnect()}}else if ReviewRolloutPolicy.reviewVoiceEnabled{Button(ChineseText.text("Connect optional voice")){voice.connect()}}
        }
    }.sheet(isPresented:$model.practiceForkRequested){ReviewPracticeSheet(model:model)}}
    private func scopedMoments(_ d:GameDocument)->[ReviewMoment]{analyzer.batchDocument==d.id ? analyzer.moments.filter{d.nodes.indices.contains($0.id)}:[]}
    private func important(_ document:GameDocument)->[Int] {document.mainline.filter{id in let n=document.nodes[id];return n.san?.contains("+")==true || n.san?.contains("#")==true || n.san?.contains("x")==true || n.san?.contains("=")==true || id==document.mainline.last}}
}
struct ReviewTransport:View {
    @ObservedObject var review:ReviewController
    var body:some View {HStack(spacing:Metrics.smallGap){
        NativeIcon(symbol:"backward.end",label:"First position"){review.first()}
        NativeIcon(symbol:"arrow.left",label:"Previous review move"){review.step(-1)}
        NativeIcon(symbol:review.playing ? "pause.fill":"play.fill",label:review.playing ? "Pause review":"Play review"){review.playing ? review.pause():review.play()}
        NativeIcon(symbol:"arrow.right",label:"Next review move"){review.step(1)}
        NativeIcon(symbol:"forward.end",label:"Last position"){review.last()}
        Text(ChineseText.text(review.branch==nil ? "Original":"Imagined")).font(.caption).foregroundStyle(.secondary)
    }.padding(Metrics.padding)}
}

struct OpponentSettingsContent:View {
    @ObservedObject var session:GameSession
    private var displayedPreset:String {session.state.settings.opponentPreset=="first_steps" && !ReviewRolloutPolicy.beginnerOpponentEnabled ? "custom":session.state.settings.opponentPreset}
    private var displayedMode:String {
        if !ReviewRolloutPolicy.beginnerOpponentEnabled && (session.state.settings.opponentPreset=="first_steps" || session.state.settings.opponentMode=="beginner") {return "skill"}
        return session.state.settings.opponentMode
    }
    private var mode:Binding<String>{Binding(get:{displayedMode},set:{value in var settings=session.state.settings;settings.opponentMode=value;settings.opponentPreset="custom";session.updateSettings(settings)})}
    func binding<T>(_ key:WritableKeyPath<AppSettings,T>)->Binding<T> {Binding(get:{session.state.settings[keyPath:key]},set:{var settings=session.state.settings;settings[keyPath:key]=$0;settings.opponentPreset="custom";session.updateSettings(settings)})}
    var preset:Binding<String>{Binding(get:{displayedPreset},set:{value in var settings=session.state.settings;settings.opponentPreset=value;session.updateSettings(settings)})}
    var body:some View {VStack(alignment:.leading,spacing:Metrics.smallGap){
        Grid(alignment:.leading,horizontalSpacing:Metrics.smallGap,verticalSpacing:Metrics.smallGap){
            GridRow {
                Text(ChineseText.text("Opponent"))
                Picker(ChineseText.text("Opponent"),selection:preset){
                    if ReviewRolloutPolicy.beginnerOpponentEnabled{Text(ChineseText.text("First steps")).tag("first_steps")}
                    Text(ChineseText.text("Gentle")).tag("gentle");Text(ChineseText.text("Club")).tag("club");Text(ChineseText.text("Custom")).tag("custom")
                }.labelsHidden().frame(maxWidth:.infinity)
            }
            if displayedPreset=="custom"{
                GridRow {
                    Text(ChineseText.text("Strength"))
                    Picker(ChineseText.text("Strength control"),selection:mode){
                        Text(ChineseText.text("Stockfish skill")).tag("skill");Text(ChineseText.text("Estimated engine Elo")).tag("elo")
                        if ReviewRolloutPolicy.beginnerOpponentEnabled{Text(ChineseText.text("Beginner")).tag("beginner")}
                    }.labelsHidden().frame(maxWidth:.infinity)
                }
                if displayedMode=="skill"{
                    GridRow {
                        Text(ChineseText.text("Skill"))
                        Picker(ChineseText.text("Skill"),selection:binding(\.skill)){ForEach(0...20,id:\.self){Text(ChineseText.text("Level \($0)")).tag($0)}}
                            .labelsHidden().frame(maxWidth:.infinity)
                    }
                }
                if displayedMode=="elo",let engine=session.engine as? NativeEngine{
                    EngineEloControl(engine:engine,value:binding(\.opponentElo)).gridCellColumns(2)
                }
            }
        }
        if displayedPreset=="custom",displayedMode=="elo"{Text(ChineseText.text("An engine estimate, not a tournament rating.")).font(.caption).foregroundStyle(.secondary)}
        if displayedPreset=="first_steps" || (displayedPreset=="custom" && displayedMode=="beginner"){Text(ChineseText.text("First steps gives more opportunities to practise. You can always use hints or take back a move.")).font(.caption).foregroundStyle(.secondary)}
    }}
}
struct EngineEloControl:View {
    @ObservedObject var engine:NativeEngine
    @Binding var value:Int
    @State private var unavailable=false
    var body:some View {Group{if let range=engine.capabilities.eloRange{Stepper(ChineseText.text("Engine estimate: \(value)"),value:$value,in:range,step:50)}else{Text(ChineseText.text(unavailable ? "This engine does not provide an Elo setting. Use Stockfish skill instead.":"Checking engine strength settings…")).foregroundStyle(.secondary)}}.task{do{try await engine.prepare();unavailable=engine.capabilities.eloRange==nil}catch{unavailable=true}}}
}

struct ReviewPracticeSheet:View {
    @ObservedObject var model:NativeModel
    @State private var side="w"
    @State private var preset="custom"
    var body:some View {VStack(alignment:.leading,spacing:Metrics.sectionGap){
        Text(ChineseText.text("Practise from this position")).font(.headline)
        Text(ChineseText.text("Your current practice is backed up and becomes Previous game, replacing that shortcut’s older game. The imported record stays unchanged."))
        Picker(ChineseText.text("Play as"),selection:$side){Text(ChineseText.text("White")).tag("w");Text(ChineseText.text("Black")).tag("b")}
        Picker(ChineseText.text("Opponent"),selection:$preset){if ReviewRolloutPolicy.beginnerOpponentEnabled{Text(ChineseText.text("First steps")).tag("first_steps")};Text(ChineseText.text("Gentle")).tag("gentle");Text(ChineseText.text("Club")).tag("club");Text(ChineseText.text("Keep custom settings")).tag("custom")}
        Button(ChineseText.text("Save this position for later")){model.saveReview();model.practiceForkRequested=false}
        HStack{Spacer();Button(ChineseText.text("Cancel")){model.practiceForkRequested=false}.keyboardShortcut(.cancelAction);Button(ChineseText.text("Start practice")){model.confirmPracticeFork(side:side,preset:preset)}.keyboardShortcut(.defaultAction)}
    }.padding(Metrics.padding).frame(minWidth:Metrics.right)}
}
