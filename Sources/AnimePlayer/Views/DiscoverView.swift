import SwiftUI

struct DiscoverView: View {
    @State private var searchQuery = ""
    @State private var results: [Anime] = []
    @State private var isLoading = false
    @State private var hasSearched = false
    @State private var category: Category = .seasonal
    @State private var categoryData: [Category: [Anime]] = [:]
    @State private var catLoading = true

    private let accent = Color(hex: "b5a8ff")
    private let bg = Color(hex: "0a0a0a")
    private let muted = Color(hex: "606060")
    private let textColor = Color(hex: "e0e0e0")
    private let borderColor = Color.white.opacity(0.08)

    enum Category: String, CaseIterable {
        case seasonal = "Seasonal"
        case trending = "Trending"
        case topRated = "Top Rated"
    }

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 16) {
                    searchBar
                    if hasSearched {
                        if results.isEmpty && !isLoading {
                            noResultsView
                        } else {
                            resultsGrid
                        }
                    } else {
                        categoryPicker
                        if catLoading {
                            ProgressView().tint(accent).padding(.top, 40)
                        } else {
                            categoryGrid
                        }
                    }
                }
                .padding(.horizontal, 10)
            }
            .background(bg)
            .navigationBarHidden(true)
            .task { await loadCategories() }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundColor(muted)
            TextField("Search anime...", text: $searchQuery)
                .font(.system(size: 14))
                .autocorrectionDisabled()
                .foregroundColor(textColor)
                .onSubmit { performSearch() }
            if !searchQuery.isEmpty {
                Button {
                    searchQuery = ""
                    results = []
                    hasSearched = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(muted)
                }
            }
        }
        .padding(10)
        .background(Color(hex: "131313"))
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(borderColor))
    }

    private var resultsGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 14) {
            ForEach(results) { anime in
                NavigationLink(destination: AnimeDetailView(anime: anime)) {
                    CardView(anime: anime, accent: accent, muted: muted, cardBg: Color(hex: "131313"), textColor: textColor, borderColor: borderColor)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var noResultsView: some View {
        VStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 36))
                .foregroundColor(muted)
            Text("No results found")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(muted)
            Text("Try a different search term")
                .font(.system(size: 13))
                .foregroundColor(muted.opacity(0.6))
        }
        .padding(.top, 60)
    }

    private var categoryPicker: some View {
        HStack(spacing: 0) {
            ForEach(Category.allCases, id: \.self) { cat in
                Button {
                    category = cat
                } label: {
                    Text(cat.rawValue)
                        .font(.system(size: 13, weight: .medium))
                        .padding(.vertical, 9)
                        .frame(maxWidth: .infinity)
                        .background(category == cat ? accent : Color.clear)
                        .foregroundColor(category == cat ? .white : muted)
                }
            }
        }
        .background(Color(hex: "131313"))
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(borderColor))
    }

    private var categoryGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 14) {
            if let items = categoryData[category] {
                ForEach(items.prefix(18)) { anime in
                    NavigationLink(destination: AnimeDetailView(anime: anime)) {
                        CardView(anime: anime, accent: accent, muted: muted, cardBg: Color(hex: "131313"), textColor: textColor, borderColor: borderColor)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func performSearch() {
        guard !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isLoading = true
        hasSearched = true
        Task {
            results = (try? await AnimeService.shared.searchAnime(query: searchQuery)) ?? []
            isLoading = false
        }
    }

    private func loadCategories() async {
        catLoading = true
        async let t = AnimeService.shared.fetchTrending()
        async let s = AnimeService.shared.fetchSeasonal()
        async let p = AnimeService.shared.fetchPopular()
        let (trending, seasonal, popular) = await ((try? t) ?? [], (try? s) ?? [], (try? p) ?? [])
        categoryData = [.trending: trending, .seasonal: seasonal, .topRated: popular]
        catLoading = false
    }
}
