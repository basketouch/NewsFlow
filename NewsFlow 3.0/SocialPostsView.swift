import SwiftUI

struct SocialPostsView: View {
    @StateObject var viewModel = SocialPostsViewModel.shared
    @StateObject var agentViewModel = ContentDailyViewModel.shared
    @State private var selectedNetwork: SocialNetwork? = nil
    @State private var selectedTab = 0
    @State private var sourceFilter: SourceFilter = .manual
    @State private var showingAgentTrigger = false

    enum SourceFilter: String, CaseIterable {
        case manual = "Manual"
        case ia     = "IA"
    }
    
    var filteredPosts: [SocialPost] {
        // Primero filtramos por red social si es necesario
        let postsFiltered: [SocialPost]
        if selectedNetwork == nil {
            postsFiltered = viewModel.posts
        } else {
            postsFiltered = viewModel.posts.filter { $0.redSocial == selectedNetwork?.rawValue }
        }
        
        // Luego ordenamos: primero los de revisión (no aprobados), después los aprobados
        return postsFiltered.sorted { post1, post2 in
            // Si ambos tienen el mismo estado de aprobación, ordenar por fecha
            if post1.aprobado == post2.aprobado {
                // Orden ascendente por fecha (más cercana primero)
                return post1.fecha < post2.fecha
            }
            // Si tienen diferente estado, primero los no aprobados (revisión)
            return !post1.aprobado && post2.aprobado
        }
    }
    
    var postsScheduledForToday: [SocialPost] {
        filteredPosts.filter { $0.isScheduledForToday }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {

                // ── Selector fuente: Manual | IA ──
                Picker("Fuente", selection: $sourceFilter) {
                    ForEach(SourceFilter.allCases, id: \.self) { f in
                        HStack {
                            Text(f.rawValue)
                            if f == .ia && agentViewModel.pendingCount > 0 {
                                Text("(\(agentViewModel.pendingCount))")
                            }
                        }.tag(f)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)

                if sourceFilter == .manual {
                    manualPostsContent
                } else {
                    aiPostsContent
                }
            }
            .navigationTitle("Publicaciones")
            .sheet(isPresented: Binding(
                get: { viewModel.isCreatingPost },
                set: { viewModel.isCreatingPost = $0 }
            )) {
                NuevaPublicacionView(viewModel: viewModel)
            }
            .sheet(isPresented: $showingAgentTrigger) {
                AgentTriggerView(viewModel: agentViewModel)
            }
            .toolbar {
                // Botón recargar
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task {
                            if sourceFilter == .manual {
                                await viewModel.loadData()
                            } else {
                                await agentViewModel.loadPosts()
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }

                // Filtro de red social (solo en pestaña Manual)
                if sourceFilter == .manual {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Menu {
                            Button {
                                selectedNetwork = nil
                            } label: {
                                Label("Todas", systemImage: selectedNetwork == nil ? "checkmark" : "network")
                            }
                            Divider()
                            ForEach(SocialNetwork.allCases) { network in
                                Button {
                                    selectedNetwork = network
                                } label: {
                                    Label(
                                        network.rawValue,
                                        systemImage: selectedNetwork == network ? "checkmark" : "circle"
                                    )
                                }
                            }
                        } label: {
                            Image(systemName: selectedNetwork == nil
                                  ? "line.3.horizontal.decrease"
                                  : "line.3.horizontal.decrease.circle.fill")
                                .foregroundColor(selectedNetwork == nil ? .primary : .blue)
                        }
                    }
                }

                // Crear publicación / generar con IA
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        if sourceFilter == .manual {
                            viewModel.isCreatingPost = true
                        } else {
                            showingAgentTrigger = true
                        }
                    } label: {
                        Image(systemName: sourceFilter == .manual ? "square.and.pencil" : "sparkles")
                    }
                }
            }
            .task {
                await agentViewModel.loadPosts()
            }
        }
    }

    // MARK: - Manual posts

    @ViewBuilder
    private var manualPostsContent: some View {
        VStack(spacing: 0) {
            if viewModel.isLoading && viewModel.posts.isEmpty {
                ProgressView("Cargando publicaciones...")
                    .padding()
            } else if let error = viewModel.error {
                ErrorView(message: error) {
                    Task { await viewModel.loadData() }
                }
            } else if filteredPosts.isEmpty {
                EmptyStateView()
            } else {
                VStack(spacing: 0) {
                    Picker("Vista", selection: $selectedTab) {
                        Text("Hoy").tag(0)
                        Text("Todas").tag(1)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal)
                    .padding(.vertical, 8)

                    TabView(selection: $selectedTab) {
                        ZStack {
                            if postsScheduledForToday.isEmpty {
                                VStack(spacing: 12) {
                                    Image(systemName: "calendar.badge.clock")
                                        .font(.system(size: 50))
                                        .foregroundColor(.gray)
                                    Text("No hay publicaciones para hoy")
                                        .font(.title3)
                                    Text("No se encontraron publicaciones programadas para hoy")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal)
                                }
                                .padding()
                            } else {
                                List {
                                    ForEach(postsScheduledForToday) { post in
                                        NavigationLink(destination: SocialPostDetailView(post: post, viewModel: viewModel)) {
                                            SocialPostRow(post: post)
                                        }
                                        .listRowSeparator(.hidden)
                                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                                    }
                                }
                                .listStyle(.plain)
                            }
                        }
                        .tag(0)

                        List {
                            let postsEnRevision = filteredPosts.filter { !$0.aprobado }
                            if !postsEnRevision.isEmpty {
                                Section(header: Text("Revisión").font(.headline)) {
                                    ForEach(postsEnRevision) { post in
                                        NavigationLink(destination: SocialPostDetailView(post: post, viewModel: viewModel)) {
                                            SocialPostRow(post: post)
                                        }
                                        .listRowSeparator(.hidden)
                                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                                    }
                                }
                            }
                            let postsAprobadas = filteredPosts.filter { $0.aprobado && !$0.publicado }
                            if !postsAprobadas.isEmpty {
                                Section(header: Text("Aprobadas").font(.headline)) {
                                    ForEach(postsAprobadas) { post in
                                        NavigationLink(destination: SocialPostDetailView(post: post, viewModel: viewModel)) {
                                            SocialPostRow(post: post)
                                        }
                                        .listRowSeparator(.hidden)
                                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                                    }
                                }
                            }
                            let postsPublicadas = filteredPosts.filter {
                                $0.publicado && Calendar.current.isDateInToday($0.fecha)
                            }
                            if !postsPublicadas.isEmpty {
                                Section(header: Text("Publicadas").font(.headline)) {
                                    ForEach(postsPublicadas) { post in
                                        NavigationLink(destination: SocialPostDetailView(post: post, viewModel: viewModel)) {
                                            SocialPostRow(post: post)
                                        }
                                        .listRowSeparator(.hidden)
                                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                                    }
                                }
                            }
                        }
                        .listStyle(.plain)
                        .tag(1)
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                }
                .refreshable { await viewModel.loadData() }
            }
        }
    }

    // MARK: - AI posts

    @ViewBuilder
    private var aiPostsContent: some View {
        if agentViewModel.isLoading && agentViewModel.posts.isEmpty {
            ProgressView("Cargando posts IA...")
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if agentViewModel.posts.isEmpty {
            VStack(spacing: 20) {
                Image(systemName: "sparkles")
                    .font(.system(size: 50))
                    .foregroundColor(.purple)
                Text("Sin posts generados")
                    .font(.title3)
                Text("Pulsa ✦ arriba para generar tu primer post con IA")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                Button {
                    showingAgentTrigger = true
                } label: {
                    Label("Generar posts con IA", systemImage: "sparkles")
                }
                .buttonStyle(.borderedProminent)
                .tint(.purple)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List {
                let pending = agentViewModel.posts.filter { $0.isPendingReview }
                let published = agentViewModel.posts.filter { !$0.isPendingReview }

                if !pending.isEmpty {
                    Section {
                        ForEach(pending) { post in
                            NavigationLink(destination: ContentDailyDetailView(post: post, viewModel: agentViewModel)) {
                                ContentDailyRow(post: post)
                            }
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        }
                    } header: {
                        Label("Pendientes de revisar", systemImage: "clock")
                            .font(.headline)
                    }
                }

                if !published.isEmpty {
                    Section {
                        ForEach(published) { post in
                            NavigationLink(destination: ContentDailyDetailView(post: post, viewModel: agentViewModel)) {
                                ContentDailyRow(post: post)
                            }
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        }
                    } header: {
                        Label("Publicados", systemImage: "checkmark.circle")
                            .font(.headline)
                    }
                }
            }
            .listStyle(.plain)
            .refreshable { await agentViewModel.loadPosts() }
        }
    }
}

// Estado vacío cuando no hay publicaciones
struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text")
                .font(.system(size: 50))
                .foregroundColor(.gray)
            
            Text("No hay publicaciones")
                .font(.title2)
            
            Text("No hay publicaciones todavía. Crea una nueva con el botón de arriba.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }
}

// Vista para mostrar errores
struct ErrorView: View {
    let message: String
    let retryAction: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            
            Text("Error")
                .font(.title2)
            
            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Reintentar") {
                retryAction()
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }
}

