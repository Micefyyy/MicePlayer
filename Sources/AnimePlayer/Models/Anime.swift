import Foundation

struct Anime: Codable, Identifiable, Hashable {
    let id: Int
    let titleRomaji: String
    let titleEnglish: String?
    let synopsis: String?
    let coverImageLarge: String?
    let coverImageMedium: String?
    let score: Double?
    let episodes: Int?
    let status: String?
    let genres: [String]?
    let studio: String?
    let year: Int?
    let season: String?

    var displayTitle: String { titleEnglish ?? titleRomaji }

    enum CodingKeys: String, CodingKey {
        case id, synopsis, score, episodes, status, genres, studio, year, season
        case titleRomaji = "title_romaji"
        case titleEnglish = "title_english"
        case coverImageLarge = "cover_image_large"
        case coverImageMedium = "cover_image_medium"
    }
}

struct Episode: Codable, Identifiable, Hashable {
    let id: Int
    let number: Int
    let title: String?
    let thumbnail: String?
    let duration: Int?

    enum CodingKeys: String, CodingKey {
        case id, number, title, thumbnail, duration
    }
}

struct StreamSource: Codable, Hashable {
    let quality: String
    let manifestUrl: String

    enum CodingKeys: String, CodingKey {
        case quality
        case manifestUrl = "manifest_url"
    }
}

struct StreamingData: Codable {
    let sources: [StreamSource]
    let subtitles: [SubtitleTrack]?
}

struct SubtitleTrack: Codable, Hashable {
    let url: String
    let language: String
}
