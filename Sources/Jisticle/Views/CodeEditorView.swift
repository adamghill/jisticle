import SwiftUI
import Neon
import SwiftTreeSitter
import TreeSitterBash
import TreeSitterBashQueries
import TreeSitterC
import TreeSitterCQueries
import TreeSitterCSharp
import TreeSitterCSharpQueries
import TreeSitterCPP
import TreeSitterCPPQueries
import TreeSitterCSS
import TreeSitterCSSQueries
import TreeSitterElixir
import TreeSitterElixirQueries
import TreeSitterGo
import TreeSitterGoQueries
import TreeSitterHaskell
import TreeSitterHaskellQueries
import TreeSitterHTML
import TreeSitterHTMLQueries
import TreeSitterJava
import TreeSitterJavaQueries
import TreeSitterJavaScript
import TreeSitterJavaScriptQueries
import TreeSitterJSON
import TreeSitterJSONQueries
import TreeSitterLaTeX
import TreeSitterLaTeXQueries
import TreeSitterLua
import TreeSitterLuaQueries
import TreeSitterMarkdown
import TreeSitterMarkdownQueries
import TreeSitterMarkdownInline
import TreeSitterMarkdownInlineQueries
import TreeSitterPerl
import TreeSitterPerlQueries
import TreeSitterPHP
import TreeSitterPHPQueries
import TreeSitterPython
import TreeSitterPythonQueries
import TreeSitterR
import TreeSitterRQueries
import TreeSitterRuby
import TreeSitterRubyQueries
import TreeSitterRust
import TreeSitterRustQueries
import TreeSitterSCSS
import TreeSitterSCSSQueries
import TreeSitterSQL
import TreeSitterSQLQueries
import TreeSitterSwift
import TreeSitterSwiftQueries
import TreeSitterTOML
import TreeSitterTOMLQueries
import TreeSitterTSX
import TreeSitterTSXQueries
import TreeSitterTypeScript
import TreeSitterTypeScriptQueries
import TreeSitterYAML
import TreeSitterYAMLQueries

@MainActor
struct CodeEditorView: NSViewRepresentable {
    /// Content size above which syntax highlighting is skipped to avoid
    /// initial load pauses. 2MB of code is typically ~40k lines; contiguous
    /// layout is still fast, but tree-sitter highlighting the visible range
    /// plus tokenization overhead can produce a noticeable hiccup.
    static let highlightingSizeThreshold = 2 * 1024 * 1024  // 2 MB

    @Binding var text: String
    let language: Language
    let theme: EditorTheme
    let fontSize: Binding<CGFloat>
    let isEditable: Bool
    let onTextChange: ((String) -> Void)?
    
    init(
        text: Binding<String>,
        language: Language = .plaintext,
        theme: EditorTheme = .github,
        fontSize: Binding<CGFloat>,
        isEditable: Bool = true,
        onTextChange: ((String) -> Void)? = nil
    ) {
        self._text = text
        self.language = language
        self.theme = theme
        self.fontSize = fontSize
        self.isEditable = isEditable
        self.onTextChange = onTextChange
    }
    
    func makeNSView(context: Context) -> NSScrollView {
        // Use a TextKit 1 text view. Neon highlights TextKit 1 views via the
        // layout manager's *temporary attributes*, which persist for the entire
        // document regardless of layout. TextKit 2's rendering attributes only
        // stick for ranges that have already been laid out (the visible
        // viewport), which leaves large documents unhighlighted until scrolled.
        let textView = NSTextView(usingTextLayoutManager: false)

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.documentView = textView

        let maxDimension = CGFloat.greatestFiniteMagnitude
        textView.minSize = .zero
        textView.maxSize = NSSize(width: maxDimension, height: maxDimension)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]

        // Lay out the whole document contiguously. Non-contiguous (lazy) layout
        // only lays out the visible viewport and *estimates* the rest, which
        // makes scrolling long files jerky: the scroller thumb and content jump
        // as real layout catches up when you reach the bottom. Gists are small
        // enough that full layout is cheap and gives smooth, accurate scrolling.
        textView.layoutManager?.allowsNonContiguousLayout = false

        // Configure text view
        textView.isEditable = isEditable
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.enabledTextCheckingTypes = 0

