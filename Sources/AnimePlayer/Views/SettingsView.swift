import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var preferences: Preferences

    var body: some View {
        NavigationStack {
            Form {
                Section("Playback") {
                    Picker("Preferred Quality", selection: $preferences.preferredQuality) {
                        Text("1080p").tag("1080p")
                        Text("720p").tag("720p")
                        Text("480p").tag("480p")
                        Text("360p").tag("360p")
                    }

                    Picker("Streaming Source", selection: $preferences.preferredSource) {
                        Text("Gogoanime").tag("gogoanime")
                        Text("Zoro").tag("zoro")
                        Text("9anime").tag("9anime")
                    }

                    Toggle("Auto-play next episode", isOn: $preferences.autoPlay)
                }

                Section("Appearance") {
                    Toggle("Dark mode", isOn: $preferences.darkMode)
                }

                Section("Audio") {
                    Toggle("English Dub", isOn: $preferences.showDub)
                }

                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}
