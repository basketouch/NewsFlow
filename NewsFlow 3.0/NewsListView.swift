import SwiftUI

// MARK: - Vista principal de Noticias

struct NewsListView: View {
    @EnvironmentObject var viewModel: ArticlesViewModel
    @StateObject private var savedVM = SupabaseArticlesViewModel.shared
    @StateObject private var nlVM    = NewsletterViewModel.shared

    @State private var searchText     = ""
    @State private var rssExpanded    = true
    @State private var n8nExpanded    = true
    @State private var urlExpanded    = true
    @State private var showAddURL     = false
    @State private var showArchivo    = false
    @State private var selectedSource: String? = nil

    // MARK: Filtros

    var rssSources: [String] {
        Array(Set(viewModel.filteredArticles.map { $0.source })).sorted()
    }

    var rssFiltered: [NewsArticle] {
        var all = viewModel.filteredArticles
        if let source = selectedSource {
            all = all.filter { $0.source == source }
        }
        guard !searchText.isEmpty else { return all }
        return all.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.description.localizedCaseInsensitiveContains(searchText) ||
            $0.source.localizedCaseInsensitiveContains(searchText)
        }
    }

    var n8nFiltered: [SupabaseArticle] {
        let all = savedVM.savedArticles.filter { $0.sourceType == "gmail" }
        guard !searchText.isEmpty else { return all }
        return all.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.description.localizedCaseInsensitiveContains(searchText) ||
            $0.sourceName.localizedCaseInsensitiveContains(searchText)
        }
    }

    var urlFiltered: [SupabaseArticle] {
        let all = savedVM.savedArticles.filter { $0.sourceType == "url" }
        guard !searchText.isEmpty else { return all }
        return all.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.sourceName.localizedCaseInsensitiveContains(searchText)
        }
    }

    // MARK: Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Búsqueda
                HStack {
                    Image(systemName: "magnifyingglass").foregroundColor(.gray)
                    TextField("Buscar noticias...", text: $searchText).autocorrectionDisabled()
                    if !searchText.isEmpty {
                        Button { searchText = "" } label: {
                            Image(systemName: "xmark.circle.fill").foregroundColor(.gray)
                        }
                    }
                }
                .padding(8)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 4)

                // Banner de estado n8n
                if nlVM.n8nStatus.isActive {
                    HStack(spacing: 10) {
                        if case .processing = nlVM.n8nStatus {
                            ProgressView().scaleEffect(0.75)
                        } else if case .connecting = nlVM.n8nStatus {
                            ProgressView().scaleEffect(0.75)
                        }
                        Text(nlVM.n8nStatus.message)
                            .font(.caption.weight(.medium))
                            .foregroundColor(nlVM.n8nStatus.color)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(nlVM.n8nStatus.color.opacity(0.08))
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                if viewModel.isLoading && viewModel.articles.isEmpty {
                    Spacer()
                    ProgressView("Cargando RSS...").padding()
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 0) {

                            // MARK: Sección RSS
                            CollapsibleSectionHeader(
                                title: "RSS",
                                icon: "dot.radiowaves.up.forward",
                                count: rssFiltered.count,
                                selected: 0,
                                isExpanded: $rssExpanded
                            )
                            if rssExpanded {
                                // Chips de fuente
                                if !rssSources.isEmpty {
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 8) {
                                            SourceChip(title: "Todas", isSelected: selectedSource == nil, color: .gray) {
                                                selectedSource = nil
                                            }
                                            ForEach(rssSources, id: \.self) { source in
                                                SourceChip(
                                                    title: source,
                                                    isSelected: selectedSource == source,
                                                    color: colorForFeed(source)
                                                ) {
                                                    selectedSource = selectedSource == source ? nil : source
                                                }
                                            }
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                    }
                                }

                                if rssFiltered.isEmpty {
                                    sectionEmpty(icon: "newspaper", text: "Sin noticias RSS", sub: "Pulsa ↺ para recargar")
                                } else {
                                    ForEach(rssFiltered) { article in
                                        let inSystem = savedVM.isInSystem(url: article.url.absoluteString)
                                        HStack(spacing: 0) {
                                            NavigationLink {
                                                RSSNoticiaDetailView(article: article, savedVM: savedVM)
                                                    .environmentObject(viewModel)
                                            } label: {
                                                NoticiaRSSRow(article: article, isInSystem: inSystem)
                                            }
                                            .buttonStyle(.plain)

                                            // Botón añadir a pendientes
                                            Button {
                                                Task { _ = await savedVM.save(rssArticle: article) }
                                            } label: {
                                                Image(systemName: inSystem ? "checkmark.circle.fill" : "tray.and.arrow.down")
                                                    .font(.system(size: 18))
                                                    .foregroundColor(inSystem ? .green : .orange)
                                                    .frame(width: 44, height: 44)
                                            }
                                            .disabled(inSystem)
                                            .padding(.trailing, 8)
                                        }
                                        Divider().padding(.leading, 16)
                                    }
                                }
                            }

                            // MARK: Sección Email / n8n
                            CollapsibleSectionHeader(
                                title: "EMAIL / N8N",
                                icon: "wand.and.stars",
                                count: n8nFiltered.count,
                                selected: 0,
                                isExpanded: $n8nExpanded
                            )
                            if n8nExpanded {
                                if savedVM.isLoading && n8nFiltered.isEmpty {
                                    ProgressView().padding(24)
                                } else if n8nFiltered.isEmpty {
                                    sectionEmpty(
                                        icon: "wand.and.stars",
                                        text: "Sin noticias de newsletters",
                                        sub: "Se sincronizan automáticamente con n8n"
                                    )
                                } else {
                                    ForEach(n8nFiltered) { article in
                                        NavigationLink {
                                            SavedArticleDetailView(article: article, viewModel: savedVM)
                                        } label: {
                                            NoticiaEmailRow(article: article)
                                        }
                                        .buttonStyle(.plain)
                                        Divider().padding(.leading, 16)
                                    }
                                }
                            }

                            // MARK: Sección URLs manuales
                            CollapsibleSectionHeader(
                                title: "URLS MANUALES",
                                icon: "link",
                                count: urlFiltered.count,
                                selected: 0,
                                isExpanded: $urlExpanded
                            )
                            if urlExpanded {
                                if urlFiltered.isEmpty {
                                    sectionEmpty(
                                        icon: "link.badge.plus",
                                        text: "Sin URLs añadidas",
                                        sub: "Pulsa + para añadir una URL"
                                    )
                                } else {
                                    ForEach(urlFiltered) { article in
                                        NavigationLink {
                                            SavedArticleDetailView(article: article, viewModel: savedVM)
                                        } label: {
                                            NoticiaURLRow(article: article)
                                        }
                                        .buttonStyle(.plain)
                                        Divider().padding(.leading, 16)
                                    }
                                }
                            }
                        }
                    }
                    .refreshable { await viewModel.loadArticlesWithRetry() }
                }
            }
            .animation(.easeInOut(duration: 0.3), value: nlVM.n8nStatus.isActive)
            .navigationTitle("Noticias")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { Task { await viewModel.loadArticlesWithRetry() } } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(viewModel.isLoading)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            Task { await nlVM.regenerateDraft() }
                        } label: {
                            Label("Actualizar noticias", systemImage: "sparkles")
                        }
                        .disabled(nlVM.n8nStatus.isActive)
                        Divider()
                        Button { showArchivo = true } label: {
                            Label("Archivo", systemImage: "archivebox")
                        }
                        Button { viewModel.showingFeedEditor = true } label: {
                            Label("Editar feeds RSS", systemImage: "gear")
                        }
                    } label: {
                        Image(systemName: nlVM.n8nStatus.isActive
                              ? "sparkles" : "ellipsis.circle")
                        .foregroundColor(nlVM.n8nStatus.isActive ? .orange : .primary)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showAddURL = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $viewModel.showingFeedEditor) {
                RSSFeedEditorView(viewModel: viewModel)
            }
            .sheet(isPresented: $showAddURL) {
                AgregarURLView(viewModel: savedVM)
            }
            .sheet(isPresented: $showArchivo) {
                NavigationStack {
                    ArchivoView(viewModel: savedVM)
                        .navigationTitle("Archivo")
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Cerrar") { showArchivo = false }
                            }
                        }
                }
            }
        }
        .onAppear {
            if viewModel.articles.isEmpty {
                Task { await viewModel.loadArticlesWithRetry() }
            }
            if savedVM.savedArticles.isEmpty {
                Task { await savedVM.loadSavedArticles() }
            }
        }
    }

    @ViewBuilder
    private func sectionEmpty(icon: String, text: String, sub: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 32)).foregroundColor(.secondary)
            Text(text).font(.caption).foregroundColor(.secondary)
            Text(sub).font(.caption2).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity).padding(24)
    }
}

