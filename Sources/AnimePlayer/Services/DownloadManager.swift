import Foundation

struct DownloadItem: Identifiable, Codable {
    let id: String
    let animeId: Int
    let animeTitle: String
    let animeImage: String
    let episodeNumber: Int
    let manifestUrl: String
    var status: DownloadStatus
    var progress: Double
    let startedAt: Date

    enum DownloadStatus: String, Codable {
        case downloading
        case completed
        case failed
    }
}

final class DownloadManager: ObservableObject {
    static let shared = DownloadManager()

    @Published var downloads: [DownloadItem] = []

    private let downloadsKey = "downloadedEpisodes"
    private let contentDir: URL

    private init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        contentDir = docs.appendingPathComponent("Downloads", isDirectory: true)
        try? FileManager.default.createDirectory(at: contentDir, withIntermediateDirectories: true)
        loadDownloads()
    }

    func download(animeId: Int, animeTitle: String, animeImage: String, episodeNumber: Int, manifestUrl: String) {
        let id = "\(animeId)-\(episodeNumber)"
        guard !downloads.contains(where: { $0.id == id }) else { return }

        var item = DownloadItem(
            id: id,
            animeId: animeId,
            animeTitle: animeTitle,
            animeImage: animeImage,
            episodeNumber: episodeNumber,
            manifestUrl: manifestUrl,
            status: .downloading,
            progress: 0,
            startedAt: Date()
        )
        downloads.insert(item, at: 0)
        saveDownloads()

        Task { @MainActor in
            do {
                try await performDownload(item: &item)
                if let idx = downloads.firstIndex(where: { $0.id == id }) {
                    downloads[idx].status = .completed
                    downloads[idx].progress = 1.0
                }
            } catch {
                if let idx = downloads.firstIndex(where: { $0.id == id }) {
                    downloads[idx].status = .failed
                }
            }
            saveDownloads()
        }
    }

    func cancelDownload(id: String) {
        downloads.removeAll { $0.id == id }
        let epDir = contentDir.appendingPathComponent(id)
        try? FileManager.default.removeItem(at: epDir)
        saveDownloads()
    }

    func deleteDownload(id: String) {
        downloads.removeAll { $0.id == id }
        let epDir = contentDir.appendingPathComponent(id)
        try? FileManager.default.removeItem(at: epDir)
        saveDownloads()
    }

    func isDownloaded(animeId: Int, episodeNumber: Int) -> Bool {
        downloads.contains { $0.animeId == animeId && $0.episodeNumber == episodeNumber && $0.status == .completed }
    }

    func localManifestUrl(animeId: Int, episodeNumber: Int) -> URL? {
        let id = "\(animeId)-\(episodeNumber)"
        let file = contentDir.appendingPathComponent(id).appendingPathComponent("playlist.m3u8")
        return FileManager.default.fileExists(atPath: file.path) ? file : nil
    }

    private func performDownload(item: inout DownloadItem) async throws {
        let id = item.id
        let epDir = contentDir.appendingPathComponent(id)
        try FileManager.default.createDirectory(at: epDir, withIntermediateDirectories: true)

        guard let manifestURL = URL(string: item.manifestUrl) else { throw DownloadError.invalidURL }

        let (manifestData, _) = try await URLSession.shared.data(from: manifestURL)
        let manifestString = String(data: manifestData, encoding: .utf8) ?? ""

        let playlistFile = epDir.appendingPathComponent("playlist.m3u8")
        try manifestData.write(to: playlistFile)

        let baseManifestURL = manifestURL.deletingLastPathComponent()
        let segmentLines = manifestString.components(separatedBy: .newlines)
        var segmentURLs: [URL] = []

        for line in segmentLines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if !trimmed.hasPrefix("#") && !trimmed.isEmpty {
                if let segURL = URL(string: trimmed, relativeTo: baseManifestURL) {
                    segmentURLs.append(segURL)
                }
            }
        }

        let total = Double(segmentURLs.count)
        guard total > 0 else { return }

        for (index, segURL) in segmentURLs.enumerated() {
            let (segData, _) = try await URLSession.shared.data(from: segURL)
            let segFile = epDir.appendingPathComponent(segURL.lastPathComponent)
            try segData.write(to: segFile)

            if let idx = downloads.firstIndex(where: { $0.id == id }) {
                downloads[idx].progress = Double(index + 1) / total
            }
        }
    }

    private func loadDownloads() {
        guard let data = UserDefaults.standard.data(forKey: downloadsKey),
              let decoded = try? JSONDecoder().decode([DownloadItem].self, from: data) else {
            return
        }
        downloads = decoded
    }

    private func saveDownloads() {
        if let data = try? JSONEncoder().encode(downloads) {
            UserDefaults.standard.set(data, forKey: downloadsKey)
        }
    }
}

enum DownloadError: LocalizedError {
    case invalidURL

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid stream URL"
        }
    }
}
