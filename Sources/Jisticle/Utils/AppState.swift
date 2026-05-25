import SwiftUI

enum GistSortOrder: String, CaseIterable, Identifiable {
    case lastUpdated = "Last Updated"
    case lastCreated = "Last Created"
    case alphabetical = "Alphabetical"
    case mostStars = "Most Stars"
    case mostForks = "Most Forks"
    case mostComments = "Most Comments"

    var id: String { rawValue }
}

private extension Array where Element == Gist {
    func sorted(using order: GistSortOrder) -> [Gist] {
        switch order {
        case .lastUpdated:
            return sorted { $0.updatedAt > $1.updatedAt }
        case .lastCreated:
            return sorted { $0.createdAt > $1.createdAt }
        case .alphabetical:
            return sorted { $0.displayTitle.localizedCaseInsensitiveCompare($1.displayTitle) == .orderedAscending }
        case .mostStars:
            return sorted { $0.stargazerCount > $1.stargazerCount }
        case .mostForks:
            return sorted { $0.forkCount > $1.forkCount }
        case .mostComments:
            return sorted { $0.commentCount > $1.commentCount }
        }
    }
}

@MainActor
@Observable
class AppState {
    var selectedGist: Gist?
    var selectedFile: GistFile?
    var gists: [Gist] = []
    var isLoading = false
    var errorMessage: String?
    var searchQuery = ""
    var sortOrder: GistSortOrder = .lastUpdated

    /// Track filenames that are new (not yet saved to GitHub)
    var newFilenames: Set<String> = []

    /// Track gist IDs that are local drafts (not yet POST'd to GitHub)
    var pendingGistIds: Set<String> = []

    /// Pending draft metadata keyed by local stub gist ID
    var pendingGistDrafts: [String: GistDraft] = [:]

    private let gistProvider: GistProvider

    init(gistProvider: GistProvider = GitHubGistProvider.shared) {
        self.gistProvider = gistProvider
        self.gists = GistCache.load() ?? []
    }

    var filteredGists: [Gist] {
        let base: [Gist]
        if searchQuery.isEmpty {
            base = gists
        } else {
            let query = searchQuery.lowercased()
            base = gists.filter { gist in
                gist.displayTitle.lowercased().contains(query) ||
                    gist.fileList.contains { $0.filename.lowercased().contains(query) }
            }
        }
        return base.sorted(using: sortOrder)
    }

