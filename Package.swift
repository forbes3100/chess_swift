// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "chess_swift",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .library(name: "chess", targets: ["chess"]),
        .executable(name: "chess_cli", targets: ["chess_cli"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "chess",
            path: "Sources/chess",
            swiftSettings: [.unsafeFlags(["-enable-bare-slash-regex"])]
        ),
        .executableTarget(
            name: "chess_cli",
            dependencies: ["chess"],
            path: "Sources/chess_cli",
            swiftSettings: [.unsafeFlags(["-enable-bare-slash-regex"])]
        ),
        .testTarget(
            name: "chessTests",
            dependencies: ["chess"],
            path: "Tests/chessTests",
            resources: [
                .copy("bad_row.txt"),
                .copy("bad_column.txt"),
                .copy("mate_in_2.txt")
            ],
            swiftSettings: [.unsafeFlags(["-enable-bare-slash-regex"])]
        )
    ]
)
