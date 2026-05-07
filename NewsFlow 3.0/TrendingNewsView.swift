import SwiftUI
import SafariServices

struct TrendingNewsView: View {
    @State private var showingSafari = false
    @State private var showingCreatePost = false
    @State private var webURLForPost: String? = nil
    @State private var webTitleForPost: String? = nil
    @State private var customURL: String = ""
    @State private var customTitle: String = ""

    @StateObject private var socialPostsViewModel = SocialPostsViewModel.shared
    
    private let googleTrendsURL = URL(string: "https://trends.google.es/trending?geo=ES")!
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header con subtítulo
                VStack(spacing: 8) {
                    Text("Tendencias")
                        .font(.largeTitle)
                        .bold()
                    
                    Text("Google Trends")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top)
                
                Spacer()
                
                // Contenido principal
                VStack(spacing: 20) {
                    // Icono principal
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 50))
                        .foregroundColor(.blue)
                    
                    // Botón principal
                    Button(action: {
                        showingSafari = true
                    }) {
                        HStack {
                            Image(systemName: "globe")
                            Text("Abrir Google Trends")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    
                    // Campos de entrada
                    VStack(spacing: 16) {
                        TextField("URL de la noticia", text: $customURL)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                        
                        TextField("Título de la noticia", text: $customTitle)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        // Botón Usar para publicación
                        Button(action: {
                            if !customURL.isEmpty {
                                webURLForPost = customURL
                                webTitleForPost = customTitle.isEmpty ? "Noticia Web" : customTitle
                                showingCreatePost = true
                            }
                        }) {
                            HStack {
                                Image(systemName: "square.and.pencil")
                                Text("Usar para publicación")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(customURL.isEmpty ? Color.gray : Color.blue)
                            .cornerRadius(12)
                        }
                        .disabled(customURL.isEmpty)
                        
                        // Botón Usar para Newsletter
                        Button(action: {
                            // TODO: Implementar funcionalidad de newsletter
                            print("Usar para Newsletter - URL: \(customURL), Título: \(customTitle)")
                        }) {
                            HStack {
                                Image(systemName: "envelope.fill")
                                Text("Usar para Newsletter")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(customURL.isEmpty ? Color.gray : Color.green)
                            .cornerRadius(12)
                        }
                        .disabled(customURL.isEmpty)
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
                
                // Información básica
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Tendencias en tiempo real")
                    }
                    
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.blue)
                        Text("Crear publicaciones desde cualquier web")
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                .padding(.horizontal)
                
                Spacer()
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showingSafari) {
                SafariView(
                    url: googleTrendsURL,
                    showingCreatePost: $showingCreatePost,
                    webURLForPost: $webURLForPost,
                    webTitleForPost: $webTitleForPost
                )
            }
            .sheet(isPresented: $showingCreatePost) {
                if let webURL = webURLForPost, let webTitle = webTitleForPost {
                    NuevaPublicacionView(
                        viewModel: socialPostsViewModel,
                        textoInicial: prepararTendenciaParaPublicacion(url: webURL, title: webTitle),
                        tematicaSugerida: "Tecnología",
                        objetivoSugerido: "Interesante",
                        webURL: webURL,
                        webTitle: webTitle,
                        isFromWeb: true
                    )
                } else {
                    Text("Error al cargar la publicación")
                        .foregroundColor(.red)
                }
            }
            .onChange(of: showingCreatePost) { newValue in
                if newValue {
                    if let webURL = webURLForPost, let webTitle = webTitleForPost {
                        print("📝 Mostrando NuevaPublicacionView - URL: \(webURL)")
                    } else {
                        print("❌ Error: webURLForPost o webTitleForPost son nil")
                    }
                }
            }
        }
    }
    
    // MARK: - Función para preparar datos de tendencias (similar a RSS)
    private func prepararTendenciaParaPublicacion(url: String, title: String) -> String {
        return """
        📈 TENDENCIA DETECTADA: \(title)
        
        🔗 Fuente: \(url)
        📊 Origen: Google Trends
        📰 Tipo: Análisis de tendencias
        
        [Generar un post atractivo para redes sociales sobre esta tendencia, incluyendo insights relevantes, hashtags apropiados y un tono profesional pero accesible. Incluir al final: "🔗 Fuente: \(url)"]
        """
    }
}



// MARK: - Preview
#Preview {
    TrendingNewsView()
} 