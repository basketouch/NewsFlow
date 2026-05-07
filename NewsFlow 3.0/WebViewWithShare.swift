import SwiftUI
import WebKit

struct WebViewWithShare: UIViewRepresentable {
    let url: URL
    @Binding var showingCreatePost: Bool
    @Binding var webURLForPost: String?
    @Binding var webTitleForPost: String?
    
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.bounces = false
        
        // Configurar request con headers apropiados
        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        request.cachePolicy = .reloadIgnoringLocalCacheData
        
        webView.load(request)
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        // No se necesita actualización
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        let parent: WebViewWithShare
        
        init(_ parent: WebViewWithShare) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // Capturar la URL actual cuando la página termina de cargar
            parent.webURLForPost = webView.url?.absoluteString
            parent.webTitleForPost = webView.title ?? "Página web"
        }
    }
}

// MARK: - Vista combinada con botón flotante
struct WebViewWithFloatingButton: View {
    let url: URL
    @Binding var showingCreatePost: Bool
    @Binding var webURLForPost: String?
    @Binding var webTitleForPost: String?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            WebViewWithShare(
                url: url,
                showingCreatePost: $showingCreatePost,
                webURLForPost: $webURLForPost,
                webTitleForPost: $webTitleForPost
            )
            
            // Botón flotante para crear publicación
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 12) {
                        // Botón para crear publicación
                        Button(action: {
                            showingCreatePost = true
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                                Text("Crear Publicación")
                                    .font(.headline)
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 25)
                                    .fill(Color.blue)
                                    .shadow(radius: 4)
                            )
                        }
                        
                        // Botón para cerrar
                        Button(action: {
                            dismiss()
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                                .padding(12)
                                .background(
                                    Circle()
                                        .fill(Color.gray.opacity(0.8))
                                        .shadow(radius: 4)
                                )
                        }
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 100) // Evitar que se superponga con la barra de herramientas
                }
            }
        }
        .navigationBarHidden(true)
    }
}

// MARK: - Vista de Safari mejorada con más opciones
struct EnhancedSafariView: View {
    let url: URL
    @Binding var showingCreatePost: Bool
    @Binding var webURLForPost: String?
    @Binding var webTitleForPost: String?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            SafariView(
                url: url,
                showingCreatePost: $showingCreatePost,
                webURLForPost: $webURLForPost,
                webTitleForPost: $webTitleForPost
            )
            .navigationBarHidden(true)
            .overlay(
                // Botón flotante
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: {
                            webURLForPost = url.absoluteString
                            webTitleForPost = "Tendencia de Google Trends"
                            showingCreatePost = true
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                                Text("Crear Publicación")
                                    .font(.headline)
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 25)
                                    .fill(Color.blue)
                                    .shadow(radius: 4)
                            )
                        }
                        .padding(.trailing, 20)
                        .padding(.bottom, 100)
                    }
                }
            )
        }
    }
} 