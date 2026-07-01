import SwiftUI

import SwiftUI

import SwiftUI

struct DownloadsView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Image(systemName: "arrow.down.circle")
                    .font(.system(size: 40))
                    .foregroundColor(.secondary)
                Text("No downloads")
                    .font(.headline)
                    .foregroundColor(.secondary)
                Text("HLS streams stream directly — nothing is stored permanently on device")
                    .font(.caption)
                    .foregroundColor(.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            .padding(.top, 80)
            .navigationTitle("Downloads")
        }
    }
}
