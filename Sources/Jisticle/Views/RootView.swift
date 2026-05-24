import SwiftUI

struct RootView: View {
    @State private var appState = AppState()
    @StateObject private var authService = AuthService.shared

    var body: some View {
        Group {
            if authService.isAuthenticated {
                MainLayout()
                    .environment(appState)
            } else {
                LoginView()
            }
        }
    }
}
