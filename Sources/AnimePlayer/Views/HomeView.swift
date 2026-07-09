import SwiftUI

struct HomeView: View {
    @State private var trending: [Anime] = []
    @State private var seasonal: [Anime] = []
    @State private var popular: [Anime] = []
    @State private var isLoading = true
    @State private var selectedSection = 0
    @State private var carouselIndex = 0

    private let accent = Color(hex: "b5a8ff")
    private let bg = Color(hex: "0a0a0a")
    private let cardBg = Color(hex: "131313")
    private let textColor = Color(hex: "e0e0e0")
    private let muted = Color(hex: "606060")
    private let borderColor = Color.white.opacity(0.08)

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                if isLoading {
                    VStack(spacing: 16) {
                        ProgressView().tint(accent).scaleEffect(1.5).padding(.top, 120)
                        Text("Loading...").foregroundColor(muted).font(.system(size: 14))
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    VStack(spacing: 0) {
                        if !trending.isEmpty {
                            carousel
                        }
                        sectionTabs
                        cardGrid
                    }
                }
            }
            .background(bg)
            .navigationBarHidden(true)
            .task { await loadData() }
        }
    }

    private var carousel: some View {
        TabView(selection: $carouselIndex) {
            ForEach(Array(trending.prefix(6).enumerated()), id: \.element.id) { i, anime in
                NavigationLink(destination: AnimeDetailView(anime: anime)) {
                    ZStack(alignment: .bottomLeading) {
                        AsyncImage(url: URL(string: anime.coverImageLarge ?? anime.coverImageMedium ?? "")) { phase in
                            if let image = phase.image {
                                image.resizable().aspectRatio(contentMode: .fill)
                            } else {
                                Color(hex: "131313")
                            }
                        }
                        .frame(height: 280)
                        .clipped()

                        LinearGradient(colors: [bg, .clear, bg], startPoint: .top, endPoint: .bottom)
                            .frame(height: 280)

                        VStack(alignment: .leading, spacing: 6) {
                            Text(anime.displayTitle)
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(textColor)
                                .shadow(color: .black.opacity(0.5), radius: 4)
                                .lineLimit(2)

                            if let desc = anime.synopsis {
                                Text(desc)
                                    .font(.system(size: 13))
                                    .foregroundColor(Color(hex: "999"))
                                    .lineLimit(2)
                            }

                            if let genres = anime.genres, !genres.isEmpty {
                                HStack(spacing: 4) {
                                    ForEach(genres.prefix(3), id: \.self) { g in
                                        Text(g)
                                            .font(.system(size: 10, weight: .semibold))
                                            .foregroundColor(textColor)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 3)
                                            .background(Color.black.opacity(0.4))
                                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(borderColor))
                                            .cornerRadius(12)
                                    }
                                }
                            }

                            HStack(spacing: 10) {
                                if let score = anime.score {
                                    HStack(spacing: 2) {
                                        Image(systemName: "star.fill").font(.system(size: 10)).foregroundColor(.yellow)
                                        Text(String(format: "%.1f", score)).font(.system(size: 12, weight: .bold)).foregroundColor(.yellow)
                                    }
                                }
                                if let year = anime.year {
                                    Text("\(year)").font(.system(size: 12)).foregroundColor(muted)
                                }
                                if let eps = anime.episodes {
                                    Text("\(eps) eps").font(.system(size: 12)).foregroundColor(muted)
                                }
                            }
                        }
                        .padding(16)
                    }
                }
                .buttonStyle(.plain)
                .tag(i)
            }
        }
        .frame(height: 280)
        .tabViewStyle(.page(indexDisplayMode: .always))
    }

    private var sectionTabs: some View {
        HStack {
            sectionTab("Trending", index: 0)
            sectionTab("Popular", index: 1)
            sectionTab("Top Rated", index: 2)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.top, 16)
        .padding(.bottom, 10)
    }

    private func sectionTab(_ title: String, index: Int) -> some View {
        Button {
            selectedSection = index
        } label: {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(selectedSection == index ? accent : muted)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(selectedSection == index ? accent.opacity(0.15) : Color.clear)
                .cornerRadius(6)
        }
    }

    private var cardGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 14) {
            let items = sectionItems
            ForEach(items) { anime in
                NavigationLink(destination: AnimeDetailView(anime: anime)) {
                    CardView(anime: anime, accent: accent, muted: muted, cardBg: cardBg, textColor: textColor, borderColor: borderColor)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 24)
    }

    private var sectionItems: [Anime] {
        switch selectedSection {
        case 0: trending
        case 1: popular
        case 2: seasonal
        default: trending
        }
    }

    private func loadData() async {
        isLoading = true
        async let t = AnimeService.shared.fetchTrending()
        async let s = AnimeService.shared.fetchSeasonal()
        async let p = AnimeService.shared.fetchPopular()
        let (td, sd, pd) = await ((try? t) ?? [], (try? s) ?? [], (try? p) ?? [])
        trending = td
        seasonal = sd
        popular = pd
        isLoading = false
    }
}

struct CardView: View {
    let anime: Anime
    let accent: Color
    let muted: Color
    let cardBg: Color
    let textColor: Color
    let borderColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topLeading) {
                AsyncImage(url: URL(string: anime.coverImageLarge ?? anime.coverImageMedium ?? "")) { phase in
                    if let image = phase.image {
                        image.resizable().aspectRatio(contentMode: .fill)
                    } else {
                        cardBg
                    }
                }
                .aspectRatio(2/3, contentMode: .fill)
                .clipped()

                if let score = anime.score {
                    HStack(spacing: 2) {
                        Image(systemName: "star.fill").font(.system(size: 8)).foregroundColor(.yellow)
                        Text(String(format: "%.1f", score)).font(.system(size: 9, weight: .bold)).foregroundColor(.white)
                    }
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(4)
                    .padding(5)
                }
            }
            .cornerRadius(8)

            VStack(alignment: .leading, spacing: 2) {
                Text(anime.displayTitle)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(textColor)
                    .lineLimit(2)

                HStack(spacing: 4) {
                    if let year = anime.year {
                        Text("\(year)").font(.system(size: 11)).foregroundColor(muted)
                    }
                    if let eps = anime.episodes {
                        Text("\(eps) eps").font(.system(size: 11)).foregroundColor(muted)
                    }
                }
            }
            .padding(.top, 6)
            .padding(.horizontal, 2)
        }
    }
}
