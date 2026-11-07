// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Ember",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Ember", targets: ["Ember"]),
        .executable(name: "EmberTests", targets: ["EmberTests"])
    ],
    targets: [
        .target(
            name: "EmberLib",
            path: "Sources/Ember"
        ),
        .executableTarget(
            name: "Ember",
            dependencies: ["EmberLib"],
            path: "Sources/EmberApp"
        ),
        .executableTarget(
            name: "EmberTests",
            dependencies: ["EmberLib"],
            path: "Tests/EmberTests"
        )
    ]
)
