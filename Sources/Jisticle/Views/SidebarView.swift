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

            // Sort picker
            sortPicker

            // Gist list
            List(selection: .init(
                get: { appState.selectedGist },
                set: { gist in
                    if let gist = gist {
                        appState.selectGist(gist)
                    }
                }
            )) {
                Section {
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
                } header: {
                    Text("Gists")
                        .font(.caption)
                        .textCase(.none)
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

    private var sortPicker: some View {
        HStack {
            Text("Sort:")
                .font(.caption)
                .foregroundStyle(.secondary)

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
            .font(.caption)
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 6)
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

struct GistRow: View {
    let gist: Gist

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(gist.displayTitle)
                .font(.system(size: 13))
                .lineLimit(2)
                .truncationMode(.tail)

            HStack(spacing: 8) {
                if let lang = gist.primaryLanguage {
                    Label(lang, systemImage: "circle.fill")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if gist.fileList.count > 1 {
                    Text("\(gist.fileList.count) files")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if !gist.public {
                    Image(systemName: "lock.fill")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    SidebarView()
        .environment(AppState())
}
