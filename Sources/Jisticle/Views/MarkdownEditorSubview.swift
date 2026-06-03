import SwiftUI

struct MarkdownEditorSubview: View {
    let gist: Gist
    let file: GistFile
    let language: Language
    let theme: EditorTheme
    let fontSize: Binding<CGFloat>
    let initialContent: String
    let onContentChange: (String) -> Void
    
    @State private var text: String = ""
    
    init(
        gist: Gist,
        file: GistFile,
        language: Language,
        theme: EditorTheme,
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
        CodeEditorView(
            text: $text,
            language: language,
            theme: theme,
            fontSize: fontSize,
            isEditable: true,
            onTextChange: { newValue in
                onContentChange(newValue)
            }
        )
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
