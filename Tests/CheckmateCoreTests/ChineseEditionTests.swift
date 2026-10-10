import XCTest
import AVFoundation
@testable import CheckmateCore

final class ChineseEditionTests: XCTestCase {
    func testLocalizedCourseKeepsEveryDiagramAndAnswer() throws {
        let original = try CourseLibrary(language: "en"), chinese = try CourseLibrary(language: "zh-Hans")
        XCTAssertEqual(chinese.lessons.count, 40)
        XCTAssertEqual(chinese.puzzles.count, 87)
        XCTAssertEqual(chinese.lessons.flatMap(\.beats).count, 864)
        XCTAssertEqual(chinese.lessons.map(\.id), original.lessons.map(\.id))
        for (index, lesson) in chinese.lessons.enumerated() {
            XCTAssertEqual(lesson.beats.map(\.id), original.lessons[index].beats.map(\.id))
            XCTAssertTrue(hasChinese(lesson.title))
            for (step, beat) in lesson.beats.enumerated() {
                let source = original.lessons[index].beats[step]
                XCTAssertTrue(hasChinese(beat.say), beat.id ?? "")
                XCTAssertEqual(beat.set, source.set)
                XCTAssertEqual(beat.moves, source.moves)
                XCTAssertEqual(beat.remove, source.remove)
                let final = try chinese.frame(lesson: index, step: step, seconds: chinese.voices[index][step].duration)
                XCTAssertEqual(final.board, original.referenceFrames[index][step].end.board, beat.id ?? "")
            }
        }
        for (localized, source) in zip(chinese.puzzles, original.puzzles) {
            XCTAssertEqual(localized.id, source.id)
            XCTAssertEqual(localized.board, source.board)
            XCTAssertEqual(localized.level, source.level)
            XCTAssertTrue(hasChinese(localized.exercise.prompt))
            XCTAssertTrue(hasChinese(localized.explanation))
            XCTAssertEqual(localized.exercise.answers, source.exercise.answers)
            XCTAssertEqual(localized.exercise.from, source.exercise.from)
            XCTAssertEqual(localized.exercise.to, source.exercise.to)
            XCTAssertEqual(localized.exercise.alternatives, source.exercise.alternatives)
            if let choices = localized.exercise.choices {
                XCTAssertEqual(choices.count, Set(choices).count)
                XCTAssertTrue(choices.contains(localized.exercise.answer!))
                let answerIndex = source.exercise.choices!.firstIndex(of: source.exercise.answer!)!
                XCTAssertEqual(localized.exercise.answer, choices[answerIndex])
            }
        }
    }

    func testEveryChineseRecordingDecodesAndFitsItsTimeline() throws {
        let course = try CourseLibrary(language: "zh-Hans")
        for voice in course.voices.flatMap({ $0 }) {
            XCTAssertTrue(voice.file.hasPrefix("course/zh-Hans/"))
            let file = try AVAudioFile(forReading: NativeResources.url(voice.file))
            let seconds = Double(file.length) / file.fileFormat.sampleRate
            XCTAssertGreaterThan(seconds, 0)
            XCTAssertEqual(voice.seconds, seconds, accuracy: 0.15)
            XCTAssertGreaterThanOrEqual(voice.duration, seconds)
        }
    }

    func testAllRulesHaveChineseAudioAndCorrectExampleGeometry() throws {
        let entries = try PieceGuideEntry.load()
        XCTAssertEqual(entries.count, 10)
        XCTAssertEqual(Set(entries.compactMap(\.piece)), Set(["k", "q", "r", "b", "n", "p"]))
        for entry in entries {
            XCTAssertTrue(hasChinese(entry.narration))
            let audio = try AVAudioFile(forReading: NativeResources.url(entry.audio))
            XCTAssertGreaterThan(audio.length, 0)
        }
        let knight = entries.first { $0.id == "knight" }!
        XCTAssertEqual(Set(knight.destinations), Set(["b3", "b5", "c2", "c6", "e2", "e6", "f3", "f5"]))
        let pawn = entries.first { $0.id == "pawn" }!
        XCTAssertEqual(pawn.destinations, ["d3", "d4"])
        XCTAssertEqual(pawn.pawnCaptures, ["c3", "e3"])
        XCTAssertEqual(entries.first { $0.id == "rook" }!.destinations.count, 14)
        XCTAssertEqual(entries.first { $0.id == "queen" }!.destinations.count, 27)
    }

    func testPresentationTranslationAndSeparateStorage() {
        XCTAssertEqual(ChineseText.translate("New game"), "新对局")
        XCTAssertEqual(ChineseText.translate("Level 12"), "第 12 级")
        XCTAssertEqual(ChineseText.translate("Black played Nf6."), "黑方走了 Nf6。")
        XCTAssertEqual(ChineseText.translate("0 solved · 0 to review"), "已完成 0 题 · 待复习 0 题")
        XCTAssertEqual(ChineseText.translate("87 exercises"), "共 87 道习题")
        XCTAssertEqual(ChineseText.translate("e2e4"), "e2e4")
        XCTAssertEqual(ChineseText.translate("Checkmate"), "将死")
        XCTAssertEqual(StateStore.dataDirectoryIdentifier(bundleIdentifier: ChineseEdition.bundleIdentifier), ChineseEdition.bundleIdentifier)
        XCTAssertEqual(StateStore.dataDirectoryIdentifier(bundleIdentifier: "ai.xiaolai.checkmate"), "ai.xiaolai.checkmate")
    }
    private func hasChinese(_ text: String) -> Bool { text.range(of: "[\u{4e00}-\u{9fff}]", options: .regularExpression) != nil }
}
