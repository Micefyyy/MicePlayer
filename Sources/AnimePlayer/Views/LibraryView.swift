import SwiftUI

struct LibraryView: View {
    @State private var bookmarkedAnime: [Anime] = []
    @State private var continueWatching: [WatchProgress] = []
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 24) {
                    if isLoading {
                        ProgressView()
                            .tint(.orange)
                            .padding(.top, 80)
                    } else if !continueWatching.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "play.fill")
                                    .foregroundColor(.orange)
                                    .font(.caption)
                                Text("Continue Watching")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                            }
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(continueWatching) { item in
                                        NavigationLink(
                                            destination: PlaybackView(
                                                animeId: item.animeId,
                                                episodeNumber: item.episodeNumber,
                                                title: item.animeTitle,
                                                animeImage: item.animeImage
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
                            HStack {
                                Image(systemName: "bookmark.fill")
                                    .foregroundColor(.orange)
                                    .font(.caption)
                                Text("Bookmarks")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                            }
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 12)], spacing: 12) {
                                ForEach(bookmarkedAnime) { anime in
                                    NavigationLink(destination: AnimeDetailView(anime: anime)) {
                                        GlassCardView(anime: anime)
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
                                .foregroundColor(.gray)
                            Text("No bookmarks yet")
                                .font(.headline)
                                .foregroundColor(.gray)
                            Text("Start browsing and add anime to your library")
                                .font(.caption)
                                .foregroundColor(.gray.opacity(0.6))
                        }
                        .padding(.top, 80)
                    }
                }
                .padding(.horizontal)
            }
            .background(Color.black)
            .navigationTitle("Library")
            .onAppear {
                bookmarkedAnime = PersistenceManager.shared.loadBookmarks()
                continueWatching = PersistenceManager.shared.loadProgress()
                isLoading = false
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name(" bookmarksChanged"))) { _ in
                bookmarkedAnime = PersistenceManager.shared.loadBookmarks()
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("progressUpdated"))) { _ in
                continueWatching = PersistenceManager.shared.loadProgress()
            }
        }
    }
}

struct ContinueCard: View {
    let progress: WatchProgress

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack {
                AsyncImage(url: URL(string: progress.animeImage)) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: .fill)
                    default:
                        Color(.systemGray5)
                    }
                }
                .frame(width: 140, height: 80)
                .clipped()

                Color.black.opacity(0.3)
                Image(systemName: "play.circle.fill")
                    .font(.title3)
                    .foregroundColor(.white)
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))

            Text(progress.animeTitle)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .lineLimit(1)
                .frame(width: 140, alignment: .leading)

            Text("Ep. \(progress.episodeNumber)")
                .font(.caption2)
                .foregroundColor(.orange)
                .fontWeight(.bold)
        }
    }
}
