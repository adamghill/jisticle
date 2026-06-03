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

        print("[API] \(method) \(url.absoluteString)")
        if let body = body, let bodyStr = String(data: body, encoding: .utf8) {
            print("[API] Body: \(bodyStr.prefix(200))...")
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            print("[API] Error: Invalid response")
            throw GistProviderError.invalidResponse
        }

        print("[API] Response: \(httpResponse.statusCode)")
        if let responseStr = String(data: data, encoding: .utf8) {
            print("[API] Response body: \(responseStr.prefix(500))")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("[API] Error: \(httpResponse.statusCode) - \(message)")
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

        var gist: Gist
        do {
            gist = try decoder.decode(Gist.self, from: data)
        } catch {
            throw GistProviderError.decodingError(error)
        }

        // The REST API only inlines file content up to ~1MB. Larger files come
        // back with `truncated == true` and partial `content`, so fetch the
        // full text from `raw_url` to show the complete file in the editor.
        for (name, file) in gist.files where file.truncated == true && !file.rawUrl.isEmpty {
            if let fullContent = try? await fetchRawContent(from: file.rawUrl) {
                var resolved = file
                resolved.content = fullContent
                gist.files[name] = resolved
            }
        }

        return gist
    }

    /// Fetches a gist file's full, untruncated content directly from its
    /// `raw_url`. The REST gist endpoint truncates content over ~1MB; the raw
    /// host serves the complete file.
    private func fetchRawContent(from urlString: String) async throws -> String {
        guard let url = URL(string: urlString) else {
            throw GistProviderError.invalidResponse
        }

        var request = URLRequest(url: url)
        if let token = authService.getAccessToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw GistProviderError.invalidResponse
        }

        return String(data: data, encoding: .utf8) ?? ""
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

        print("=== updateGist response received, data length: \(data.count) ===")
        if let responseJson = String(data: data, encoding: .utf8) {
            print(responseJson.prefix(500))
        }

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
        print("Before adding: updatedFiles count: \(updatedFiles.count)")
        updatedFiles[filename] = GistFile(
            filename: filename,
            type: nil,
            language: nil,
            rawUrl: "",
            size: content.count,
            content: content,
            truncated: false
        )
        print("New file created with content length: \(content.count)")
        print("In updatedFiles, new file content length: \(updatedFiles[filename]?.content?.count ?? -1)")

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
        print("[DELETE] Starting delete for file: \(filename) from gist: \(id)")

        // First, fetch the current gist to get existing files
        let currentGist = try await fetchGist(id: id)

        print("[DELETE] Fetched gist with \(currentGist.files.count) files")
        print("[DELETE] Files: \(Array(currentGist.files.keys))")

        // Verify file exists
        guard currentGist.files[filename] != nil else {
            print("[DELETE] ERROR: File '\(filename)' not found in gist!")
            throw GistProviderError.apiError(statusCode: 404, message: "File not found: \(filename)")
        }

        // Create a draft that EXPLICITLY sets deleted file to null
        // GitHub requires this to delete files
        var filesDict: [String: GistFileDraft?] = [:]

        // Set the file to delete as null
        filesDict[filename] = nil

        // Include all other files with their content
        for (key, value) in currentGist.files where key != filename {
            filesDict[key] = GistFileDraft(content: value.content ?? "")
        }

        print("[DELETE] Sending draft with \(filesDict.count) entries, deleted file set to null")

        // Use custom encoder to properly encode null values
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.outputFormatting = .prettyPrinted

        // Build JSON manually to ensure null is sent
        var filesJson: [String: Any] = [:]
        filesJson[filename] = NSNull()  // This will encode as null
        for (key, value) in currentGist.files where key != filename {
            filesJson[key] = ["content": value.content ?? ""]
        }

        let bodyDict: [String: Any] = [
            "description": currentGist.description ?? "",
            "public": currentGist.public,
            "files": filesJson
        ]

        let body = try JSONSerialization.data(withJSONObject: bodyDict)

        let url = URL(string: "\(baseURL)/gists/\(id)")!
        let data = try await makeRequest(url: url, method: "PATCH", body: body)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            let result = try decoder.decode(Gist.self, from: data)
            print("[DELETE] Success! Result has \(result.files.count) files")
            return result
        } catch {
            throw GistProviderError.decodingError(error)
        }
    }

    func renameFileInGist(id: String, oldFilename: String, newFilename: String) async throws -> Gist {
        print("[RENAME] Starting rename: \(oldFilename) -> \(newFilename)")

        // First, fetch the current gist to get existing files
        let currentGist = try await fetchGist(id: id)

        print("[RENAME] Fetched gist with \(currentGist.files.count) files")

        // Get the file to rename
        guard let fileToRename = currentGist.files[oldFilename] else {
            throw GistProviderError.apiError(statusCode: 404, message: "File not found: \(oldFilename)")
        }

        // Build JSON manually to ensure old file is set to null (deleted) and new file is created
        var filesJson: [String: Any] = [:]

        // 1. Set old file to null (deletes it)
        filesJson[oldFilename] = NSNull()

        // 2. Create new file with the old file's content
        filesJson[newFilename] = ["content": fileToRename.content ?? ""]

        // 3. Include all other existing files unchanged
        for (key, value) in currentGist.files where key != oldFilename {
            filesJson[key] = ["content": value.content ?? ""]
        }

        let bodyDict: [String: Any] = [
            "description": currentGist.description ?? "",
            "public": currentGist.public,
            "files": filesJson
        ]

        print("[RENAME] Sending: old='\(oldFilename)'->null, new='\(newFilename)' with \(fileToRename.content?.count ?? 0) chars")

        let body = try JSONSerialization.data(withJSONObject: bodyDict)
        let url = URL(string: "\(baseURL)/gists/\(id)")!
        let data = try await makeRequest(url: url, method: "PATCH", body: body)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            let result = try decoder.decode(Gist.self, from: data)
            print("[RENAME] Success! Result has \(result.files.count) files")
            return result
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
