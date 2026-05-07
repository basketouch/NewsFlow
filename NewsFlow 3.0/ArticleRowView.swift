import SwiftUI

struct ArticleRowView: View {
    let article: NewsArticle
    @EnvironmentObject var viewModel: ArticlesViewModel
    
    // Propiedad computada para el estado actual de favorito
    private var isFavorite: Bool {
        // Busca el artículo actual en la lista de artículos del viewModel para obtener su estado actual
        if let existingArticle = viewModel.articles.first(where: { $0.id == article.id }) {
            return existingArticle.isFavorite
        } else if let existingArticle = viewModel.articles.first(where: { $0.url == article.url }) {
            return existingArticle.isFavorite
        }
        return article.isFavorite
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Título del artículo
            Text(article.title)
                .font(.headline)
                .lineLimit(1)
            
            // Descripción del artículo (limitada a 3 líneas)
            Text(article.description)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(3)
            
            HStack {
                // Fuente del artículo
                Text(article.source)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                // Tiempo transcurrido
                Text(article.publishedDate.timeAgo())
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                // Indicador de favorito (solo si es favorito)
                if isFavorite {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                        .font(.caption)
                }
            }
        }
        .padding(10)
        .background(article.isRead ? Color.defaultSecondary : Color.defaultBackground)
        .cornerRadius(8)
        .shadow(radius: 1)
    }
}

#Preview {
    ArticleRowView(article: NewsArticle.mockArticles()[0])
        .environmentObject(ArticlesViewModel())
        .frame(maxWidth: .infinity)
        .padding()
} 