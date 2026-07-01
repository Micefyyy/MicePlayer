import AVFoundation
import Combine

final class HLSPlayer: ObservableObject {
    let player: AVPlayer

    @Published var isPlaying = false
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var isLoading = true
    @Published var error: String?

    private var timeObserver: Any?
    private var cancellables = Set<AnyCancellable>()

    init() {
        self.player = AVPlayer()
        setupObservers()
    }

    func load(manifestUrl: URL) {
        isLoading = true
        error = nil
        let asset = AVAsset(url: manifestUrl)
        let playerItem = AVPlayerItem(asset: asset)
        player.replaceCurrentItem(with: playerItem)

        Task { @MainActor in
            do {
                try await asset.load(.duration)
                self.duration = CMTimeGetSeconds(asset.duration)
                self.isLoading = false
                self.player.play()
                self.isPlaying = true
            } catch {
                self.error = "Failed to load stream: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }

    func play() {
        player.play()
        isPlaying = true
    }

    func pause() {
        player.pause()
        isPlaying = false
    }

    func seek(to seconds: Double) {
        let time = CMTime(seconds: seconds, preferredTimescale: 600)
        player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    func changeQuality(manifestUrl: URL) {
        let currentPos = currentTime
        load(manifestUrl: manifestUrl)
        seek(to: currentPos)
    }

    private func setupObservers() {
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.5, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            self?.currentTime = CMTimeGetSeconds(time)
        }

        player.publisher(for: \.timeControlStatus)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                switch status {
                case .playing:
                    self?.isPlaying = true
                    self?.isLoading = false
                case .waitingToPlayAtSpecifiedRate:
                    self?.isLoading = true
                case .paused:
                    self?.isPlaying = false
                    self?.isLoading = false
                @unknown default:
                    break
                }
            }
            .store(in: &cancellables)
    }

    deinit {
        if let observer = timeObserver {
            player.removeTimeObserver(observer)
        }
    }
}