        // Font and layout
        updateFont(for: textView)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: maxDimension, height: maxDimension)

        // Setup highlighting first so Neon's NSTextStorageDelegate is attached
        // before the initial content is set.
        context.coordinator.setupHighlighting(textView: textView, language: language, theme: theme)

        // Set initial text after highlighting is configured so the content
        // flows through Neon's storage delegate and triggers a full highlight
        // pass.
        textView.string = text

        // Set delegate
        textView.delegate = context.coordinator

        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        
        // Update text if it changed externally (not from typing)
        if textView.string != text && !context.coordinator.isProcessingChange {
            let selectedRange = textView.selectedRange()
            textView.string = text
            textView.setSelectedRange(selectedRange)
        }
        
        // Update font size
        updateFont(for: textView)
        
        // Update theme if needed
        if context.coordinator.currentTheme != theme {
            context.coordinator.updateTheme(theme, for: textView)
        }
        
        // Update language if needed
        if context.coordinator.currentLanguage != language {
            context.coordinator.updateLanguage(language, for: textView)
        }
        
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    private func updateFont(for textView: NSTextView) {
        let font = NSFont.monospacedSystemFont(ofSize: fontSize.wrappedValue, weight: .regular)
        textView.font = font
    }
    
    @MainActor
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: CodeEditorView
        var highlighter: TextViewHighlighter?
        var isProcessingChange = false
        var currentTheme: EditorTheme = .github
        var currentLanguage: Language = .plaintext
        
        init(_ parent: CodeEditorView) {
            self.parent = parent
            super.init()
        }
        
        func setupHighlighting(textView: NSTextView, language: Language, theme: EditorTheme) {
            self.currentLanguage = language
            self.currentTheme = theme

            // Skip highlighting for large files to avoid initial load pauses.
            // Contiguous layout of the text itself is fast, but tree-sitter
            // tokenization + attribute application for the visible range can
            // produce a noticeable hiccup on files above the threshold.
            let contentSize = textView.string.utf8.count
            guard contentSize < CodeEditorView.highlightingSizeThreshold else {
                print("Content size \(contentSize) exceeds threshold; skipping highlighting")
                return
            }

            // Create language configuration
            guard let languageConfig = language.languageConfiguration else {
                // No highlighting for plaintext
                return
            }
            
            // Create the highlighter configuration.
            //
            // The languageProvider resolves injected/embedded grammars. Markdown
            // in particular delegates all inline content (emphasis, strong,
            // links, code spans) to the `markdown_inline` grammar via injection,
            // so it must be provided here or inline markdown is left unstyled.
            let config = TextViewHighlighter.Configuration(
                languageConfiguration: languageConfig,
                attributeProvider: theme.attributeProvider,
                languageProvider: { Language.injectedLanguageConfiguration(named: $0) },
                locationTransformer: { _ in nil }
            )
            
            do {
                let highlighter = try TextViewHighlighter(textView: textView, configuration: config)
                self.highlighter = highlighter
                highlighter.observeEnclosingScrollView()
            } catch {
                print("Failed to create highlighter: \(error)")
            }
        }
        
        func updateTheme(_ theme: EditorTheme, for textView: NSTextView) {
            currentTheme = theme
            // Recreate highlighter with new theme
            highlighter = nil
            setupHighlighting(textView: textView, language: currentLanguage, theme: theme)
        }
        
        func updateLanguage(_ language: Language, for textView: NSTextView) {
            currentLanguage = language
            
            // Recreate highlighter with new language
            highlighter = nil
            
            setupHighlighting(textView: textView, language: language, theme: currentTheme)
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            
            isProcessingChange = true
            parent.text = textView.string
            parent.onTextChange?(textView.string)
            isProcessingChange = false
        }
    }
}

// MARK: - Language Enum

enum Language: String, CaseIterable, Equatable {
    case plaintext = "plaintext"
    case swift = "swift"
    case python = "python"
    case javascript = "javascript"
    case typescript = "typescript"
    case tsx = "tsx"
    case jsx = "jsx"
    case ruby = "ruby"
    case go = "go"
    case rust = "rust"
    case java = "java"
    case kotlin = "kotlin"
    case csharp = "csharp"
    case cpp = "cpp"
    case c = "c"
    case objectivec = "objectivec"
    case shell = "shell"
    case html = "html"
    case css = "css"
    case scss = "scss"
    case json = "json"
    case xml = "xml"
    case yaml = "yaml"
    case toml = "toml"
    case markdown = "markdown"
    case sql = "sql"
    case r = "r"
    case php = "php"
    case perl = "perl"
    case lua = "lua"
    case haskell = "haskell"
    case elixir = "elixir"
    case erlang = "erlang"
    case scala = "scala"
    case dart = "dart"
    case dockerfile = "dockerfile"
    case makefile = "makefile"
    case ini = "ini"
    case tex = "tex"
    case vim = "vim"
    
