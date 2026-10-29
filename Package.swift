// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "GuitarJim",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "GuitarJim", targets: ["GuitarPractice"]),
        .executable(name: "GuitarJimAudioCheck", targets: ["GuitarJimAudioCheck"]),
        .library(name: "GuitarPracticeCore", targets: ["GuitarPracticeCore"])
    ],
    targets: [
        .target(name: "GuitarPracticeCore"),
        .target(name: "AudioRingSupport", publicHeadersPath: "include"),
        .executableTarget(name: "GuitarJimAudioCheck", dependencies: ["GuitarPracticeCore"]),
        .executableTarget(name: "GuitarPractice", dependencies: ["GuitarPracticeCore", "AudioRingSupport"], resources: [.process("Resources")]),
        .testTarget(name: "GuitarPracticeCoreTests", dependencies: ["GuitarPracticeCore", "GuitarPractice"])
    ]
)
