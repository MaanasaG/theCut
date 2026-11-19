// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "PomvoxSpeech",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "PomvoxSpeech", targets: ["PomvoxSpeech"]),
    ],
    dependencies: [
        // Same FluidAudio pin range as Pomvox.app (Parakeet on Neural Engine).
        .package(url: "https://github.com/FluidInference/FluidAudio.git", "0.15.0"..<"0.15.6"),
    ],
    targets: [
        .target(
            name: "PomvoxSpeech",
            dependencies: [
                .product(name: "FluidAudio", package: "FluidAudio"),
            ]
        ),
    ]
)
