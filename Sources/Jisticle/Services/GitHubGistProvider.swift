import Foundation

@MainActor
class GitHubGistProvider: GistProvider, ObservableObject {
    static let shared = GitHubGistProvider()

    private let baseURL = "https://api.github.com"
    private let authService = AuthService.shared

    private init() {}

    private func makeRequest(url: URL, method: String = "GET", body: Data? = nil) async throws -> Data {
        guard let token = authService.getAccessToken() else {
            throw GistProviderError.notAuthenticated
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")

        if let body = body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = body
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GistProviderError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw GistProviderError.apiError(statusCode: httpResponse.statusCode, message: message)
        }

        return data
    }

    func listGists() async throws -> [Gist] {
        let url = URL(string: "https://api.github.com/graphql")!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        var allGists: [Gist] = []
        var cursor: String? = nil

        repeat {
            let afterArg = cursor.map { ", after: \"\($0)\"" } ?? ""
            let query = """
            {
              viewer {
                gists(first: 100, privacy: ALL\(afterArg)) {
                  pageInfo { hasNextPage endCursor }
                  nodes {
                    name
                    description
                    isPublic
                    createdAt
                    updatedAt
                    url
                    stargazerCount
                    forks { totalCount }
                    comments { totalCount }
                    owner { login avatarUrl }
                    files(limit: 300) {
                      name
                      language { name }
                      size
                      encodedName
                    }
                  }
                }
              }
            }
            """

            let body = try JSONSerialization.data(withJSONObject: ["query": query])
            let data = try await makeRequest(url: url, method: "POST", body: body)

            let response: GraphQLGistsResponse
            do {
                response = try decoder.decode(GraphQLGistsResponse.self, from: data)
            } catch {
                throw GistProviderError.decodingError(error)
            }

            if let errors = response.errors, !errors.isEmpty {
                throw GistProviderError.apiError(statusCode: 200, message: errors.map { $0.message }.joined(separator: ", "))
            }

            guard let connection = response.data?.viewer.gists else { break }
            allGists.append(contentsOf: connection.nodes.map { $0.toGist() })

            if connection.pageInfo.hasNextPage {
                cursor = connection.pageInfo.endCursor
            } else {
                cursor = nil
            }
        } while cursor != nil

        return allGists
    }

    func fetchGist(id: String) async throws -> Gist {
        let url = URL(string: "\(baseURL)/gists/\(id)")!
        let data = try await makeRequest(url: url)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            return try decoder.decode(Gist.self, from: data)
        } catch {
            throw GistProviderError.decodingError(error)
        }
    }

    func createGist(_ draft: GistDraft) async throws -> Gist {
        let url = URL(string: "\(baseURL)/gists")!

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let body = try encoder.encode(draft)

        let data = try await makeRequest(url: url, method: "POST", body: body)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            return try decoder.decode(Gist.self, from: data)
        } catch {
            throw GistProviderError.decodingError(error)
        }
    }

    func updateGist(id: String, _ draft: GistDraft) async throws -> Gist {
        let url = URL(string: "\(baseURL)/gists/\(id)")!

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let body = try encoder.encode(draft)

        let data = try await makeRequest(url: url, method: "PATCH", body: body)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            return try decoder.decode(Gist.self, from: data)
        } catch {
            throw GistProviderError.decodingError(error)
        }
    }

    func deleteGist(id: String) async throws {
        let url = URL(string: "\(baseURL)/gists/\(id)")!
        _ = try await makeRequest(url: url, method: "DELETE")
    }
}

private struct GraphQLGistsResponse: Decodable {
    let data: GraphQLGistsData?
    let errors: [GraphQLError]?
}

private struct GraphQLError: Decodable {
    let message: String
}

private struct GraphQLGistsData: Decodable {
    let viewer: GraphQLViewer
}

private struct GraphQLViewer: Decodable {
    let gists: GraphQLGistConnection
}

private struct GraphQLGistConnection: Decodable {
    let pageInfo: GraphQLPageInfo
    let nodes: [GraphQLGistNode]
}

private struct GraphQLPageInfo: Decodable {
    let hasNextPage: Bool
    let endCursor: String?
}

private struct GraphQLGistNode: Decodable {
    let name: String
    let description: String?
    let isPublic: Bool
    let createdAt: Date
    let updatedAt: Date
    let url: String
    let stargazerCount: Int
    let forks: GraphQLTotalCount
    let comments: GraphQLTotalCount
    let owner: GraphQLOwner?
    let files: [GraphQLGistFile]?

    func toGist() -> Gist {
        let gistFiles: [String: GistFile] = Dictionary(
            uniqueKeysWithValues: (files ?? []).compactMap { f -> (String, GistFile)? in
                guard let filename = f.name else { return nil }
                let file = GistFile(
                    filename: filename,
                    type: nil,
                    language: f.language?.name,
                    rawUrl: "",
                    size: f.size ?? 0,
                    content: nil,
                    truncated: nil
                )
                return (filename, file)
            }
        )

        return Gist(
            id: name,
            description: description,
            public: isPublic,
            owner: owner.map { GistOwner(login: $0.login, avatarUrl: $0.avatarUrl) },
            files: gistFiles,
            createdAt: createdAt,
            updatedAt: updatedAt,
            htmlUrl: url,
            stargazerCount: stargazerCount,
            forkCount: forks.totalCount,
            commentCount: comments.totalCount
        )
    }
}

private struct GraphQLTotalCount: Decodable {
    let totalCount: Int
}

private struct GraphQLOwner: Decodable {
    let login: String
    let avatarUrl: String?
}

private struct GraphQLGistFile: Decodable {
    let name: String?
    let language: GraphQLLanguage?
    let size: Int?
    let encodedName: String?
}

private struct GraphQLLanguage: Decodable {
    let name: String
}
