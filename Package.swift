// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Jisticle",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Jisticle", targets: ["Jisticle"])
    ],
    dependencies: [
        .package(url: "https://github.com/ZeeZide/CodeEditor.git", from: "1.0.0"),
        .package(url: "https://github.com/kishikawakatsumi/KeychainAccess.git", from: "4.2.2"),
        .package(url: "https://github.com/gonzalezreal/swift-markdown-ui", from: "2.1.0"),
    ],
    targets: [
        .executableTarget(
            name: "Jisticle",
            dependencies: [
                .product(name: "CodeEditor", package: "CodeEditor"),
                .product(name: "KeychainAccess", package: "KeychainAccess"),
                .product(name: "MarkdownUI", package: "swift-markdown-ui"),
            ],
            exclude: ["Info.plist"],
            resources: [
                .process("Assets.xcassets"),
                .copy("Jisticle.entitlements")
            ]
        ),
        .testTarget(
            name: "JisticleTests",
            dependencies: ["Jisticle"]
        ),
    ]
)
