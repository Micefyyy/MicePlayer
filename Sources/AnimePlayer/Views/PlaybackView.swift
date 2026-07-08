import SwiftUI
import AVKit

struct PlaybackView: View {
    let animeId: Int
    let episodeNumber: Int
    let title: String
    var animeImage: String? = nil

    @StateObject private var playerEngine = HLSPlayer()
    @EnvironmentObject private var preferences: Preferences
    @State private var episodes: [Episode] = []
    @State private var isLoadingEpisodes = true
    @State private var isFullscreen = false
    @State private var hasSavedProgress = false
    @State private var showAutoPlayOverlay = false
    @State private var navigateToNext = false
    @State private var nextEpisodeNumber = 0

    private var currentIndex: Int? {
        episodes.firstIndex(where: { $0.number == episodeNumber })
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                ZStack(alignment: .bottomTrailing) {
                    PlayerViewWrapper(playerEngine: playerEngine, player: playerEngine.player)
                        .frame(height: UIScreen.main.bounds.width * 9 / 16)

                    Button {
                        isFullscreen.toggle()
                    } label: {
                        Image(systemName: isFullscreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.black.opacity(0.5))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .padding(8)
                }

                if let error = playerEngine.error {
                    errorState(error)
                } else {
                    episodeInfo
                }
            }
        }
        .navigationTitle("Ep. \(episodeNumber)")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadStream()
            loadEpisodes()
        }
        .onDisappear { playerEngine.pause() }
        .fullScreenCover(isPresented: $isFullscreen) {
            ZStack {
                Color.black.ignoresSafeArea()
                PlayerViewWrapper(playerEngine: playerEngine, player: playerEngine.player)
                    .ignoresSafeArea()
                VStack {
                    HStack {
                        Button {
                            isFullscreen = false
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                                .padding(12)
                                .background(Color.black.opacity(0.4))
                                .clipShape(Circle())
                        }
                        .padding()
                        Spacer()
                    }
                    Spacer()
                }
            }
            .background(Color.black)
            .ignoresSafeArea()
        }
        .overlay {
            if showAutoPlayOverlay {
                autoPlayOverlay
            }
        }
        .background(
            NavigationLink(
                destination: nextEpisodeNumber > 0 ? PlaybackView(
                    animeId: animeId,
                    episodeNumber: nextEpisodeNumber,
                    title: title,
                    animeImage: animeImage
                ) : nil,
                isActive: $navigateToNext
            ) { EmptyView() }
            .hidden()
        )
    }

    private var episodeInfo: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Episode \(episodeNumber)")
                            .font(.title3)
                            .fontWeight(.black)
                            .foregroundColor(.white)
                        Text(title)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .lineLimit(1)
                    }
                    Spacer()
                    if DownloadManager.shared.isDownloaded(animeId: animeId, episodeNumber: episodeNumber) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    } else {
                        Button {
                            downloadCurrentEpisode()
                        } label: {
                            Image(systemName: "arrow.down.circle")
                                .font(.title3)
                                .foregroundColor(.orange)
                        }
                    }
                }

                // Prev / Next buttons
                HStack(spacing: 12) {
                    if let idx = currentIndex, idx > 0 {
                        NavigationLink(destination: PlaybackView(
                            animeId: animeId,
                            episodeNumber: episodes[idx - 1].number,
                            title: title,
                            animeImage: animeImage
                        )) {
                            Label("Previous", systemImage: "chevron.left")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.white.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }

                    if let idx = currentIndex, idx < episodes.count - 1 {
                        NavigationLink(destination: PlaybackView(
                            animeId: animeId,
                            episodeNumber: episodes[idx + 1].number,
                            title: title,
                            animeImage: animeImage
                        )) {
                            Label("Next", systemImage: "chevron.right")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.orange)
                                .foregroundColor(.black)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Audio & Quality
                VStack(alignment: .leading, spacing: 8) {
                    Text("Audio & Quality")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    HStack(spacing: 8) {
                        Button {
                            preferences.showDub.toggle()
                            loadStream()
                        } label: {
                            Text(preferences.showDub ? "DUB" : "SUB")
                                .font(.caption)
                                .fontWeight(.bold)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(preferences.showDub ? Color.orange : Color.white.opacity(0.08))
                                .foregroundColor(preferences.showDub ? .black : .white)
                                .clipShape(Capsule())
                        }

                        ForEach(StreamQuality.allCases, id: \.rawValue) { quality in
                            Button {
                                preferences.preferredQuality = quality.rawValue
                                loadStream()
                            } label: {
                                Text(quality.rawValue)
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        quality.rawValue == preferences.preferredQuality
                                            ? Color.orange
                                            : Color.white.opacity(0.08)
                                    )
                                    .foregroundColor(
                                        quality.rawValue == preferences.preferredQuality
                                            ? .black
                                            : .white
                                    )
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }

                // Episode list
                if !episodes.isEmpty {
                    Text("Episodes")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    LazyVStack(spacing: 0) {
                        ForEach(episodes) { ep in
                            NavigationLink(destination: PlaybackView(
                                animeId: animeId,
                                episodeNumber: ep.number,
                                title: title,
                                animeImage: animeImage
                            )) {
                                EpisodeRowCompact(episode: ep, isCurrent: ep.number == episodeNumber)
                            }
                            .buttonStyle(.plain)
                            Divider()
                                .background(Color.white.opacity(0.05))
                                .padding(.leading, 56)
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
    }

    private func errorState(_ error: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "wifi.slash")
                .font(.system(size: 40))
                .foregroundColor(.gray)
            Text(error)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button("Retry") {
                loadStream()
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            Spacer()
        }
    }

    private var autoPlayOverlay: some View {
        VStack(spacing: 16) {
            Spacer()
            VStack(spacing: 12) {
                if let idx = currentIndex, idx < episodes.count - 1 {
                    Text("Up Next")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("Episode \(episodes[idx + 1].number)")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    if let epTitle = episodes[idx + 1].title {
                        Text(epTitle)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .lineLimit(1)
                    }
                    HStack(spacing: 12) {
                        Button("Cancel") {
                            showAutoPlayOverlay = false
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.1))
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                        Button("Play Now") {
                            showAutoPlayOverlay = false
                            nextEpisodeNumber = episodes[idx + 1].number
                            navigateToNext = true
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(Color.orange)
                        .foregroundColor(.black)
                        .fontWeight(.bold)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
            .padding(24)
            .background(Color.black.opacity(0.9))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 32)
            Spacer()
        }
        .background(Color.black.opacity(0.5))
    }

    private func loadStream() {
        Task {
            do {
                let data = try await AnimeService.shared.getStreamingSources(
                    animeId: animeId,
                    episode: episodeNumber
                )
                let useDub = preferences.showDub
                var candidates = data.sources(for: useDub)
                if candidates.isEmpty {
                    candidates = data.sources(for: !useDub)
                }
                guard let source = candidates.first else { return }

                if let url = URL(string: source.manifestUrl) {
                    playerEngine.load(manifestUrl: url)
                    saveProgress()
                    observePlaybackEnd()
                }
            } catch {
                playerEngine.error = "Failed to load stream"
            }
        }
    }

    private func saveProgress() {
        guard !hasSavedProgress else { return }
        hasSavedProgress = true
        PersistenceManager.shared.updateProgress(
            animeId: animeId,
            animeTitle: title,
            animeImage: animeImage ?? "",
            episodeNumber: episodeNumber
        )
        NotificationCenter.default.post(name: Notification.Name("progressUpdated"), object: nil)
    }

    private func observePlaybackEnd() {
        playerEngine.onPlaybackEnded = { [weak self] in
            guard let self = self else { return }
            DispatchQueue.main.async {
                if self.preferences.autoPlay, let idx = self.currentIndex, idx < self.episodes.count - 1 {
                    self.showAutoPlayOverlay = true
                }
            }
        }
    }

    private func loadEpisodes() {
        Task {
            episodes = (try? await AnimeService.shared.getEpisodes(animeId: animeId)) ?? []
            isLoadingEpisodes = false
        }
    }

    private func downloadCurrentEpisode() {
        Task {
            do {
                let data = try await AnimeService.shared.getStreamingSources(
                    animeId: animeId,
                    episode: episodeNumber
                )
                let useDub = preferences.showDub
                var candidates = data.sources(for: useDub)
                if candidates.isEmpty {
                    candidates = data.sources(for: !useDub)
                }
                guard let source = candidates.first else { return }

                DownloadManager.shared.download(
                    animeId: animeId,
                    animeTitle: title,
                    animeImage: animeImage ?? "",
                    episodeNumber: episodeNumber,
                    manifestUrl: source.manifestUrl
                )
            } catch {
                playerEngine.error = "Failed to start download"
            }
        }
    }
}

struct EpisodeRowCompact: View {
    let episode: Episode
    var isCurrent: Bool = false

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                AsyncImage(url: URL(string: episode.thumbnail ?? "")) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: .fill)
                    default:
                        Color(.systemGray5)
                    }
                }
                .frame(width: 80, height: 45)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 6))

                if isCurrent {
                    Color.black.opacity(0.4)
                    Image(systemName: "play.fill")
                        .font(.caption2)
                        .foregroundColor(.white)
                }
            }

            VStack(alignment: .leading, spacing: 1) {
                Text("Episode \(episode.number)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(isCurrent ? .orange : .white)
                if let title = episode.title {
                    Text(title)
                        .font(.caption2)
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
            }

            Spacer()
        }
        .padding(.vertical, 6)
        .padding(.horizontal)
        .background(isCurrent ? Color.orange.opacity(0.05) : Color.clear)
        .contentShape(Rectangle())
    }
}