    var languageConfiguration: LanguageConfiguration? {
        switch self {
        case .plaintext:
            return nil
        case .swift:
            let queriesURL = TreeSitterSwiftQueries.Query.highlightsFileURL.deletingLastPathComponent()
            return try? LanguageConfiguration(tree_sitter_swift(), name: "Swift", queriesURL: queriesURL)
        case .python:
            let queriesURL = TreeSitterPythonQueries.Query.highlightsFileURL.deletingLastPathComponent()
            return try? LanguageConfiguration(tree_sitter_python(), name: "Python", queriesURL: queriesURL)
        case .javascript, .jsx:
            let queriesURL = TreeSitterJavaScriptQueries.Query.highlightsFileURL.deletingLastPathComponent()
            return try? LanguageConfiguration(tree_sitter_javascript(), name: "JavaScript", queriesURL: queriesURL)
        case .typescript:
            let queriesURL = TreeSitterTypeScriptQueries.Query.highlightsFileURL.deletingLastPathComponent()
            return try? LanguageConfiguration(tree_sitter_typescript(), name: "TypeScript", queriesURL: queriesURL)
        case .tsx:
            let queriesURL = TreeSitterTSXQueries.Query.highlightsFileURL.deletingLastPathComponent()
            return try? LanguageConfiguration(tree_sitter_tsx(), name: "TSX", queriesURL: queriesURL)
        case .ruby:
            let queriesURL = TreeSitterRubyQueries.Query.highlightsFileURL.deletingLastPathComponent()
            return try? LanguageConfiguration(tree_sitter_ruby(), name: "Ruby", queriesURL: queriesURL)
        case .go:
            let queriesURL = TreeSitterGoQueries.Query.highlightsFileURL.deletingLastPathComponent()
            return try? LanguageConfiguration(tree_sitter_go(), name: "Go", queriesURL: queriesURL)
        case .rust:
            let queriesURL = TreeSitterRustQueries.Query.highlightsFileURL.deletingLastPathComponent()
            return try? LanguageConfiguration(tree_sitter_rust(), name: "Rust", queriesURL: queriesURL)
        case .java:
            let queriesURL = TreeSitterJavaQueries.Query.highlightsFileURL.deletingLastPathComponent()
            return try? LanguageConfiguration(tree_sitter_java(), name: "Java", queriesURL: queriesURL)
        case .csharp:
            let queriesURL = TreeSitterCSharpQueries.Query.highlightsFileURL.deletingLastPathComponent()
            return try? LanguageConfiguration(tree_sitter_c_sharp(), name: "C#", queriesURL: queriesURL)
        case .cpp:
            let queriesURL = TreeSitterCPPQueries.Query.highlightsFileURL.deletingLastPathComponent()
            return try? LanguageConfiguration(tree_sitter_cpp(), name: "C++", queriesURL: queriesURL)
        case .c:
            let queriesURL = TreeSitterCQueries.Query.highlightsFileURL.deletingLastPathComponent()
            return try? LanguageConfiguration(tree_sitter_c(), name: "C", queriesURL: queriesURL)
        case .shell:
            let queriesURL = TreeSitterBashQueries.Query.highlightsFileURL.deletingLastPathComponent()
            return try? LanguageConfiguration(tree_sitter_bash(), name: "Bash", queriesURL: queriesURL)
        case .html, .xml:
            let queriesURL = TreeSitterHTMLQueries.Query.highlightsFileURL.deletingLastPathComponent()
            return try? LanguageConfiguration(tree_sitter_html(), name: "HTML", queriesURL: queriesURL)
        case .css:
            let queriesURL = TreeSitterCSSQueries.Query.highlightsFileURL.deletingLastPathComponent()
            return try? LanguageConfiguration(tree_sitter_css(), name: "CSS", queriesURL: queriesURL)
        case .scss:
            let queriesURL = TreeSitterSCSSQueries.Query.highlightsFileURL.deletingLastPathComponent()
            return try? LanguageConfiguration(tree_sitter_scss(), name: "SCSS", queriesURL: queriesURL)
        case .json:
            let queriesURL = TreeSitterJSONQueries.Query.highlightsFileURL.deletingLastPathComponent()
            return try? LanguageConfiguration(tree_sitter_json(), name: "JSON", queriesURL: queriesURL)
        case .yaml:
            let queriesURL = TreeSitterYAMLQueries.Query.highlightsFileURL.deletingLastPathComponent()
            return try? LanguageConfiguration(tree_sitter_yaml(), name: "YAML", queriesURL: queriesURL)
        case .toml, .ini:
            let queriesURL = TreeSitterTOMLQueries.Query.highlightsFileURL.deletingLastPathComponent()
            return try? LanguageConfiguration(tree_sitter_toml(), name: "TOML", queriesURL: queriesURL)
        case .markdown:
            let queriesURL = TreeSitterMarkdownQueries.Query.highlightsFileURL.deletingLastPathComponent()
            return try? LanguageConfiguration(tree_sitter_markdown(), name: "Markdown", queriesURL: queriesURL)
        case .sql:
            let queriesURL = TreeSitterSQLQueries.Query.highlightsFileURL.deletingLastPathComponent()
            return try? LanguageConfiguration(tree_sitter_sql(), name: "SQL", queriesURL: queriesURL)
        case .r:
            let queriesURL = TreeSitterRQueries.Query.highlightsFileURL.deletingLastPathComponent()
            return try? LanguageConfiguration(tree_sitter_r(), name: "R", queriesURL: queriesURL)
        case .php:
            let queriesURL = TreeSitterPHPQueries.Query.highlightsFileURL.deletingLastPathComponent()
            return try? LanguageConfiguration(tree_sitter_php(), name: "PHP", queriesURL: queriesURL)
        case .perl:
            let queriesURL = TreeSitterPerlQueries.Query.highlightsFileURL.deletingLastPathComponent()
            return try? LanguageConfiguration(tree_sitter_perl(), name: "Perl", queriesURL: queriesURL)
        case .lua:
            let queriesURL = TreeSitterLuaQueries.Query.highlightsFileURL.deletingLastPathComponent()
            return try? LanguageConfiguration(tree_sitter_lua(), name: "Lua", queriesURL: queriesURL)
        case .haskell:
            let queriesURL = TreeSitterHaskellQueries.Query.highlightsFileURL.deletingLastPathComponent()
            return try? LanguageConfiguration(tree_sitter_haskell(), name: "Haskell", queriesURL: queriesURL)
        case .elixir:
            let queriesURL = TreeSitterElixirQueries.Query.highlightsFileURL.deletingLastPathComponent()
            return try? LanguageConfiguration(tree_sitter_elixir(), name: "Elixir", queriesURL: queriesURL)
        case .tex:
            let queriesURL = TreeSitterLaTeXQueries.Query.highlightsFileURL.deletingLastPathComponent()
            return try? LanguageConfiguration(tree_sitter_latex(), name: "LaTeX", queriesURL: queriesURL)
        case .kotlin, .erlang, .scala, .dart, .dockerfile, .makefile, .vim, .objectivec:
            return nil
        }
    }

