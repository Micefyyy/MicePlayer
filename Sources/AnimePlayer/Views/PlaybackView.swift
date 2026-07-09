import SwiftUI
import AVKit

struct PlaybackView: View {
    let animeId: Int
    let episodeNumber: Int
    let title: String
    var animeImage: String? = nil

    @StateObject private var playerEngine = HLSPlayer()
    @EnvironmentObject private var preferences: Preferences
    @Environment(\.dismiss) private var dismiss
    @State private var episodes: [Episode] = []
    @State private var animeInfo: Anime?
    @State private var isLoadingEpisodes = true
    @State private var isFullscreen = false
    @State private var hasSavedProgress = false
    @State private var showAutoPlayOverlay = false
    @State private var navigateToNext = false
    @State private var nextEpisodeNumber = 0
    @State private var useDub = false
    @State private var epPage = 0
    @State private var isBookmarked = false

    private let accent = Color(hex: "b5a8ff")
    private let bg = Color(hex: "0a0a0a")
    private let cardBg = Color(hex: "131313")
    private let muted = Color(hex: "606060")
    private let textColor = Color(hex: "e0e0e0")
    private let borderColor = Color.white.opacity(0.08)
    private let pageSize = 50

    private var currentIndex: Int? {
        episodes.firstIndex(where: { $0.number == episodeNumber })
    }

    private var pagedEpisodes: [Episode] {
        let start = epPage * pageSize
        return Array(episodes.dropFirst(start).prefix(pageSize))
    }

    private var totalPages: Int {
        max(1, (episodes.count + pageSize - 1) / pageSize)
    }

    var body: some View {
        VStack(spacing: 0) {
            playerHeader
            ZStack {
                Color.black.ignoresSafeArea()
                VStack(spacing: 0) {
                    ZStack(alignment: .bottomTrailing) {
                        PlayerViewWrapper(playerEngine: playerEngine, player: playerEngine.player)
                            .aspectRatio(16/9, contentMode: .fit)
                        fullscreenButton
                    }
                    if playerEngine.error == nil {
                        scrollContent
                    } else {
                        errorState(playerEngine.error!)
                    }
                }
            }
        }
        .background(bg)
        .navigationBarHidden(true)
        .onAppear {
            useDub = preferences.showDub
            loadStream()
            loadEpisodes()
            loadAnimeInfo()
            isBookmarked = PersistenceManager.shared.isBookmarked(animeId)
        }
        .onDisappear { playerEngine.pause() }
        .fullScreenCover(isPresented: $isFullscreen) {
            fullscreenView
        }
        .overlay {
            if showAutoPlayOverlay { autoPlayOverlay }
        }
        .background(
            NavigationLink(
                destination: nextEpisodeNumber > 0 ? PlaybackView(
                    animeId: animeId, episodeNumber: nextEpisodeNumber, title: title, animeImage: animeImage
                ) : nil,
                isActive: $navigateToNext
            ) { EmptyView() }.hidden()
        )
    }

