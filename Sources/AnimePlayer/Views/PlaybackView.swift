import SwiftUI
import AVKit

struct PlaybackView: View {
    let animeId: Int
    let episodeNumber: Int
    let title: String

    @StateObject private var playerEngine = HLSPlayer()
    @EnvironmentObject private var preferences: Preferences

    var body: some View {
        VStack(spacing: 0) {
            PlayerViewWrapper(playerEngine: playerEngine, player: playerEngine.player)
                .frame(height: UIScreen.main.bounds.width * 9 / 16)

            if let error = playerEngine.error {
                VStack(spacing: 12) {
                    Image(systemName: "wifi.slash")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text(error)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Retry") {
                        loadStream()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.top, 40)
                Spacer()
            } else {
                List {
                    Section {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Episode \(episodeNumber)")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                if !title.isEmpty {
                                    Text(title)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                        }
                    }

                    Section("Servers") {
                        ForEach(StreamQuality.allCases, id: \.rawValue) { quality in
                            Button {
                                // quality switch triggers a new stream load
                            } label: {
                                HStack {
                                    Text(quality.rawValue)
                                    Spacer()
                                    if quality.rawValue == preferences.preferredQuality {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.orange)
                                    }
                                }
                            }
                            .foregroundColor(.primary)
                        }
                    }
                }
            }
        }
        .background(Color(.systemBackground))
        .navigationTitle("Ep. \(episodeNumber)")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { loadStream() }
        .onDisappear { playerEngine.pause() }
    }

    private func loadStream() {
        Task {
            do {
                let data = try await AnimeService.shared.getStreamingSources(
                    animeId: animeId,
                    episode: episodeNumber
                )
                guard let source = data.sources.first(where: {
                    $0.quality == preferences.preferredQuality
                }) ?? data.sources.first else { return }

                if let url = URL(string: source.manifestUrl) {
                    playerEngine.load(manifestUrl: url)
                }
            } catch {
                playerEngine.error = "Failed to load stream"
            }
        }
    }
}
