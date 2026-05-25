import Foundation

enum GistCache {
    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    private static var cacheURL: URL? {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        return appSupport.appendingPathComponent("Jisticle/gists.json")
    }

    static func load() -> [Gist]? {
        guard let url = cacheURL else {
            print("[GistCache] load: no cache URL")
            return nil
        }
        guard let data = try? Data(contentsOf: url) else {
            print("[GistCache] load: no file at \(url.path)")
            return nil
        }
        do {
            let gists = try decoder.decode([Gist].self, from: data)
            print("[GistCache] load: \(gists.count) gists from cache")
            return gists
        } catch {
            print("[GistCache] load: decode failed — \(error)")
            return nil
        }
    }

    static func save(_ gists: [Gist]) {
        guard let url = cacheURL else { return }
        let dir = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        guard let data = try? encoder.encode(gists) else { return }
        try? data.write(to: url, options: .atomic)
    }

    static func clear() {
        guard let url = cacheURL else { return }
        try? FileManager.default.removeItem(at: url)
    }
}