    private var playerHeader: some View {
        HStack(spacing: 8) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 30, height: 30)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Circle())
            }

            Text("Ep. \(episodeNumber)")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(textColor)
                .lineLimit(1)

            Spacer()

            HStack(spacing: 0) {
                Button {
                    useDub = false
                    preferences.showDub = false
                    loadStream()
                } label: {
                    Text("SUB")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(!useDub ? .white : .white.opacity(0.45))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(!useDub ? accent : Color.white.opacity(0.06))
                }

                Button {
                    useDub = true
                    preferences.showDub = true
                    loadStream()
                } label: {
                    Text("DUB")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(useDub ? .white : .white.opacity(0.45))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(useDub ? accent : Color.white.opacity(0.06))
                }
            }
            .cornerRadius(6)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.15)))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(bg.opacity(0.95))
        .overlay(Divider().background(borderColor), alignment: .bottom)
    }

    private var fullscreenButton: some View {
        Button {
            isFullscreen.toggle()
        } label: {
            Image(systemName: "arrow.up.left.and.arrow.down.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
                .padding(6)
                .background(Color.black.opacity(0.5))
                .cornerRadius(4)
        }
        .padding(6)
    }

    private var scrollContent: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                if let anime = animeInfo {
                    animeInfoCard(anime)
                }
                navButtons
                qualitySelector
                episodeSection
            }
            .padding(.horizontal, 10)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
    }

    private func animeInfoCard(_ anime: Anime) -> some View {
        HStack(spacing: 10) {
            AsyncImage(url: URL(string: anime.coverImageMedium ?? "")) { phase in
                if let image = phase.image {
                    image.resizable().aspectRatio(contentMode: .fill)
                } else {
                    cardBg
                }
            }
            .frame(width: 50, height: 68)
            .cornerRadius(6)

            VStack(alignment: .leading, spacing: 3) {
                Text(anime.displayTitle)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(textColor)
                    .lineLimit(2)

                if let genres = anime.genres, !genres.isEmpty {
                    HStack(spacing: 3) {
                        ForEach(genres.prefix(3), id: \.self) { g in
                            Text(g)
                                .font(.system(size: 8, weight: .semibold))
                                .foregroundColor(accent)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(accent.opacity(0.1))
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(accent.opacity(0.25)))
                                .cornerRadius(6)
                        }
                    }
                }

                if let synopsis = anime.synopsis {
                    Text(synopsis)
                        .font(.system(size: 10))
                        .foregroundColor(muted)
                        .lineLimit(2)
                }

                HStack(spacing: 8) {
                    Button {
                        isBookmarked = PersistenceManager.shared.toggleBookmark(anime)
                        NotificationCenter.default.post(name: Notification.Name("bookmarksChanged"), object: nil)
                    } label: {
                        Image(systemName: isBookmarked ? "heart.fill" : "heart")
                            .font(.system(size: 12))
                            .foregroundColor(isBookmarked ? accent : muted)
                            .frame(width: 24, height: 24)
                            .background(cardBg)
                            .cornerRadius(4)
                            .overlay(RoundedRectangle(cornerRadius: 4).stroke(borderColor))
                    }

                    if !DownloadManager.shared.isDownloaded(animeId: animeId, episodeNumber: episodeNumber) {
                        Button { downloadCurrentEpisode() } label: {
                            Image(systemName: "arrow.down.circle")
                                .font(.system(size: 12))
                                .foregroundColor(muted)
                                .frame(width: 24, height: 24)
                                .background(cardBg)
                                .cornerRadius(4)
                                .overlay(RoundedRectangle(cornerRadius: 4).stroke(borderColor))
                        }
                    }
                }
            }
        }
        .padding(10)
        .background(cardBg)
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(borderColor))
    }

    private var navButtons: some View {
        HStack(spacing: 10) {
            if let idx = currentIndex, idx > 0 {
                NavigationLink(destination: PlaybackView(animeId: animeId, episodeNumber: episodes[idx - 1].number, title: title, animeImage: animeImage)) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left").font(.system(size: 11, weight: .bold))
                        Text("Previous").font(.system(size: 13, weight: .bold))
                    }
                    .foregroundColor(textColor)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(cardBg)
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(borderColor))
                }
                .buttonStyle(.plain)
            }

            if let idx = currentIndex, idx < episodes.count - 1 {
                NavigationLink(destination: PlaybackView(animeId: animeId, episodeNumber: episodes[idx + 1].number, title: title, animeImage: animeImage)) {
                    HStack(spacing: 4) {
                        Text("Next").font(.system(size: 13, weight: .bold))
                        Image(systemName: "chevron.right").font(.system(size: 11, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(accent)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var qualitySelector: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Quality")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(textColor)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(StreamQuality.allCases, id: \.rawValue) { quality in
                        Button {
                            preferences.preferredQuality = quality.rawValue
                            loadStream()
                        } label: {
                            Text(quality.rawValue)
                                .font(.system(size: 11, weight: .bold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(quality.rawValue == preferences.preferredQuality ? accent : cardBg)
                                .foregroundColor(quality.rawValue == preferences.preferredQuality ? .white : muted)
                                .cornerRadius(6)
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(borderColor))
                        }
                    }
                }
            }
        }
    }

    private var episodeSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Episodes")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(textColor)
                Spacer()
                Text("\(episodes.count) total")
                    .font(.system(size: 11))
                    .foregroundColor(muted)
            }

            if isLoadingEpisodes {
                ProgressView().tint(accent).frame(maxWidth: .infinity).padding(.vertical, 20)
            } else if !episodes.isEmpty {
                if episodes.count > pageSize {
                    HStack(spacing: 6) {
                        Button { epPage = max(0, epPage - 1) } label: {
                            Text("<- Prev")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(accent)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(accent.opacity(0.1))
                                .cornerRadius(4)
                        }
                        .disabled(epPage == 0)

                        Text("\(epPage * pageSize + 1)-\(min((epPage + 1) * pageSize, episodes.count))")
                            .font(.system(size: 11))
                            .foregroundColor(muted)
                            .frame(minWidth: 70)

                        Button { epPage = min(totalPages - 1, epPage + 1) } label: {
                            Text("Next ->")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(accent)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(accent.opacity(0.1))
                                .cornerRadius(4)
                        }
                        .disabled(epPage >= totalPages - 1)

                        Spacer()

                        HStack(spacing: 4) {
                            Button { epPage = 0 } label: { Text("+100").font(.system(size: 10)).foregroundColor(muted) }
                                .disabled(epPage == 0)
                            Button { epPage = max(0, epPage - 5) } label: { Text("-10").font(.system(size: 10)).foregroundColor(muted) }
                                .disabled(epPage == 0)
                            Button { epPage = min(totalPages - 1, epPage + 5) } label: { Text("+10").font(.system(size: 10)).foregroundColor(muted) }
                                .disabled(epPage >= totalPages - 1)
                            Button { epPage = totalPages - 1 } label: { Text("+100").font(.system(size: 10)).foregroundColor(muted) }
                                .disabled(epPage >= totalPages - 1)
                        }
                    }
                    .padding(.bottom, 4)
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 60), spacing: 4)], spacing: 4) {
                    ForEach(pagedEpisodes) { ep in
                        NavigationLink(destination: PlaybackView(animeId: animeId, episodeNumber: ep.number, title: title, animeImage: animeImage)) {
                            Text("\(ep.number)")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(ep.number == episodeNumber ? .white : muted)
                                .frame(height: 30)
                                .frame(maxWidth: .infinity)
                                .background(ep.number == episodeNumber ? accent : cardBg)
                                .cornerRadius(6)
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(borderColor))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func errorState(_ error: String) -> some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "wifi.slash").font(.system(size: 32)).foregroundColor(muted)
            Text(error).font(.system(size: 13)).foregroundColor(muted).multilineTextAlignment(.center).padding(.horizontal, 40)
            Button("Retry") { loadStream() }
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .background(accent)
                .cornerRadius(8)
            Spacer()
        }
    }

    private var autoPlayOverlay: some View {
        VStack(spacing: 16) {
            Spacer()
            VStack(spacing: 12) {
                if let idx = currentIndex, idx < episodes.count - 1 {
                    Text("Up Next").font(.system(size: 12)).foregroundColor(muted)
                    Text("Episode \(episodes[idx + 1].number)").font(.system(size: 16, weight: .bold)).foregroundColor(textColor)
                    if let epTitle = episodes[idx + 1].title {
                        Text(epTitle).font(.system(size: 13)).foregroundColor(muted).lineLimit(1)
                    }
                    HStack(spacing: 12) {
                        Button("Cancel") { showAutoPlayOverlay = false }
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(textColor)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 10)
                            .background(cardBg)
                            .cornerRadius(8)
                        Button("Play Now") {
                            showAutoPlayOverlay = false
                            nextEpisodeNumber = episodes[idx + 1].number
                            navigateToNext = true
                        }
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(accent)
                        .cornerRadius(8)
                    }
                }
            }
            .padding(20)
            .background(bg.opacity(0.9))
            .cornerRadius(12)
            .padding(.horizontal, 32)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(borderColor))
            Spacer()
        }
        .background(Color.black.opacity(0.5))
    }

    private var fullscreenView: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            PlayerViewWrapper(playerEngine: playerEngine, player: playerEngine.player)
                .ignoresSafeArea()
            VStack {
                HStack {
                    Button { isFullscreen = false } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .padding(10)
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

    private func loadStream() {
        Task {
            do {
                let data = try await AnimeService.shared.getStreamingSources(animeId: animeId, episode: episodeNumber)
                let candidates = data.sources(for: useDub)
                guard let source = candidates.first ?? data.sources(for: !useDub).first else { return }
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
        PersistenceManager.shared.updateProgress(animeId: animeId, animeTitle: title, animeImage: animeImage ?? "", episodeNumber: episodeNumber)
        NotificationCenter.default.post(name: Notification.Name("progressUpdated"), object: nil)
    }

    private func observePlaybackEnd() {
        playerEngine.onPlaybackEnded = {
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

    private func loadAnimeInfo() {
        Task {
            animeInfo = try? await AnimeService.shared.getAnimeDetail(id: animeId)
        }
    }

    private func downloadCurrentEpisode() {
        Task {
            do {
                let data = try await AnimeService.shared.getStreamingSources(animeId: animeId, episode: episodeNumber)
                let candidates = data.sources(for: useDub)
                guard let source = candidates.first ?? data.sources(for: !useDub).first else { return }
                DownloadManager.shared.download(animeId: animeId, animeTitle: title, animeImage: animeImage ?? "", episodeNumber: episodeNumber, manifestUrl: source.manifestUrl)
            } catch {
                playerEngine.error = "Failed to start download"
            }
        }
    }
}
