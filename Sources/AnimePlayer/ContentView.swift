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
        GeometryReader { geo in
            ZStack {
                Color(hex: "0A0A0C")
                WebView(url: URL(string: "https://miceplayer.onrender.com/web/")!, frame: CGRect(origin: .zero, size: geo.size))
                    .allowsHitTesting(true)
            }
            .overlay(alignment: .bottomTrailing) {
                Button {
                    showDownloads = true
                } label: {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(Color(hex: "14552D"))
                        .shadow(color: .black.opacity(0.4), radius: 4)
                }
                .padding(.trailing, 16)
                .padding(.bottom, 20)
            }
        }
        .ignoresSafeArea()
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showDownloads) {
            DownloadsView()
        }
        .onAppear {
            try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
        }
    }
}

struct WebView: UIViewRepresentable {
    let url: URL
    let frame: CGRect

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        let contentController = WKUserContentController()
        contentController.add(context.coordinator, name: "micePlayer")
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

        let webView = WKWebView(frame: frame, configuration: config)
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        webView.isOpaque = false
        webView.backgroundColor = UIColor(red: 10/255, green: 10/255, blue: 12/255, alpha: 1)
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.scrollView.bounces = false
        webView.scrollView.contentInset = .zero
        webView.scrollView.scrollIndicatorInsets = .zero
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        if webView.frame != frame {
            webView.frame = frame
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, WKScriptMessageHandler {
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "micePlayer" {
                print("JS message:", message.body)
            }
        }
    }
}
