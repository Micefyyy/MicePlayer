import Foundation

enum StreamQuality: String, CaseIterable, Codable {
    case q360p = "360p"
    case q480p = "480p"
    case q720p = "720p"
    case q1080p = "1080p"

    var sortOrder: Int {
        switch self {
        case .q360p: return 0
        case .q480p: return 1
        case .q720p: return 2
        case .q1080p: return 3
        }
    }
}
