import SwiftUI

struct HomeView: View {
    @State private var trending: [Anime] = []
    @State private var seasonal: [Anime] = []
    @State private var popular: [Anime] = []
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                if isLoading {
                    VStack(spacing: 24) {
                        ProgressView()
                            .tint(.orange)
                            .scaleEffect(1.5)
                            .padding(.top, 100)
                        Text("Loading...")
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    LazyVStack(spacing: 24) {
                        if let first = trending.first {
                            heroSection(first)
                        }
                        if !trending.isEmpty {
                            sectionHeader("Trending Now")
                            cardScroll(trending)
                        }
                        if !seasonal.isEmpty {
                            sectionHeader("Seasonal Hits")
                            cardScroll(seasonal)
                        }
                        if !popular.isEmpty {
                            sectionHeader("Most Popular")
                            cardScroll(popular)
                        }
                    }
                    .padding(.bottom, 24)
                }
            }
            .background(Color.black)
            .task { await loadData() }
        }
    }

    private func heroSection(_ anime: Anime) -> some View {
        NavigationLink(destination: AnimeDetailView(anime: anime)) {
            ZStack(alignment: .bottomLeading) {
                AsyncImage(url: URL(string: anime.coverImageLarge ?? "")) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    default:
                        Color(.systemGray5)
                    }
                }
                .frame(height: 300)
                .clipped()

                LinearGradient(
                    gradient: Gradient(colors: [.clear, .black.opacity(0.85)]),
                    startPoint: .top,
                    endPoint: .bottom
                )

                VStack(alignment: .leading, spacing: 8) {
                    Text("TRENDING #1")
                        .font(.caption2)
                        .fontWeight(.black)
                        .foregroundColor(.black)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.orange)
                        .clipShape(Capsule())
                    Text(anime.displayTitle)
                        .font(.title2)
                        .fontWeight(.black)
                        .foregroundColor(.white)
                        .lineLimit(2)
                    HStack(spacing: 12) {
                        if let score = anime.score {
                            Label(String(format: "%.1f", score), systemImage: "star.fill")
                                .foregroundColor(.yellow)
                                .font(.caption)
                                .fontWeight(.bold)
                        }
                        if let year = anime.year {
                            Text("\(year)")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                        }
                        if let eps = anime.episodes {
                            Text("\(eps) eps")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                }
                .padding()
            }
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
    }

    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.white)
            Spacer()
            Text("See All")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.orange)
        }
        .padding(.horizontal)
    }

    private func cardScroll(_ items: [Anime]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(items) { anime in
                    NavigationLink(destination: AnimeDetailView(anime: anime)) {
                        GlassCardView(anime: anime)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
    }

    private func loadData() async {
        isLoading = true
        async let t = AnimeService.shared.fetchTrending()
        async let s = AnimeService.shared.fetchSeasonal()
        async let p = AnimeService.shared.fetchPopular()
        let (trendingData, seasonalData, popularData) = await ((try? t) ?? [], (try? s) ?? [], (try? p) ?? [])
        trending = trendingData
        seasonal = seasonalData
        popular = popularData
        isLoading = false
    }
}

struct GlassCardView: View {
    let anime: Anime

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ZStack(alignment: .topLeading) {
                AsyncImage(url: URL(string: anime.coverImageLarge ?? anime.coverImageMedium ?? "")) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    default:
                        Color(.systemGray5)
                    }
                }
                .frame(width: 160, height: 225)
                .clipped()

                if let score = anime.score {
                    HStack(spacing: 2) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 8))
                            .foregroundColor(.yellow)
                        Text(String(format: "%.1f", score))
                            .font(.system(size: 9, weight: .black))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.black.opacity(0.7))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .padding(6)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Text(anime.displayTitle)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .lineLimit(2)
                .frame(width: 160, alignment: .leading)

            HStack(spacing: 4) {
                if let year = anime.year {
                    Text("\(year)")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                Spacer()
                if let eps = anime.episodes {
                    Text("\(eps) eps")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
            .frame(width: 160)
        }
    }
}
