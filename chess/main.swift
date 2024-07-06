//
//  main.swift -- Minimal Chess
//
//  Created by Scott Forbes on 6/30/24.
//

import Foundation

extension String {
    subscript(i: Int) -> Character {
        return self[index(startIndex, offsetBy: i)]
    }
}

enum ChessError: Error {
    case parse(String)
}

enum Side: Int {
    case black = 0
    case white = 1
}

// Get String representation of a board position.
func posRepr(_ x: Int, _ y: Int) -> String {
    return "\("abcdefgh"[x])\(y + 1)"
}

// A chess piece.
struct Piece: CustomStringConvertible {
    var type: Character
    var side: Side
    var hasMoved: Bool

    init(type: Character = ".", side: Side = .black) {
        self.type = type
        self.side = side
        hasMoved = false
    }

    var description: String {
        if side == .white {
            return " \(type) "
        } else {
            return "{\(type)}"
        }
    }
}

// A chess move of a piece, from (x1, y1) to (x2, y2).
struct Move: CustomStringConvertible {
    var piece: Piece?
    var val: Double
    var x1: Int
    var y1: Int
    var x2: Int
    var y2: Int

    init(piece: Piece? = nil, val: Double = 0.0, x1: Int = 0, y1: Int = 0, x2: Int = 0, y2: Int = 0) {
        self.piece = piece
        self.val = val
        self.x1 = x1
        self.y1 = y1
        self.x2 = x2
        self.y2 = y2
    }

    var description: String {
        if let piece = self.piece {
            if val == 0.0 {
                return "\(piece) \(posRepr(x1, y1)) \(posRepr(x2, y2))"
            } else {
                let formatter = NumberFormatter()
                formatter.numberStyle = .decimal
                formatter.maximumFractionDigits = 2
                formatter.groupingSeparator = ""
                let formattedVal = formatter.string(from: val as NSNumber)
                return "\(piece) \(posRepr(x1, y1)) \(posRepr(x2, y2)) \(formattedVal ?? "")"
            }
        }
        return "-"
    }
}

// A state of the chess board.
struct Board: CustomStringConvertible {
    static let debug = false
    static let maxPlies = 4

    var pos = [Piece](repeating: Piece(), count: 64)
    var side: Side
    var ply: Int
    var piece: Piece
    var bestMove: Move
    var bestMoves = [Move](repeating: Move(), count: maxPlies)
    var x1: Int
    var y1: Int
    var nPlies: Int

    // Piece valuations
    static let valuation: [Character: Int] = ["P": 1, "B": 3, "N": 3, "R": 5, "Q": 10, "K": 1000]

    // List of move directions (dx, dy, maxStep) for each linear-moving piece
    static let legalMoves: [Character: [(Int, Int, Int)]] = [
        "B": [(-1, -1, 8), (-1,  1, 8), (1, -1, 8), (1, 1, 8)],
        "R": [(-1,  0, 8), ( 0, -1, 8), (1,  0, 8), (0, 1, 8)],
        "Q": [(-1, -1, 8), (-1,  1, 8), (1, -1, 8), (1, 1, 8),
              (-1,  0, 8), ( 0, -1, 8), (1,  0, 8), (0, 1, 8)],
        "K": [(-1, -1, 1), (-1,  1, 1), (1, -1, 1), (1, 1, 1),
              (-1,  0, 1), ( 0, -1, 1), (1,  0, 1), (0, 1, 1)]
    ]

    static let legalTypes: String = "PBNRQK"

    init(side: Side = .black, ply: Int = 0, piece: Piece = Piece(), bestMove: Move = Move(),
         x1: Int = 0, y1: Int = 0, nPlies: Int = maxPlies) {
        let backRow = "RNBQKBNR"
        for i in 0..<8 {
            let backType = backRow[i]
            pos[i] = Piece(type: backType, side: .white)
            pos[8 + i] = Piece(type: "P", side: .white)
            pos[6*8 + i] = Piece(type: "P", side: .black)
            pos[7*8 + i] = Piece(type: backType, side: .black)
        }
        self.side = side
        self.ply = ply
        self.piece = piece
        self.bestMove = bestMove
        self.x1 = x1
        self.y1 = y1
        self.nPlies = nPlies
    }

    var description: String {
        var s = "    a  b  c  d  e  f  g  h\n"
        for y in stride(from: 7, through: 0, by: -1) {
            s += "\(y + 1): "
            for x in 0..<8 {
                let p = pos[y * 8 + x]
                if p.type == "." {
                    s += " \(((x + y) & 1) == 1 ? "·" : "-") "
                } else {
                    s += p.description
                }
            }
            if y > 0 {
                s += "\n"
            }
        }
        return s
    }

