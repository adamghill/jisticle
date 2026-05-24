import SwiftUI

struct LoginView: View {
    @StateObject private var authService = AuthService.shared

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // App Icon Placeholder
            RoundedRectangle(cornerRadius: 20)
                .fill(.secondary.opacity(0.2))
                .frame(width: 120, height: 120)
                .overlay(
                    Image(systemName: "doc.text")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                )

            VStack(spacing: 8) {
                Text("Jisticle")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("A native macOS GitHub Gist client")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if authService.isAuthenticating {
                authenticatingView
            } else {
                Button("Sign in with GitHub") {
                    authService.startDeviceFlow()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }

            if let error = authService.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Spacer()
        }
        .frame(width: 400, height: 500)
        .padding()
    }

    private var authenticatingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)

            if let code = authService.deviceCode {
                VStack(spacing: 8) {
                    Text("Enter this code on GitHub:")
                        .font(.headline)

                    Text(code)
                        .font(.system(size: 32, weight: .bold, design: .monospaced))
                        .padding()
                        .background(.secondary.opacity(0.1))
                        .cornerRadius(8)
                        .textSelection(.enabled)

                    if let uri = authService.verificationUri {
                        Text("Or visit: \(uri)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Button("Cancel") {
                authService.logout()
            }
            .buttonStyle(.borderless)
        }
    }
}

#Preview {
    LoginView()
}
