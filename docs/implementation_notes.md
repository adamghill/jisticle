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

**Current (post-v0.2.0, after CodeEditSourceEditor attempt):** `Neon + TreeSitterLanguages` (Tree-sitter based).
- ✅ Native NSTextView with TextKit 1 - better macOS integration
- ✅ Tree-sitter incremental parsing - no flicker, fast highlighting
- ✅ Swift 6 compatible (pinned to commit `484d6fb` post-0.6.0)
- ✅ Proper markdown support via TreeSitterLanguages
- ✅ Full-document highlighting via TextKit 1 temporary attributes
- ❌ Dependency size (~15-25MB with full language bundle)

**Dependency Pinning Note:**
Neon is pinned to revision `484d6fb` (post-0.6.0) because:
- v0.6.0 has a Swift 6 strict concurrency error in `TreeSitterClient.swift:451`
- Commit `f159801` (included in `484d6fb`) fixes this with proper `@MainActor` handling
- Pinning ensures reproducible builds until v0.6.1+ is released

```swift
// Package.swift
.package(url: "https://github.com/ChimeHQ/Neon", revision: "484d6fb"),
```

**Known Limitations:**
- Syntax highlighting is skipped for files larger than 2MB to avoid initial load pauses (see `CodeEditorView.highlightingSizeThreshold`)
- This threshold was chosen because 2MB of code is typically ~40k lines; contiguous layout is still fast, but tree-sitter highlighting the visible range plus tokenization overhead can produce a noticeable hiccup

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
- .js/.mjs/.cjs → JavaScript
- .ts/.mts/.cts → TypeScript
- .jsx → JSX
- .tsx → TSX
- .json → JSON
- .md/.markdown → Markdown
- .go → Go
- .rs → Rust
- .java → Java
- .kt/.kts → Kotlin
- .cs → C#
- .cpp/.cxx/.cc/.c++ → C++
- .c/.h → C
- .m/.mm → Objective-C
- .sh/.bash/.zsh/.fish → Bash
- .html/.htm → HTML
- .css → CSS
- .scss/.sass → SCSS
- .sql → SQL
- .r → R
- .php → PHP
- .pl/.pm → Perl
- .lua → Lua
- .hs/.lhs → Haskell
- .ex/.exs → Elixir
- .erl/.hrl → Erlang
- .scala → Scala
- .dart → Dart
- .dockerfile → Dockerfile
- .makefile/.mk → Makefile
- .yaml/.yml → YAML
- .toml → TOML
- .xml/.plist/.svg → XML
- .ini/.cfg/.conf → INI
- .tex → LaTeX
- .vim → Vim

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

### 14. Markdown Preview Architecture

**Decision:** Implemented split view editor with live markdown preview for .md and .markdown files.

**Trade-offs:**
- ✅ Real-time preview with 50ms debouncing for responsive updates
- ✅ Uses swift-markdown-ui for proper rendering (code blocks, tables, lists, etc.)
- ✅ Theme-aware (docC for dark mode, gitHub for light mode)
- ✅ Isolated editor subview prevents cursor jumping on preview updates
- ❌ Only available for markdown files (not other markup formats)
- ❌ Preview doesn't support custom themes or extensions

**Implementation Details:**
- `SplitEditorView` uses `HSplitView` with editor and preview panes
- `MarkdownEditorSubview` isolates the editor to prevent cursor jumping when preview updates
- Preview updates are debounced (50ms) to avoid excessive re-renders during typing
- Language changes are debounced (100ms) to avoid re-initializing the editor unnecessarily
- Theme switching is cached to avoid recalculating on every render

## Known Limitations / V2 Ideas

1. **Limited Offline Cache** - Gist list is cached to disk as JSON, but individual gist content is not cached
2. **No Multi-file Gist Creation** - UI supports it but API call needs updating
3. **No Star/Fork** - Easy to add, just UI work
4. **No Public Gist Browsing** - Limited to authenticated user's gists
5. **No Syntax Highlighting Language Customization** - Uses hardcoded themes
6. **No Settings/Preferences** - Could add theme switching, font size, etc.

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