    public mutating func loadPos(fromDescription description: String) throws {
        let lines = description.split(separator: "\n")
        for line in lines {
            if let match = try? /\ *([1-8]):(.*)/.firstMatch(in: line) {
                let y = Int(match.output.1)! - 1
                if y < 0 || y > 7 {
                    throw ChessError.parse("row \(match.output.1) out of range")
                }
                let pieces = match.output.2
                let matches = pieces.matches(of: /(\{[A-Z]\}|[A-Z]|[\.·-])/)
                if matches.count != 8 {
                    throw ChessError.parse("row \(y + 1): wrong number of columns \(matches.count)")
                }
                var x = 0
                for match in matches {
                    let s = String(match.output.0)
                    if s == "." || s == "·" || s == "-" {
                        pos[y * 8 + x].type = "."
                    } else {
                        let side: Side = s[0] == "{" ? .black : .white
                        let type = side == .black ? s[1] : s[0]
                        if !Board.legalTypes.contains(type) {
                            throw ChessError.parse("bad piece '\(type)'")
                        }
                        var piece = Piece(type: type, side: side)
                        if type == "P" {
                            if (side == .black && y != 6) || (side == .white && y != 1) {
                                piece.hasMoved = true
                            }
                        }
                        pos[y * 8 + x] = piece
                    }
                    x += 1
                }
            }
        }
    }

    public mutating func loadPos(fromFile filename: String) throws {
        if let fileContent = try? String(contentsOfFile: filename) {
            try loadPos(fromDescription: fileContent)
        }
    }

    // Create a copy of board b at next ply, then find the best move for it, setting .bestMove.
    init(findBestMoveFrom b: Board, nPlies: Int = maxPlies) {
        self = b
        self.nPlies = nPlies

        // set up search for our turn
        ply = b.ply + 1
        side = Side(rawValue: 1 - b.side.rawValue)!
        bestMove = Move(val: -9999)

        // for each of X's pieces on board
        for y1 in 0..<8 {
            self.y1 = y1
            for x1 in 0..<8 {
                self.x1 = x1
                // lift piece from starting position (x1, y1)
                piece = pos[y1 * 8 + x1]
                pos[y1 * 8 + x1].type = "."
                if piece.type != "." && piece.side == b.side {
                    // for each possible move of piece, search for best next move
                    let pType = piece.type

                    if pType == "P" {  // pawn
                        let adv = piece.side == .white ? 1 : -1
                        if checkMove(x2: x1, y2: y1 + adv) && !piece.hasMoved {
                            _ = checkMove(x2: x1, y2: y1 + 2*adv)
                        }
                        checkMoves([(1, adv), (-1, adv)], canMove: false)
                    } else if pType == "N" {  // knight
                        checkMoves([(-1, -2), (-2, -1), (1, -2), (2, -1), (1, 2), (2, 1),
                                    (-1, 2), (-2, 1)])
                    } else {  // standard piece: try all legal moves for it
                        findBestMoveLinearly()
                    }
                    if Board.debug {
                        let indent = String(repeating: ".", count: ply)
                        print("\(indent)=> \(bestMove)")
                    }
                }
                // restore original position of our piece
                pos[y1 * 8 + x1] = piece
            }
        }
    }

    // Check all moves from (x1, y1) to relative positions in posList. Updates self.bestMove.
    mutating func checkMoves(_ posList: [(Int, Int)], canCapture: Bool = true, canMove: Bool = true) {
        for (dx, dy) in posList {
            _ = checkMove(x2: x1 + dx, y2: y1 + dy, canCapture: canCapture, canMove: canMove)
        }
    }

    // Find the best move for standard piece at (x1, y1). Updates self.bestMove.
    mutating func findBestMoveLinearly() {
        for (dx, dy, maxDist) in Board.legalMoves[piece.type]! {
            // move starts with self.piece at (x1, y1)
            var x2 = x1
            var y2 = y1
            var remainingDist = maxDist
            while remainingDist > 0 {
                x2 += dx
                y2 += dy
                if !checkMove(x2: x2, y2: y2, canCapture: true, canMove: true) {
                    break
                }
                remainingDist -= 1
            }
        }
    }

