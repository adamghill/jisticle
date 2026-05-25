import Foundation

@MainActor
protocol GistProvider {
    func listGists() async throws -> [Gist]
    func fetchGist(id: String) async throws -> Gist
    func createGist(_ draft: GistDraft) async throws -> Gist
    func updateGist(id: String, _ draft: GistDraft) async throws -> Gist
    func addFileToGist(id: String, filename: String, content: String) async throws -> Gist
    func deleteFileFromGist(id: String, filename: String) async throws -> Gist
    func renameFileInGist(id: String, oldFilename: String, newFilename: String) async throws -> Gist
    func deleteGist(id: String) async throws
}

enum GistProviderError: Error, LocalizedError {
    case notAuthenticated
    case invalidResponse
    case apiError(statusCode: Int, message: String)
    case networkError(Error)
    case decodingError(Error)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Not authenticated. Please sign in."
        case .invalidResponse:
            return "Invalid response from server."
        case .apiError(let statusCode, let message):
            return "API Error (\(statusCode)): \(message)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Failed to parse response: \(error.localizedDescription)"
        }
    }
}
