import SwiftUI

struct ArticleDetailView: View {
    let article: NewsArticle
    @EnvironmentObject var viewModel: ArticlesViewModel
    @StateObject private var savedVM = SupabaseArticlesViewModel.shared
    @State private var showSafari = false
    @State private var showShareSheet = false
    @State private var showingNewPost = false
    @State private var showingCreatePost = false
    @State private var webURLForPost: String? = nil
    @State private var webTitleForPost: String? = nil
    @State private var showSaveConfirm = false
    @State private var saveMessage: String? = nil
    @Environment(\.dismiss) private var dismiss

    private var alreadySaved: Bool {
        savedVM.isSaved(url: article.url.absoluteString)
    }
    
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
    
    // Variable computada para verificar si el contenido y la descripción son similares
    private var isContentSimilarToDescription: Bool {
        guard let content = article.content else { return false }
        
        // Si el contenido incluye la descripción o viceversa, o son idénticos
        let cleanContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanDescription = article.description.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return cleanContent == cleanDescription || 
               cleanContent.contains(cleanDescription) || 
               cleanDescription.contains(cleanContent)
    }
    
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                // Contenido
                VStack(alignment: .leading, spacing: 12) {
                    // Título
                    Text(article.title)
                        .font(.title)
                        .fontWeight(.bold)
                    
                    // Metadatos (fuente, fecha)
                    HStack {
                        Text(article.source)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text(article.publishedDate.formattedString())
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    // Categoría
                    if let category = article.category {
                        Text(category)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.2))
                            .foregroundColor(.blue)
                            .cornerRadius(4)
                    }
                    
                    Divider()
                    
                    // Mostrar descripción solo si es diferente del contenido
                    if !isContentSimilarToDescription {
                        Text(article.description)
                            .font(.headline)
                            .padding(.vertical, 4)
                    }
                    
                    // Contenido
                    if let content = article.content {
                        Text(content)
                            .font(.body)
                            .lineSpacing(6)
                    } else {
                        // Si no hay contenido, mostrar al menos la descripción
                        Text(article.description)
                            .font(.body)
                            .lineSpacing(6)
                    }
                    
                    Spacer(minLength: 20)
                    
                    // Botones de acción reorganizados
                    VStack(spacing: 16) {
                        // Primera fila: Favorito, Navegador, Compartir
                        HStack(spacing: 12) {
                            // Botón de favoritos
                            Button(action: {
                                viewModel.toggleFavorite(for: article)
                            }) {
                                VStack(spacing: 8) {
                                    Image(systemName: isFavorite ? "star.fill" : "star")
                                        .font(.title2)
                                        .foregroundColor(isFavorite ? .yellow : .primary)
                                    Text(isFavorite ? "Quitar" : "Favorito")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color(.systemGray6))
                                .foregroundColor(.primary)
                                .cornerRadius(10)
                            }
                            
                            // Botón de navegador
                            Button(action: {
                                showSafari = true
                            }) {
                                VStack(spacing: 8) {
                                    Image(systemName: "safari")
                                        .font(.title2)
                                        .foregroundColor(.blue)
                                    Text("Navegador")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color(.systemGray6))
                                .foregroundColor(.primary)
                                .cornerRadius(10)
                            }
                            
                            // Botón de compartir
                            Button(action: {
                                showShareSheet = true
                            }) {
                                VStack(spacing: 8) {
                                    Image(systemName: "square.and.arrow.up")
                                        .font(.title2)
                                        .foregroundColor(.green)
                                    Text("Compartir")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color(.systemGray6))
                                .foregroundColor(.primary)
                                .cornerRadius(10)
                            }
                        }
                        
                        // Segunda fila: Usar para publicación (centrado)
                        Button(action: {
                            showingNewPost = true
                        }) {
                            HStack {
                                Image(systemName: "square.and.pencil")
                                    .font(.title2)
                                Text("Usar para publicación")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        
                        // Tercera fila: Guardar en NewsFlow
                        Button {
                            Task {
                                let ok = await savedVM.save(rssArticle: article)
                                saveMessage = ok ? "✅ Guardado y añadido al Newsletter" : (savedVM.error ?? "Error al guardar")
                                showSaveConfirm = true
                            }
                        } label: {
                            HStack {
                                Image(systemName: alreadySaved ? "tray.fill" : "tray.and.arrow.down")
                                    .font(.title2)
                                Text(alreadySaved ? "Ya guardado" : "Guardar en NewsFlow")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(alreadySaved ? Color(.systemGray4) : Color.green)
                            .foregroundColor(alreadySaved ? .secondary : .white)
                            .cornerRadius(12)
                        }
                        .disabled(alreadySaved || savedVM.isLoading)
                    }
                    .padding(.top, 8)
                }
                .padding()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 4) {
                    // Guardar en NewsFlow (Supabase)
                    Button {
                        Task {
                            let ok = await savedVM.save(rssArticle: article)
                            saveMessage = ok ? "✅ Guardado y añadido al Newsletter" : (savedVM.error ?? "Error al guardar")
                            showSaveConfirm = true
                        }
                    } label: {
                        if savedVM.isLoading {
                            ProgressView().scaleEffect(0.7)
                        } else {
                            Image(systemName: alreadySaved ? "tray.fill" : "tray.and.arrow.down")
                                .foregroundColor(alreadySaved ? .green : .primary)
                        }
                    }
                    .disabled(alreadySaved || savedVM.isLoading)

                    // Favorito RSS
                    Button {
                        viewModel.toggleFavorite(for: article)
                    } label: {
                        Image(systemName: isFavorite ? "star.fill" : "star")
                            .foregroundColor(isFavorite ? .yellow : .gray)
                    }
                }
            }
        }
        .alert(saveMessage ?? "", isPresented: $showSaveConfirm) {
            Button("OK", role: .cancel) { saveMessage = nil }
        }
        .sheet(isPresented: $showSafari) {
            SafariView(
                url: article.url,
                showingCreatePost: $showingCreatePost,
                webURLForPost: $webURLForPost,
                webTitleForPost: $webTitleForPost
            )
            .edgesIgnoringSafeArea(.all)
        }
        .sheet(isPresented: $showShareSheet) {
            ActivityViewController(activityItems: [article.url])
        }
        .sheet(isPresented: $showingNewPost) {
            // Preparar datos para la nueva publicación
            let (textoInicial, tematicaSugerida) = viewModel.prepararNoticiaParaPublicacion(article)
            let objetivoSugerido = viewModel.obtenerObjetivoSugerido(article)
            
            NuevaPublicacionView(
                viewModel: SocialPostsViewModel.shared,
                textoInicial: textoInicial,
                tematicaSugerida: tematicaSugerida,
                objetivoSugerido: objetivoSugerido
            )
        }
        .onChange(of: showingNewPost) { newValue in
            if newValue {
                // Cerrar otros sheets antes de mostrar la vista de creación
                showSafari = false
                showShareSheet = false
            }
        }
        .onAppear {
            viewModel.markAsRead(article)
        }
    }
}

// Helper para compartir contenido
struct ActivityViewController: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: applicationActivities
        )
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    NavigationView {
        ArticleDetailView(
            article: NewsArticle.mockArticles()[0]
        )
        .environmentObject(ArticlesViewModel())
    }
} 
