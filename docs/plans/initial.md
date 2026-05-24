# GistDeck — Native macOS Gist Client in SwiftUI
## Project Plan & Technical Assessment

---

## TL;DR

This is a **medium-difficulty** project for someone comfortable with Swift/SwiftUI. The GitHub API layer and core CRUD are fairly straightforward. The genuinely tricky parts are: GitHub OAuth (a browser dance with a custom URL scheme), good syntax highlighting in an editable `TextEditor`, and wiring up a polished three-pane macOS layout. Markdown preview is clearly doable but earns its V2 status. Estimate: **4–8 weeks** of part-time work to a solid V1.

---

## Existing Projects Worth Studying or Forking

### 1. Lepton ⭐ 10,000+ — `github.com/hackjutsu/Lepton`
The most feature-complete open-source Gist manager. **Problem: it's Electron (React + Redux), not Swift.** However, its UX, auth flow, and API integration are excellent reference material. Study this for product decisions, not code reuse.
- MIT licensed
- Has search, tags via description conventions (`[title] desc #tag1 #tag2`), markdown rendering, Cmd+F search
- Last pushed Jan 2024 — still active enough to mine for ideas

### 2. macGist — `github.com/Tnra/macGist`
Tiny Swift app for sending clipboard contents to Gist. Very minimal — more of a menubar toy than a full client. Good for studying Keychain + GitHub API token storage in native Swift. MIT licensed.

### 3. GistBox (Mac, Swift 2016) — found via GitHub topics
Listed in the `mac-app` GitHub topic as *"a gistbox client for mac"*. Appears abandoned and pre-SwiftUI, but worth a look for any Objective-C/early-Swift API patterns. Stars: 4.

### 4. Maple Git Client — `github.com/poolcamacho/Maple`
Not a Gist client, but a **very recent (April 2026) native macOS Git client in SwiftUI**. MIT licensed. Excellent reference for: three-pane SwiftUI layout on macOS, GitHub API patterns, CI/CD setup with SwiftLint and CodeQL, and overall project scaffolding. Strongly recommended as a structural template.

### Verdict
There is no native SwiftUI macOS Gist client worth forking. You are building greenfield, but Lepton (for UX reference) and Maple (for SwiftUI/macOS architecture reference) together cover most of what you need to study.

---

## Architecture

```
GistDeckApp (SwiftUI App lifecycle)
├── AppState (ObservableObject — auth, selected gist)
├── AuthService            ← GitHub OAuth + Keychain
├── GistService            ← GitHub REST API (async/await)
├── Views/
│   ├── LoginView
│   ├── MainLayout (NavigationSplitView, 3 panes)
│   │   ├── SidebarView (list of gists, search)
│   │   ├── GistListView (files in gist)
│   │   └── EditorView (CodeEditor + toolbar)
│   └── NewGistSheet
└── Models/
    ├── Gist.swift
    └── GistFile.swift
```

Use **`NavigationSplitView`** (macOS 13+) for the three-column layout — it gives you the sidebar + detail split that GitHub's own Gist UI approximates, for free.

---

## V1 Feature Scope

| Feature | Difficulty | Notes |
|---|---|---|
| GitHub OAuth login | Medium | Browser redirect + custom URL scheme |
| Token storage in Keychain | Easy | Use KeychainAccess SPM package |
| List all user gists | Easy | Single API call, paginated |
| View gist files with syntax highlighting | Medium | CodeEditor or Highlightr |
| Create new gist | Easy | POST to API |
| Edit existing gist | Easy | PATCH to API |
| Delete gist | Easy | DELETE to API |
| Multi-file gists (add/remove files) | Medium | Dynamic form UI |
| Public/secret toggle | Easy | Bool in create/edit form |
| Search/filter gist list | Easy | Client-side filter on `description` |

## V2 Feature Scope

| Feature | Difficulty | Notes |
|---|---|---|
| Markdown preview | Medium | `WKWebView` or `AttributedString` rendering |
| Browse public/starred gists | Easy | Additional API endpoints |
| Fork a gist | Easy | POST `/gists/{id}/forks` |
| Star/unstar gists | Easy | PUT/DELETE `/gists/{id}/star` |
| Tags via description convention | Medium | Parse `[title] desc #tag` like Lepton |
| Offline cache | Hard | Core Data or SQLite backing store |
| iCloud sync of settings | Easy | `NSUbiquitousKeyValueStore` |