    func loadGists() async {
        isLoading = true
        errorMessage = nil

        do {
            let fresh = try await gistProvider.listGists()
            let freshById = Dictionary(uniqueKeysWithValues: fresh.map { ($0.id, $0) })

            var idsToRemove: Set<String> = []
            for index in gists.indices {
                let id = gists[index].id
                if let updated = freshById[id] {
                    if updated.updatedAt != gists[index].updatedAt {
                        gists[index] = updated
                    }
                } else {
                    idsToRemove.insert(id)
                }
            }
            if !idsToRemove.isEmpty {
                gists.removeAll { idsToRemove.contains($0.id) }
            }

            let existingIds = Set(gists.map { $0.id })
            for newGist in fresh where !existingIds.contains(newGist.id) {
                gists.append(newGist)
            }

            GistCache.save(gists)
        } catch let error as GistProviderError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func selectGist(_ gist: Gist) {
        selectedGist = gist
        selectedFile = nil

        Task {
            do {
                var fullGist = try await gistProvider.fetchGist(id: gist.id)
                // Preserve counts from GraphQL (they may be missing or 0 in REST API)
                fullGist.stargazerCount = gist.stargazerCount
                fullGist.forkCount = gist.forkCount
                fullGist.commentCount = gist.commentCount
                if let index = gists.firstIndex(where: { $0.id == gist.id }) {
                    gists[index] = fullGist
                }
                selectedGist = fullGist
                selectedFile = fullGist.fileList.first
            } catch let error as GistProviderError {
                errorMessage = error.errorDescription
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func selectFile(_ file: GistFile) {
        print("[AppState] selectFile called: \(file.filename)")
        selectedFile = file
    }

    /// Build a local stub gist and select it — no API call yet. The gist is created
    /// on GitHub the first time the user saves content in EditorView.
    func prepareDraftGist(filename: String, description: String, isPublic: Bool) {
        let localId = "draft-\(UUID().uuidString)"
        let now = Date()
        let stubFile = GistFile(
            filename: filename,
            type: nil,
            language: nil,
            rawUrl: "",
            size: 0,
            content: "",
            truncated: false
        )
        let stubGist = Gist(
            id: localId,
            description: description.isEmpty ? nil : description,
            public: isPublic,
            owner: nil,
            files: [filename: stubFile],
            createdAt: now,
            updatedAt: now,
            htmlUrl: ""
        )

        gists.insert(stubGist, at: 0)
        pendingGistIds.insert(localId)
        pendingGistDrafts[localId] = GistDraft(
            description: description,
            isPublic: isPublic,
            files: [filename: GistFileDraft(content: "")]
        )
        newFilenames.insert(filename)

        selectedGist = stubGist
        selectedFile = stubFile
    }

    func createGist(draft: GistDraft) async {
        isLoading = true
        errorMessage = nil

        do {
            let newGist = try await gistProvider.createGist(draft)
            gists.insert(newGist, at: 0)
            GistCache.save(gists)
            selectedGist = newGist
            selectedFile = newGist.fileList.first
        } catch let error as GistProviderError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func updateGist(draft: GistDraft) async {
        guard let gist = selectedGist else { return }

        isLoading = true
        errorMessage = nil

        do {
            let updatedGist = try await gistProvider.updateGist(id: gist.id, draft)
            if let index = gists.firstIndex(where: { $0.id == gist.id }) {
                gists[index] = updatedGist
            }
            GistCache.save(gists)
            selectedGist = updatedGist
        } catch let error as GistProviderError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    /// Add a file locally only (no API call). File will be synced on save.
    func addFileToGistLocal(filename: String) {
        guard let gist = selectedGist else { return }

        // Create new file locally
        let newFile = GistFile(
            filename: filename,
            type: nil,
            language: nil,
            rawUrl: "",
            size: 0,
            content: "",
            truncated: false
        )

        // Add to selected gist
        var updatedFiles = gist.files
        updatedFiles[filename] = newFile

        // Create new Gist with updated files (files is let, so we need new instance)
        let updatedGist = Gist(
            id: gist.id,
            description: gist.description,
            public: gist.public,
            owner: gist.owner,
            files: updatedFiles,
            createdAt: gist.createdAt,
            updatedAt: gist.updatedAt,
            htmlUrl: gist.htmlUrl,
            stargazerCount: gist.stargazerCount,
            forkCount: gist.forkCount,
            commentCount: gist.commentCount,
            revisionCount: gist.revisionCount
        )

        // Update in gists array
        if let index = gists.firstIndex(where: { $0.id == gist.id }) {
            gists[index] = updatedGist
        }
        selectedGist = updatedGist

        // Track as new file
        newFilenames.insert(filename)

        // Select the new file
        selectedFile = newFile
    }

    /// Actually create a new file on GitHub (called during save).
    /// If the parent gist is still a local draft, POST the whole gist first.
    func createFileOnGitHub(filename: String, content: String) async throws -> Gist {
        guard let gist = selectedGist else {
            throw GistProviderError.notAuthenticated
        }

        let updatedGist: Gist

        if pendingGistIds.contains(gist.id) {
            // Gist hasn't been created on GitHub yet — POST it now with real content
            let draftMeta = pendingGistDrafts[gist.id]
            let draft = GistDraft(
                description: draftMeta?.description ?? "",
                isPublic: draftMeta?.isPublic ?? true,
                files: [filename: GistFileDraft(content: content)]
            )
            let createdGist = try await gistProvider.createGist(draft)

            // Replace the local stub with the real gist
            if let index = gists.firstIndex(where: { $0.id == gist.id }) {
                gists[index] = createdGist
            }
            pendingGistIds.remove(gist.id)
            pendingGistDrafts.removeValue(forKey: gist.id)
            newFilenames.remove(filename)
            GistCache.save(gists)

            selectedGist = createdGist
            if let newFile = createdGist.files[filename] {
                selectedFile = newFile
            }
            return createdGist
        } else {
            updatedGist = try await gistProvider.addFileToGist(id: gist.id, filename: filename, content: content)

            if let index = gists.firstIndex(where: { $0.id == gist.id }) {
                gists[index] = updatedGist
            }
            selectedGist = updatedGist
            newFilenames.remove(filename)

            if let newFile = updatedGist.files[filename] {
                selectedFile = newFile
            }
            return updatedGist
        }
    }

    /// Original API-call version (kept for compatibility)
    func addFileToGist(filename: String, content: String) async {
        guard let gist = selectedGist else { return }

        isLoading = true
        errorMessage = nil

        do {
            let updatedGist = try await gistProvider.addFileToGist(id: gist.id, filename: filename, content: content)
            if let index = gists.firstIndex(where: { $0.id == gist.id }) {
                gists[index] = updatedGist
            }
            selectedGist = updatedGist

            // Auto-select the newly created file
            if let newFile = updatedGist.files[filename] {
                selectedFile = newFile
            }
        } catch let error as GistProviderError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func deleteFileFromGist(filename: String) async {
        guard let gist = selectedGist else { return }

        // Check if this is a new file (not yet on GitHub) - just remove locally
        if newFilenames.contains(filename) {
            var updatedFiles = gist.files
            updatedFiles.removeValue(forKey: filename)

            let updatedGist = Gist(
                id: gist.id,
                description: gist.description,
                public: gist.public,
                owner: gist.owner,
                files: updatedFiles,
                createdAt: gist.createdAt,
                updatedAt: gist.updatedAt,
                htmlUrl: gist.htmlUrl,
                stargazerCount: gist.stargazerCount,
                forkCount: gist.forkCount,
                commentCount: gist.commentCount,
                revisionCount: gist.revisionCount
            )

            if let index = gists.firstIndex(where: { $0.id == gist.id }) {
                gists[index] = updatedGist
            }
            selectedGist = updatedGist
            newFilenames.remove(filename)

            if selectedFile?.filename == filename {
                selectedFile = nil
            }
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            print("[AppState] Calling gistProvider.deleteFileFromGist...")
            let updatedGist = try await gistProvider.deleteFileFromGist(id: gist.id, filename: filename)
            print("[AppState] Delete succeeded, updating local state")
            if let index = gists.firstIndex(where: { $0.id == gist.id }) {
                gists[index] = updatedGist
            }
            selectedGist = updatedGist
            GistCache.save(gists)
            print("[AppState] Local state updated, gist now has \(updatedGist.files.count) files")

            // If the deleted file was selected, clear the selection
            if selectedFile?.filename == filename {
                selectedFile = nil
            }
        } catch let error as GistProviderError {
            print("[AppState] Delete failed with GistProviderError: \(error)")
            errorMessage = error.errorDescription
        } catch {
            print("[AppState] Delete failed with error: \(error)")
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func renameFileInGist(oldFilename: String, newFilename: String) async {
        guard let gist = selectedGist else { return }

        // Check if this is a new file - just rename locally
        if newFilenames.contains(oldFilename) {
            guard let fileToRename = gist.files[oldFilename] else { return }

            var updatedFiles = gist.files
            updatedFiles.removeValue(forKey: oldFilename)

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

            let updatedGist = Gist(
                id: gist.id,
                description: gist.description,
                public: gist.public,
                owner: gist.owner,
                files: updatedFiles,
                createdAt: gist.createdAt,
                updatedAt: gist.updatedAt,
                htmlUrl: gist.htmlUrl,
                stargazerCount: gist.stargazerCount,
                forkCount: gist.forkCount,
                commentCount: gist.commentCount,
                revisionCount: gist.revisionCount
            )

            if let index = gists.firstIndex(where: { $0.id == gist.id }) {
                gists[index] = updatedGist
            }
            selectedGist = updatedGist

            // Update tracking
            newFilenames.remove(oldFilename)
            newFilenames.insert(newFilename)

            // Update selected file if needed
            if selectedFile?.filename == oldFilename {
                selectedFile = renamedFile
            }
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let updatedGist = try await gistProvider.renameFileInGist(id: gist.id, oldFilename: oldFilename, newFilename: newFilename)
            if let index = gists.firstIndex(where: { $0.id == gist.id }) {
                gists[index] = updatedGist
            }
            selectedGist = updatedGist
            
            // Update the selected file if it was the renamed one
            if selectedFile?.filename == oldFilename {
                if let renamedFile = updatedGist.files[newFilename] {
                    selectedFile = renamedFile
                }
            }
        } catch let error as GistProviderError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func deleteGist(_ gist: Gist) async {
        // If this is a local draft that was never POST'd, just remove it locally
        if pendingGistIds.contains(gist.id) {
            gists.removeAll { $0.id == gist.id }
            pendingGistIds.remove(gist.id)
            pendingGistDrafts.removeValue(forKey: gist.id)
            if let filename = gist.fileList.first?.filename {
                newFilenames.remove(filename)
            }
            if selectedGist?.id == gist.id {
                selectedGist = nil
                selectedFile = nil
            }
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            try await gistProvider.deleteGist(id: gist.id)
            gists.removeAll { $0.id == gist.id }
            GistCache.save(gists)
            if selectedGist?.id == gist.id {
                selectedGist = nil
                selectedFile = nil
            }
        } catch let error as GistProviderError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
