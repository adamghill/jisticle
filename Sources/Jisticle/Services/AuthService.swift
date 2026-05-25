import AppKit
import Foundation
import KeychainAccess

@MainActor
class AuthService: ObservableObject {
    static let shared = AuthService()
    
    static let clientId = "Ov23lic748xQGnAj31mO"

    private let keychain = Keychain(service: "com.adamghill.jisticle")
    private let tokenKey = "github_access_token"
    private let baseURL = "https://github.com"

    @Published var isAuthenticated = false
    @Published var isAuthenticating = false
    @Published var deviceCode: String?
    @Published var verificationUri: String?
    @Published var errorMessage: String?

    private var pollTask: Task<Void, Never>?

    private init() {
        checkExistingAuth()
    }

    private func checkExistingAuth() {
        if let token = try? keychain.get(tokenKey), !token.isEmpty {
            isAuthenticated = true
        }
    }

    func getAccessToken() -> String? {
        try? keychain.get(tokenKey)
    }

    func startDeviceFlow() {
        isAuthenticating = true
        errorMessage = nil

        pollTask = Task {
            do {
                let (deviceCode, userCode, verificationUri, interval) = try await requestDeviceCode()

                await MainActor.run {
                    self.deviceCode = userCode
                    self.verificationUri = verificationUri
                }

                // Open browser for user
                if let url = URL(string: verificationUri) {
                    NSWorkspace.shared.open(url)
                }

                // Start polling
                try await pollForToken(deviceCode: deviceCode, interval: interval)

            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isAuthenticating = false
                }
            }
        }
    }

    private func requestDeviceCode() async throws -> (deviceCode: String, userCode: String, verificationUri: String, interval: Int) {
        let url = URL(string: "\(baseURL)/login/device/code")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let bodyParams = [
            "client_id": Self.clientId,
            "scope": "gist"
        ]
        request.httpBody = bodyParams.percentEncoded()

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.deviceCodeRequestFailed(message: "No HTTP response")
        }
        
        guard httpResponse.statusCode == 200 else {
            let responseBody = String(data: data, encoding: .utf8) ?? "No response body"
            throw AuthError.deviceCodeRequestFailed(message: "HTTP \(httpResponse.statusCode): \(responseBody)")
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let deviceCode = json["device_code"] as? String,
              let userCode = json["user_code"] as? String,
              let verificationUri = json["verification_uri"] as? String else {
            throw AuthError.invalidResponse
        }

        let interval = json["interval"] as? Int ?? 5

        return (deviceCode, userCode, verificationUri, interval)
    }

    private func pollForToken(deviceCode: String, interval: Int) async throws {
        let url = URL(string: "\(baseURL)/login/oauth/access_token")!

        var attempts = 0
        let maxAttempts = 60 // 5 minutes with default interval

        while attempts < maxAttempts {
            try await Task.sleep(nanoseconds: UInt64(interval) * 1_000_000_000)

            // Check if task was cancelled
            if Task.isCancelled {
                throw AuthError.cancelled
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

            let bodyParams = [
                "client_id": Self.clientId,
                "device_code": deviceCode,
                "grant_type": "urn:ietf:params:oauth:grant-type:device_code"
            ]
            request.httpBody = bodyParams.percentEncoded()

            let (data, _) = try await URLSession.shared.data(for: request)

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                continue
            }

            if let error = json["error"] as? String {
                if error == "authorization_pending" {
                    attempts += 1
                    continue
                } else if error == "slow_down" {
                    // Server asked us to slow down, wait longer next time
                    try await Task.sleep(nanoseconds: UInt64(interval + 5) * 1_000_000_000)
                    continue
                } else {
                    throw AuthError.oauthError(error)
                }
            }

            if let accessToken = json["access_token"] as? String {
                try keychain.set(accessToken, key: tokenKey)

                await MainActor.run {
                    self.isAuthenticated = true
                    self.isAuthenticating = false
                    self.deviceCode = nil
                    self.verificationUri = nil
                }
                return
            }

            attempts += 1
        }

        throw AuthError.timeout
    }

    func logout() {
        pollTask?.cancel()
        pollTask = nil

        try? keychain.remove(tokenKey)
        GistCache.clear()
        isAuthenticated = false
        isAuthenticating = false
        deviceCode = nil
        verificationUri = nil
        errorMessage = nil
    }
}

enum AuthError: Error, LocalizedError {
    case deviceCodeRequestFailed(message: String)
    case invalidResponse
    case oauthError(String)
    case timeout
    case cancelled

    var errorDescription: String? {
        switch self {
        case .deviceCodeRequestFailed(let message):
            if message.contains("404") || message.contains("Bad credentials") {
                return "GitHub OAuth app not configured.\n\nCreate an OAuth app at github.com/settings/developers with Device Flow enabled, then update clientId in AuthService.swift"
            }
            return "Failed to request device code: \(message)"
        case .invalidResponse:
            return "Invalid response from GitHub."
        case .oauthError(let error):
            return "OAuth error: \(error)"
        case .timeout:
            return "Authentication timed out. Please try again."
        case .cancelled:
            return "Authentication was cancelled."
        }
    }
}

extension Dictionary where Key == String, Value == String {
    func percentEncoded() -> Data? {
        return map { key, value in
            let escapedKey = key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            let escapedValue = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            return "\(escapedKey)=\(escapedValue)"
        }
        .joined(separator: "&")
        .data(using: .utf8)
    }
}