// MARK: - Fila RSS

struct NoticiaRSSRow: View {
    let article: NewsArticle
    let isInSystem: Bool

    private var sourceColor: Color { colorForFeed(article.source) }
    private var sourceIcon: String  { iconForFeed(article.source)  }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: sourceIcon)
                    .font(.caption).foregroundColor(sourceColor)
                Text(article.source)
                    .font(.caption.weight(.medium)).foregroundColor(sourceColor)
                Spacer()
                Text(article.publishedDate.timeAgo())
                    .font(.caption2).foregroundColor(.secondary)
            }
            Text(article.title)
                .font(.system(size: 15, weight: .semibold))
                .lineLimit(2)
                .foregroundColor(article.isRead ? .secondary : .primary)
            if !article.description.isEmpty {
                Text(article.description)
                    .font(.caption).foregroundColor(.secondary).lineLimit(2)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .opacity(article.isRead ? 0.7 : 1)
    }
}

// MARK: - Fila Draft n8n

struct NoticiaDraftRow: View {
    let article: DraftArticle
    let isSaved: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "wand.and.stars")
                    .font(.caption).foregroundColor(.blue)
                Text(article.categoria)
                    .font(.caption.weight(.medium)).foregroundColor(.blue)
                Spacer()
                if isSaved {
                    Image(systemName: "tray.fill")
                        .font(.system(size: 9))
                        .foregroundColor(Color(.systemGray3))
                }
            }
            Text(article.titulo)
                .font(.system(size: 15, weight: .semibold)).lineLimit(2)
            Text(article.resumen)
                .font(.caption).foregroundColor(.secondary).lineLimit(2)
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
    }
}

