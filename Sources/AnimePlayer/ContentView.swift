import SwiftUI
import WebKit
import AVFoundation

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6: (a, r, g, b) = (255, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = ((int >> 24) & 0xFF, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
}

struct ContentView: View {
    @State private var showDownloads = false

    var body: some View {
        ZStack {
            Color(hex: "0A0A0C").ignoresSafeArea()
            WebView(url: URL(string: "https://miceplayer.onrender.com/web/")!)
        }
        .ignoresSafeArea()
        .preferredColorScheme(.dark)
        .overlay(alignment: .bottomTrailing) {
            Button {
                showDownloads = true
            } label: {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(Color(hex: "14552D"))
                    .background(Circle().fill(Color(hex: "0A0A0C")).frame(width: 36, height: 36))
                    .shadow(color: .black.opacity(0.4), radius: 4)
            }
            .padding(.trailing, 16)
            .padding(.bottom, 20)
        }
        .sheet(isPresented: $showDownloads) {
            DownloadsView()
        }
        .onAppear {
            try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
        }
    }
}

struct WebView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> WebViewContainer {
        let container = WebViewContainer()
        container.load(url: url)
        return container
    }

    func updateUIViewController(_ uiViewController: WebViewContainer, context: Context) {}
}

class WebViewContainer: UIViewController {
    private var webView: WKWebView?
    private var url: URL?

    func load(url: URL) {
        self.url = url
        if isViewLoaded { startLoad() }
    }

    private func startLoad() {
        guard let url = url else { return }
        webView?.load(URLRequest(url: url))
    }

    override func loadView() {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        let contentController = WKUserContentController()
        contentController.add(MessageHandler(), name: "micePlayer")
        let fsScript = WKUserScript(source: """
        if (HTMLVideoElement.prototype.webkitEnterFullscreen) {
            HTMLVideoElement.prototype.requestFullscreen = function() {
                this.webkitEnterFullscreen();
                return Promise.resolve();
            };
        }
        """, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
        contentController.addUserScript(fsScript)
        config.userContentController = contentController

        let wv = WKWebView(frame: .zero, configuration: config)
        wv.translatesAutoresizingMaskIntoConstraints = false
        wv.isOpaque = false
        wv.backgroundColor = UIColor(red: 10/255, green: 10/255, blue: 12/255, alpha: 1)
        wv.scrollView.contentInsetAdjustmentBehavior = .never
        wv.scrollView.bounces = false
        webView = wv

        view = UIView()
        view.addSubview(wv)
        NSLayoutConstraint.activate([
            wv.topAnchor.constraint(equalTo: view.topAnchor),
            wv.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            wv.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            wv.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        startLoad()
    }
}

class MessageHandler: NSObject, WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "micePlayer" {
            print("JS message:", message.body)
        }
    }
}
