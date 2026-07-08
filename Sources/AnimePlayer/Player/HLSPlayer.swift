import AVFoundation
import Combine

final class HLSPlayer: ObservableObject {
    let player: AVPlayer

    @Published var isPlaying = false
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var isLoading = true
    @Published var error: String?

    var onPlaybackEnded: (() -> Void)?

    private var timeObserver: Any?
    private var cancellables = Set<AnyCancellable>()
    private var hasReachedEnd = false
    private var fairPlayManager: FairPlayManager?

    init() {
        self.player = AVPlayer()
        setupObservers()
    }

    func load(manifestUrl: URL) {
        isLoading = true
        error = nil
        hasReachedEnd = false

        let asset = AVURLAsset(url: manifestUrl)

        if manifestUrl.scheme == "skd" {
            let fpsManager = FairPlayManager(
                licenseURL: URL(string: "https://your-fairplay-license-server.com/license")!,
                certificateURL: URL(string: "https://your-fairplay-license-server.com/cert")!
            )
            self.fairPlayManager = fpsManager
            asset.resourceLoader.setDelegate(fpsManager, queue: DispatchQueue(label: "com.animeplayer.fairplay"))
        } else {
            self.fairPlayManager = nil
        }

        let playerItem = AVPlayerItem(asset: asset)
        player.replaceCurrentItem(with: playerItem)

        Task { @MainActor in
            do {
                let dur = try await asset.load(.duration)
                self.duration = CMTimeGetSeconds(dur)
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
            guard let self = self else { return }
            let seconds = CMTimeGetSeconds(time)
            self.currentTime = seconds

            if self.duration > 0 && seconds >= self.duration - 1.0 && !self.hasReachedEnd {
                self.hasReachedEnd = true
                self.onPlaybackEnded?()
            }
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
        fairPlayManager = nil
    }
}
