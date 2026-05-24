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
        .package(url: "https://github.com/mchakravarty/CodeEditorView.git", from: "0.14.0"),
        .package(url: "https://github.com/kishikawakatsumi/KeychainAccess.git", from: "4.2.2"),
    ],
    targets: [
        .executableTarget(
            name: "Jisticle",
            dependencies: [
                .product(name: "CodeEditorView", package: "CodeEditorView"),
                .product(name: "LanguageSupport", package: "CodeEditorView"),
                .product(name: "KeychainAccess", package: "KeychainAccess"),
            ],
            exclude: ["Info.plist"],
            resources: [
                .process("Assets.xcassets")
            ]
        ),
        .testTarget(
            name: "JisticleTests",
            dependencies: ["Jisticle"]
        ),
    ]
)
