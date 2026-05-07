import SwiftUI
import WebKit

struct NewsletterPreviewView: View {
    let html: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            NewsletterWebView(html: html)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle("Vista previa")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cerrar") { dismiss() }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        ShareLink(item: html, subject: Text("Newsletter INSIDE Life")) {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
        }
    }
}

// MARK: - WKWebView wrapper

struct NewsletterWebView: UIViewRepresentable {
    let html: String

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        webView.loadHTMLString(html, baseURL: URL(string: NewsletterConfig.siteURL))
    }
}
