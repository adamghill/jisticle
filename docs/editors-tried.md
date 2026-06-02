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
- Highlightr/JS-based highlighting had performance issues
- Tree-sitter based alternatives offer better native integration

**Evidence:**
- v0.1.0 and v0.2.0 `Package.swift` both use ZeeZide/CodeEditor
- CHANGELOG.md for v0.1.0 mentions "Syntax highlighting" (referring to this)
- Current `HEAD` (but not yet committed) has replaced this with STTextView

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
- Tried after ZeeZide/CodeEditor to fix flickering issues
- `Package.swift` dependencies: `CodeEditSourceEditor` + `CodeEditLanguages`
- Uses `SourceEditor($text, language:, configuration:, state:)` SwiftUI API

**Why abandoned:**
- Markdown language support was broken/missing
- CodeEditLanguages uses non-standard capture names that didn't match markdown content
- Couldn't properly highlight markdown headings, code blocks, etc.
- Migration was fully implemented but reverted due to markdown issues

**Evidence:**
- Never committed to git (remained in working directory)
- Full migration completed: Package.swift, EditorView.swift, SplitEditorView.swift, MarkdownEditorSubview.swift
- Build succeeded but markdown editing was non-functional

**Links:**
- Repository: https://github.com/CodeEditApp/CodeEditSourceEditor
- CodeEditLanguages: https://github.com/CodeEditApp/CodeEditLanguages

---

## 4. STTextView + STTextView-Plugin-Neon (Tree-sitter based)

**Status:** Currently in use (uncommitted changes, post-v0.2.0, after CodeEditSourceEditor attempt)

**Details:**
- Native macOS text view with TextKit 2
- Tree-sitter based syntax highlighting via Neon plugin
- Supports many languages: Swift, Python, JavaScript, TypeScript, Go, Rust, Ruby, Java, C/C++, C#, Bash, HTML, CSS, JSON, YAML, TOML, Markdown, SQL, PHP
- Line numbers, highlight current line, word wrap options
- SwiftUI wrapper via `STTextViewSwiftUI`

**Implementation:**
- `CodeEditorSubview.swift` - Used for code files
- `MarkdownEditorSubview.swift` - Used for markdown files in split-view
- Both use `NeonPlugin` for syntax highlighting

**Dependencies:**
```swift
// Package.swift
.package(url: "https://github.com/krzyzanowskim/STTextView", from: "2.2.2"),
.package(url: "https://github.com/krzyzanowskim/STTextView-Plugin-Neon", revision: "482b73cf442b2262525a0aa4355603b6467b6084"),
```

**Why chosen:**
- Better language support via Tree-sitter
- More performant highlighting
- Native macOS feel with modern TextKit 2
- Good SwiftUI integration

**Links:**
- STTextView: https://github.com/krzyzanowskim/STTextView
- STTextView-Plugin-Neon: https://github.com/krzyzanowskim/STTextView-Plugin-Neon

---

## Summary Timeline

| Commit/Tag | Editor | Notes |
|---------|--------|-------|
| Initial commit (ff14097) | mchakravarty/CodeEditorView | First implementation, immediately replaced |
| 1db2b14 - v0.2.0 | ZeeZide/CodeEditor | Used for shipped v0.1.0 and v0.2.0 releases |
| Uncommitted attempt | CodeEditSourceEditor | Tried to fix flicker, abandoned due to markdown issues |
| Current (uncommitted) | STTextView + Neon | Final solution with proper markdown support |

---

## Related Components

- **Markdown Preview:** Uses `swift-markdown-ui` (MarkdownUI package) for the preview pane in split-view mode
- **Split Editor:** `SplitEditorView.swift` combines `MarkdownEditorSubview` (STTextView) with `MarkdownPreviewView` (MarkdownUI)
