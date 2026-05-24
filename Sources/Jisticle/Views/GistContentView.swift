import SwiftUI

struct GistContentView: View {
    @Environment(AppState.self) private var appState

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
                        Label("\(gist.commentCount)", systemImage: "bubble")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .help("\(gist.commentCount) comment\(gist.commentCount == 1 ? "" : "s")")

                        let revisionsUrl = URL(string: "\(gist.htmlUrl)/revisions")!
                        Link(destination: revisionsUrl) {
                            Label("\(gist.revisionCount)", systemImage: "clock.arrow.circlepath")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .help("\(gist.revisionCount) revision\(gist.revisionCount == 1 ? "" : "s")")
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary.opacity(0.2))

            Divider()

            // File list
            List(selection: .init(
                get: { appState.selectedFile },
                set: { file in
                    if let file = file {
                        appState.selectFile(file)
                    }
                }
            )) {
                Section("Files") {
                    ForEach(gist.fileList) { file in
                        FileRow(file: file)
                            .tag(file)
                    }
                }
            }
            .listStyle(.plain)
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
}

struct FileRow: View {
    let file: GistFile

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(file.filename)
                    .font(.system(size: 13))
                    .lineLimit(1)

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

            Spacer()
        }
        .padding(.vertical, 4)
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
