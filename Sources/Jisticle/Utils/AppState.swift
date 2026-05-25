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

    private let gistProvider: GistProvider

    init(gistProvider: GistProvider = GitHubGistProvider.shared) {
        self.gistProvider = gistProvider
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
            gists = try await gistProvider.listGists()
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
        selectedFile = file
    }

    func createGist(draft: GistDraft) async {
        isLoading = true
        errorMessage = nil

        do {
            let newGist = try await gistProvider.createGist(draft)
            gists.insert(newGist, at: 0)
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
            selectedGist = updatedGist
        } catch let error as GistProviderError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

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

        isLoading = true
        errorMessage = nil

        do {
            let updatedGist = try await gistProvider.deleteFileFromGist(id: gist.id, filename: filename)
            if let index = gists.firstIndex(where: { $0.id == gist.id }) {
                gists[index] = updatedGist
            }
            selectedGist = updatedGist
            
            // If the deleted file was selected, clear the selection
            if selectedFile?.filename == filename {
                selectedFile = nil
            }
        } catch let error as GistProviderError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func renameFileInGist(oldFilename: String, newFilename: String) async {
        guard let gist = selectedGist else { return }

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
        isLoading = true
        errorMessage = nil

        do {
            try await gistProvider.deleteGist(id: gist.id)
            gists.removeAll { $0.id == gist.id }
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
