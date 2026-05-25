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
        encoder.outputFormatting = .prettyPrinted
        let body = try encoder.encode(draft)

        // Debug: Print the JSON being sent
        if let jsonString = String(data: body, encoding: .utf8) {
            print("=== updateGist JSON being sent ===")
            print(jsonString)
            print("===================================")
        }

        let data = try await makeRequest(url: url, method: "PATCH", body: body)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            return try decoder.decode(Gist.self, from: data)
        } catch {
            throw GistProviderError.decodingError(error)
        }
    }

    func addFileToGist(id: String, filename: String, content: String) async throws -> Gist {
        // First, fetch the current gist to get existing files
        let currentGist = try await fetchGist(id: id)
        
        print("=== addFileToGist Debug ===")
        print("Current gist ID: \(currentGist.id)")
        print("Current files count: \(currentGist.files.count)")
        print("Current files: \(currentGist.files.keys)")
        
        // Create a new files dictionary with existing files plus the new file
        var updatedFiles = currentGist.files
        updatedFiles[filename] = GistFile(
            filename: filename,
            type: nil,
            language: nil,
            rawUrl: "",
            size: content.count,
            content: content,
            truncated: false
        )
        
        print("Updated files count: \(updatedFiles.count)")
        print("Updated files: \(updatedFiles.keys)")
        
        // Create a draft with all existing files plus the new one
        let filesDict = Dictionary(uniqueKeysWithValues: updatedFiles.map { key, value in
            let content = value.content ?? ""
            print("File: \(key) -> content length: \(content.count)")
            return (key, GistFileDraft(content: content))
        })
        
        print("Files dict count: \(filesDict.count)")
        
        let draft = GistDraft(
            description: currentGist.description ?? "",
            isPublic: currentGist.public,
            files: filesDict
        )
        
        print("Draft files count: \(draft.files.count)")
        
        // Update the gist with the new file
        return try await updateGist(id: id, draft)
    }

    func deleteFileFromGist(id: String, filename: String) async throws -> Gist {
        // First, fetch the current gist to get existing files
        let currentGist = try await fetchGist(id: id)
        
        print("=== deleteFileFromGist Debug ===")
        print("Current gist ID: \(currentGist.id)")
        print("Current files count: \(currentGist.files.count)")
        print("Deleting file: \(filename)")
        
        // Remove the file from the dictionary
        var updatedFiles = currentGist.files
        updatedFiles.removeValue(forKey: filename)
        
        print("Updated files count: \(updatedFiles.count)")
        
        // Create a draft with all remaining files
        let filesDict = Dictionary(uniqueKeysWithValues: updatedFiles.map { key, value in
            let content = value.content ?? ""
            print("Remaining file: \(key) -> content length: \(content.count)")
            return (key, GistFileDraft(content: content))
        })
        
        let draft = GistDraft(
            description: currentGist.description ?? "",
            isPublic: currentGist.public,
            files: filesDict
        )
        
        print("Draft files count: \(draft.files.count)")
        
        // Update the gist without the deleted file
        return try await updateGist(id: id, draft)
    }

    func renameFileInGist(id: String, oldFilename: String, newFilename: String) async throws -> Gist {
        // First, fetch the current gist to get existing files
        let currentGist = try await fetchGist(id: id)
        
        print("=== renameFileInGist Debug ===")
        print("Current gist ID: \(currentGist.id)")
        print("Current files count: \(currentGist.files.count)")
        print("Renaming file: \(oldFilename) -> \(newFilename)")
        
        // Get the file to rename
        guard let fileToRename = currentGist.files[oldFilename] else {
            throw GistProviderError.apiError(statusCode: 404, message: "File not found: \(oldFilename)")
        }
        
        // Create updated files dictionary
        var updatedFiles = currentGist.files
        updatedFiles.removeValue(forKey: oldFilename)
        
        // Add the renamed file
        let renamedFile = GistFile(
            filename: newFilename,
            type: fileToRename.type,
            language: fileToRename.language,
            rawUrl: fileToRename.rawUrl,
            size: fileToRename.size,
            content: fileToRename.content,
            truncated: fileToRename.truncated
        )
        updatedFiles[newFilename] = renamedFile
        
        print("Updated files count: \(updatedFiles.count)")
        
        // Create a draft with all files including the renamed one
        let filesDict = Dictionary(uniqueKeysWithValues: updatedFiles.map { key, value in
            let content = value.content ?? ""
            print("File: \(key) -> content length: \(content.count)")
            return (key, GistFileDraft(content: content))
        })
        
        let draft = GistDraft(
            description: currentGist.description ?? "",
            isPublic: currentGist.public,
            files: filesDict
        )
        
        print("Draft files count: \(draft.files.count)")
        
        // Update the gist with the renamed file
        return try await updateGist(id: id, draft)
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
