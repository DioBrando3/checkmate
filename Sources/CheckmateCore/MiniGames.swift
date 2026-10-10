import Foundation

public enum MiniGameKind:String,Codable,CaseIterable {
    case pawnWars="pawn-wars",rookHunt="rook-hunt",rooksAndPawns="rooks-and-pawns"
    case bishopHunt="bishop-hunt",bishopsAndPawns="bishops-and-pawns",queenChase="queen-chase",hungryHorse="hungry-horse",knightHop="knight-hop"
    public var title:String {switch self{case .pawnWars:return "Pawn Wars";case .rookHunt:return "Rook Pawn Hunt";case .rooksAndPawns:return "Rooks and Pawns";case .bishopHunt:return "Bishop Pawn Hunt";case .bishopsAndPawns:return "Bishops and Pawns";case .queenChase:return "Queen Chase";case .hungryHorse:return "Hungry Horse";case .knightHop:return "Knight Hop"}}
    public var solo:Bool {self == .knightHop}
    public var lessonID:String {switch self{case .pawnWars:return "pawn-wars";case .rookHunt,.rooksAndPawns:return "rampant-rooks";case .bishopHunt,.bishopsAndPawns:return "busy-bishops";case .queenChase:return "quirky-queens";case .hungryHorse,.knightHop:return "hungry-horses"}}
    public static func available(lessonID:String)->[Self] {allCases.filter{$0.lessonID==lessonID}}
    public var rules:String {switch self {
        case .pawnWars:return "Reach the far rank, capture every opposing pawn, or leave the opponent without a move. Pawns stay pawns. No en passant."
        case .rookHunt,.bishopHunt:return "Only \(self == .rookHunt ? "rooks":"bishops") move. Capture every opposing pawn to win. Losing all your moving pieces or having no move loses."
        case .rooksAndPawns,.bishopsAndPawns,.queenChase:return "Capture every opposing piece, or reach the far rank with a pawn that survives the opponent’s next move. Having no move loses. Pawns stay pawns. No en passant."
        case .hungryHorse:return "Only knights move. Capture opposing pieces. Losing your knight or having no knight move loses."
        case .knightHop:return "Visit h1, h8, a8, then return to a1. Avoid black pawns and the squares they attack."
    }}
    public var initialBoard:Position {
        let pawns=Dictionary(uniqueKeysWithValues:"abcdefgh".flatMap{[(String($0)+"2","wp"),(String($0)+"7","bp")]})
        switch self {
        case .pawnWars:return pawns
        case .rooksAndPawns:return pawns.merging(["a1":"wr","h1":"wr","a8":"br","h8":"br"]){_,new in new}
        case .bishopsAndPawns:return pawns.merging(["c1":"wb","f1":"wb","c8":"bb","f8":"bb"]){_,new in new}
        case .queenChase:return pawns.filter{$0.value=="wp"}.merging(["d8":"bq"]){_,new in new}
        case .rookHunt:return ["a1":"wr","h8":"br","a6":"wp","c5":"wp","e5":"wp","b4":"wp","g4":"wp","d3":"wp","b2":"wp","f2":"wp","a7":"bp","d7":"bp","c6":"bp","f6":"bp","h5":"bp","c4":"bp","f3":"bp","h2":"bp"]
        case .bishopHunt:return ["c1":"wb","f1":"wb","c8":"bb","f8":"bb","b2":"wp","g2":"wp","a3":"wp","d3":"wp","f4":"wp","c5":"wp","e5":"wp","g6":"wp","e3":"bp","a4":"bp","h4":"bp","d5":"bp","f5":"bp","b6":"bp","e7":"bp","h7":"bp"]
        case .hungryHorse:return pawns.merging(["a8":"br","c8":"bb","d8":"bq","e8":"wn","f8":"bb","h8":"br","a1":"wr","c1":"wb","d1":"wq","e1":"bn","f1":"wb","h1":"wr"]){_,new in new}
        case .knightHop:return ["a1":"wn","c3":"bp","f3":"bp","c6":"bp","f6":"bp"]
        }
    }
    func canMove(_ piece:String)->Bool {switch self{case .rookHunt:return piece.hasSuffix("r");case .bishopHunt:return piece.hasSuffix("b");case .hungryHorse,.knightHop:return piece.hasSuffix("n");case .pawnWars:return piece.hasSuffix("p");case .rooksAndPawns:return piece.hasSuffix("p") || piece.hasSuffix("r");case .bishopsAndPawns:return piece.hasSuffix("p") || piece.hasSuffix("b");case .queenChase:return piece.hasSuffix("p") || piece.hasSuffix("q")}}
    var delayedFinish:Bool {self == .rooksAndPawns || self == .bishopsAndPawns || self == .queenChase}
}
public struct MiniGameMove:Codable,Equatable {public let from:String,to:String;public init(from:String,to:String){self.from=from;self.to=to}}
public struct MiniGameSnapshot:Codable,Equatable {
    public var board:Position,turn:String,pendingFinish:String?,cornerIndex:Int,lastMove:MiniGameMove?
}
public struct MiniGameState:Codable,Equatable {
    public static let maximumHistory=256
    public var kind:MiniGameKind,computer:Bool,snapshot:MiniGameSnapshot,history:[MiniGameSnapshot]=[]
    public var opponentSeed:String?
    public init(kind:MiniGameKind,computer:Bool=true){self.kind=kind;self.computer=computer && !kind.solo;opponentSeed=String(UInt64.random(in:UInt64.min...UInt64.max),radix:16);snapshot=MiniGameSnapshot(board:kind.initialBoard,turn:"w",pendingFinish:nil,cornerIndex:0,lastMove:nil)}
    public var board:Position {snapshot.board}
    public var turn:String {snapshot.turn}
    public var winner:String? {
        if kind.solo{return snapshot.cornerIndex==MiniGameRules.corners.count ? "w":nil}
        for side in ["w","b"] {
            let far=side=="w" ? "8":"1",atEnd=board.contains{$0.value==side+"p" && $0.key.hasSuffix(far)}
            if atEnd && (kind == .pawnWars || kind.delayedFinish && turn==side){return side}
            let other=side=="w" ? "b":"w"
            let targets=board.values.filter{$0.hasPrefix(other) && (!(kind == .rookHunt || kind == .bishopHunt) || $0.hasSuffix("p"))}
            if targets.isEmpty{return side}
        }
        return MiniGameRules.moves(board:board,kind:kind,side:turn).isEmpty ? (turn=="w" ? "b":"w"):nil
    }
    public func destinations(from:String)->[String] {guard winner==nil,board[from]?.hasPrefix(turn)==true else{return []};return MiniGameRules.moves(board:board,kind:kind,side:turn).filter{$0.from==from}.map(\.to)}
    @discardableResult public mutating func play(_ move:MiniGameMove,remember:Bool=true)->Bool {
        guard destinations(from:move.from).contains(move.to),let piece=board[move.from] else{return false}
        if remember{history.append(snapshot);if history.count>Self.maximumHistory{history.removeFirst()}}
        snapshot.board.removeValue(forKey:move.from);snapshot.board[move.to]=piece;snapshot.lastMove=move
        if kind.solo {if snapshot.cornerIndex<MiniGameRules.corners.count,move.to==MiniGameRules.corners[snapshot.cornerIndex]{snapshot.cornerIndex+=1}}
        else {
            if let pending=snapshot.pendingFinish,!board.contains(where:{$0.value==pending+"p" && $0.key.hasSuffix(pending=="w" ? "8":"1")}){snapshot.pendingFinish=nil}
            if kind.delayedFinish,piece.hasSuffix("p"),move.to.hasSuffix(turn=="w" ? "8":"1"){snapshot.pendingFinish=turn}
            snapshot.turn=turn=="w" ? "b":"w"
        }
        return true
    }
    public mutating func undo(){guard let previous=history.popLast() else{return};snapshot=previous;if computer,snapshot.turn=="b",let whiteTurn=history.popLast(){snapshot=whiteTurn}}
}
public enum MiniGameRules {
    public static let corners=["h1","h8","a8","a1"]
    private static let straight=[(1,0),(-1,0),(0,1),(0,-1)],diagonal=[(1,1),(1,-1),(-1,1),(-1,-1)]
    private static let jumps=[(1,2),(2,1),(-1,2),(-2,1),(1,-2),(2,-1),(-1,-2),(-2,-1)]
    public static func moves(board:Position,kind:MiniGameKind,side:String)->[MiniGameMove] {
        var result:[MiniGameMove]=[]
        for from in board.keys.sorted() {
            guard let piece=board[from],piece.hasPrefix(side),kind.canMove(piece),ChessRules.validSquare(from) else{continue}
            if piece.hasSuffix("p"){result += CourseLibrary.pawnMoves(board,from:from).map{MiniGameMove(from:from,to:$0)};continue}
            let file=Int(from.utf8.first!-97),rank=Int(from.suffix(1))!-1
            let knight=piece.hasSuffix("n"),directions=knight ? jumps:piece.hasSuffix("b") ? diagonal:piece.hasSuffix("r") ? straight:straight+diagonal
            for (dx,dy) in directions {
                var x=file+dx,y=rank+dy
                while (0..<8).contains(x),(0..<8).contains(y) {
                    let to=String(UnicodeScalar(97+x)!)+String(y+1),occupant=board[to]
                    if occupant?.hasPrefix(side)==true{break}
                    let safe = !kind.solo || occupant==nil && !board.contains{entry in entry.value=="bp" && abs(Int(entry.key.utf8.first!-97)-x)==1 && Int(entry.key.suffix(1))!-2==y}
                    if safe{result.append(MiniGameMove(from:from,to:to))}
                    if occupant != nil || knight{break};x+=dx;y+=dy
                }
            }
        }
        return result
    }
}
public struct MiniOpponentPolicy:Codable,Equatable {
    public let version:Int,maximumDepth:Int,nodeBudget:Int,milliseconds:Int
    public static func forGame(_ kind:MiniGameKind,profile:String)->Self {
        let complex = kind == .pawnWars || kind == .rooksAndPawns || kind == .bishopsAndPawns
        let depth = profile == "beginner" ? 1 : profile == "challenging" ? (complex ? 5:4) : (complex ? 4:3)
        let nodes = profile == "beginner" ? 400 : profile == "challenging" ? (complex ? 12000:7000) : (complex ? 7000:3500)
        return Self(version:2,maximumDepth:depth,nodeBudget:nodes,milliseconds:650)
    }
}
public enum MiniGameOpponent {
    // Bounded search is independent of kings, check and standard-chess promotion.
    public static let replyDelay:Duration = .milliseconds(400),nodeBudget=8_000,maximumDepth=4
    private static let win=100_000,limit=1_000_000
    public static func choose(in state:MiniGameState,profile:String="standard",seed:UInt64=1)->MiniGameMove? {
        let policy=MiniOpponentPolicy.forGame(state.kind,profile:profile),maximumDepth=policy.maximumDepth,nodeBudget=policy.nodeBudget
        let deadline=Date().addingTimeInterval(Double(policy.milliseconds)/1000)
        var random=seed
        func pick(_ moves:[MiniGameMove])->MiniGameMove {random=random &* 6364136223846793005 &+ 1442695040888963407;return moves[Int((random >> 32) % UInt64(moves.count))]}
        func exhausted()->Bool {nodes>=nodeBudget || Task.isCancelled || Date()>=deadline}
        guard !state.kind.solo,state.winner==nil else{return nil}
        let legal=ordered(state);guard var best=legal.first else{return nil}
        var nodes=0
        func evaluate(_ s:MiniGameState)->Int {
            var score=0
            for (square,piece) in s.board {
                let side=piece.hasPrefix("w") ? 1:-1,type=String(piece.suffix(1)),rank=Int(square.suffix(1))!
                let value=["p":100,"n":350,"b":330,"r":500,"q":900][type,default:0]
                score+=side*(value+(type=="p" ? (side==1 ? rank-2:7-rank)*18:0))
            }
            return score
        }
        func search(_ s:MiniGameState,_ depth:Int,_ alpha:Int,_ beta:Int)->Int {
            nodes+=1
            if let winner=s.winner{return (winner=="w" ? 1:-1)*(win+depth)}
            if depth==0 || exhausted(){return evaluate(s)}
            var a=alpha,b=beta,value=s.turn=="w" ? -limit:limit
            for move in ordered(s) {
                var child=s;_ = child.play(move,remember:false)
                let score=search(child,depth-1,a,b)
                if s.turn=="w"{value=max(value,score);a=max(a,value)}else{value=min(value,score);b=min(b,value)}
                if a>=b || exhausted(){break}
            }
            return value
        }
        for depth in 1...maximumDepth {
            var candidates:[MiniGameMove]=[],value=state.turn=="w" ? -limit:limit,complete=true
            for move in legal {
                if exhausted(){complete=false;break}
                var child=state;_ = child.play(move,remember:false)
                let score=search(child,depth-1,-limit,limit)
                if state.turn=="w" ? score>value:score<value{candidates=[move];value=score}else if score==value{candidates.append(move)}
                if exhausted(){complete=false;break}
            }
            if complete,!candidates.isEmpty{best=pick(candidates)}else{break}
        }
        return Task.isCancelled ? nil:best
    }
    private static func ordered(_ state:MiniGameState)->[MiniGameMove] {MiniGameRules.moves(board:state.board,kind:state.kind,side:state.turn).sorted{a,b in
        func priority(_ m:MiniGameMove)->Int {(state.board[m.to] != nil ? 10:0)+(m.to.hasSuffix(state.turn=="w" ? "8":"1") ? 5:0)}
        return priority(a)==priority(b) ? a.from+a.to<b.from+b.to:priority(a)>priority(b)
    }}
}
