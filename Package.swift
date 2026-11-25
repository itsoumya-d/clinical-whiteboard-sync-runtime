// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ClinicalWhiteboardRuntime",
    platforms: [
        .macOS(.v13),
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "ClinicalWhiteboardRuntime",
            targets: ["ClinicalWhiteboardRuntime"]
        ),
    ],
    targets: [
        .target(
            name: "ClinicalWhiteboardRuntime",
            dependencies: []
        ),
        .testTarget(
            name: "ClinicalWhiteboardRuntimeTests",
            dependencies: ["ClinicalWhiteboardRuntime"]
        ),
    ]
)
