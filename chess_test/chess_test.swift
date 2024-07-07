//
//  chess_test.swift
//  chess_test
//
//  Created by Scott Forbes on 7/3/24.
//

import XCTest
@testable import chess

func captureStandardOutput(_ closure: @escaping () -> Void) -> String {
    let outPipe = Pipe()
    var outString = ""
    let sema = DispatchSemaphore(value: 0)

    outPipe.fileHandleForReading.readabilityHandler = { fileHandle in
        let data = fileHandle.availableData
        if data.isEmpty { // end-of-file condition
            fileHandle.readabilityHandler = nil
            sema.signal()
        } else {
            outString += String(data: data, encoding: .utf8) ?? ""
        }
    }

    // Redirect stdout to the pipe
    setvbuf(stdout, nil, _IONBF, 0)
    let savedStdout = dup(STDOUT_FILENO)
    dup2(outPipe.fileHandleForWriting.fileDescriptor, STDOUT_FILENO)

    // Execute the closure
    closure()

    // Restore stdout and close the pipe
    dup2(savedStdout, STDOUT_FILENO)
    try! outPipe.fileHandleForWriting.close()
    close(savedStdout)
    sema.wait() // Wait until the read handler is done

    return outString
}

final class ChessTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testBoardInitialization() {
        let board = Board()
        XCTAssertEqual(board.pos[0].type, "R")
        XCTAssertEqual(board.pos[1].type, "N")
        XCTAssertEqual(board.pos[2].type, "B")
        XCTAssertEqual(board.pos[3].type, "Q")
        XCTAssertEqual(board.pos[4].type, "K")
        XCTAssertEqual(board.pos[5].type, "B")
        XCTAssertEqual(board.pos[6].type, "N")
        XCTAssertEqual(board.pos[7].type, "R")

        for i in 8..<16 {
            XCTAssertEqual(board.pos[i].type, "P")
            XCTAssertEqual(board.pos[i].side, .white)
        }

        for i in 48..<56 {
            XCTAssertEqual(board.pos[i].type, "P")
            XCTAssertEqual(board.pos[i].side, .black)
        }

        XCTAssertEqual(board.pos[56].type, "R")
        XCTAssertEqual(board.pos[57].type, "N")
        XCTAssertEqual(board.pos[58].type, "B")
        XCTAssertEqual(board.pos[59].type, "Q")
        XCTAssertEqual(board.pos[60].type, "K")
        XCTAssertEqual(board.pos[61].type, "B")
        XCTAssertEqual(board.pos[62].type, "N")
        XCTAssertEqual(board.pos[63].type, "R")
    }

    // Trim trailing whitespace from a board description.
    func trim(description: String) -> String {
        return description
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .joined(separator: "\n")
    }

    func testBoardDescription() {
        let board = Board()
        let expectedDescription = """
            a  b  c  d  e  f  g  h
        8: {R}{N}{B}{Q}{K}{B}{N}{R}
        7: {P}{P}{P}{P}{P}{P}{P}{P}
        6:  ·  -  ·  -  ·  -  ·  -
        5:  -  ·  -  ·  -  ·  -  ·
        4:  ·  -  ·  -  ·  -  ·  -
        3:  -  ·  -  ·  -  ·  -  ·
        2:  P  P  P  P  P  P  P  P
        1:  R  N  B  Q  K  B  N  R
        """

        let generatedDescription = trim(description: board.description)
        let expectedTrimmedDescription = trim(description: expectedDescription)
        XCTAssertEqual(generatedDescription, expectedTrimmedDescription)
    }

    // Helper function to compare board states and best move
    func verifyBestMove(from before: String, to after: String, expectedMove: Move) {
        var board = Board()
        do {
            try board.loadPos(fromDescription: before)
        } catch {
            print("Error loading 'before' description")
        }
        let newBoard = Board(findBestMoveFrom: board)
        board.move(newBoard.bestMove)
        print(board.description)
        print(newBoard.bestMove)
        XCTAssertEqual(trim(description: board.description),
                       trim(description: after), "Board state mismatch")
        XCTAssertEqual(newBoard.bestMove.description, expectedMove.description, "Best move mismatch")
    }

    func testBestMove() {
        let before = """
            a  b  c  d  e  f  g  h
        8: {R}{N}{B}{Q}{K}{B}{N}{R}
        7: {P}{P}{P}{P}{P}{P}{P}{P}
        6:  ·  -  ·  -  ·  -  ·  -
        5:  -  ·  -  ·  -  ·  -  ·
        4:  ·  -  ·  -  ·  -  ·  -
        3:  -  ·  -  ·  -  ·  -  ·
        2:  P  P  P  P  P  P  P  P
        1:  R  N  B  Q  K  B  N  R
        """

        let after = """
            a  b  c  d  e  f  g  h
        8: {R}{N}{B}{Q}{K}{B}{N}{R}
        7: {P}{P}{P} · {P}{P}{P}{P}
        6:  ·  -  ·  -  ·  -  ·  -
        5:  -  ·  - {P} -  ·  -  ·
        4:  ·  -  ·  -  ·  -  ·  -
        3:  -  ·  -  ·  -  ·  -  ·
        2:  P  P  P  P  P  P  P  P
        1:  R  N  B  Q  K  B  N  R
        """

        let expectedMove = Move(piece: Piece(type: "P", side: .black), val: 0.05, x1: 3, y1: 6, x2: 3, y2: 4)
        verifyBestMove(from: before, to: after, expectedMove: expectedMove)
    }


    func testCheck() {
        let before = """
            a  b  c  d  e  f  g  h
        8: {R}{N} ·  -  ·  - {N}{R}
        7: {P} · {P} ·  - {P}{P}{P}
        6: {P} -  ·  - {Q} -  ·  -
        5:  -  ·  -  ·  -  ·  -  ·
        4:  ·  -  B  - {P} -  ·  P
        3:  K  · {K} ·  -  ·  -  ·
        2:  ·  -  ·  -  ·  -  ·  -
        1:  -  ·  -  ·  -  ·  N  R
        """

        let after = """
            a  b  c  d  e  f  g  h
        8: {R}{N} ·  -  ·  - {N}{R}
        7: {P} · {P} ·  - {P}{P}{P}
        6: {P} -  ·  -  ·  -  ·  -
        5:  -  ·  -  ·  -  ·  -  ·
        4:  ·  - {Q} - {P} -  ·  P
        3:  K  · {K} ·  -  ·  -  ·
        2:  ·  -  ·  -  ·  -  ·  -
        1:  -  ·  -  ·  -  ·  N  R
        """

        let expectedMove = Move(piece: Piece(type: "Q", side: .black), val: 3.44, x1: 4, y1: 5, x2: 2, y2: 3)
        verifyBestMove(from: before, to: after, expectedMove: expectedMove)
    }

    func testMainWithArguments() {
        let originalArguments = CommandLine.arguments

        CommandLine.arguments = ["chess", "-t"]
        let output = captureStandardOutput {
            main()
        }
        print(output)

        XCTAssertTrue(output.contains("Your move: a2 a4"),
                      "Output should contain human's move.")
        XCTAssertTrue(output.contains("best move: {P} d7 d5 0.05;  P  d2 d4 0.73; {P} e7 e6 -0.03;"),
                      "Output should contain best moves.")
        XCTAssertTrue(output.contains("5:  -  ·  - {P} -  ·  -  · "),
                      "Output should contain diagram of computer's move.")
        XCTAssertTrue(output.contains("4:  P  -  ·  -  ·  -  ·  - "),
                      "Output should contain diagram of human's move.")

        CommandLine.arguments = originalArguments
    }
}
