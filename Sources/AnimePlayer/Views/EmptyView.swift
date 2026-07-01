import SwiftUI

struct DownloadsView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Image(systemName: "arrow.down.circle")
                    .font(.system(size: 40))
                    .foregroundColor(.gray)
                Text("No downloads")
                    .font(.headline)
                    .foregroundColor(.gray)
                Text("Stream directly — nothing is stored on device")
                    .font(.caption)
                    .foregroundColor(.gray.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            .padding(.top, 80)
            .navigationTitle("Downloads")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)
        }
    }
}
