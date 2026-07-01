import Foundation

actor AnimeService {
    static let shared = AnimeService()
    private let session: URLSession
    private let baseURL: String

    init(baseURL: String = "http://localhost:8000") {
        self.baseURL = baseURL
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
    }

    func fetchTrending() async throws -> [Anime] {
        try await get("/api/trending")
    }

    func fetchSeasonal() async throws -> [Anime] {
        try await get("/api/seasonal")
    }

    func fetchPopular() async throws -> [Anime] {
        try await get("/api/popular")
    }

    func searchAnime(query: String) async throws -> [Anime] {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        return try await get("/api/search?q=\(encoded)")
    }

    func getAnimeDetail(id: Int) async throws -> Anime {
        try await get("/api/anime/\(id)")
    }

    func getEpisodes(animeId: Int) async throws -> [Episode] {
        try await get("/api/anime/\(animeId)/episodes")
    }

    func getStreamingSources(animeId: Int, episode: Int) async throws -> StreamingData {
        try await get("/api/anime/\(animeId)/episode/\(episode)/stream")
    }

    private func get<T: Decodable>(_ path: String) async throws -> T {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw ServiceError.invalidURL
        }
        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse,
              200..<300 ~= httpResponse.statusCode else {
            throw ServiceError.httpError
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
}

enum ServiceError: LocalizedError {
    case invalidURL
    case httpError
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .httpError: return "Server error"
        case .decodingFailed: return "Failed to parse response"
        }
    }
}
