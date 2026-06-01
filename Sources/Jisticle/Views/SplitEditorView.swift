import CodeEditor
import SwiftUI

struct SplitEditorView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme
    @State private var splitPosition: CGFloat = 0.5
    
    @AppStorage("editorFontSize") private var fontSize = Int(NSFont.monospacedSystemFont(ofSize: 0, weight: .regular).pointSize)
    @State private var currentContent: String = ""
    @State private var debouncedPreviewContent: String = ""
    @State private var currentLanguage: CodeEditor.Language = .init(rawValue: "plaintext")
    @State private var isDirty = false
    @State private var debounceTask: Task<Void, Never>?
    @State private var cachedTheme: CodeEditor.ThemeName?
    @State private var lastColorScheme: ColorScheme?
    @State private var languageDebounceTask: Task<Void, Never>?
    
    private var theme: CodeEditor.ThemeName {
        if let cachedTheme, lastColorScheme == colorScheme {
            return cachedTheme
        }
        let newTheme: CodeEditor.ThemeName = colorScheme == .dark ? .init(rawValue: "github-dark") : .init(rawValue: "github")
        cachedTheme = newTheme
        lastColorScheme = colorScheme
        return newTheme
    }
    
    var body: some View {
        HSplitView {
            // Editor pane - isolated subview prevents cursor jumping on preview updates
            VStack(spacing: 0) {
                if let gist = appState.selectedGist, let file = appState.selectedFile {
                    MarkdownEditorSubview(
                        gist: gist,
                        file: file,
                        language: currentLanguage,
                        theme: theme,
                        fontSize: .init(get: { CGFloat(fontSize) }, set: { fontSize = Int($0) }),
                        initialContent: currentContent,
                        onContentChange: { newValue in
                            // Reduce debounce for more responsive preview updates
                            debounceTask?.cancel()
                            debounceTask = Task {
                                try? await Task.sleep(for: .milliseconds(50))
                                guard !Task.isCancelled else { return }
                                await MainActor.run {
                                    debouncedPreviewContent = newValue
                                }
                            }
                            
                            let key = "\(gist.id)/\(file.filename)"
                            if newValue == (file.content ?? "") {
                                appState.pendingEdits.removeValue(forKey: key)
                                appState.editedKeys.remove(key)
                            } else {
                                appState.pendingEdits[key] = newValue
                                appState.editedKeys.insert(key)
                            }
                        }
                    )
                    .id("editor-\(gist.id)-\(file.filename)-\(currentLanguage.rawValue)")
                }
            }
            .frame(minWidth: 200)
            
            // Preview pane
            VStack(spacing: 0) {
                MarkdownPreviewView(content: debouncedPreviewContent)
            }
            .frame(minWidth: 200)
            .id("preview-\(appState.selectedGist?.id ?? "")-\(appState.selectedFile?.filename ?? "")")
        }
        .onAppear {
            loadContent()
        }
        .onChange(of: appState.selectedFile) { _, newFile in
            loadContent()
        }
        .onChange(of: appState.selectedGist) { _, newGist in
            syncSelectedFileToNewGist()
        }
    }
    
    private func loadContent() {
        guard let file = appState.selectedFile else { return }
        
        updateLanguage(language(for: file))
        
        if let gist = appState.selectedGist {
            let key = "\(gist.id)/\(file.filename)"
            if let pending = appState.pendingEdits[key] {
                currentContent = pending
                debouncedPreviewContent = pending
                appState.editedKeys.insert(key)
                isDirty = true
                return
            }
        }
        
        let content = file.content ?? ""
        currentContent = content
        debouncedPreviewContent = content
        isDirty = appState.newFilenames.contains(file.filename) && !(file.content?.isEmpty ?? true)
    }
    
    private func updateLanguage(_ newLanguage: CodeEditor.Language) {
        guard newLanguage != currentLanguage else { return }
        
        languageDebounceTask?.cancel()
        languageDebounceTask = Task {
            try? await Task.sleep(for: .milliseconds(100))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                currentLanguage = newLanguage
            }
        }
    }
    
    private func syncSelectedFileToNewGist() {
        guard let filename = appState.selectedFile?.filename,
              let updatedFile = appState.selectedGist?.files[filename] else { return }
        
        appState.selectedFile = updatedFile
    }
    
    private func saveChanges() {
        guard let gist = appState.selectedGist, let file = appState.selectedFile else { return }
        
        Task {
            if appState.newFilenames.contains(file.filename) {
                do {
                    _ = try await appState.createFileOnGitHub(filename: file.filename, content: currentContent)
                    isDirty = false
                } catch {
                    appState.errorMessage = "Failed to create file: \(error.localizedDescription)"
                }
            } else {
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
                isDirty = false
            }
        }
    }
    
    // Maps GitHub languages to ZeeZide/CodeEditor languages
    private func language(for file: GistFile?) -> CodeEditor.Language {
        guard let file else { return .init(rawValue: "plaintext") }
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
    
    private func formatBytes(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

#Preview {
    SplitEditorView()
        .environment(AppState())
        .frame(width: 800, height: 600)
}
