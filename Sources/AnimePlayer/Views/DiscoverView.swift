import SwiftUI

struct DiscoverView: View {
    @State private var searchQuery = ""
    @State private var results: [Anime] = []
    @State private var isLoading = false
    @State private var hasSearched = false
    @State private var category: Category = .seasonal
    @State private var categoryData: [Category: [Anime]] = [:]
    @State private var catLoading = true

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
                            ProgressView()
                                .tint(.orange)
                                .padding(.top, 40)
                        } else {
                            categoryGrid
                        }
                    }
                }
                .padding(.horizontal)
            }
            .background(Color.black)
            .navigationTitle("Discover")
            .task { await loadCategories() }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            TextField("Search anime...", text: $searchQuery)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
                .foregroundColor(.white)
                .onSubmit { performSearch() }
            if !searchQuery.isEmpty {
                Button {
                    searchQuery = ""
                    results = []
                    hasSearched = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var resultsGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 12)], spacing: 12) {
            ForEach(results) { anime in
                NavigationLink(destination: AnimeDetailView(anime: anime)) {
                    GlassCardView(anime: anime)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var noResultsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundColor(.gray)
            Text("No results found")
                .font(.headline)
                .foregroundColor(.gray)
            Text("Try a different search term")
                .font(.caption)
                .foregroundColor(.gray.opacity(0.6))
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
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .background(category == cat ? Color.orange : Color.clear)
                        .foregroundColor(category == cat ? .black : .gray)
                }
            }
        }
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var categoryGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 12)], spacing: 12) {
            if let items = categoryData[category] {
                ForEach(items.prefix(12)) { anime in
                    NavigationLink(destination: AnimeDetailView(anime: anime)) {
                        GlassCardView(anime: anime)
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
