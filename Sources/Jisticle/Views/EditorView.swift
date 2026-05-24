@preconcurrency import CodeEditorView
import LanguageSupport
import SwiftUI

nonisolated(unsafe) private let safeDefaultDark = Theme(
    colourScheme: .dark,
    fontName: "SFMono-Medium",
    fontSize: 13.0,
    textColour: NSColor(red: 0.87, green: 0.87, blue: 0.88, alpha: 1.0),
    commentColour: NSColor(red: 0.51, green: 0.55, blue: 0.59, alpha: 1.0),
    stringColour: NSColor(red: 0.94, green: 0.53, blue: 0.46, alpha: 1.0),
    characterColour: NSColor(red: 0.84, green: 0.79, blue: 0.53, alpha: 1.0),
    numberColour: NSColor(red: 0.81, green: 0.74, blue: 0.40, alpha: 1.0),
    identifierColour: NSColor(red: 0.41, green: 0.72, blue: 0.64, alpha: 1.0),
    operatorColour: NSColor(red: 0.62, green: 0.94, blue: 0.87, alpha: 1.0),
    keywordColour: NSColor(red: 0.94, green: 0.51, blue: 0.69, alpha: 1.0),
    symbolColour: NSColor(red: 0.72, green: 0.72, blue: 0.73, alpha: 1.0),
    typeColour: NSColor(red: 0.36, green: 0.85, blue: 1.0, alpha: 1.0),
    fieldColour: NSColor(red: 0.63, green: 0.40, blue: 0.90, alpha: 1.0),
    caseColour: NSColor(red: 0.82, green: 0.66, blue: 1.0, alpha: 1.0),
    backgroundColour: NSColor(red: 0.16, green: 0.16, blue: 0.18, alpha: 1.0),
    currentLineColour: NSColor(red: 0.19, green: 0.20, blue: 0.22, alpha: 1.0),
    selectionColour: NSColor(red: 0.40, green: 0.44, blue: 0.51, alpha: 1.0),
    cursorColour: NSColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0),
    invisiblesColour: NSColor(red: 0.33, green: 0.37, blue: 0.42, alpha: 1.0)
)

nonisolated(unsafe) private let safeDefaultLight = Theme(
    colourScheme: .light,
    fontName: "SFMono-Medium",
    fontSize: 13.0,
    textColour: NSColor(red: 0.15, green: 0.15, blue: 0.15, alpha: 1.0),
    commentColour: NSColor(red: 0.45, green: 0.50, blue: 0.55, alpha: 1.0),
    stringColour: NSColor(red: 0.76, green: 0.24, blue: 0.16, alpha: 1.0),
    characterColour: NSColor(red: 0.14, green: 0.19, blue: 0.81, alpha: 1.0),
    numberColour: NSColor(red: 0.0, green: 0.05, blue: 1.0, alpha: 1.0),
    identifierColour: NSColor(red: 0.23, green: 0.50, blue: 0.54, alpha: 1.0),
    operatorColour: NSColor(red: 0.18, green: 0.05, blue: 0.43, alpha: 1.0),
    keywordColour: NSColor(red: 0.63, green: 0.28, blue: 0.62, alpha: 1.0),
    symbolColour: NSColor(red: 0.24, green: 0.13, blue: 0.48, alpha: 1.0),
    typeColour: NSColor(red: 0.04, green: 0.29, blue: 0.46, alpha: 1.0),
    fieldColour: NSColor(red: 0.36, green: 0.15, blue: 0.60, alpha: 1.0),
    caseColour: NSColor(red: 0.18, green: 0.05, blue: 0.43, alpha: 1.0),
    backgroundColour: NSColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0),
    currentLineColour: NSColor(red: 0.93, green: 0.96, blue: 1.0, alpha: 1.0),
    selectionColour: NSColor(red: 0.73, green: 0.84, blue: 0.99, alpha: 1.0),
    cursorColour: NSColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0),
    invisiblesColour: NSColor(red: 0.84, green: 0.84, blue: 0.84, alpha: 1.0)
)

@MainActor
struct EditorView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme

    @State private var editorPosition = CodeEditor.Position()
    @State private var editorMessages: Set<TextLocated<Message>> = []
    @State private var currentContent: String = ""
    @State private var isDirty = false

    private var theme: Theme {
        colorScheme == .dark ? safeDefaultDark : safeDefaultLight
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

            // Code Editor
            CodeEditor(
                text: .init(
                    get: { currentContent },
                    set: { newValue in
                        currentContent = newValue
                        isDirty = true
                    }
                ),
                position: $editorPosition,
                messages: $editorMessages,
                language: languageConfiguration(for: file),
                layout: CodeEditor.LayoutConfiguration(showMinimap: false, wrapText: true)
            )
            .environment(\.codeEditorTheme, theme)
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

    private func languageConfiguration(for file: GistFile) -> LanguageConfiguration {
        let ext = (file.filename as NSString).pathExtension.lowercased()

        // CodeEditorView has built-in support for: swift, haskell, agda, cabal, cypher
        // For others, we return .none (plain text with basic highlighting)
        switch ext {
        case "swift":
            return .swift()
        case "hs":
            return .haskell()
        case "agda":
            return .agda()
        case "cabal":
            return .cabal()
        case "cypher", "cql":
            return .cypher()
        default:
            // Try to detect from language name
            if let lang = file.language?.lowercased() {
                switch lang {
                case "swift": return .swift()
                case "haskell": return .haskell()
                default: return .none
                }
            }
            return .none
        }
    }
}

#Preview {
    EditorView()
        .environment(AppState())
}
