import SwiftUI

struct SidebarView: View {
    @Environment(AppState.self) private var appState
    @StateObject private var authService = AuthService.shared
    @State private var showingDeleteConfirmation = false
    @State private var gistToDelete: Gist?

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            searchBar

            Divider()

            // Gists header
            HStack {
                Text("Gists")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Picker("Sort", selection: .init(
                    get: { appState.sortOrder },
                    set: { appState.sortOrder = $0 }
                )) {
                    ForEach(GistSortOrder.allCases) { order in
                        Text(order.rawValue).tag(order)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .controlSize(.small)
                .font(.caption)
                Button("+") {
                    NotificationCenter.default.post(name: .createNewGist, object: nil)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            // Gist list
            List(selection: .init(
                get: { appState.selectedGist },
                set: { gist in
                    if let gist = gist {
                        Task { appState.selectGist(gist) }
                    }
                }
            )) {
                ForEach(appState.filteredGists) { gist in
                    GistRow(gist: gist)
                        .tag(gist)
                        .contextMenu {
                            Button("Open in Browser") {
                                if let url = URL(string: gist.htmlUrl) {
                                    NSWorkspace.shared.open(url)
                                }
                            }

                            Divider()

                            Button("Delete", role: .destructive) {
                                gistToDelete = gist
                                showingDeleteConfirmation = true
                            }
                        }
                }
            }
            .listStyle(.sidebar)

            // Status bar
            statusBar
        }
        .frame(minWidth: 250)
        .alert("Delete Gist?", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let gist = gistToDelete {
                    Task {
                        await appState.deleteGist(gist)
                    }
                }
            }
        } message: {
            Text("This action cannot be undone.")
        }
    }

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Search gists...", text: .init(
                get: { appState.searchQuery },
                set: { appState.searchQuery = $0 }
            ))
            .textFieldStyle(.plain)

            if !appState.searchQuery.isEmpty {
                Button {
                    appState.searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(8)
        .background(.secondary.opacity(0.1))
        .cornerRadius(8)
        .padding(.horizontal, 12)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private var statusBar: some View {
        HStack {
            if appState.isLoading {
                ProgressView()
                    .controlSize(.small)
                Text("Loading...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("\(appState.gists.count) gists")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                Task {
                    await appState.loadGists()
                }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .disabled(appState.isLoading)

            Menu {
                Button("Sign Out") {
                    authService.logout()
                }
            } label: {
                Image(systemName: "person.circle")
            }
            .menuStyle(.borderlessButton)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.quaternary.opacity(0.3))
    }
}

private extension Date {
    var relativeFormatted: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.dateTimeStyle = .named
        formatter.calendar?.minimumDaysInFirstWeek = 1
        return formatter.localizedString(for: self, relativeTo: .now)
    }
}

struct GistRow: View {
    let gist: Gist

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                if !gist.public {
                    Image(systemName: "lock.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }

                Text(gist.displayTitle)
                    .font(.system(size: 13))
                    .lineLimit(2)
                    .truncationMode(.tail)
            }

            HStack(spacing: 4) {
                Text(gist.fileList.count == 1 ? "1 file" : "\(gist.fileList.count) files")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Text("·")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Text(gist.updatedAt.relativeFormatted)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    SidebarView()
        .environment(AppState())
}
