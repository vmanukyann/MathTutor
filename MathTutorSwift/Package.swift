// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MathTutorSwift",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "MathTutorCore", targets: ["MathTutorCore"]),
        .executable(name: "MathTutorCoreChecks", targets: ["MathTutorCoreChecks"])
    ],
    targets: [
        .target(name: "MathTutorCore"),
        .executableTarget(
            name: "MathTutorCoreChecks",
            dependencies: ["MathTutorCore"]
        )
    ]
)
