import SwiftUI

struct HomeView: View {
    @State private var trending: [Anime] = []
    @State private var seasonal: [Anime] = []
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                if isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .padding(.top, 80)
                        Text("Loading...")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    LazyVStack(spacing: 24) {
                        heroSection
                        if !trending.isEmpty {
                            sectionHeader("Trending Now")
                            trendingScroll
                        }
                        if !seasonal.isEmpty {
                            sectionHeader("Seasonal Hits")
                            seasonalScroll
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .background(Color(.systemBackground))
            .navigationTitle("Home")
            .task {
                await loadData()
            }
        }
    }

    private var heroSection: some View {
        Group {
            if let first = trending.first {
                NavigationLink(destination: AnimeDetailView(anime: first)) {
                    ZStack(alignment: .bottomLeading) {
                        AsyncImage(url: URL(string: first.coverImageLarge ?? "")) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            default:
                                Color(.systemGray5)
                            }
                        }
                        .frame(height: 320)
                        .clipped()

                        LinearGradient(
                            gradient: Gradient(colors: [.clear, .black.opacity(0.8)]),
                            startPoint: .top,
                            endPoint: .bottom
                        )

                        VStack(alignment: .leading, spacing: 8) {
                            Text(first.displayTitle)
                                .font(.title2)
                                .fontWeight(.black)
                                .foregroundColor(.white)
                            if let score = first.score {
                                HStack(spacing: 4) {
                                    Image(systemName: "star.fill")
                                        .foregroundColor(.yellow)
                                        .font(.caption)
                                    Text(String(format: "%.1f", score))
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                }
                            }
                        }
                        .padding()
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var trendingScroll: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(trending) { anime in
                    NavigationLink(destination: AnimeDetailView(anime: anime)) {
                        AnimeCardView(anime: anime)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var seasonalScroll: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(seasonal) { anime in
                    NavigationLink(destination: AnimeDetailView(anime: anime)) {
                        AnimeCardView(anime: anime)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.headline)
                .fontWeight(.bold)
            Spacer()
            Text("See All")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.orange)
        }
    }

    private func loadData() async {
        isLoading = true
        async let t = AnimeService.shared.fetchTrending()
        async let s = AnimeService.shared.fetchSeasonal()
        (trending, seasonal) = await ((try? t) ?? [], (try? s) ?? [])
        isLoading = false
    }
}

struct AnimeCardView: View {
    let anime: Anime

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            AsyncImage(url: URL(string: anime.coverImageMedium ?? "")) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                default:
                    Color(.systemGray5)
                }
            }
            .frame(width: 130, height: 180)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Text(anime.displayTitle)
                .font(.caption)
                .fontWeight(.semibold)
                .lineLimit(2)
                .frame(width: 130, alignment: .leading)
                .foregroundColor(.primary)
        }
    }
}
