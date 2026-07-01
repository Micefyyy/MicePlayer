import SwiftUI
import AVKit

struct PlayerView: UIViewControllerRepresentable {
    let player: AVPlayer
    var showsControls: Bool = true

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = showsControls
        controller.entersFullScreenWhenPlaybackBegins = false
        controller.exitsFullScreenWhenPlaybackEnds = false
        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        uiViewController.player = player
    }
}

struct PlayerViewWrapper: View {
    @ObservedObject var playerEngine: HLSPlayer
    let player: AVPlayer
    @State private var showControls = true
    @State private var controlsTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            PlayerView(player: player, showsControls: true)
                .ignoresSafeArea()

            if playerEngine.isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
            }

            if let error = playerEngine.error {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.largeTitle)
                        .foregroundColor(.yellow)
                    Text(error)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
        }
        .background(Color.black)
    }
}
