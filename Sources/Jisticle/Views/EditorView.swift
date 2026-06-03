import SwiftUI

@MainActor
struct EditorView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme

    @AppStorage("editorFontSize") private var fontSize = Int(NSFont.monospacedSystemFont(ofSize: 0, weight: .regular).pointSize)
    @AppStorage("showMarkdownPreview") private var showMarkdownPreview = true
    @State private var currentContent: String = ""
    @State private var currentLanguage: Language = .plaintext
    @State private var cachedTheme: EditorTheme?
    @State private var lastColorScheme: ColorScheme?
    private var isDirty: Bool {
        guard let gist = appState.selectedGist, let file = appState.selectedFile else { return false }
        return appState.editedKeys.contains("\(gist.id)/\(file.filename)")
            || (appState.newFilenames.contains(file.filename) && !(file.content?.isEmpty ?? true))
    }

    private var theme: EditorTheme {
        if let cachedTheme, lastColorScheme == colorScheme {
            return cachedTheme
        }
        let newTheme: EditorTheme = colorScheme == .dark ? .githubDark : .github
        cachedTheme = newTheme
        lastColorScheme = colorScheme
        return newTheme
    }

    var body: some View {
        Group {
            if let gist = appState.selectedGist, let file = appState.selectedFile {
                editorContent(gist: gist, file: file)
            } else {
                emptyState
            }
        }
        .frame(minWidth: 400)
        .onChange(of: appState.selectedFile) { _, newFile in
            print("[EditorView] selectedFile changed to: \(newFile?.filename ?? "nil")")
            if let file = newFile, let gist = appState.selectedGist {
                let key = "\(gist.id)/\(file.filename)"
                if let pending = appState.pendingEdits[key] {
                    currentContent = pending
                } else {
                    currentContent = file.content ?? ""
                }
            } else {
                currentContent = newFile?.content ?? ""
            }
            currentLanguage = language(for: newFile)
        }
        .onChange(of: appState.selectedGist) { _, newGist in
            print("[EditorView] selectedGist changed to: \(newGist?.id ?? "nil")")
            // Re-sync selectedFile to new gist's file instance
            if let filename = appState.selectedFile?.filename,
               let updatedFile = newGist?.files[filename] {
                print("[EditorView] Re-syncing selectedFile to new instance")
                appState.selectedFile = updatedFile
            }
        }
    }

    private func editorContent(gist: Gist, file: GistFile) -> some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .top, spacing: 6) {
                        if let url = URL(string: file.rawUrl), !file.rawUrl.isEmpty {
                            Link(destination: url) {
                                Text(file.filename)
                                    .font(.headline)
                            }
                            .pointingCursor()
                        } else {
                            Text(file.filename)
                                .font(.headline)
                        }

                        Text(file.displayLanguage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(.secondary.opacity(0.1))
                            .cornerRadius(4)
                            .padding(.top, 2)
                    }

                    Text(formatBytes(file.size))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if isDirty {
                    Text("Modified")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                if appState.isMarkdownFile {
                    Button {
                        showMarkdownPreview.toggle()
                    } label: {
                        Image(systemName: showMarkdownPreview ? "eye.slash" : "eye")
                    }
                    .help(showMarkdownPreview ? "Hide Preview" : "Show Preview")
                }

                Button("Save") {
                    saveChanges()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isDirty)
                .keyboardShortcut("s", modifiers: .command)
            }
            .padding()

            Divider()

            // Conditional content based on file type
            Group {
                if appState.isMarkdownFile {
                    SplitEditorView(showPreview: $showMarkdownPreview)
                } else {
                    codeEditorView(file: file)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("Select a file to view and edit")
                .foregroundStyle(.secondary)
        }
    }

    private func saveChanges() {
        guard let gist = appState.selectedGist, let file = appState.selectedFile else { return }

        Task {
            // Check if this is a new file (not yet on GitHub)
            if appState.newFilenames.contains(file.filename) {
                // Create the file on GitHub with content
                do {
                    _ = try await appState.createFileOnGitHub(filename: file.filename, content: currentContent)
                } catch {
                    appState.errorMessage = "Failed to create file: \(error.localizedDescription)"
                }
            } else {
                // Regular update for existing files
                var files: [String: GistFileDraft] = [:]
                for gistFile in gist.fileList {
                    if gistFile.id == file.id {
                        files[gistFile.filename] = GistFileDraft(content: currentContent)
                    } else {
                        files[gistFile.filename] = GistFileDraft(content: gistFile.content ?? "")
                    }
                }

                let draft = GistDraft(
                    description: gist.displayTitle,
                    isPublic: gist.public,
                    files: files
                )

                await appState.updateGist(draft: draft)
                let saveKey = "\(gist.id)/\(file.filename)"
                appState.pendingEdits.removeValue(forKey: saveKey)
                appState.editedKeys.remove(saveKey)
            }
        }
    }

    // Maps GitHub languages to tree-sitter Language enum
    private func language(for file: GistFile?) -> Language {
        guard let file else { return .plaintext }
        let ext = (file.filename as NSString).pathExtension.lowercased()

        switch ext {
        case "swift":                           return .swift
        case "py":                              return .python
        case "js", "mjs", "cjs":               return .javascript
        case "ts", "mts", "cts":               return .typescript
        case "jsx":                             return .jsx
        case "tsx":                             return .tsx
        case "rb", "rake", "gemspec":           return .ruby
        case "go":                              return .go
        case "rs":                              return .rust
        case "java":                            return .java
        case "kt", "kts":                       return .kotlin
        case "cs":                              return .csharp
        case "cpp", "cxx", "cc", "c++":        return .cpp
        case "c", "h":                          return .c
        case "m", "mm":                         return .objectivec
        case "sh", "bash", "zsh", "fish":       return .shell
        case "html", "htm":                     return .html
        case "css":                             return .css
        case "scss", "sass":                    return .scss
        case "json":                            return .json
        case "xml", "plist", "svg":             return .xml
        case "yaml", "yml":                     return .yaml
        case "toml":                            return .toml
        case "md", "markdown":                  return .markdown
        case "sql":                             return .sql
        case "r":                               return .r
        case "php":                             return .php
        case "pl", "pm":                        return .perl
        case "lua":                             return .lua
        case "hs", "lhs":                       return .haskell
        case "ex", "exs":                       return .elixir
        case "erl", "hrl":                      return .erlang
        case "scala":                           return .scala
        case "dart":                            return .dart
        case "dockerfile":                      return .dockerfile
        case "makefile", "mk":                  return .makefile
        case "ini", "cfg", "conf":              return .ini
        case "tex":                             return .tex
        case "vim":                             return .vim
        default:                                break
        }

        // Fallback: use the language name reported by the GitHub API
        switch file.language?.lowercased() {
        case "swift":                           return .swift
        case "python":                          return .python
        case "javascript", "coffeescript":      return .javascript
        case "typescript":                      return .typescript
        case "ruby":                            return .ruby
        case "go":                              return .go
        case "rust":                            return .rust
        case "java":                            return .java
        case "kotlin":                          return .kotlin
        case "c#":                              return .csharp
        case "c++":                             return .cpp
        case "c":                               return .c
        case "objective-c", "objective-c++":   return .objectivec
        case "shell", "bash":                   return .shell
        case "html":                            return .html
        case "css":                             return .css
        case "json":                            return .json
        case "xml":                             return .xml
        case "yaml":                            return .yaml
        case "markdown":                        return .markdown
        case "sql", "plpgsql", "tsql":          return .sql
        case "r":                               return .r
        case "php":                             return .php
        case "perl":                            return .perl
        case "lua":                             return .lua
        case "haskell":                         return .haskell
        case "elixir":                          return .elixir
        case "erlang":                          return .erlang
        case "scala":                           return .scala
        case "dart":                            return .dart
        case "dockerfile":                      return .dockerfile
        case "makefile":                        return .makefile
        case "tex":                             return .tex
        default:                                return .plaintext
        }
    }

    private func formatBytes(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
    
    // MARK: - View Components
    
    @ViewBuilder
    private func codeEditorView(file: GistFile) -> some View {
        CodeEditorView(
            text: .init(
                get: { currentContent },
                set: { newValue in
                    currentContent = newValue
                    if let gist = appState.selectedGist, let file = appState.selectedFile {
                        let key = "\(gist.id)/\(file.filename)"
                        if newValue == (file.content ?? "") {
                            appState.pendingEdits.removeValue(forKey: key)
                            appState.editedKeys.remove(key)
                        } else {
                            appState.pendingEdits[key] = newValue
                            appState.editedKeys.insert(key)
                        }
                    }
                }
            ),
            language: currentLanguage,
            theme: theme,
            fontSize: .init(get: { CGFloat(fontSize) }, set: { fontSize = Int($0) }),
            isEditable: true,
            onTextChange: { newValue in
                if let gist = appState.selectedGist, let file = appState.selectedFile {
                    let key = "\(gist.id)/\(file.filename)"
                    if newValue == (file.content ?? "") {
                        appState.pendingEdits.removeValue(forKey: key)
                        appState.editedKeys.remove(key)
                    } else {
                        appState.pendingEdits[key] = newValue
                        appState.editedKeys.insert(key)
                    }
                }
            }
        )
        .onAppear {
            if let gist = appState.selectedGist {
                let key = "\(gist.id)/\(file.filename)"
                if let pending = appState.pendingEdits[key] {
                    currentContent = pending
                } else {
                    currentContent = file.content ?? ""
                }
            } else {
                currentContent = file.content ?? ""
            }
            currentLanguage = language(for: file)
        }
    }
}

#Preview {
    EditorView()
        .environment(AppState())
}
