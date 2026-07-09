import SwiftUI

struct AnimeDetailView: View {
    let anime: Anime
    @State private var episodes: [Episode] = []
    @State private var isLoading = true
    @State private var isBookmarked = false
    @State private var lastWatchedEp: Int?

    private let accent = Color(hex: "b5a8ff")
    private let bg = Color(hex: "0a0a0a")
    private let cardBg = Color(hex: "131313")
    private let muted = Color(hex: "606060")
    private let textColor = Color(hex: "e0e0e0")
    private let borderColor = Color.white.opacity(0.08)

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                heroSection
                VStack(alignment: .leading, spacing: 16) {
                    infoSection
                    actionBar
                    synopsisSection
                    metadataSection
                    episodesSection
                }
                .padding(.horizontal, 12)
            }
        }
        .background(bg)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .task { await loadData() }
        .onAppear {
            isBookmarked = PersistenceManager.shared.isBookmarked(anime.id)
            lastWatchedEp = PersistenceManager.shared.getLastWatchedEpisode(animeId: anime.id)
        }
    }

    private var heroSection: some View {
        ZStack(alignment: .top) {
            AsyncImage(url: URL(string: anime.coverImageLarge ?? "")) { phase in
                if let image = phase.image {
                    image.resizable().aspectRatio(contentMode: .fill)
                } else {
                    cardBg
                }
            }
            .frame(height: 260)
            .clipped()

            LinearGradient(colors: [.black.opacity(0.6), .clear, bg], startPoint: .top, endPoint: .bottom)
                .frame(height: 260)
        }
    }

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(anime.displayTitle)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(textColor)

            HStack(spacing: 10) {
                if let score = anime.score {
                    HStack(spacing: 3) {
                        Image(systemName: "star.fill").font(.system(size: 11)).foregroundColor(.yellow)
                        Text(String(format: "%.1f", score)).font(.system(size: 13, weight: .bold)).foregroundColor(.yellow)
                    }
                }
                if let year = anime.year {
                    Text("\(year)").font(.system(size: 13)).foregroundColor(muted)
                }
                if let episodes = anime.episodes {
                    Text("\(episodes) eps").font(.system(size: 13)).foregroundColor(muted)
                }
                if let status = anime.status {
                    Text(status.replacingOccurrences(of: "_", with: " ").capitalized)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(status == "RELEASING" ? .green : muted)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background((status == "RELEASING" ? Color.green : muted).opacity(0.12))
                        .cornerRadius(8)
                }
            }

            if let genres = anime.genres, !genres.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 5) {
                        ForEach(genres, id: \.self) { genre in
                            Text(genre)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(accent)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(accent.opacity(0.1))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(accent.opacity(0.25)))
                                .cornerRadius(10)
                        }
                    }
                }
            }
        }
    }

    private var actionBar: some View {
        HStack(spacing: 10) {
            NavigationLink(destination: PlaybackView(
                animeId: anime.id,
                episodeNumber: lastWatchedEp ?? 1,
                title: anime.displayTitle,
                animeImage: anime.coverImageMedium
            )) {
                HStack(spacing: 6) {
                    Image(systemName: "play.fill").font(.system(size: 13))
                    Text(lastWatchedEp != nil ? "Continue Ep. \(lastWatchedEp!)" : "Start Watching")
                        .font(.system(size: 14, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(accent)
                .cornerRadius(10)
            }
            .buttonStyle(.plain)

            Button {
                isBookmarked = PersistenceManager.shared.toggleBookmark(anime)
                NotificationCenter.default.post(name: Notification.Name("bookmarksChanged"), object: nil)
            } label: {
                Image(systemName: isBookmarked ? "heart.fill" : "heart")
                    .font(.system(size: 16))
                    .foregroundColor(isBookmarked ? accent : muted)
                    .frame(width: 46, height: 46)
                    .background(cardBg)
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(borderColor))
            }
        }
    }

    private var synopsisSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Synopsis")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(textColor)
            Text(anime.synopsis ?? "No synopsis available.")
                .font(.system(size: 13))
                .foregroundColor(muted)
                .lineSpacing(4)
        }
    }

    private var metadataSection: some View {
        HStack(spacing: 20) {
            if let studio = anime.studio {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Studio").font(.system(size: 10, weight: .bold)).foregroundColor(muted)
                    Text(studio).font(.system(size: 12, weight: .medium)).foregroundColor(textColor)
                }
            }
            if let season = anime.season, let year = anime.year {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Season").font(.system(size: 10, weight: .bold)).foregroundColor(muted)
                    Text("\(season.capitalized) \(year)").font(.system(size: 12, weight: .medium)).foregroundColor(textColor)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var episodesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Episodes")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(textColor)
                .padding(.top, 4)

            if isLoading {
                ProgressView().tint(accent).frame(maxWidth: .infinity).padding(.vertical, 30)
            } else if episodes.isEmpty {
                Text("No episodes available")
                    .font(.system(size: 13))
                    .foregroundColor(muted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(episodes) { ep in
                        NavigationLink(destination: PlaybackView(
                            animeId: anime.id,
                            episodeNumber: ep.number,
                            title: anime.displayTitle,
                            animeImage: anime.coverImageMedium
                        )) {
                            EpisodeRow(episode: ep, isCurrent: lastWatchedEp == ep.number, accent: accent, muted: muted, textColor: textColor, cardBg: cardBg)
                        }
                        .buttonStyle(.plain)
                        Divider().background(borderColor).padding(.leading, 56)
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
    let accent: Color
    let muted: Color
    let textColor: Color
    let cardBg: Color

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                AsyncImage(url: URL(string: episode.thumbnail ?? "")) { phase in
                    if let image = phase.image {
                        image.resizable().aspectRatio(contentMode: .fill)
                    } else {
                        cardBg
                    }
                }
                .frame(width: 90, height: 52)
                .clipped()

                if isCurrent {
                    Color.black.opacity(0.35)
                    Image(systemName: "play.fill").font(.system(size: 12)).foregroundColor(.white)
                }
            }
            .cornerRadius(6)

            VStack(alignment: .leading, spacing: 2) {
                Text("Episode \(episode.number)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(isCurrent ? accent : textColor)
                if let title = episode.title {
                    Text(title)
                        .font(.system(size: 11))
                        .foregroundColor(muted)
                        .lineLimit(1)
                }
                if let duration = episode.duration {
                    Text("\(duration / 60):\(String(format: "%02d", duration % 60))")
                        .font(.system(size: 10))
                        .foregroundColor(muted.opacity(0.6))
                }
            }

            Spacer()

            Image(systemName: "play.circle")
                .font(.system(size: 16))
                .foregroundColor(isCurrent ? accent : muted.opacity(0.4))
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 8)
        .background(isCurrent ? accent.opacity(0.05) : Color.clear)
        .contentShape(Rectangle())
    }
}