    // Check a single move of piece at (x1, y1) to (x2, y2). Updates self.bestMove
    // and returns True if successful.
    mutating func checkMove(x2: Int, y2: Int, canCapture: Bool = false, canMove: Bool = true) -> Bool {

        // stop when we run off of board
        if x2 < 0 || y2 < 0 || x2 >= 8 || y2 >= 8 {
            return false
        }
        var move = Move(piece: piece, x1: x1, y1: y1, x2: x2, y2: y2)
        if Board.debug {
            let indent = String(repeating: ".", count: ply)
            print("\(indent)\(move.description)")
        }
        let piece2 = pos[y2 * 8 + x2]

        if piece2.type != "." {
            if canCapture && piece2.side == side {
                // if move is a capture: move value = piece value
                move.val = Double(Board.valuation[piece2.type]!)
            } else {
                // stop if we run into our own piece
                return false
            }
        } else if !canMove {
            return false
        }

        // best move for each ply will be put here
        var newBestMoves = [Move](repeating: Move(), count: Board.maxPlies)

        // if not at deepest ply level:
        if ply < nPlies {
            // make our actual move
            let origHasMoved = piece.hasMoved
            piece.hasMoved = true
            pos[y2 * 8 + x2] = piece

            // make move for other side on board copy
            let board2 = Board(findBestMoveFrom: self)

            // subtract that move value from our value, with a future discount
            move.val -= 0.9 * board2.bestMove.val
            newBestMoves = board2.bestMoves

            // remove our piece from this position
            pos[y2 * 8 + x2] = piece2
            piece.hasMoved = origHasMoved
        }

        // add in board position value (center is best)
        move.val += 0.8 - (abs(3.5 - Double(x2)) + abs(3.5 - Double(y2))) * 0.1

        // only keep move if best
        if move.val > bestMove.val {
            bestMove = move
            if ply < nPlies {
                bestMoves = newBestMoves
                bestMoves[ply] = move
                if Board.debug {
                    print("ply=\(ply)")
                    for m in bestMoves {
                        print(m.description, terminator: "; ")
                    }
                    print()
                }
            }
        }
        return piece2.type == "."
    }

    // Actually make move m.
    mutating func move(_ move: Move) {
        pos[move.y2 * 8 + move.x2] = pos[move.y1 * 8 + move.x1]
        pos[move.y1 * 8 + move.x1].type = "."
    }
}

func getHumanMove(board: Board, testMode: Bool) -> Move? {
    while true {
        let board2 = Board(findBestMoveFrom: board, nPlies: 1)
        let nextMove = board2.bestMove
        if nextMove.val > 500 {
            print("      Check!")
        }

        print("\nYour move: ", terminator: "")
        var hIn = "a2 a4"
        if testMode {
            print(hIn)
        } else {
            hIn = readLine() ?? ""
            if hIn[0] == "q" {
                break
            }
        }
        let movePattern = /([a-h])([1-8])[^a-h1-8]+([a-h])([1-8])/
        if let result = try? movePattern.wholeMatch(in: hIn) {
            let x1 = Int(result.1.first!.asciiValue! - Character("a").asciiValue!)
            let y1 = Int(String(result.2))! - 1
            let x2 = Int(result.3.first!.asciiValue! - Character("a").asciiValue!)
            let y2 = Int(String(result.4))! - 1

            let hPiece = board.pos[y1 * 8 + x1]
            if hPiece.type != "." && hPiece.side == .white {
                return Move(x1: x1, y1: y1, x2: x2, y2: y2)
            } else {
                print("Not your piece at \(posRepr(x1, y1))")
                continue
            }
        } else {
            print("? Expected a pair of coordinates. Type 'q' to quit.")
        }
    }
    return nil
}

func main() {
    var board = Board()
    var testMode = false

    // if given a starting-position-pattern filename, read in that file
    if CommandLine.arguments.count == 2 {
        if CommandLine.arguments[1] == "-t" {
            testMode = true
        } else {
            let filename = CommandLine.arguments[1]
            do {
                try board.loadPos(fromFile: filename)
            } catch ChessError.parse(let message) {
                print("Error loading file \(filename): \(message)")
            } catch {
                print("Error loading file \(filename)")
            }
        }
    }

    while true {
        print(board)

        // ask human for a move and check it for basic validity
        if let hMove = getHumanMove(board: board, testMode: testMode) {
            board.move(hMove)
        } else {
            return
        }
        print()
        print(board)

        // computer's turn
        let board2 = Board(findBestMoveFrom: board)
        board.move(board2.bestMove)

        // list move predictions
        print("best move: ", terminator: "")
        for move in board2.bestMoves.dropFirst() {
            print(move.description, terminator: "; ")
        }
        print("\n")

        // if our predicted next move is hopeless, computer wins
        if board2.bestMoves[2].val < -500 {
            print(board)
            print("Checkmate!")
            return
        }

        if testMode {
            print()
            print(board)
            break
        }
    }
}

main()
