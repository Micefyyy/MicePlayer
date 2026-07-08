import SwiftUI

struct DownloadsView: View {
    @StateObject private var downloadManager = DownloadManager.shared

    var body: some View {
        NavigationStack {
            Group {
                if downloadManager.downloads.isEmpty {
                    emptyState
                } else {
                    downloadsList
                }
            }
            .background(Color.black)
            .navigationTitle("Downloads")
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 40))
                .foregroundColor(.gray)
            Text("No downloads")
                .font(.headline)
                .foregroundColor(.gray)
            Text("Tap the download button on any episode to save it for offline viewing")
                .font(.caption)
                .foregroundColor(.gray.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .padding(.top, 80)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var downloadsList: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 12) {
                ForEach(downloadManager.downloads) { item in
                    DownloadRow(item: item, manager: downloadManager)
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
        }
    }
}

struct DownloadRow: View {
    let item: DownloadItem
    @ObservedObject var manager: DownloadManager

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                AsyncImage(url: URL(string: item.animeImage)) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: .fill)
                    default:
                        Color(.systemGray5)
                    }
                }
                .frame(width: 80, height: 50)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 8))

                if item.status == .downloading {
                    Color.black.opacity(0.4)
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(0.7)
                } else if item.status == .completed {
                    Color.black.opacity(0.3)
                    Image(systemName: "play.fill")
                        .foregroundColor(.white)
                        .font(.caption)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(item.animeTitle)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .lineLimit(1)
                Text("Episode \(item.episodeNumber)")
                    .font(.caption2)
                    .foregroundColor(.orange)
                    .fontWeight(.bold)

                if item.status == .downloading {
                    ProgressView(value: item.progress)
                        .tint(.orange)
                        .scaleEffect(y: 0.6)
                        .padding(.top, 4)
                    Text("\(Int(item.progress * 100))%")
                        .font(.caption2)
                        .foregroundColor(.gray)
                } else if item.status == .completed {
                    Text("Downloaded")
                        .font(.caption2)
                        .foregroundColor(.green)
                } else if item.status == .failed {
                    Text("Failed")
                        .font(.caption2)
                        .foregroundColor(.red)
                }
            }

            Spacer()

            Button {
                if item.status == .downloading {
                    manager.cancelDownload(id: item.id)
                } else {
                    manager.deleteDownload(id: item.id)
                }
            } label: {
                Image(systemName: item.status == .downloading ? "xmark.circle.fill" : "trash.fill")
                    .foregroundColor(.gray)
                    .font(.caption)
            }
        }
        .padding(10)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
