import SwiftUI

struct LibraryView: View {
    @State private var bookmarkedAnime: [Anime] = []
    @State private var continueWatching: [WatchProgress] = []
    @State private var isLoading = true

    private let accent = Color(hex: "b5a8ff")
    private let bg = Color(hex: "0a0a0a")
    private let cardBg = Color(hex: "131313")
    private let muted = Color(hex: "606060")
    private let textColor = Color(hex: "e0e0e0")
    private let borderColor = Color.white.opacity(0.08)

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 20) {
                    if isLoading {
                        ProgressView().tint(accent).padding(.top, 80)
                    } else if bookmarkedAnime.isEmpty && continueWatching.isEmpty {
                        emptyState
                    } else {
                        if !continueWatching.isEmpty {
                            continueSection
                        }
                        if !bookmarkedAnime.isEmpty {
                            bookmarksSection
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .background(bg)
            .navigationBarHidden(true)
            .onAppear(perform: loadData)
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("bookmarksChanged"))) { _ in
                bookmarkedAnime = PersistenceManager.shared.loadBookmarks()
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("progressUpdated"))) { _ in
                continueWatching = PersistenceManager.shared.loadProgress()
            }
        }
    }

    private var continueSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Continue Watching", icon: "play.fill")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(continueWatching) { item in
                        NavigationLink(destination: PlaybackView(
                            animeId: item.animeId, episodeNumber: item.episodeNumber,
                            title: item.animeTitle, animeImage: item.animeImage
                        )) {
                            ContinueCard(progress: item, accent: accent, muted: muted, textColor: textColor, cardBg: cardBg)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var bookmarksSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Bookmarks", icon: "heart.fill")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 14) {
                ForEach(bookmarkedAnime) { anime in
                    NavigationLink(destination: AnimeDetailView(anime: anime)) {
                        CardView(anime: anime, accent: accent, muted: muted, cardBg: cardBg, textColor: textColor, borderColor: borderColor)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "bookmark").font(.system(size: 36)).foregroundColor(muted)
            Text("No bookmarks yet").font(.system(size: 16, weight: .semibold)).foregroundColor(muted)
            Text("Start browsing and add anime to your library")
                .font(.system(size: 13)).foregroundColor(muted.opacity(0.6))
        }
        .padding(.top, 80)
        .frame(maxWidth: .infinity)
    }

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 12)).foregroundColor(accent)
            Text(title).font(.system(size: 15, weight: .semibold)).foregroundColor(textColor)
        }
    }

    private func loadData() {
        bookmarkedAnime = PersistenceManager.shared.loadBookmarks()
        continueWatching = PersistenceManager.shared.loadProgress()
        isLoading = false
    }
}

struct ContinueCard: View {
    let progress: WatchProgress
    let accent: Color
    let muted: Color
    let textColor: Color
    let cardBg: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            ZStack {
                AsyncImage(url: URL(string: progress.animeImage)) { phase in
                    if let image = phase.image {
                        image.resizable().aspectRatio(contentMode: .fill)
                    } else {
                        cardBg
                    }
                }
                .frame(width: 130, height: 74)
                .clipped()

                Color.black.opacity(0.3)
                Image(systemName: "play.circle.fill").font(.system(size: 18)).foregroundColor(.white)
            }
            .cornerRadius(8)

            Text(progress.animeTitle)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(textColor)
                .lineLimit(1)
                .frame(width: 130, alignment: .leading)

            Text("Ep. \(progress.episodeNumber)")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(accent)
        }
    }
}
