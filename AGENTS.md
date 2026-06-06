# Jisticle - AI Agent Reference

## Project Overview

**Jisticle** is a native macOS GitHub Gist client built with SwiftUI.

- **Language**: Swift 6.0
- **Platform**: macOS 14.0+
- **UI Framework**: SwiftUI with NavigationSplitView (three-pane layout)

## Architecture

### Directory Structure

```
Sources/Jisticle/
├── JisticleApp.swift          # App entry point
├── Models/
│   └── Gist.swift             # Data models for Gists and GistFile
├── Services/
│   ├── AuthService.swift      # GitHub Device Flow OAuth + Keychain token storage
│   ├── GistCache.swift        # Simple in-memory gist caching
│   ├── GistProvider.swift     # Protocol for gist operations (CRUD)
│   └── GitHubGistProvider.swift  # GitHub API implementation
├── Views/
│   ├── AboutView.swift           # App about dialog
│   ├── CodeEditorView.swift      # Code editor view (NSTextView + Neon highlighting)
│   ├── EditorView.swift          # Editor container with file management
│   ├── GistContentView.swift     # Gist detail view (files list, preview, edit)
│   ├── LoginView.swift           # GitHub device flow login UI
│   ├── MainLayout.swift          # Root layout container
│   ├── MarkdownEditorSubview.swift # Isolated markdown editor subview
│   ├── MarkdownPreviewView.swift # Markdown preview rendering
│   ├── NewGistSheet.swift        # Create new gist modal
│   ├── RootView.swift            # App root view
│   ├── SidebarView.swift         # Searchable gist list sidebar
│   └── SplitEditorView.swift     # Split view editor with live markdown preview
└── Utils/
    ├── AppState.swift         # @Observable app state (selection, gist list, sorting)
    └── View+PointingCursor.swift  # Cursor style extension
```

### Key Dependencies

| Package | Purpose |
|---------|---------|
| [Neon](https://github.com/ChimeHQ/Neon) | Tree-sitter syntax highlighting for NSTextView |
| [SwiftTreeSitter](https://github.com/ChimeHQ/SwiftTreeSitter) | Swift bindings for tree-sitter |
| [TreeSitterLanguages](https://github.com/simonbs/TreeSitterLanguages) | 30+ language parsers (Swift, Python, JavaScript, TypeScript, Go, Rust, Java, C/C++, C#, Ruby, PHP, HTML, CSS, SQL, R, Perl, Lua, Haskell, Elixir, LaTeX, TOML, YAML, JSON, Bash, Dockerfile, Makefile, and more) |
| [swift-markdown-ui](https://github.com/gonzalezreal/swift-markdown-ui) | Markdown preview rendering |
| [KeychainAccess](https://github.com/kishikawakatsumi/KeychainAccess) | Secure token storage |

**Previous editors tried:** See `docs/editors-tried.md` for full history including CodeEditorView, ZeeZide/CodeEditor, CodeEditSourceEditor, and STTextView attempts.

## Build Commands

```bash
# Development build and run
swift build && open .build/debug/Jisticle

# Or using just
just run

# Run tests
just test

# Release build (creates .app + DMG)
just build-release [version]
```

> **IMPORTANT — keep dependencies in sync:** `swift build` / `just run` use `Package.swift`, but `just build-release` regenerates an Xcode project from `project.yml` (via XcodeGen) and builds with `xcodebuild`. These two files maintain **separate** dependency lists. When adding or removing a Swift package product, update **both** `Package.swift` and the `dependencies:` section of `project.yml`, otherwise `swift build` will pass while `just build-release` fails with `unable to resolve module dependency`.

## Key Patterns

### GistProvider Protocol
The app uses a protocol-based abstraction for gist operations to enable future multi-provider support:

```swift
@MainActor
protocol GistProvider {
    func listGists() async throws -> [Gist]
    func fetchGist(id: String) async throws -> Gist
    func createGist(_ draft: GistDraft) async throws -> Gist
    func updateGist(id: String, _ draft: GistDraft) async throws -> Gist
    func addFileToGist(id: String, filename: String, content: String) async throws -> Gist
    func deleteFileFromGist(id: String, filename: String) async throws -> Gist
    func renameFileInGist(id: String, oldFilename: String, newFilename: String) async throws -> Gist
    func deleteGist(id: String) async throws
}
```

### Authentication Flow
1. `AuthService` initiates GitHub Device Flow OAuth
2. User code displayed for manual entry at github.com/login/device
3. Polls for authorization completion
4. Access token stored in macOS Keychain
5. Token used for all subsequent GitHub API calls

### State Management
- `AppState` — `@Observable` class holding selection, gist list, sorting, and draft state
- `AuthService.shared` — `ObservableObject` singleton for auth state
- `GistCache` for temporary in-memory caching
- `@AppStorage` for persistent user preferences

## File Naming Conventions

- Views: `*View.swift`
- Services: `*Service.swift`, `*Provider.swift`
- Models: Descriptive nouns (e.g., `Gist.swift`)

## Testing

- Test target: `JisticleTests` (directory: `Tests/JisticleTests/`)
- Run with: `swift test` or `just test`

## Notes for Agents

- This is a **macOS-only** SwiftUI app (not multi-platform)
- Uses **Swift 6.0** toolchain
- Code editor uses a **TextKit 1** `NSTextView` (`NSTextView(usingTextLayoutManager: false)` in `CodeEditorView.swift`). This is required for Neon: it highlights TextKit 1 views via the layout manager's *temporary attributes*, which persist for the whole document. TextKit 2's rendering attributes only stick for laid-out (visible) ranges, leaving large files unhighlighted until scrolled.
- Syntax highlighting is skipped for files larger than 2MB to avoid initial load pauses (see `CodeEditorView.highlightingSizeThreshold`)
- Markdown files (.md, .markdown) show a split view with live preview using `swift-markdown-ui`
- Preview updates are debounced (50ms) and language changes are debounced (100ms) for performance
- GitHub API calls are async/await based
- Keychain access requires entitlements (see `Jisticle.entitlements`)