    /// Resolves embedded/injected grammars requested by a root grammar.
    ///
    /// Tree-sitter Markdown is split into a block grammar and an inline grammar.
    /// The block grammar injects `markdown_inline` to handle all inline content
    /// (emphasis, strong, links, code spans), so it must be provided here.
    static func injectedLanguageConfiguration(named name: String) -> LanguageConfiguration? {
        switch name {
        case "markdown_inline", "markdown.inline":
            let queriesURL = TreeSitterMarkdownInlineQueries.Query.highlightsFileURL.deletingLastPathComponent()
            return try? LanguageConfiguration(tree_sitter_markdown_inline(), name: "MarkdownInline", queriesURL: queriesURL)
        default:
            return nil
        }
    }
}

// MARK: - Theme

enum EditorTheme: Equatable {
    case github
    case githubDark
    
    var backgroundColor: NSColor {
        switch self {
        case .github:
            return .white
        case .githubDark:
            return NSColor(red: 0.13, green: 0.15, blue: 0.18, alpha: 1.0)
        }
    }
    
    var foregroundColor: NSColor {
        switch self {
        case .github:
            return .black
        case .githubDark:
            return NSColor(red: 0.86, green: 0.87, blue: 0.89, alpha: 1.0)
        }
    }
    
    var attributeProvider: TokenAttributeProvider {
        let regularFont = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        let boldFont = NSFont.monospacedSystemFont(ofSize: 14, weight: .bold)
        let italicDescriptor = regularFont.fontDescriptor.withSymbolicTraits(.italic)
        let italicFont = NSFont(descriptor: italicDescriptor, size: 14) ?? regularFont
        
        return { token in
            switch token.name {
            case let keyword where keyword.hasPrefix("keyword"):
                return [.foregroundColor: self.keywordColor, .font: boldFont]
            case "string", "string.special", "string.regex", "string.escape", "character":
                return [.foregroundColor: self.stringColor, .font: regularFont]
            case "comment":
                return [.foregroundColor: self.commentColor, .font: italicFont]
            case "number", "float":
                return [.foregroundColor: self.numberColor, .font: regularFont]
            case "function", "method", "function.call", "method.call", "function.macro", "macro":
                return [.foregroundColor: self.functionColor, .font: regularFont]
            case "type", "class", "type.builtin", "type.definition", "type.qualifier":
                return [.foregroundColor: self.typeColor, .font: regularFont]
            case "property", "attribute", "field", "parameter":
                return [.foregroundColor: self.propertyColor, .font: regularFont]
            case "variable", "variable.parameter":
                return [.foregroundColor: self.propertyColor, .font: regularFont]
            case "variable.builtin", "constant.builtin", "boolean":
                return [.foregroundColor: self.keywordColor, .font: boldFont]
            case "constant", "constant.macro":
                return [.foregroundColor: self.numberColor, .font: regularFont]
            case "namespace", "module":
                return [.foregroundColor: self.typeColor, .font: regularFont]
            case "constructor":
                return [.foregroundColor: self.functionColor, .font: regularFont]
            case "tag", "tag.attribute":
                return [.foregroundColor: self.keywordColor, .font: regularFont]
            case "tag.delimiter":
                return [.foregroundColor: self.keywordColor, .font: regularFont]
            case "label":
                return [.foregroundColor: self.typeColor, .font: regularFont]
            case "operator", "keyword.operator":
                return [.foregroundColor: self.foregroundColor, .font: regularFont]
            case "punctuation", "punctuation.bracket", "punctuation.delimiter":
                return [.foregroundColor: self.foregroundColor, .font: regularFont]
            case "punctuation.special":
                return [.foregroundColor: self.keywordColor, .font: regularFont]
            case "include", "exception", "conditional", "repeat", "debug", "define", "preproc":
                return [.foregroundColor: self.keywordColor, .font: boldFont]

            // Markdown (block + inline grammar) capture names.
            case "text.title":
                return [.foregroundColor: self.keywordColor, .font: boldFont]
            case "text.literal":
                return [.foregroundColor: self.stringColor, .font: regularFont]
            case "text.emphasis":
                return [.foregroundColor: self.foregroundColor, .font: italicFont]
            case "text.strong":
                return [.foregroundColor: self.foregroundColor, .font: boldFont]
            case "text.uri", "text.reference":
                return [.foregroundColor: self.functionColor, .font: regularFont]

            default:
                return [.foregroundColor: self.foregroundColor, .font: regularFont]
            }
        }
    }
    
