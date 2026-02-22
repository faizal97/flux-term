// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FluxTerm",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/migueldeicaza/SwiftTerm.git", from: "1.0.0")
    ],
    targets: [
        .executableTarget(
            name: "FluxTerm",
            dependencies: ["SwiftTerm"],
            resources: [.process("Renderer/Shaders.metal")]
        ),
        .testTarget(
            name: "FluxTermTests",
            dependencies: ["FluxTerm", "SwiftTerm"]
        )
    ]
)
