import SwiftUI

@main
struct MicePlayerApp: App {
    @StateObject private var preferences = Preferences.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(preferences)
        }
    }
}
