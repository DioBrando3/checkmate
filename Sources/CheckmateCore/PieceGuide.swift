import Foundation

public struct PieceGuideEntry: Codable, Identifiable {
    public let id, title, symbol, summary: String
    public let piece, origin: String?
    public let rules: [String]
    public let audio: String
    public var narration: String { ([title + "。", summary] + rules).joined(separator: "\n") }
    public var board: Position {
        guard let piece, let origin else { return [:] }
        return [origin: "w" + piece]
    }
    /// Empty-board geometry only: the lesson explicitly explains king safety.
    public var destinations: [String] {
        guard let origin, let piece else { return [] }
        if piece == "p" { return CourseLibrary.pawnMoves(board, from: origin) }
        return ChessRules.squares.filter { CourseLibrary.attacks(board, from: origin, to: $0) }
    }
    public var pawnCaptures: [String] { piece == "p" ? ["c3", "e3"] : [] }
    public static func load() throws -> [Self] {
        try JSONDecoder().decode([Self].self, from: Data(contentsOf: NativeResources.url("piece-guide.zh-Hans.json")))
    }
}
