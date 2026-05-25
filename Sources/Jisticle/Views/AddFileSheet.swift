import SwiftUI

struct AddFileSheet: View {
    @Environment(AppState.self) private var appState
    @Binding var isPresented: Bool

    @State private var filename = ""
    @State private var content = ""
    @State private var isSaving = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Add File to Gist")
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.escape)

                Button("Add") {
                    addFile()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canAdd || isSaving)
                .keyboardShortcut(.return, modifiers: .command)
            }
            .padding()

            Divider()

            // Form
            Form {
                Section {
                    TextField("Filename (e.g., newfile.swift)", text: $filename)
                        .textFieldStyle(.roundedBorder)

                    Text("This file will be added to: \(appState.selectedGist?.displayTitle ?? "Unknown Gist")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("File Content") {
                    TextEditor(text: $content)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 300)
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
        .onKeyPress(.escape) {
            isPresented = false
            return .handled
        }
    }

    private var canAdd: Bool {
        !filename.isEmpty && !content.isEmpty
    }

    private func addFile() {
        isSaving = true

        print("=== AddFileSheet.addFile START - filename: '\(filename)', content length: \(content.count) ===")

        // Ensure we have a valid filename and content before adding
        guard !filename.isEmpty && !content.isEmpty else {
            print("=== AddFileSheet.addFile GUARD FAILED - filename empty: \(filename.isEmpty), content empty: \(content.isEmpty) ===")
            isSaving = false
            return
        }

        print("=== AddFileSheet adding file: \(filename), content length: \(content.count) ===")

        Task {
            await appState.addFileToGist(filename: filename, content: content)
            isSaving = false
            isPresented = false
        }
    }
}

#Preview {
    AddFileSheet(isPresented: .constant(true))
        .environment(AppState())
}
