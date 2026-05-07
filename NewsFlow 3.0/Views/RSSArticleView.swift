import SwiftUI

struct RSSArticleRow: View {
    let article: RSSArticle
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(article.normalizedTitle)
                .font(.headline)
                .lineLimit(2)
                .foregroundColor(.primary)
            
            if let description = article.description {
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            HStack {
                Text(article.pubDate.formattedString())
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct RSSArticleDetailView: View {
    let article: RSSArticle
    @State private var showSafari = false
    @State private var showingCreatePost = false
    @State private var webURLForPost: String? = nil
    @State private var webTitleForPost: String? = nil
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Imagen superior si está disponible
                if let imageUrl = article.imageUrl ?? article.extractImageFromContent() {
                    AsyncImage(url: imageUrl) { phase in
                        switch phase {
                        case .empty:
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 200)
                                .overlay(ProgressView())
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 200)
                                .clipped()
                        case .failure:
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 200)
                                .overlay(
                                    Image(systemName: "photo")
                                        .foregroundColor(.gray)
                                )
                        @unknown default:
                            EmptyView()
                        }
                    }
                }
                
                // Título principal
                Text(article.normalizedTitle)
                    .font(.system(size: 32, weight: .bold))
                    .padding(.horizontal)
                
                // Metadatos en una línea
                HStack {
                    Text("Medios de USA")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(article.pubDate.formattedString())
                        .foregroundColor(.secondary)
                }
                .font(.subheadline)
                .padding(.horizontal)
                
                // Contenido principal
                Text(article.mainContent)
                    .font(.body)
                    .lineSpacing(8)
                    .padding(.horizontal)
                    .padding(.top, 8)
                
                // Barra de acciones
                HStack(spacing: 30) {
                    // Icono de redes sociales (inactivo)
                    Image(systemName: "person.2")
                        .font(.system(size: 20))
                        .foregroundColor(.gray)
                    
                    // Icono de Newsletter (inactivo)
                    Image(systemName: "envelope.badge")
                        .font(.system(size: 20))
                        .foregroundColor(.gray)
                    
                    // Botón para ver en navegador (activo)
                    Button(action: {
                        showSafari = true
                    }) {
                        Image(systemName: "safari")
                            .font(.system(size: 20))
                            .foregroundColor(.blue)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("NewsFlow")
        .sheet(isPresented: $showSafari) {
            SafariView(
                url: article.link,
                showingCreatePost: $showingCreatePost,
                webURLForPost: $webURLForPost,
                webTitleForPost: $webTitleForPost
            )
            .edgesIgnoringSafeArea(.all)
        }
    }
}

// Vista previa para desarrollo
struct RSSArticleRow_Previews: PreviewProvider {
    static var previews: some View {
        let sampleArticle = RSSArticle(
            title: "Este es un título de ejemplo para RSS",
            link: URL(string: "https://ejemplo.com")!,
            pubDate: Date(),
            description: "Esta es una descripción de ejemplo para el artículo RSS que muestra cómo se verá el contenido en la aplicación.",
            content: "Este es el contenido completo del artículo RSS. Puede contener múltiples párrafos y formato básico como saltos de línea y listas."
        )
        
        return Group {
            RSSArticleRow(article: sampleArticle)
                .previewLayout(.sizeThatFits)
                .padding()
            
            RSSArticleDetailView(article: sampleArticle)
                .previewLayout(.sizeThatFits)
        }
    }
} 