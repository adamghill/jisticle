import Foundation

private struct AnyCodableIgnored: Decodable {
    init(from decoder: Decoder) throws {
        _ = try? decoder.singleValueContainer()
    }
}

struct Gist: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let description: String?
    let `public`: Bool
    let owner: GistOwner?
    let files: [String: GistFile]
    let createdAt: Date
    let updatedAt: Date
    let htmlUrl: String
    var stargazerCount: Int
    var forkCount: Int
    var commentCount: Int
    var revisionCount: Int

    enum CodingKeys: String, CodingKey {
        case id
        case description
        case `public`
        case owner
        case files
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case htmlUrl = "html_url"
        case stargazerCount = "stargazer_count"
        case forkCount = "forks_count"
        case commentCount = "comments_count"
    }

    private enum RestCodingKeys: String, CodingKey {
        case history
    }

    init(id: String, description: String?, public isPublic: Bool, owner: GistOwner?,
         files: [String: GistFile], createdAt: Date, updatedAt: Date, htmlUrl: String,
         stargazerCount: Int = 0, forkCount: Int = 0, commentCount: Int = 0, revisionCount: Int = 0) {
        self.id = id
        self.description = description
        self.public = isPublic
        self.owner = owner
        self.files = files
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.htmlUrl = htmlUrl
        self.stargazerCount = stargazerCount
        self.forkCount = forkCount
        self.commentCount = commentCount
        self.revisionCount = revisionCount
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        description = try c.decodeIfPresent(String.self, forKey: .description)
        `public` = try c.decode(Bool.self, forKey: .public)
        owner = try c.decodeIfPresent(GistOwner.self, forKey: .owner)
        files = try c.decode([String: GistFile].self, forKey: .files)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        updatedAt = try c.decode(Date.self, forKey: .updatedAt)
        htmlUrl = try c.decode(String.self, forKey: .htmlUrl)
        stargazerCount = try c.decodeIfPresent(Int.self, forKey: .stargazerCount) ?? 0
        forkCount = try c.decodeIfPresent(Int.self, forKey: .forkCount) ?? 0
        commentCount = try c.decodeIfPresent(Int.self, forKey: .commentCount) ?? 0
        let r = try decoder.container(keyedBy: RestCodingKeys.self)
        let history = try r.decodeIfPresent([AnyCodableIgnored].self, forKey: .history)
        revisionCount = history?.count ?? 0
    }

    var fileList: [GistFile] {
        Array(files.values).sorted { $0.filename.localizedCaseInsensitiveCompare($1.filename) == .orderedAscending }
    }

    var displayTitle: String {
        if let desc = description, !desc.isEmpty {
            return desc
        }
        if let firstFile = fileList.first {
            return firstFile.filename
        }
        return "Untitled Gist"
    }

    var primaryLanguage: String? {
        fileList.first?.language
    }
}

struct GistOwner: Codable, Equatable, Hashable {
    let login: String
    let avatarUrl: String?

    enum CodingKeys: String, CodingKey {
        case login
        case avatarUrl = "avatar_url"
    }
}

struct GistFile: Identifiable, Codable, Equatable, Hashable {
    let id = UUID()
    let filename: String
    let type: String?
    let language: String?
    let rawUrl: String
    let size: Int
    var content: String?
    let truncated: Bool?

    enum CodingKeys: String, CodingKey {
        case filename
        case type
        case language
        case rawUrl = "raw_url"
        case size
        case content
        case truncated
    }

    var displayLanguage: String {
        language ?? "Plain Text"
    }
}

struct GistDraft: Codable {
    var description: String
    var isPublic: Bool
    var files: [String: GistFileDraft]

    enum CodingKeys: String, CodingKey {
        case description
        case isPublic = "public"
        case files
    }
}

struct GistFileDraft: Codable {
    var content: String
}