// MARK: - Fila Email / n8n

struct NoticiaEmailRow: View {
    let article: SupabaseArticle

    var body: some View {
        HStack(alignment: .top, spacing: 10) {

            // Score badge
            if let score = article.relevanceScore {
                ZStack {
                    Circle()
                        .fill(scoreColor(score))
                        .frame(width: 32, height: 32)
                    Text("\(score)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                }
                .padding(.top, 2)
            }

            VStack(alignment: .leading, spacing: 5) {
                // Meta
                HStack(spacing: 6) {
                    if let category = article.category, !category.isEmpty {
                        Text(category)
                            .font(.system(size: 10, weight: .semibold))
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color.blue.opacity(0.12))
                            .foregroundColor(.blue)
                            .cornerRadius(5)
                    }
                    Text(article.sourceName)
                        .font(.caption).foregroundColor(.secondary)
                    Spacer()
                    Text(article.formattedDate)
                        .font(.caption2).foregroundColor(.secondary)
                }

                // Título
                Text(article.title)
                    .font(.system(size: 15, weight: .semibold)).lineLimit(2)

                // Descripción
                if !article.description.isEmpty {
                    Text(article.description)
                        .font(.caption).foregroundColor(.secondary).lineLimit(2)
                }

                // Razón IA
                if let reason = article.relevanceReason, !reason.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles").font(.system(size: 9))
                        Text(reason).font(.caption).lineLimit(1)
                    }
                    .foregroundColor(.purple)
                }
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
    }

    func scoreColor(_ score: Int) -> Color {
        if score >= 8 { return .green }
        if score >= 6 { return .orange }
        return Color(.systemGray3)
    }
}

// MARK: - Fila URL manual

struct NoticiaURLRow: View {
    let article: SupabaseArticle

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "link")
                    .font(.caption).foregroundColor(.green)
                Text(article.sourceName)
                    .font(.caption.weight(.medium)).foregroundColor(.green)
                Spacer()
                Image(systemName: "tray.fill")
                    .font(.system(size: 9))
                    .foregroundColor(Color(.systemGray3))
                Text(article.formattedDate)
                    .font(.caption2).foregroundColor(.secondary)
            }
            Text(article.title)
                .font(.system(size: 15, weight: .semibold)).lineLimit(2)
            if !article.description.isEmpty {
                Text(article.description)
                    .font(.caption).foregroundColor(.secondary).lineLimit(2)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
    }
}

