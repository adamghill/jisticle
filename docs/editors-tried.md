# Editors Tried in Jisticle

This document tracks the different code editor approaches tried during Jisticle's development.

## 1. mchakravarty/CodeEditorView (TextKit 2 based)

**Status:** Used in initial commit only (immediately replaced)

**Details:**
- Native TextKit 2 based editor
- Xcode-inspired visual style
- More native macOS feel

**Usage:**
- Used in the very first `Initial commit` (ff14097)
- Immediately replaced in the next commit `Syntax highlighting` (1db2b14)

**Why replaced:**
- Limited language support (swift, haskell, agda, cabal, cypher)
- No Python, JavaScript, TypeScript, etc. highlighting
- Required additional packages for more languages

**Evidence:**
- Initial `Package.swift` had: `.package(url: "https://github.com/mchakravarty/CodeEditorView.git", from: "0.14.0")`
- Commit 1db2b14 switched to ZeeZide/CodeEditor

**Links:**
- Repository: https://github.com/mchakravarty/CodeEditorView

---

## 2. ZeeZide/CodeEditor (Highlightr-based)

**Status:** Used in v0.1.0 and v0.2.0

**Details:**
- Wraps `Highlightr` (which wraps `highlight.js` via JavaScriptCore)
- 180+ languages, 80+ themes
- Drop-in `TextEditor` replacement with editable, highlighted code
- ~50ms to highlight 500 lines
- GitHub dark/light themes available

**Usage:**
- `import CodeEditor` in `EditorView.swift`
- Used from commit 1db2b14 through v0.2.0 tag
- `Package.swift` dependency: `.package(url: "https://github.com/ZeeZide/CodeEditor.git", from: "1.0.0")`

**Why replaced:**
- Highlightr/JS-based highlighting was on the whole file, so every keystroke triggered a full re-highlight and caused a flicker
- Tree-sitter based alternatives offer better native integration

**Links:**
- Repository: https://github.com/ZeeZide/CodeEditor

---

## 3. CodeEditSourceEditor (CodeEditApp) — Tree-sitter based

**Status:** Attempted but abandoned (uncommitted changes, post-v0.2.0)

**Details:**
- Tree-sitter based incremental parsing
- Native SwiftUI `SourceEditor` view
- 30+ languages via CodeEditLanguages package
- Actively maintained, used in CodeEdit macOS app

**Usage:**
- `Package.swift` dependencies: `CodeEditSourceEditor` + `CodeEditLanguages`
- Uses `SourceEditor($text, language:, configuration:, state:)` SwiftUI API

**Why abandoned:**
- Markdown language support was broken/missing
- CodeEditLanguages uses non-standard capture names that didn't match markdown content
- Couldn't properly highlight markdown headings, code blocks, etc.
- Made the application much bigger to download
- Migration was fully implemented but reverted
- App crashes with certain markdown content

**Links:**
- Repository: https://github.com/CodeEditApp/CodeEditSourceEditor
- CodeEditLanguages: https://github.com/CodeEditApp/CodeEditLanguages

---

## 4. Neon + Tree-sitter

**Status:** Currently in use — Successfully implemented with Swift 6

**Details:**
- Native NSTextView with TextKit 1 (required for full-document highlighting)
- Tree-sitter based syntax highlighting via Neon
- Swift 6 compatible (pinned to commit 484d6fb post-0.6.0)
- 30+ languages via TreeSitterLanguages: Swift, Python, JavaScript, TypeScript, Go, Rust, Java, C/C++, C#, Ruby, PHP, HTML, CSS, SQL, R, Perl, Lua, Haskell, Elixir, LaTeX, TOML, YAML, JSON, Bash, Dockerfile, Makefile, and more
- Syntax highlighting skipped for files >2MB to avoid initial load pauses
- Markdown files show split view with live preview using swift-markdown-ui

**Implementation:**
- `CodeEditorView.swift` - SwiftUI wrapper with NSTextView(usingTextLayoutManager: false)
- Uses TextKit 1 temporary attributes for full-document highlighting (TextKit 2 only highlights visible ranges)
- `SplitEditorView.swift` - Split view editor for markdown with live preview
- `MarkdownEditorSubview.swift` - Isolated editor subview prevents cursor jumping on preview updates
- `MarkdownPreviewView.swift` - Markdown preview rendering with theme support
- GitHub light/dark themes with proper token colors
- Preview updates debounced (50ms), language changes debounced (100ms)

**Dependencies:**
```swift
// Package.swift
.package(url: "https://github.com/ChimeHQ/Neon", revision: "484d6fb"),
.package(url: "https://github.com/ChimeHQ/SwiftTreeSitter", from: "0.8.0"),
.package(url: "https://github.com/simonbs/TreeSitterLanguages", from: "0.1.10"),
.package(url: "https://github.com/gonzalezreal/swift-markdown-ui", from: "2.1.0"),
```

**Why it works:**
- Neon pinned to commit `484d6fb` (post-0.6.0) which includes commit f159801 fixing Swift 6 strict concurrency
- TextKit 1 temporary attributes persist for entire document, not just visible ranges
- SPI reports zero data race safety errors

**Links:**
- Neon: https://github.com/ChimeHQ/Neon
- SwiftTreeSitter: https://github.com/ChimeHQ/SwiftTreeSitter
- TreeSitterLanguages: https://github.com/simonbs/TreeSitterLanguages
- swift-markdown-ui: https://github.com/gonzalezreal/swift-markdown-ui

---

## 5. STTextView (Not Used)

**Status:** Attempted — switched to NSTextView with TextKit 1

**Details:**
- Alternative tree-sitter based editor
- STTextView + STTextView-Plugin-Neon
- Uses same Neon library underneath

**Why not used:**
- Direct Neon integration provides more control
- Simpler dependency chain

---

## Related Components

- **Markdown Preview:** Uses `swift-markdown-ui` (MarkdownUI package) for the preview pane in split-view mode
- **Split Editor:** `SplitEditorView.swift` combines `MarkdownEditorSubview` (Neon-highlighted) with `MarkdownPreviewView` (MarkdownUI)
- **Code Editor:** `CodeEditorView.swift` - SwiftUI wrapper with `TextViewHighlighter` for syntax highlighting