// MARK: - ContentDailyRow

struct ContentDailyRow: View {
    let post: ContentDailyPost

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("IA", systemImage: "sparkles")
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(.purple)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Color.purple.opacity(0.1))
                    .cornerRadius(4)

                Spacer()

                Text(post.formattedDate)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text(post.topic)
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)

            HStack(spacing: 6) {
                platformBadge("LI", available: post.linkedinPost != nil, published: post.publishedTo.contains("linkedin"), color: .blue)
                platformBadge("IG", available: post.instagramPost != nil, published: post.publishedTo.contains("instagram"), color: .pink)
                platformBadge("X",  available: post.twitterPost != nil,  published: post.publishedTo.contains("twitter"),  color: Color(red: 0.11, green: 0.63, blue: 0.95))
                platformBadge("TK", available: post.tiktokScript != nil,  published: post.publishedTo.contains("tiktok"),   color: .purple)

                Spacer()

                Text(post.statusLabel)
                    .font(.caption2)
                    .foregroundColor(post.isPendingReview ? .orange : .green)
            }
        }
        .padding(.vertical, 4)
    }

    private func platformBadge(_ label: String, available: Bool, published: Bool, color: Color) -> some View {
        Text(label)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(published ? color : (available ? color.opacity(0.15) : Color.gray.opacity(0.1)))
            .foregroundColor(published ? .white : (available ? color : .secondary))
            .cornerRadius(4)
    }
}

// Previsualización
#Preview {
    NavigationStack {
        SocialPostsView()
    }
} 