import Foundation
import Combine

final class Preferences: ObservableObject {
    static let shared = Preferences()

    @Published var preferredQuality: String {
        didSet { UserDefaults.standard.set(preferredQuality, forKey: "preferredQuality") }
    }
    @Published var preferredSource: String {
        didSet { UserDefaults.standard.set(preferredSource, forKey: "preferredSource") }
    }
    @Published var darkMode: Bool {
        didSet { UserDefaults.standard.set(darkMode, forKey: "darkMode") }
    }
    @Published var autoPlay: Bool {
        didSet { UserDefaults.standard.set(autoPlay, forKey: "autoPlay") }
    }
    @Published var showDub: Bool {
        didSet { UserDefaults.standard.set(showDub, forKey: "showDub") }
    }

    private init() {
        let defaults = UserDefaults.standard
        self.preferredQuality = defaults.string(forKey: "preferredQuality") ?? "1080p"
        self.preferredSource = defaults.string(forKey: "preferredSource") ?? "gogoanime"
        self.darkMode = defaults.bool(forKey: "darkMode")
        self.autoPlay = defaults.bool(forKey: "autoPlay")
        self.showDub = defaults.bool(forKey: "showDub")
    }
}
