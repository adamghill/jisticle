# Jisticle Implementation Notes

## Trade-offs and Design Decisions

### 1. Authentication: GitHub Device Flow vs OAuth Redirect

**Decision:** Used GitHub Device Flow instead of browser redirect OAuth.

**Trade-offs:**
- ✅ No client_secret needed - more secure for distribution
- ✅ No custom URL scheme required - simpler configuration
- ✅ Works well for developer tools
- ❌ User must manually enter a code on GitHub.com
- ❌ Slightly longer authentication flow (polling-based)

**Alternative considered:** Traditional OAuth with `gistdeck://` custom URL scheme.
- Would require client_secret (security concern for distributed apps)
- More complex setup with Info.plist URL types
- Better UX (automatic redirect)

### 2. Code Editor Evolution

**Initial commit:** `mchakravarty/CodeEditorView` was added but immediately replaced.

**v0.1.0 - v0.2.0:** Used `ZeeZide/CodeEditor` (Highlightr-based).
- ✅ Easy integration
- ✅ 180+ languages via highlight.js
- ❌ JavaScriptCore-based (not native TextKit 2)
- ❌ Performance issues with large files

**Post-v0.2.0 attempt:** `CodeEditSourceEditor` (Tree-sitter based).
- ✅ Tree-sitter incremental parsing - no flicker
- ✅ 30+ languages via CodeEditLanguages
- ❌ Markdown language support broken (non-standard capture names)
- ❌ Full migration completed but abandoned due to markdown issues

**Current (post-v0.2.0, after CodeEditSourceEditor attempt):** `STTextView + STTextView-Plugin-Neon` (Tree-sitter based).
- ✅ Native TextKit 2 based - better macOS integration
- ✅ More native-feeling editor (Xcode-inspired)
- ✅ Tree-sitter syntax highlighting with proper markdown support
- ❌ More complex integration with Auto Layout constraints

### 3. Architecture: Protocol-Based Service Layer

**Decision:** Implemented `GistProvider` protocol as suggested in the plan.

**Trade-offs:**
- ✅ Testability - easy to inject `MockGistProvider`
- ✅ Future-proofing - could add GitLab/Bitbucket later
- ✅ Clean separation of concerns
- ❌ Slight overhead of protocol abstraction

### 4. Build System: Swift Package Manager + XcodeGen

**Decision:** SPM for dependencies, XcodeGen for .xcodeproj generation.

**Trade-offs:**
- ✅ Can build outside Xcode via `swift build` and `just build-release`
- ✅ Reproducible builds via project.yml
- ✅ No checked-in .xcodeproj (cleaner git history)
- ❌ Requires XcodeGen to be installed
- ❌ Slightly longer build process (generate project → archive)

### 5. State Management: @Observable (iOS 17+) vs ObservableObject

**Decision:** Used `@Observable` for AppState (modern SwiftUI), `@StateObject` for AuthService.

**Trade-offs:**
- ✅ More efficient re-rendering (fine-grained observation)
- ✅ Cleaner syntax (no @Published needed)
- ❌ Requires macOS 14+ (Ventura)
- ❌ Need to be careful with @MainActor annotations

### 6. Language Detection Strategy

**Decision:** Extension-based detection with language name fallback.

**Trade-offs:**
- ✅ Fast client-side detection
- ✅ Works offline
- ❌ Not as accurate as GitHub's Linguist
- ❌ Manual mapping for each language

**Extensions mapped:**
- .swift → Swift
- .py → Python
- .js/.ts → JavaScript/TypeScript
- .json → JSON
- .md → Markdown
- .go → Go
- .rs → Rust
- .java → Java
- .c/.h/.cpp → C/C++
- .html/.css → HTML/CSS
- .sql → SQL
- .sh/.bash/.zsh → Bash
- .yaml/.yml → YAML
- Dockerfile → Dockerfile

### 7. Three-Pane Layout: NavigationSplitView

**Decision:** Used `NavigationSplitView` for sidebar + content + detail layout.

**Trade-offs:**
- ✅ Native macOS three-column layout
- ✅ Automatic handling of column visibility
- ✅ Built-in sidebar toggle support
- ❌ Requires macOS 13+ (fine for our 14+ target)

### 8. Data Fetching Strategy

**Decision:** Fetch full gist content when selecting (not in list view).

**Trade-offs:**
- ✅ Faster initial load (list endpoint is fast)
- ✅ Less memory usage for large gist lists
- ❌ Slight delay when opening a gist (one extra API call)
- ❌ No offline support in V1

### 9. File Editing Workflow

**Decision:** In-place editing with "Save" button (not auto-save).

**Trade-offs:**
- ✅ Explicit control over when changes are persisted
- ✅ Shows "Modified" indicator
- ✅ Keyboard shortcut (Cmd+S) for save
- ❌ Less "modern" than auto-save
- ❌ Risk of losing changes if app closes

### 10. Security: Keychain for Token Storage

**Decision:** Used `KeychainAccess` library for secure token storage.

**Trade-offs:**
- ✅ Industry standard for secure storage
- ✅ Handles Keychain access complexities
- ✅ Item remains after app reinstall
- ❌ Additional dependency

### 11. Error Handling Strategy

**Decision:** Centralized error display in MainLayout with alert presentation.

**Trade-offs:**
- ✅ Consistent UX for all errors
- ✅ Simple implementation
- ❌ Could be more granular (per-view errors)

### 12. Network Entitlements

**Decision:** Added `com.apple.security.network.client` entitlement.

**Required for:** GitHub API calls

### 13. Minimum macOS Target

**Decision:** macOS 14.0 (Ventura)

**Rationale:**
- Required for `@Observable` macro
- `NavigationSplitView` works best on 13+
- `CodeEditorView` requires 12+
- Most users on modern macOS versions

### 14. Syntax Highlighting Language Support

**Decision:** Limited to languages supported by CodeEditorView (swift, haskell, agda, cabal, cypher).

**Trade-offs:**
- ✅ Simple integration
- ✅ Good Swift support
- ❌ No Python, JavaScript, TypeScript, etc. highlighting
- ❌ Would need additional packages for more languages

**Future:** Could add tree-sitter based highlighting via additional packages.

## Known Limitations / V2 Ideas

1. **No Markdown Preview** - Planned for V2
2. **No Offline Cache** - Would require Core Data/SQLite backing store
3. **No Multi-file Gist Creation** - UI supports it but API call needs updating
4. **No Star/Fork** - Easy to add, just UI work
5. **No Public Gist Browsing** - Limited to authenticated user's gists
6. **No Syntax Highlighting Language Customization** - Uses hardcoded themes
7. **No Settings/Preferences** - Could add theme switching, font size, etc.

## GitHub OAuth App Setup (Required)

Before running Jisticle, you must create a GitHub OAuth app:

1. Go to https://github.com/settings/developers
2. Click "New OAuth App"
3. Fill in:
   - **Application name**: Jisticle
   - **Homepage URL**: https://github.com/adamghill/jisticle (or your fork)
   - **Authorization callback URL**: http://localhost (not used for Device Flow but required)
4. Click "Register application"
5. **Important**: Click "Enable Device Flow" button on the app settings page
6. Copy the **Client ID** (not the secret)
7. Paste it into `Sources/Jisticle/Services/AuthService.swift`:
   ```swift
   static let clientId = "YOUR_ACTUAL_CLIENT_ID_HERE"
   ```

## Build Instructions

```bash
# Install dependencies
swift package resolve

# Generate Xcode project (optional - for Xcode IDE users)
xcodegen generate

# Build and run
just run

# Build release
just build-release

# Run tests
just test
```