    private var keywordColor: NSColor {
        switch self {
        case .github:
            return NSColor(red: 0.8, green: 0.07, blue: 0.36, alpha: 1.0)
        case .githubDark:
            return NSColor(red: 0.95, green: 0.33, blue: 0.52, alpha: 1.0)
        }
    }
    
    private var stringColor: NSColor {
        switch self {
        case .github:
            return NSColor(red: 0.03, green: 0.45, blue: 0.03, alpha: 1.0)
        case .githubDark:
            return NSColor(red: 0.6, green: 0.82, blue: 0.56, alpha: 1.0)
        }
    }
    
    private var commentColor: NSColor {
        switch self {
        case .github:
            return NSColor(red: 0.35, green: 0.42, blue: 0.49, alpha: 1.0)
        case .githubDark:
            return NSColor(red: 0.55, green: 0.62, blue: 0.69, alpha: 1.0)
        }
    }
    
    private var numberColor: NSColor {
        switch self {
        case .github:
            return NSColor(red: 0.0, green: 0.4, blue: 0.8, alpha: 1.0)
        case .githubDark:
            return NSColor(red: 0.9, green: 0.75, blue: 0.45, alpha: 1.0)
        }
    }
    
    private var functionColor: NSColor {
        switch self {
        case .github:
            return NSColor(red: 0.05, green: 0.25, blue: 0.55, alpha: 1.0)
        case .githubDark:
            return NSColor(red: 0.62, green: 0.83, blue: 0.99, alpha: 1.0)
        }
    }
    
    private var typeColor: NSColor {
        switch self {
        case .github:
            return NSColor(red: 0.55, green: 0.32, blue: 0.07, alpha: 1.0)
        case .githubDark:
            return NSColor(red: 0.86, green: 0.76, blue: 0.47, alpha: 1.0)
        }
    }
    
    private var propertyColor: NSColor {
        switch self {
        case .github:
            return NSColor(red: 0.0, green: 0.38, blue: 0.6, alpha: 1.0)
        case .githubDark:
            return NSColor(red: 0.6, green: 0.82, blue: 0.99, alpha: 1.0)
        }
    }
}
