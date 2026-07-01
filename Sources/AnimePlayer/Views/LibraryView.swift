import SwiftUI

struct LibraryView: View {
    @State private var bookmarkedAnime: [Anime] = []
    @State private var continueWatching: [WatchProgress] = []

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 24) {
                    if !continueWatching.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Continue Watching", systemImage: "play.fill")
                                .font(.headline)
                                .fontWeight(.bold)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(continueWatching) { item in
                                        NavigationLink(
                                            destination: PlaybackView(
                                                animeId: item.animeId,
                                                episodeNumber: item.episodeNumber,
                                                title: item.animeTitle
                                            )
                                        ) {
                                            ContinueCard(progress: item)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }

                    if !bookmarkedAnime.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Bookmarks", systemImage: "bookmark.fill")
                                .font(.headline)
                                .fontWeight(.bold)
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 12)], spacing: 12) {
                                ForEach(bookmarkedAnime) { anime in
                                    NavigationLink(destination: AnimeDetailView(anime: anime)) {
                                        AnimeCardView(anime: anime)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    if bookmarkedAnime.isEmpty && continueWatching.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "bookmark")
                                .font(.system(size: 40))
                                .foregroundColor(.secondary)
                            Text("No bookmarks yet")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Text("Start browsing and add anime to your library")
                                .font(.caption)
                                .foregroundColor(.tertiary)
                        }
                        .padding(.top, 80)
                    }
                }
                .padding(.horizontal)
            }
            .background(Color(.systemBackground))
            .navigationTitle("Library")
        }
    }
}

struct WatchProgress: Identifiable, Codable {
    let animeId: Int
    let animeTitle: String
    let animeImage: String
    let episodeNumber: Int
    let updatedAt: Date

    var id: String { "\(animeId)-\(episodeNumber)" }
}

struct ContinueCard: View {
    let progress: WatchProgress

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            AsyncImage(url: URL(string: progress.animeImage)) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().aspectRatio(contentMode: .fill)
                default:
                    Color(.systemGray5)
                }
            }
            .frame(width: 150, height: 85)
            .clipped()
            .overlay {
                ZStack {
                    Color.black.opacity(0.3)
                    Image(systemName: "play.circle.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))

            Text(progress.animeTitle)
                .font(.caption)
                .fontWeight(.semibold)
                .lineLimit(1)
                .frame(width: 150, alignment: .leading)
                .foregroundColor(.primary)

            Text("Ep. \(progress.episodeNumber)")
                .font(.caption2)
                .foregroundColor(.orange)
                .fontWeight(.bold)
        }
    }
}
