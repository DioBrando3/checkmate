import XCTest
@testable import CheckmateCore
final class MiniOpponentPolicyTests:XCTestCase {
    func testEveryCompetitiveProfileIsLegalAndDeterministic(){for kind in MiniGameKind.allCases where !kind.solo {let game=MiniGameState(kind:kind);for profile in ["beginner","standard","challenging"] {let a=MiniGameOpponent.choose(in:game,profile:profile,seed:42),b=MiniGameOpponent.choose(in:game,profile:profile,seed:42);XCTAssertEqual(a,b);XCTAssertTrue(a.map{MiniGameRules.moves(board:game.board,kind:kind,side:game.turn).contains($0)} ?? false)}}}
}
extension MiniOpponentPolicyTests {
    func testSeedActuallySelectsDifferentEqualCandidates(){let game=MiniGameState(kind:.pawnWars);let choices=Set((1...16).compactMap{seed in MiniGameOpponent.choose(in:game,profile:"beginner",seed:UInt64(seed)).map{$0.from+$0.to}});XCTAssertGreaterThan(choices.count,1)}
    func testFrozenPawnHuntAndImmediateRaceWin(){var hunt=MiniGameState(kind:.rookHunt);hunt.snapshot.board=["a1":"wr","h8":"br","a7":"bp","b2":"wp"];for profile in ["beginner","standard","challenging"]{let move=MiniGameOpponent.choose(in:hunt,profile:profile,seed:1);XCTAssertEqual(move,MiniGameMove(from:"a1",to:"a7"));XCTAssertFalse(MiniGameRules.moves(board:hunt.board,kind:.rookHunt,side:"w").contains{$0.from=="b2"})};var race=MiniGameState(kind:.pawnWars);race.snapshot.board=["a7":"wp","b2":"bp"];XCTAssertEqual(MiniGameOpponent.choose(in:race,profile:"beginner"),MiniGameMove(from:"a7",to:"a8"))}
    func testEveryGameProfileP95UnderOneSecond()throws {var samples:[Double]=[],rows:[[String:Any]]=[];for kind in MiniGameKind.allCases where !kind.solo{for profile in ["beginner","standard","challenging"]{let game=MiniGameState(kind:kind),start=Date(),move=MiniGameOpponent.choose(in:game,profile:profile,seed:17),milliseconds=Date().timeIntervalSince(start)*1000;samples.append(milliseconds);XCTAssertNotNil(move);rows.append(["game":kind.rawValue,"profile":profile,"milliseconds":milliseconds,"policy":jsonObject(MiniOpponentPolicy.forGame(kind,profile:profile))])}};samples.sort();let p95=samples[Int(Double(samples.count)*0.95)];XCTAssertLessThanOrEqual(p95,1000);if let path=ProcessInfo.processInfo.environment["CHECKMATE_MINI_PERFORMANCE"]{try JSONSerialization.data(withJSONObject:["p95Ms":p95,"samples":rows],options:[.prettyPrinted,.sortedKeys]).write(to:URL(fileURLWithPath:path))}}
    func testMiniSeedPersistsAndLegacyStateStillDecodes()throws {
        let game=MiniGameState(kind:.pawnWars),data=try JSONEncoder().encode(game),restored=try JSONDecoder().decode(MiniGameState.self,from:data)
        XCTAssertEqual(restored.opponentSeed,game.opponentSeed);XCTAssertNotNil(restored.opponentSeed)
        var old=try JSONSerialization.jsonObject(with:data) as! [String:Any];old.removeValue(forKey:"opponentSeed")
        let legacy=try JSONDecoder().decode(MiniGameState.self,from:JSONSerialization.data(withJSONObject:old));XCTAssertNil(legacy.opponentSeed);XCTAssertEqual(legacy.board,game.board)
    }

}
@MainActor final class MiniProfileCancellationTests:XCTestCase {
    func testProfileChangeReplacesPendingReplyAndResetCancelsIt()async throws {
        let session=try GameSession(engine:nil),player=try LearningPlayer(session:session)
        session.state.settings.pieceDuration=0;session.state.settings.miniOpponentProfile="challenging"
        player.openLesson(index:3);player.startPawnWars();player.click("g2");player.click("g4")
        XCTAssertTrue(player.miniThinking)
        session.state.settings.miniOpponentProfile="beginner";player.settingsChanged()
        for _ in 0..<75 where player.miniThinking{try await Task.sleep(for:.milliseconds(40))}
        XCTAssertFalse(player.miniThinking);XCTAssertEqual(player.miniGame?.history.count,2)
        try await Task.sleep(for:.milliseconds(700));XCTAssertEqual(player.miniGame?.history.count,2)
        player.click("h2");player.click("h4");session.state.settings.miniOpponentProfile="challenging";player.settingsChanged();player.restartMini()
        let seed=player.miniGame?.opponentSeed
        try await Task.sleep(for:.milliseconds(750));XCTAssertEqual(player.miniGame?.history.count,0);XCTAssertEqual(player.miniTurn,"w");XCTAssertEqual(player.miniGame?.opponentSeed,seed)
        player.shutdown()
    }
}
