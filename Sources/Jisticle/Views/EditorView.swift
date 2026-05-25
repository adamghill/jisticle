import CodeEditor
import SwiftUI

@MainActor
struct EditorView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme

    @AppStorage("editorFontSize") private var fontSize = Int(NSFont.monospacedSystemFont(ofSize: 0, weight: .regular).pointSize)
    @State private var currentContent: String = ""
    @State private var isDirty = false

    private var theme: CodeEditor.ThemeName {
        colorScheme == .dark ? .atelierSavannaDark : .atelierSavannaLight
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
            currentContent = newFile?.content ?? ""
            isDirty = false
        }
    }

    private func editorContent(gist: Gist, file: GistFile) -> some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Text(file.filename)
                    .font(.headline)

                Spacer()

                Text(file.displayLanguage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(.secondary.opacity(0.1))
                    .cornerRadius(4)

                if isDirty {
                    Text("Modified")
                        .font(.caption)
                        .foregroundStyle(.orange)
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

            // Code Editor with ZeeZide/CodeEditor
            CodeEditor(
                source: .init(
                    get: { currentContent },
                    set: { newValue in
                        currentContent = newValue
                        isDirty = true
                    }
                ),
                language: language(for: file),
                theme: theme,
                fontSize: .init(get: { CGFloat(fontSize) }, set: { fontSize = Int($0) }),
                flags: [.editable, .selectable, .smartIndent]
            )
            .onAppear {
                currentContent = file.content ?? ""
                isDirty = false
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
        guard let gist = appState.selectedGist else { return }

        var files: [String: GistFileDraft] = [:]
        for gistFile in gist.fileList {
            if gistFile.id == appState.selectedFile?.id {
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

        Task {
            await appState.updateGist(draft: draft)
            isDirty = false
        }
    }

    // Maps GitHub languages to ZeeZide/CodeEditor languages
    // ZeeZide/CodeEditor supports 180+ languages via highlight.js
    private func language(for file: GistFile) -> CodeEditor.Language {
        let ext = (file.filename as NSString).pathExtension.lowercased()

        switch ext {
        case "swift":                           return .swift
        case "py":                              return .python
        case "js", "mjs", "cjs":               return .javascript
        case "ts", "mts", "cts":               return .typescript
        case "jsx":                             return .init(rawValue: "jsx")
        case "tsx":                             return .init(rawValue: "tsx")
        case "rb", "rake", "gemspec":           return .ruby
        case "go":                              return .go
        case "rs":                              return .rust
        case "java":                            return .java
        case "kt", "kts":                       return .init(rawValue: "kotlin")
        case "cs":                              return .cs
        case "cpp", "cxx", "cc", "c++":        return .cpp
        case "c", "h":                          return .c
        case "m", "mm":                         return .objectivec
        case "sh", "bash", "zsh", "fish":       return .shell
        case "html", "htm":                     return .init(rawValue: "html")
        case "css":                             return .css
        case "scss", "sass":                    return .init(rawValue: "scss")
        case "json":                            return .json
        case "xml", "plist", "svg":             return .xml
        case "yaml", "yml":                     return .yaml
        case "toml":                            return .init(rawValue: "toml")
        case "md", "markdown":                  return .markdown
        case "sql":                             return .sql
        case "r":                               return .init(rawValue: "r")
        case "php":                             return .php
        case "pl", "pm":                        return .init(rawValue: "perl")
        case "lua":                             return .lua
        case "hs", "lhs":                       return .init(rawValue: "haskell")
        case "ex", "exs":                       return .init(rawValue: "elixir")
        case "erl", "hrl":                      return .init(rawValue: "erlang")
        case "scala":                           return .init(rawValue: "scala")
        case "dart":                            return .init(rawValue: "dart")
        case "dockerfile":                      return .dockerfile
        case "makefile", "mk":                  return .makefile
        case "ini", "cfg", "conf":              return .init(rawValue: "ini")
        case "tex":                             return .tex
        case "vim":                             return .init(rawValue: "vim")
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
        case "kotlin":                          return .init(rawValue: "kotlin")
        case "c#":                              return .cs
        case "c++":                             return .cpp
        case "c":                               return .c
        case "objective-c", "objective-c++":   return .objectivec
        case "shell", "bash":                   return .shell
        case "html":                            return .init(rawValue: "html")
        case "css":                             return .css
        case "json":                            return .json
        case "xml":                             return .xml
        case "yaml":                            return .yaml
        case "markdown":                        return .markdown
        case "sql", "plpgsql", "tsql":          return .pgsql
        case "r":                               return .init(rawValue: "r")
        case "php":                             return .php
        case "perl":                            return .init(rawValue: "perl")
        case "lua":                             return .lua
        case "haskell":                         return .init(rawValue: "haskell")
        case "elixir":                          return .init(rawValue: "elixir")
        case "erlang":                          return .init(rawValue: "erlang")
        case "scala":                           return .init(rawValue: "scala")
        case "dart":                            return .init(rawValue: "dart")
        case "dockerfile":                      return .dockerfile
        case "makefile":                        return .makefile
        case "tex":                             return .tex
        default:                                return .init(rawValue: "plaintext")
        }
    }
}

#Preview {
    EditorView()
        .environment(AppState())
}