---

## Technical Deep-Dives

### 1. GitHub OAuth — The Trickiest V1 Piece

macOS apps can't use a redirect to `localhost` cleanly without spinning up a local HTTP server, so the standard pattern is:

1. Register a **GitHub OAuth App** at `github.com/settings/developers`
2. Set the callback URL to a custom scheme like `gistdeck://oauth/callback`
3. Register that URL scheme in your `Info.plist` under `CFBundleURLTypes`
4. On login, open `https://github.com/login/oauth/authorize?client_id=...` in the user's default browser via `NSWorkspace.shared.open(...)`
5. When GitHub redirects back to `gistdeck://oauth/callback?code=...`, your app receives it via `onOpenURL` in SwiftUI
6. Exchange the `code` for an `access_token` via a POST to `https://github.com/login/oauth/access_token`
7. Store the token in Keychain

**Important:** The token exchange requires your `client_secret`. Never ship the secret in the binary if distributing publicly. For a personal tool, it's fine; for App Store distribution, proxy the exchange through a small backend (Cloudflare Worker or similar).

**Recommended library:** `p2/OAuth2` (`github.com/p2/OAuth2`) — mature Swift OAuth2 framework with Keychain integration and `ASWebAuthenticationSession` support. Or roll it yourself — the GitHub Device Flow is even simpler for a developer tool (no browser redirect needed, just poll with a code).

**GitHub Device Flow** is worth considering: it shows the user a code, they visit `github.com/login/device` and enter it, your app polls until confirmed. Simpler to implement, no URL scheme needed, great for developer-facing tools.

### 2. Syntax Highlighting

Three solid options, all MIT licensed and available as Swift packages:

**Option A — `ZeeZide/CodeEditor`** (`github.com/ZeeZide/CodeEditor`) ⭐ Recommended for V1
- Wraps `Highlightr` (which wraps `highlight.js` via JavaScriptCore) as a SwiftUI `View`
- Drop-in replacement for `TextEditor` with editable, highlighted code
- 180+ languages, 80+ themes
- Supports `macOS 12+`
- ~50ms to highlight 500 lines — fast enough for real-time editing
- One-liner integration: `CodeEditor(source: $source, language: .swift, theme: .ocean)`

**Option B — `mchakravarty/CodeEditorView`** (`github.com/mchakravarty/CodeEditorView`)
- Based on TextKit 2, more native-feeling
- Xcode-inspired visual style
- Slightly more complex integration but more Mac-native

**Option C — `appstefan/HighlightSwift`** (`github.com/appstefan/HighlightSwift`)
- For **display only** (read-only syntax coloring of `Text`)
- Good for a gist viewer, not for an editable editor

**Recommendation:** Use `ZeeZide/CodeEditor` for the editor. You can auto-detect the language from the gist file's `language` field returned by the GitHub API, and map it to `CodeEditor.Language`.

### 3. Markdown Preview (V2)

The simplest approach on macOS:
- `WKWebView` wrapped in `NSViewRepresentable`, render the markdown to HTML using a JS library (Marked.js bundled in your app) or use Apple's `AttributedString(markdown:)` for simple cases
- For a native feel, `AttributedString(markdown:)` works for basic markdown with no code blocks. For full GFM (GitHub Flavored Markdown with fenced code blocks), you'll want a WebView.
- The `SwiftDevJournal/SwiftUIMarkdownEditor` repo on GitHub shows exactly this pattern with `CodeEditor` + a live preview using `WKWebView`.

### 4. The GitHub REST API

Gists are one of the simplest parts of the GitHub API. All endpoints you need:

```
GET    /gists                    — list authenticated user's gists
GET    /gists/{gist_id}          — get single gist (includes file content)
POST   /gists                    — create gist
PATCH  /gists/{gist_id}          — update gist
DELETE /gists/{gist_id}          — delete gist
```

Authentication is just an `Authorization: Bearer {token}` header. Use `URLSession` with `async/await` — no third-party networking library needed. Model your `Gist` and `GistFile` as `Codable` structs matching the API's JSON shape.

Pagination: `GET /gists` returns up to 30 gists by default. Use `?per_page=100&page=N` and parse the `Link` response header for next-page URLs if users have many gists.

---

## Difficulty Assessment

