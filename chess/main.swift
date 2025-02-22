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

// Get String representation of a board position.
func posRepr(_ i: Int) -> String {
    return "\("abcdefgh"[i % 8])\((i / 8) + 1)"
}

// A chess piece.
struct Piece: CustomStringConvertible {
    var type: Character
    var isWhite: Bool
    var hasMoved: Bool

    init(type: Character = ".", isWhite: Bool = false) {
        self.type = type
        self.isWhite = isWhite
        hasMoved = false
    }

    var description: String {
        if isWhite {
            return " \(type) "
        } else {
            return "{\(type)}"
        }
    }
}

// A chess move of a piece, from i1 to i2.
struct Move: CustomStringConvertible {
    var piece: Piece?
    var val: Double
    var i1: Int
    var i2: Int

    init(piece: Piece? = nil, val: Double = 0.0, i1: Int = 0, i2: Int = 0) {
        self.piece = piece
        self.val = val
        self.i1 = i1
        self.i2 = i2
    }

    var description: String {
        if let piece = self.piece {
            if val == 0.0 {
                return "\(piece) \(posRepr(i1)) \(posRepr(i2))"
            } else {
                let formatter = NumberFormatter()
                formatter.numberStyle = .decimal
                formatter.maximumFractionDigits = 2
                formatter.groupingSeparator = ""
                let formattedVal = formatter.string(from: val as NSNumber)
                return "\(piece) \(posRepr(i1)) \(posRepr(i2)) \(formattedVal ?? "")"
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
    var isWhite: Bool
    var ply: Int
    var piece: Piece
    var bestMove: Move
    var bestMoves = [Move](repeating: Move(), count: maxPlies)
    var i1: Int
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

    init(isWhite: Bool = false, ply: Int = 0, piece: Piece = Piece(), bestMove: Move = Move(),
         i1: Int = 0, nPlies: Int = maxPlies) {
        let backRow = "RNBQKBNR"
        for i in 0..<8 {
            let backType = backRow[i]
            pos[i] = Piece(type: backType, isWhite: true)
            pos[8 + i] = Piece(type: "P", isWhite: true)
            pos[6*8 + i] = Piece(type: "P", isWhite: false)
            pos[7*8 + i] = Piece(type: backType, isWhite: false)
        }
        self.isWhite = isWhite
        self.ply = ply
        self.piece = piece
        self.bestMove = bestMove
        self.i1 = i1
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
                var i = y * 8
                for match in matches {
                    let s = String(match.output.0)
                    if s == "." || s == "·" || s == "-" {
                        pos[i].type = "."
                    } else {
                        let isWhite = s[0] != "{"
                        let type = isWhite ? s[0] : s[1]
                        if !Board.legalTypes.contains(type) {
                            throw ChessError.parse("bad piece '\(type)'")
                        }
                        var piece = Piece(type: type, isWhite: isWhite)
                        if type == "P" {
                            if (!isWhite && y != 6) || (isWhite && y != 1) {
                                piece.hasMoved = true
                            }
                        }
                        pos[i] = piece
                    }
                    i += 1
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
        isWhite = !isWhite
        bestMove = Move(val: -9999)

        // for each of X's pieces on board
        for y1 in 0..<8 {
            for x1 in 0..<8 {
                i1 = y1 * 8 + x1
                // lift piece from starting position (x1, y1)
                piece = pos[i1]
                pos[i1].type = "."
                if piece.type != "." && piece.isWhite == b.isWhite {
                    // for each possible move of piece, search for best next move
                    let pType = piece.type

                    if pType == "P" {  // pawn
                        let adv = piece.isWhite ? 1 : -1
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
                pos[i1] = piece
            }
        }
    }

    // Check all moves from (x1, y1) to relative positions in posList. Updates self.bestMove.
    mutating func checkMoves(_ posList: [(Int, Int)], canCapture: Bool = true, canMove: Bool = true) {
        for (dx, dy) in posList {
            let x1 = i1 % 8
            let y1 = i1 / 8
            _ = checkMove(x2: x1 + dx, y2: y1 + dy, canCapture: canCapture, canMove: canMove)
        }
    }

    // Find the best move for standard piece at (x1, y1). Updates self.bestMove.
    mutating func findBestMoveLinearly() {
        for (dx, dy, maxDist) in Board.legalMoves[piece.type]! {
            // move starts with self.piece at (x1, y1)
            var x2 = i1 % 8
            var y2 = i1 / 8
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
        let i2 = y2 * 8 + x2
        var move = Move(piece: piece, i1: i1, i2: i2)
        if Board.debug {
            let indent = String(repeating: ".", count: ply)
            print("\(indent)\(move.description)")
        }
        let piece2 = pos[i2]

        if piece2.type != "." {
            if canCapture && piece2.isWhite == isWhite {
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
            pos[i2] = piece

            // make move for other side on board copy
            let board2 = Board(findBestMoveFrom: self)

            // subtract that move value from our value, with a future discount
            move.val -= 0.9 * board2.bestMove.val
            newBestMoves = board2.bestMoves

            // remove our piece from this position
            pos[i2] = piece2
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
        pos[move.i2] = pos[move.i1]
        pos[move.i1].type = "."
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

            let i1 = y1 * 8 + x1
            let i2 = y2 * 8 + x2
            let hPiece = board.pos[i1]
            if hPiece.type != "." && hPiece.isWhite {
                return Move(i1: i1, i2: i2)
            } else {
                print("Not your piece at \(posRepr(i1))")
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
