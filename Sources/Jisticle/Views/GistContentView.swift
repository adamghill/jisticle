import SwiftUI

struct GistContentView: View {
    @Environment(AppState.self) private var appState
    @State private var isAddingFile = false
    @State private var newFilename = ""
    @State private var isDropTarget = false
    @FocusState private var filenameFieldFocused: Bool

    var body: some View {
        Group {
            if let gist = appState.selectedGist {
                fileList(gist: gist)
            } else {
                emptyState
            }
        }
        .frame(minWidth: 200)
    }

    private func fileList(gist: Gist) -> some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                let title = gist.displayTitle
                HStack(spacing: 6) {
                    Image(systemName: gist.public ? "globe" : "lock.fill")
                        .foregroundStyle(gist.public ? .blue : .orange)
                    Text(title)
                        .font(.headline)
                        .lineLimit(2)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Label("Updated \(formatDate(gist.updatedAt))", systemImage: "pencil")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .help("Updated: \(formatFullDate(gist.updatedAt))")

                    Label("Created \(formatDate(gist.createdAt))", systemImage: "clock")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .help("Created: \(formatFullDate(gist.createdAt))")

                    HStack(spacing: 12) {
                        Label("\(gist.stargazerCount)", systemImage: "star")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .help("\(gist.stargazerCount) star\(gist.stargazerCount == 1 ? "" : "s")")

                        Label("\(gist.forkCount)", systemImage: "tuningfork")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .help("\(gist.forkCount) fork\(gist.forkCount == 1 ? "" : "s")")
                    }

                    HStack(spacing: 12) {
                        let commentsUrl = URL(string: "\(gist.htmlUrl)#comments")!
                        Link(destination: commentsUrl) {
                            Label("\(gist.commentCount)", systemImage: "bubble")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .pointingCursor()
                        .help("\(gist.commentCount) comment\(gist.commentCount == 1 ? "" : "s")")

                        let revisionsUrl = URL(string: "\(gist.htmlUrl)/revisions")!
                        Link(destination: revisionsUrl) {
                            Label("\(gist.revisionCount)", systemImage: "clock.arrow.circlepath")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .pointingCursor()
                        .help("\(gist.revisionCount) revision\(gist.revisionCount == 1 ? "" : "s")")
                    }

                    if let zipUrl = gist.zipArchiveUrl {
                        Link(destination: zipUrl) {
                            Label("Download", systemImage: "arrow.down.circle")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .pointingCursor()
                        .help("Download ZIP archive")
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary.opacity(0.2))

            Divider()

            // File list
            List {
                Section {
                    // Inline add file input row
                    if isAddingFile {
                        HStack {
                            TextField("filename.ext", text: $newFilename)
                                .focused($filenameFieldFocused)
                                .onSubmit {
                                    confirmAddFile()
                                }
                                .onKeyPress(.escape) {
                                    cancelAddFile()
                                    return .handled
                                }

                            Spacer()

                            Button("✓") {
                                confirmAddFile()
                            }
                            .disabled(newFilename.isEmpty)
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)

                            Button("×") {
                                cancelAddFile()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                        .padding(.vertical, 2)
                    }

                    // Existing files
                    ForEach(gist.fileList) { file in
                        FileRow(file: file)
                            .listRowInsets(EdgeInsets())
                            .listRowSeparator(.visible)
                            .listRowBackground(appState.selectedFile?.filename == file.filename ? Color.accentColor.opacity(0.2) : Color.clear)
                    }
                } header: {
                    HStack {
                        Text("Files")
                        Spacer()
                        
                        if !isAddingFile {
                            Button("+") {
                                startAddFile()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .keyboardShortcut("n", modifiers: [.command])
                        }
                    }
                }
            }
            .listStyle(.plain)
            .environment(\.defaultMinListRowHeight, 30)
            .dropDestination(for: URL.self) { urls, location in
                Task {
                    for url in urls {
                        await appState.addFileFromDisk(url: url)
                    }
                }
                return true
            } isTargeted: { isTargeted in
                isDropTarget = isTargeted
            }
            .overlay {
                if isDropTarget {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.accentColor, lineWidth: 2)
                        .background(Color.accentColor.opacity(0.1))
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("Select a gist to view its files")
                .foregroundStyle(.secondary)
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func formatFullDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    // MARK: - Inline Add File Methods
    
    private func startAddFile() {
        isAddingFile = true
        newFilename = ""
        filenameFieldFocused = true
    }
    
    private func confirmAddFile() {
        guard !newFilename.isEmpty else { return }

        // Add file locally only - will be synced to GitHub on first save
        appState.addFileToGistLocal(filename: newFilename)

        isAddingFile = false
        newFilename = ""
    }
    
    private func cancelAddFile() {
        isAddingFile = false
        newFilename = ""
    }
}

struct FileRow: View {
    let file: GistFile
    @Environment(AppState.self) private var appState
    @State private var isRenaming = false
    @State private var renameText = ""
    @State private var showDeleteConfirmation = false
    @FocusState private var renameFieldFocused: Bool

    private var isNewFile: Bool {
        appState.newFilenames.contains(file.filename)
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                if isRenaming {
                    TextField("filename.ext", text: $renameText)
                        .font(.system(size: 13))
                        .focused($renameFieldFocused)
                        .onSubmit {
                            confirmRename()
                        }
                        .onKeyPress(.escape) {
                            cancelRename()
                            return .handled
                        }
                } else {
                    HStack(spacing: 4) {
                        Text(file.filename)
                            .font(.system(size: 13))
                            .lineLimit(1)

                        if isNewFile {
                            Image(systemName: "circle.fill")
                                .font(.system(size: 6))
                                .foregroundStyle(.orange)
                                .help("New file - not yet saved to GitHub")
                        }
                    }
                }

                if !isNewFile {
                    HStack {
                        Text(file.displayLanguage)
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        Text("•")
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        Text(formatBytes(file.size))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture {
            print("[FileRow] Single tap on: \(file.filename)")
            appState.selectFile(file)
        }
        .contextMenu {
            Button("Rename") {
                startRename()
            }
            .keyboardShortcut("r", modifiers: [.command])

            Divider()

            Button("Delete", role: .destructive) {
                showDeleteConfirmation = true
            }
            .keyboardShortcut(.delete, modifiers: [.command])
        }
        .confirmationDialog(
            "Delete \"\(file.filename)\"?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                Task {
                    await appState.deleteFileFromGist(filename: file.filename)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This action cannot be undone.")
        }
    }
    
    private func startRename() {
        isRenaming = true
        renameText = file.filename
        renameFieldFocused = true
    }
    
    private func confirmRename() {
        guard !renameText.isEmpty && renameText != file.filename else {
            cancelRename()
            return
        }
        
        Task {
            await appState.renameFileInGist(oldFilename: file.filename, newFilename: renameText)
            await MainActor.run {
                isRenaming = false
                renameText = ""
            }
        }
    }
    
    private func cancelRename() {
        isRenaming = false
        renameText = ""
    }
    
    private func formatBytes(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

#Preview {
    GistContentView()
        .environment(AppState())
}
