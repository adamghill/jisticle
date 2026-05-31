@preconcurrency import MarkdownUI
import SwiftUI

struct MarkdownPreviewView: View {
    let content: String
    @Environment(\.colorScheme) private var colorScheme
    
    private var theme: MarkdownUI.Theme {
        colorScheme == .dark ? .docC : .gitHub
    }
    
    var body: some View {
        Group {
            if content.isEmpty {
                emptyState
            } else {
                ScrollView {
                    Markdown(content)
                        .markdownTheme(theme)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
            }
        }
        .background(Color.clear)
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            
            Text("No content to preview")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}


#Preview {
    VStack {
        MarkdownPreviewView(
            content: """
            # Markdown Preview
            
            This is a **bold** text and this is *italic*.
            
            ## Code Example
            
            ```swift
            func hello() {
                print("Hello, World!")
            }
            ```
            
            ### Lists
            
            - Item 1
            - Item 2
            - Item 3
            
            ### Tables
            
            | Name | Age |
            |------|-----|
            | John | 25  |
            | Jane | 30  |
            
            > This is a blockquote
            
            [Link to GitHub](https://github.com)
            """
        )
    }
    .frame(width: 400, height: 600)
}
