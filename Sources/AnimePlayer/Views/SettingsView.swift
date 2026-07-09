import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var preferences: Preferences

    private let accent = Color(hex: "b5a8ff")
    private let muted = Color(hex: "606060")
    private let textColor = Color(hex: "e0e0e0")
    private let borderColor = Color.white.opacity(0.08)

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 12) {
                    settingsSection("Playback") {
                        qualityRow
                        toggleRow("Auto-play next episode", isOn: $preferences.autoPlay)
                    }
                    settingsSection("Appearance") {
                        toggleRow("Dark mode", isOn: $preferences.darkMode)
                    }
                    settingsSection("Audio") {
                        toggleRow("English Dub", isOn: $preferences.showDub)
                    }
                    settingsSection("About") {
                        HStack {
                            Text("Version").font(.system(size: 14)).foregroundColor(textColor)
                            Spacer()
                            Text("1.0.0").font(.system(size: 14)).foregroundColor(muted)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .background(Color(hex: "0a0a0a"))
            .navigationBarHidden(true)
        }
    }

    private func settingsSection(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(muted)
                .padding(.horizontal, 4)
            VStack(spacing: 0) {
                content()
            }
            .padding(12)
            .background(Color(hex: "131313"))
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(borderColor))
        }
    }

    private var qualityRow: some View {
        HStack {
            Text("Preferred Quality").font(.system(size: 14)).foregroundColor(textColor)
            Spacer()
            Picker("", selection: $preferences.preferredQuality) {
                Text("1080p").tag("1080p")
                Text("720p").tag("720p")
                Text("480p").tag("480p")
                Text("360p").tag("360p")
            }
            .pickerStyle(.menu)
            .tint(accent)
        }
        .padding(.vertical, 4)
    }

    private func toggleRow(_ label: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Text(label).font(.system(size: 14)).foregroundColor(textColor)
            Spacer()
            Toggle("", isOn: isOn)
                .tint(accent)
                .labelsHidden()
        }
        .padding(.vertical, 4)
    }
}
