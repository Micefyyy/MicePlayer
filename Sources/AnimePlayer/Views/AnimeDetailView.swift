import SwiftUI

struct AnimeDetailView: View {
    let anime: Anime
    @State private var episodes: [Episode] = []
    @State private var isLoading = true
    @State private var isBookmarked = false
    @State private var lastWatchedEp: Int?

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                heroSection
                infoSection
                actionBar
                synopsisSection
                metadataSection
                episodesSection
            }
        }
        .background(Color.black)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadData() }
        .onAppear { isBookmarked = UserDefaults.standard.data(forKey: "bookmarks") != nil }
    }

    private var heroSection: some View {
        ZStack(alignment: .top) {
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

            LinearGradient(
                gradient: Gradient(colors: [.black.opacity(0.6), .clear, .black]),
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(anime.displayTitle)
                .font(.title2)
                .fontWeight(.black)
                .foregroundColor(.white)

            HStack(spacing: 12) {
                if let score = anime.score {
                    Label(String(format: "%.1f", score), systemImage: "star.fill")
                        .foregroundColor(.yellow)
                        .font(.subheadline)
                        .fontWeight(.bold)
                }
                if let year = anime.year {
                    Text("\(year)")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                if let episodes = anime.episodes {
                    Text("\(episodes) eps")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                if let status = anime.status {
                    Text(status.replacingOccurrences(of: "_", with: " ").capitalized)
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(status == "RELEASING" ? .green : .gray)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(status == "RELEASING" ? Color.green.opacity(0.15) : Color.gray.opacity(0.15))
                        .clipShape(Capsule())
                }
            }

            if let genres = anime.genres {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(genres, id: \.self) { genre in
                            Text(genre)
                                .font(.caption2)
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
        .padding(.top, 16)
    }

    private var actionBar: some View {
        HStack(spacing: 12) {
            NavigationLink(destination: PlaybackView(
                animeId: anime.id,
                episodeNumber: lastWatchedEp ?? 1,
                title: "\(anime.displayTitle)"
            )) {
                HStack {
                    Image(systemName: "play.fill")
                    Text(lastWatchedEp != nil ? "Continue Ep. \(lastWatchedEp!)" : "Start Watching")
                        .fontWeight(.black)
                }
                .font(.subheadline)
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.orange)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)

            Button {
                isBookmarked.toggle()
            } label: {
                Image(systemName: isBookmarked ? "heart.fill" : "heart")
                    .font(.title3)
                    .foregroundColor(isBookmarked ? .red : .gray)
                    .frame(width: 48, height: 48)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
        .padding(.horizontal)
        .padding(.top, 16)
    }

    private var synopsisSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Synopsis")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.white)
            Text(anime.synopsis ?? "No synopsis available.")
                .font(.subheadline)
                .foregroundColor(.gray)
                .lineLimit(nil)
        }
        .padding(.horizontal)
        .padding(.top, 24)
    }

    private var metadataSection: some View {
        HStack(spacing: 24) {
            if let studio = anime.studio {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Studio")
                        .font(.caption2)
                        .fontWeight(.black)
                        .foregroundColor(.gray)
                    Text(studio)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }
            }
            if let season = anime.season, let year = anime.year {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Season")
                        .font(.caption2)
                        .fontWeight(.black)
                        .foregroundColor(.gray)
                    Text("\(season.capitalized) \(year)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }
            }
        }
        .padding(.horizontal)
        .padding(.top, 16)
    }

    private var episodesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Episodes")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(.horizontal)
                .padding(.top, 16)

            if isLoading {
                ProgressView()
                    .tint(.orange)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
            } else if episodes.isEmpty {
                Text("No episodes available")
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(episodes) { ep in
                        NavigationLink(destination: PlaybackView(
                            animeId: anime.id,
                            episodeNumber: ep.number,
                            title: "\(anime.displayTitle)"
                        )) {
                            EpisodeRow(episode: ep, isCurrent: lastWatchedEp == ep.number)
                        }
                        .buttonStyle(.plain)
                        Divider()
                            .background(Color.white.opacity(0.05))
                            .padding(.leading, 60)
                    }
                }
                .padding(.bottom, 24)
            }
        }
    }

    private func loadData() async {
        isLoading = true
        async let eps = AnimeService.shared.getEpisodes(animeId: anime.id)
        episodes = (try? await eps) ?? []
        isLoading = false
    }
}

struct EpisodeRow: View {
    let episode: Episode
    var isCurrent: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                AsyncImage(url: URL(string: episode.thumbnail ?? "")) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: .fill)
                    default:
                        Color(.systemGray5)
                    }
                }
                .frame(width: 100, height: 56)
                .clipped()

                if isCurrent {
                    Color.black.opacity(0.3)
                    Image(systemName: "play.fill")
                        .foregroundColor(.white)
                        .font(.caption)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text("Episode \(episode.number)")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(isCurrent ? .orange : .white)
                if let title = episode.title {
                    Text(title)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
                if let duration = episode.duration {
                    let minutes = duration / 60
                    let secs = duration % 60
                    Text("\(minutes):\(String(format: "%02d", secs))")
                        .font(.caption2)
                        .foregroundColor(.gray.opacity(0.6))
                }
            }

            Spacer()

            Image(systemName: "play.circle")
                .foregroundColor(isCurrent ? .orange : .gray.opacity(0.5))
                .font(.title3)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(isCurrent ? Color.orange.opacity(0.05) : Color.clear)
        .contentShape(Rectangle())
    }
}