// MARK: - Detalle artículo RSS

struct RSSNoticiaDetailView: View {
    let article: NewsArticle
    @ObservedObject var savedVM: SupabaseArticlesViewModel
    @EnvironmentObject var rssVM: ArticlesViewModel
    @State private var showSafari     = false
    @State private var showingNewPost = false

    private var supabaseArticle: SupabaseArticle? {
        savedVM.savedArticles.first  { $0.url == article.url.absoluteString } ??
        savedVM.pendingArticles.first { $0.url == article.url.absoluteString }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                // Cabecera
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "dot.radiowaves.up.forward")
                            .font(.caption).foregroundColor(.orange)
                        Text(article.source)
                            .font(.caption.weight(.medium)).foregroundColor(.orange)
                        Text("·").foregroundColor(.secondary)
                        Text("RSS").font(.caption).foregroundColor(.secondary)
                        Spacer()
                        Text(article.publishedDate.formattedString())
                            .font(.caption).foregroundColor(.secondary)
                    }
                    Text(article.title)
                        .font(.title2.weight(.bold))
                        .fixedSize(horizontal: false, vertical: true)
                    if let category = article.category {
                        Text(category)
                            .font(.caption)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Color.orange.opacity(0.12))
                            .foregroundColor(.orange)
                            .cornerRadius(6)
                    }
                }
                .padding(.horizontal)

                Divider()

                if !article.description.isEmpty {
                    Text(article.description)
                        .font(.body).foregroundColor(.secondary).padding(.horizontal)
                }
                if let content = article.content, !content.isEmpty, content != article.description {
                    Text(content).font(.body).padding(.horizontal)
                }

                Divider().padding(.horizontal)

                // Acciones
                VStack(spacing: 12) {
                    Button {
                        showSafari = true
                        Task { await silentSave() }
                    } label: {
                        Label("Leer artículo completo", systemImage: "safari")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Button {
                        Task { await silentSave() }
                        showingNewPost = true
                    } label: {
                        Label("Crear post para RRSS", systemImage: "square.and.pencil")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    if let sb = supabaseArticle {
                        Button {
                            Task { await savedVM.toggleNewsletter(sb) }
                        } label: {
                            Label(
                                sb.selectedForNewsletter ? "Quitar del Newsletter" : "Añadir al Newsletter",
                                systemImage: sb.selectedForNewsletter ? "envelope.badge.fill" : "envelope.badge"
                            )
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(sb.selectedForNewsletter ? .purple : .primary)
                    } else {
                        Button {
                            Task { await silentSave() }
                        } label: {
                            Label("Añadir al Newsletter", systemImage: "envelope.badge")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .padding(.top, 16)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { rssVM.toggleFavorite(for: article) } label: {
                    Image(systemName: article.isFavorite ? "star.fill" : "star")
                        .foregroundColor(article.isFavorite ? .yellow : .gray)
                }
            }
        }
        .sheet(isPresented: $showSafari) {
            SafariView(
                url: article.url,
                showingCreatePost: .constant(false),
                webURLForPost: .constant(nil),
                webTitleForPost: .constant(nil)
            )
            .edgesIgnoringSafeArea(.all)
        }
        .sheet(isPresented: $showingNewPost) {
            NuevaPublicacionView(
                viewModel: SocialPostsViewModel.shared,
                textoInicial: "📰 \(article.title)\n\n\(article.description)",
                webURL: article.url.absoluteString,
                webTitle: article.title,
                isFromWeb: true
            )
        }
    }

    private func silentSave() async {
        guard !savedVM.isInSystem(url: article.url.absoluteString) else { return }
        _ = await savedVM.save(rssArticle: article)
    }
}

// MARK: - Detalle artículo Draft n8n

struct DraftNoticiaDetailView: View {
    let article: DraftArticle
    @ObservedObject var savedVM: SupabaseArticlesViewModel
    @State private var showSafari     = false
    @State private var showingNewPost = false

    private var supabaseArticle: SupabaseArticle? {
        guard let url = article.url else { return nil }
        return savedVM.savedArticles.first  { $0.url == url } ??
               savedVM.pendingArticles.first { $0.url == url }
    }

    private var hasURL: Bool { !(article.url?.isEmpty ?? true) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                // Cabecera
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "wand.and.stars")
                            .font(.caption).foregroundColor(.blue)
                        Text(article.categoria)
                            .font(.caption.weight(.medium)).foregroundColor(.blue)
                        Text("·").foregroundColor(.secondary)
                        Text("Email / n8n").font(.caption).foregroundColor(.secondary)
                        Spacer()
                    }
                    Text(article.titulo)
                        .font(.title2.weight(.bold))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal)

                Divider()

                Text(article.resumen)
                    .font(.body).foregroundColor(.secondary).padding(.horizontal)

                Divider().padding(.horizontal)

                // Acciones
                VStack(spacing: 12) {
                    Button {
                        showSafari = true
                        Task { await savedVM.saveDraftIfNeeded(article: article) }
                    } label: {
                        Label("Leer artículo completo", systemImage: "safari")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(!hasURL)

                    Button {
                        Task { await savedVM.saveDraftIfNeeded(article: article) }
                        showingNewPost = true
                    } label: {
                        Label("Crear post para RRSS", systemImage: "square.and.pencil")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    if let sb = supabaseArticle {
                        Button {
                            Task { await savedVM.toggleNewsletter(sb) }
                        } label: {
                            Label(
                                sb.selectedForNewsletter ? "Quitar del Newsletter" : "Añadir al Newsletter",
                                systemImage: sb.selectedForNewsletter ? "envelope.badge.fill" : "envelope.badge"
                            )
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(sb.selectedForNewsletter ? .purple : .primary)
                    } else {
                        Button {
                            Task { await savedVM.saveDraftIfNeeded(article: article) }
                        } label: {
                            Label("Añadir al Newsletter", systemImage: "envelope.badge")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .padding(.top, 16)
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showSafari) {
            if let urlStr = article.url, let url = URL(string: urlStr) {
                SafariView(
                    url: url,
                    showingCreatePost: .constant(false),
                    webURLForPost: .constant(nil),
                    webTitleForPost: .constant(nil)
                )
                .edgesIgnoringSafeArea(.all)
            }
        }
        .sheet(isPresented: $showingNewPost) {
            NuevaPublicacionView(
                viewModel: SocialPostsViewModel.shared,
                textoInicial: "📰 \(article.titulo)\n\n\(article.resumen)",
                webURL: article.url,
                webTitle: article.titulo,
                isFromWeb: true
            )
        }
    }
}

// MARK: - Chip de fuente RSS

struct SourceChip: View {
    let title: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(isSelected ? color : Color(.systemGray5))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Helpers (reutilizados también en otros archivos)

func iconForFeed(_ feedName: String) -> String {
    switch feedName {
    case "Medios de Asia":  return "globe.asia.australia"
    case "Medios de USA":   return "flag"
    case "IA":              return "brain.head.profile"
    case "INSIDE Life":     return "sparkles"
    case "Basketball":      return "basketball"
    default:                return "newspaper"
    }
}

func colorForFeed(_ feedName: String) -> Color {
    switch feedName {
    case "Medios de Asia":  return .orange
    case "Medios de USA":   return .blue
    case "IA":              return .purple
    case "INSIDE Life":     return .pink
    case "Basketball":      return .red
    default:                return .gray
    }
}

#Preview {
    NewsListView()
        .environmentObject(ArticlesViewModel())
}
