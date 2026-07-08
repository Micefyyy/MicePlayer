import Foundation

final class PersistenceManager {
    static let shared = PersistenceManager()

    private let bookmarksKey = "bookmarks"
    private let progressKey = "watchProgress"

    private init() {}

    // MARK: - Bookmarks

    func loadBookmarks() -> [Anime] {
        guard let data = UserDefaults.standard.data(forKey: bookmarksKey),
              let decoded = try? JSONDecoder().decode([Anime].self, from: data) else {
            return []
        }
        return decoded
    }

    func saveBookmarks(_ anime: [Anime]) {
        if let data = try? JSONEncoder().encode(anime) {
            UserDefaults.standard.set(data, forKey: bookmarksKey)
        }
    }

    func isBookmarked(_ animeId: Int) -> Bool {
        loadBookmarks().contains { $0.id == animeId }
    }

    func toggleBookmark(_ anime: Anime) -> Bool {
        var bookmarks = loadBookmarks()
        if let idx = bookmarks.firstIndex(where: { $0.id == anime.id }) {
            bookmarks.remove(at: idx)
            saveBookmarks(bookmarks)
            return false
        } else {
            bookmarks.append(anime)
            saveBookmarks(bookmarks)
            return true
        }
    }

    // MARK: - Watch Progress

    func loadProgress() -> [WatchProgress] {
        guard let data = UserDefaults.standard.data(forKey: progressKey),
              let decoded = try? JSONDecoder().decode([WatchProgress].self, from: data) else {
            return []
        }
        return decoded
    }

    func saveProgress(_ progress: [WatchProgress]) {
        if let data = try? JSONEncoder().encode(progress) {
            UserDefaults.standard.set(data, forKey: progressKey)
        }
    }

    func updateProgress(animeId: Int, animeTitle: String, animeImage: String, episodeNumber: Int) {
        var progress = loadProgress()
        progress.removeAll { $0.animeId == animeId && $0.episodeNumber == episodeNumber }
        let entry = WatchProgress(
            animeId: animeId,
            animeTitle: animeTitle,
            animeImage: animeImage,
            episodeNumber: episodeNumber,
            updatedAt: Date()
        )
        progress.insert(entry, at: 0)
        if progress.count > 50 {
            progress = Array(progress.prefix(50))
        }
        saveProgress(progress)
    }

    func removeProgress(animeId: Int) {
        var progress = loadProgress()
        progress.removeAll { $0.animeId == animeId }
        saveProgress(progress)
    }

    func getLastWatchedEpisode(animeId: Int) -> Int? {
        loadProgress()
            .filter { $0.animeId == animeId }
            .max(by: { $0.updatedAt < $1.updatedAt })?
            .episodeNumber
    }
}
