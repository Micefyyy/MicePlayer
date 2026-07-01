import SwiftUI
import AVKit

struct PlayerViewWrapper: View {
    @ObservedObject var playerEngine: HLSPlayer
    let player: AVPlayer


    var body: some View {
        ZStack {
            VideoPlayer(player: player)

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