| Area | Difficulty (1–5) | Why |
|---|---|---|
| Project setup & SwiftUI scaffolding | 2 | Xcode + SwiftUI is well-documented |
| NavigationSplitView 3-pane layout | 3 | macOS-specific quirks but well-documented |
| GitHub API (CRUD) | 2 | Simple REST with `async/await` |
| OAuth login flow | 4 | Browser dance, URL scheme, token exchange |
| Syntax highlighting (editable) | 3 | Third-party package does the heavy lifting |
| Markdown preview | 4 | WebView integration + GFM edge cases |
| Multi-file gist editing UI | 3 | Dynamic form with add/remove |
| Pagination + performance | 3 | Not complex but easy to skip and regret |

**Overall V1: 3/5** — A Swift developer with SwiftUI experience can ship this in a month of focused evenings. The OAuth flow is the biggest gotcha.

---

## Recommended Swift Package Dependencies

| Package | Repo | Purpose |
|---|---|---|
| `CodeEditor` | `ZeeZide/CodeEditor` | Syntax-highlighted editable text view |
| `KeychainAccess` | `kishikawakatsumi/KeychainAccess` | Simple Keychain wrapper |
| *(optional)* `p2/OAuth2` | `p2/OAuth2` | OAuth2 flow (or roll your own) |

Keep dependencies minimal. The GitHub API layer, models, and most of the app logic should be plain Swift with no external dependencies.

---

## Suggested Build Order

1. **Week 1 — Skeleton**: Xcode project, `NavigationSplitView` layout, placeholder views, SwiftUI previews working
2. **Week 2 — Auth**: GitHub OAuth app registered, Device Flow or browser redirect implemented, token stored in Keychain, login/logout working
3. **Week 3 — List & Read**: Fetch gists from API, display list in sidebar, show file content in detail view with `CodeEditor` syntax highlighting
4. **Week 4 — Write**: Create new gist sheet, edit existing gist with PATCH, delete with confirmation, public/secret toggle
5. **Week 5 — Polish**: Multi-file gist support, search/filter, error handling, empty states, loading states, app icon, menu bar commands
6. **V2**: Markdown preview, starring, forking, browse public gists

---

## Gotchas & Notes

- **App Sandbox**: If you're not distributing via the App Store, you can disable sandboxing and skip some entitlement headaches. For App Store, you'll need `com.apple.security.network.client` entitlement for API calls.
- **client_secret**: Don't ship it in the binary for a public release. Use GitHub's Device Flow instead — it needs no secret.
- **Gist file content**: The full file content is only returned from `GET /gists/{gist_id}`, not from the list endpoint. The list gives you a `truncated` field and a `raw_url` for large files — handle this.
- **Rate limits**: Authenticated requests get 5,000/hour — more than enough for any realistic use.
- **Minimum macOS target**: Aim for **macOS 13 (Ventura)** to get `NavigationSplitView` and the best SwiftUI support. `CodeEditor` needs macOS 12+.

---

## Future-Proofing: The `GistProvider` Protocol

Don't build a generic multi-backend system in V1 — the auth stories alone (GitHub Device Flow vs GitLab OAuth vs AWS Signature V4) make that a project in itself, and APIs that look similar on the surface differ enough that a clean abstraction leaks badly. S3, for example, has no concept of multi-file gists, descriptions, language detection, or forking.

**What to do instead:** design your service layer around a protocol from day one, ship one implementation, and leave the door open. Define the protocol around *your app's needs* — not GitHub's API shape specifically — so a second provider isn't an awkward fit later.

```swift
protocol GistProvider {
    func listGists() async throws -> [Gist]
    func fetchGist(id: String) async throws -> Gist
    func createGist(_ draft: GistDraft) async throws -> Gist
    func updateGist(id: String, _ draft: GistDraft) async throws -> Gist
    func deleteGist(id: String) async throws
}

// V1: the only implementation
class GitHubGistProvider: GistProvider { ... }

// V2 possibility, isolated and scoped:
// class GitLabSnippetProvider: GistProvider { ... }
```

Your views and view models should depend on `GistProvider`, never on `GitHubGistProvider` directly. This also gives you testability for free — inject a `MockGistProvider` in SwiftUI previews and unit tests without hitting the real API.

The filesystem layer idea (mountable `gist://`, open files in any editor) is a different app entirely — a file sync tool — and substantially harder. Worth revisiting only after V1 is shipped and you understand where the seams naturally are.