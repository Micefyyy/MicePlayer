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

                    if !results.isEmpty && hasSearched {
                        resultsGrid
                    } else if hasSearched {
                        noResultsView
                    }

                    if !hasSearched {
                        categoryPicker
                        categoryGrid
                    }
                }
                .padding(.horizontal)
            }
            .background(Color(.systemBackground))
            .navigationTitle("Discover")
            .task { await loadCategories() }
        }
    }

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField("Search anime...", text: $searchQuery)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
                .onSubmit { performSearch() }
            if !searchQuery.isEmpty {
                Button { searchQuery = ""; results = []; hasSearched = false }
                    label: { Image(systemName: "xmark.circle.fill").foregroundColor(.secondary) }
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var resultsGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 12)], spacing: 12) {
            ForEach(results) { anime in
                NavigationLink(destination: AnimeDetailView(anime: anime)) {
                    AnimeCardView(anime: anime)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var noResultsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            Text("No results found")
                .font(.headline)
                .foregroundColor(.secondary)
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
                        .foregroundColor(category == cat ? .white : .secondary)
                }
            }
        }
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var categoryGrid: some View {
        Group {
            if catLoading {
                ProgressView().padding(.top, 40)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 12)], spacing: 12) {
                    if let items = categoryData[category] {
                        ForEach(items.prefix(12)) { anime in
                            NavigationLink(destination: AnimeDetailView(anime: anime)) {
                                AnimeCardView(anime: anime)
                            }
                            .buttonStyle(.plain)
                        }
                    }
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
        let (trending, seasonal) = await ((try? t) ?? [], (try? s) ?? [])
        categoryData = [.trending: trending, .seasonal: seasonal, .topRated: []]
        catLoading = false
    }
}
