import CodeEditor
import SwiftUI

struct MarkdownEditorSubview: View {
    let gist: Gist
    let file: GistFile
    let language: CodeEditor.Language
    let theme: CodeEditor.ThemeName
    let fontSize: Binding<CGFloat>
    let initialContent: String
    let onContentChange: (String) -> Void
    
    @State private var text: String = ""
    @State private var contentChangeTask: Task<Void, Never>?
    
    init(
        gist: Gist,
        file: GistFile,
        language: CodeEditor.Language,
        theme: CodeEditor.ThemeName,
        fontSize: Binding<CGFloat>,
        initialContent: String,
        onContentChange: @escaping (String) -> Void
    ) {
        self.gist = gist
        self.file = file
        self.language = language
        self.theme = theme
        self.fontSize = fontSize
        self.initialContent = initialContent
        self.onContentChange = onContentChange
        _text = State(initialValue: initialContent)
    }
    
    var body: some View {
        CodeEditor(
            source: $text,
            language: language,
            theme: theme,
            fontSize: fontSize,
            flags: [.editable, .selectable, .smartIndent]
        )
        .onChange(of: text) { _, newValue in
            // Debounce content changes to reduce flickering during typing
            contentChangeTask?.cancel()
            contentChangeTask = Task {
                try? await Task.sleep(for: .milliseconds(16))
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    onContentChange(newValue)
                }
            }
        }
        .onChange(of: initialContent) { _, newValue in
            // Sync when parent loads new content (e.g., file switch)
            if text != newValue {
                text = newValue
            }
        }
        .task {
            // Ensure text is synced when view appears
            if text != initialContent {
                text = initialContent
            }
        }
    }
}
