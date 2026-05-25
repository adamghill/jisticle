import SwiftUI

struct NewGistSheet: View {
    @Environment(AppState.self) private var appState
    @Binding var isPresented: Bool

    @State private var filename = ""
    @State private var description = ""
    @State private var isPrivate = true

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("New Gist")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
            }
            .padding()

            Divider()

            // Form
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Description")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("Optional", text: $description)
                        .textFieldStyle(.roundedBorder)
                }

                Toggle("Is Private", isOn: $isPrivate)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Filename")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("e.g. script.swift", text: $filename)
                        .textFieldStyle(.roundedBorder)
                }
            }
            .padding()

            Spacer()

            Divider()

            // Footer buttons
            HStack {
                Spacer()
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.escape)

                Button("Create") {
                    appState.prepareDraftGist(
                        filename: filename,
                        description: description,
                        isPublic: !isPrivate
                    )
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(filename.isEmpty)
                .keyboardShortcut(.return, modifiers: .command)
            }
            .padding()
        }
        .frame(width: 400, height: 260)
    }
}

#Preview {
    NewGistSheet(isPresented: .constant(true))
        .environment(AppState())
}
