import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    @EnvironmentObject private var preferences: Preferences

    var body: some View {
        VStack(spacing: 0) {
            navbar
            tabContent
                .frame(maxHeight: .infinity)
        }
        .background(Color(hex: "0a0a0a"))
        .preferredColorScheme(preferences.darkMode ? .dark : nil)
    }

    private var navbar: some View {
        HStack(spacing: 0) {
            Button { selectedTab = 0 } label: {
                Text("Mice Player")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color(hex: "e0e0e0"))
            }

            navButton("Home", tab: 0)
            navButton("Discover", tab: 1)
            navButton("Library", tab: 2)

            Spacer()

            Button { selectedTab = 3 } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 16))
                    .foregroundColor(selectedTab == 3 ? Color(hex: "b5a8ff") : Color(hex: "606060"))
                    .frame(width: 32, height: 32)
                    .background(selectedTab == 3 ? Color(hex: "b5a8ff").opacity(0.15) : Color.clear)
                    .cornerRadius(6)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(hex: "0a0a0a").opacity(0.85))
        .background(Material.ultraThinMaterial)
        .overlay(Divider(), alignment: .bottom)
    }

    private func navButton(_ title: String, tab: Int) -> some View {
        Button { selectedTab = tab } label: {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(selectedTab == tab ? Color(hex: "b5a8ff") : Color(hex: "606060"))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(selectedTab == tab ? Color(hex: "b5a8ff").opacity(0.15) : Color.clear)
                .cornerRadius(6)
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case 0: HomeView()
        case 1: DiscoverView()
        case 2: LibraryView()
        case 3: SettingsView()
        default: HomeView()
        }
    }
}
