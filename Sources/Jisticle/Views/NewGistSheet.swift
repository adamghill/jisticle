import SwiftUI

struct NewGistSheet: View {
    @Environment(AppState.self) private var appState
    @Binding var isPresented: Bool

    @State private var description = ""
    @State private var isPublic = true
    @State private var filename = ""
    @State private var content = ""
    @State private var isSaving = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("New Gist")
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.escape)

                Button("Create") {
                    createGist()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canCreate || isSaving)
                .keyboardShortcut(.return, modifiers: .command)
            }
            .padding()

            Divider()

            // Form
            Form {
                Section {
                    TextField("Description", text: $description)
                        .textFieldStyle(.roundedBorder)

                    Toggle("Public Gist", isOn: $isPublic)
                }

                Section("File") {
                    TextField("Filename (e.g., script.swift)", text: $filename)
                        .textFieldStyle(.roundedBorder)

                    TextEditor(text: $content)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 200)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(.secondary.opacity(0.2), lineWidth: 1)
                        )
                }
            }
            .formStyle(.grouped)
            .padding()

            Spacer()
        }
        .frame(width: 600, height: 500)
    }

    private var canCreate: Bool {
        !filename.isEmpty && !content.isEmpty
    }

    private func createGist() {
        isSaving = true

        let draft = GistDraft(
            description: description,
            isPublic: isPublic,
            files: [filename: GistFileDraft(content: content)]
        )

        Task {
            await appState.createGist(draft: draft)
            isSaving = false
            isPresented = false
        }
    }
}

#Preview {
    NewGistSheet(isPresented: .constant(true))
        .environment(AppState())
}
