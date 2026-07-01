import SwiftUI

@main
struct AnimePlayerApp: App {
    @StateObject private var preferences = Preferences.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(preferences)
                .preferredColorScheme(preferences.darkMode ? .dark : nil)
        }
    }
}
