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
│   ├── AboutView.swift        # App about dialog
│   ├── EditorView.swift       # Code editor with syntax highlighting
│   ├── GistContentView.swift  # Gist detail view (files list, preview, edit)
│   ├── LoginView.swift        # GitHub device flow login UI
│   ├── MainLayout.swift       # Root layout container
│   ├── NewGistSheet.swift     # Create new gist modal
│   ├── RootView.swift         # App root view
│   └── SidebarView.swift      # Searchable gist list sidebar
└── Utils/
    ├── AppState.swift         # @Observable app state (selection, gist list, sorting)
    └── View+PointingCursor.swift  # Cursor style extension
```

### Key Dependencies

| Package | Purpose |
|---------|---------|
| [CodeEditor](https://github.com/ZeeZide/CodeEditor) | Syntax highlighting via TextKit 2 |
| [KeychainAccess](https://github.com/kishikawakatsumi/KeychainAccess) | Secure token storage |

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

- Test target: `JisticleTests` (directory: `Tests/GisticleTests/`)
- Run with: `swift test` or `just test`

## Notes for Agents

- This is a **macOS-only** SwiftUI app (not multi-platform)
- Uses **Swift 6.0** toolchain
- Code editor uses TextKit 2 (not UITextView - this is macOS)
- GitHub API calls are async/await based
- Keychain access requires entitlements (see `Jisticle.entitlements`)
