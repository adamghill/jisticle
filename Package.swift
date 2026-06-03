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
        .package(url: "https://github.com/kishikawakatsumi/KeychainAccess.git", from: "4.2.2"),
        .package(url: "https://github.com/gonzalezreal/swift-markdown-ui", from: "2.1.0"),
        .package(url: "https://github.com/ChimeHQ/SwiftTreeSitter", from: "0.8.0"),
        .package(url: "https://github.com/ChimeHQ/Neon", revision: "484d6fb"),
        .package(url: "https://github.com/simonbs/TreeSitterLanguages", from: "0.1.10"),
    ],
    targets: [
        .executableTarget(
            name: "Jisticle",
            dependencies: [
                .product(name: "KeychainAccess", package: "KeychainAccess"),
                .product(name: "MarkdownUI", package: "swift-markdown-ui"),
                .product(name: "SwiftTreeSitter", package: "SwiftTreeSitter"),
                .product(name: "Neon", package: "Neon"),
                // TreeSitter language parsers + highlight queries
                .product(name: "TreeSitterBash", package: "TreeSitterLanguages"),
                .product(name: "TreeSitterBashQueries", package: "TreeSitterLanguages"),
                .product(name: "TreeSitterC", package: "TreeSitterLanguages"),
                .product(name: "TreeSitterCQueries", package: "TreeSitterLanguages"),
                .product(name: "TreeSitterCSharp", package: "TreeSitterLanguages"),
                .product(name: "TreeSitterCSharpQueries", package: "TreeSitterLanguages"),
                .product(name: "TreeSitterCPP", package: "TreeSitterLanguages"),
                .product(name: "TreeSitterCPPQueries", package: "TreeSitterLanguages"),
                .product(name: "TreeSitterCSS", package: "TreeSitterLanguages"),
                .product(name: "TreeSitterCSSQueries", package: "TreeSitterLanguages"),
                .product(name: "TreeSitterElixir", package: "TreeSitterLanguages"),
                .product(name: "TreeSitterElixirQueries", package: "TreeSitterLanguages"),
                .product(name: "TreeSitterGo", package: "TreeSitterLanguages"),
                .product(name: "TreeSitterGoQueries", package: "TreeSitterLanguages"),
                .product(name: "TreeSitterHaskell", package: "TreeSitterLanguages"),
                .product(name: "TreeSitterHaskellQueries", package: "TreeSitterLanguages"),
                .product(name: "TreeSitterHTML", package: "TreeSitterLanguages"),
                .product(name: "TreeSitterHTMLQueries", package: "TreeSitterLanguages"),
                .product(name: "TreeSitterJava", package: "TreeSitterLanguages"),
                .product(name: "TreeSitterJavaQueries", package: "TreeSitterLanguages"),
                .product(name: "TreeSitterJavaScript", package: "TreeSitterLanguages"),
                .product(name: "TreeSitterJavaScriptQueries", package: "TreeSitterLanguages"),
                .product(name: "TreeSitterJSON", package: "TreeSitterLanguages"),
                .product(name: "TreeSitterJSONQueries", package: "TreeSitterLanguages"),
                .product(name: "TreeSitterLaTeX", package: "TreeSitterLanguages"),
                .product(name: "TreeSitterLaTeXQueries", package: "TreeSitterLanguages"),
                .product(name: "TreeSitterLua", package: "TreeSitterLanguages"),
                .product(name: "TreeSitterLuaQueries", package: "TreeSitterLanguages"),
                .product(name: "TreeSitterMarkdown", package: "TreeSitterLanguages"),
                .product(name: "TreeSitterMarkdownQueries", package: "TreeSitterLanguages"),
                .product(name: "TreeSitterMarkdownInline", package: "TreeSitterLanguages"),
                .product(name: "TreeSitterMarkdownInlineQueries", package: "TreeSitterLanguages"),
                .product(name: "TreeSitterPerl", package: "TreeSitterLanguages"),
                .product(name: "TreeSitterPerlQueries", package: "TreeSitterLanguages"),
                .product(name: "TreeSitterPHP", package: "TreeSitterLanguages"),
                .product(name: "TreeSitterPHPQueries", package: "TreeSitterLanguages"),
                .product(name: "TreeSitterPython", package: "TreeSitterLanguages"),
                .product(name: "TreeSitterPythonQueries", package: "TreeSitterLanguages"),
                .product(name: "TreeSitterR", package: "TreeSitterLanguages"),
                .product(name: "TreeSitterRQueries", package: "TreeSitterLanguages"),
                .product(name: "TreeSitterRuby", package: "TreeSitterLanguages"),
                .product(name: "TreeSitterRubyQueries", package: "TreeSitterLanguages"),
                .product(name: "TreeSitterRust", package: "TreeSitterLanguages"),
                .product(name: "TreeSitterRustQueries", package: "TreeSitterLanguages"),
                .product(name: "TreeSitterSCSS", package: "TreeSitterLanguages"),
                .product(name: "TreeSitterSCSSQueries", package: "TreeSitterLanguages"),
                .product(name: "TreeSitterSQL", package: "TreeSitterLanguages"),
                .product(name: "TreeSitterSQLQueries", package: "TreeSitterLanguages"),
                .product(name: "TreeSitterSwift", package: "TreeSitterLanguages"),
                .product(name: "TreeSitterSwiftQueries", package: "TreeSitterLanguages"),
                .product(name: "TreeSitterTOML", package: "TreeSitterLanguages"),
                .product(name: "TreeSitterTOMLQueries", package: "TreeSitterLanguages"),
                .product(name: "TreeSitterTSX", package: "TreeSitterLanguages"),
                .product(name: "TreeSitterTSXQueries", package: "TreeSitterLanguages"),
                .product(name: "TreeSitterTypeScript", package: "TreeSitterLanguages"),
                .product(name: "TreeSitterTypeScriptQueries", package: "TreeSitterLanguages"),
                .product(name: "TreeSitterYAML", package: "TreeSitterLanguages"),
                .product(name: "TreeSitterYAMLQueries", package: "TreeSitterLanguages"),
            ],
            exclude: ["Info.plist"],
            resources: [
                .process("Assets.xcassets"),
                .copy("Jisticle.entitlements")
            ],
        ),
        .testTarget(
            name: "JisticleTests",
            dependencies: ["Jisticle"]
        ),
    ]
)
