import SwiftUI

struct MainLayout: View {
    @Environment(AppState.self) private var appState
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    @State private var showNewGistSheet = false

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView()
        } content: {
            GistContentView()
        } detail: {
            EditorView()
        }
        .onAppear {
            Task {
                await appState.loadGists()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .createNewGist)) { _ in
            showNewGistSheet = true
        }
        .sheet(isPresented: $showNewGistSheet) {
            NewGistSheet(isPresented: $showNewGistSheet)
        }
        .alert("Error", isPresented: .init(
            get: { appState.errorMessage != nil },
            set: { if !$0 { appState.errorMessage = nil } }
        )) {
            Button("OK") {
                appState.errorMessage = nil
            }
        } message: {
            Text(appState.errorMessage ?? "")
        }
    }
}

#Preview {
    MainLayout()
        .environment(AppState())
}
