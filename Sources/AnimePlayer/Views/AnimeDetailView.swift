import SwiftUI

struct AnimeDetailView: View {
    let anime: Anime
    @State private var episodes: [Episode] = []
    @State private var isLoading = true

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                heroSection
                infoSection
                synopsisSection
                episodesSection
            }
        }
        .background(Color(.systemBackground))
        .navigationTitle(anime.displayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadEpisodes() }
    }

    private var heroSection: some View {
        ZStack(alignment: .bottom) {
            AsyncImage(url: URL(string: anime.coverImageLarge ?? "")) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().aspectRatio(contentMode: .fill)
                default:
                    Color(.systemGray5)
                }
            }
            .frame(height: 280)
            .clipped()

            LinearGradient(gradient: Gradient(colors: [.clear, .black.opacity(0.7)]),
                           startPoint: .top, endPoint: .bottom)
        }
    }

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(anime.displayTitle)
                .font(.title2)
                .fontWeight(.black)

            HStack(spacing: 16) {
                if let score = anime.score {
                    Label(String(format: "%.1f", score), systemImage: "star.fill")
                        .foregroundColor(.yellow)
                        .font(.subheadline)
                        .fontWeight(.bold)
                }
                if let year = anime.year {
                    Text("\(year)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                if let episodes = anime.episodes {
                    Text("\(episodes) eps")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            if let genres = anime.genres {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(genres, id: \.self) { genre in
                            Text(genre)
                                .font(.caption)
                                .fontWeight(.bold)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.orange.opacity(0.15))
                                .foregroundColor(.orange)
                                .clipShape(Capsule())
                        }
                    }
                }
            }
        }
        .padding(.horizontal)
    }

    private var synopsisSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Synopsis")
                .font(.headline)
                .fontWeight(.bold)
            Text(anime.synopsis ?? "No synopsis available.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(nil)
        }
        .padding(.horizontal)
    }

    private var episodesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Episodes")
                .font(.headline)
                .fontWeight(.bold)
                .padding(.horizontal)

            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
            } else if episodes.isEmpty {
                Text("No episodes available")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(episodes) { ep in
                        NavigationLink(destination: PlaybackView(
                            animeId: anime.id,
                            episodeNumber: ep.number,
                            title: "Ep. \(ep.number) - \(ep.title ?? "")"
                        )) {
                            EpisodeRow(episode: ep)
                        }
                        .buttonStyle(.plain)
                        Divider().padding(.leading)
                    }
                }
            }
        }
    }

    private func loadEpisodes() async {
        isLoading = true
        episodes = (try? await AnimeService.shared.getEpisodes(animeId: anime.id)) ?? []
        isLoading = false
    }
}

struct EpisodeRow: View {
    let episode: Episode

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: episode.thumbnail ?? "")) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().aspectRatio(contentMode: .fill)
                default:
                    Color(.systemGray5)
                }
            }
            .frame(width: 120, height: 68)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text("Episode \(episode.number)")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                if let title = episode.title {
                    Text(title)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                if let duration = episode.duration {
                    Text("\(duration / 60):\(String(format: "%02d", duration % 60))")
                        .font(.caption2)
                        .foregroundColor(.tertiary)
                }
            }
            Spacer()
            Image(systemName: "play.circle.fill")
                .foregroundColor(.orange)
                .font(.title3)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}
