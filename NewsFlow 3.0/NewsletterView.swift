import SwiftUI

struct NewsletterView: View {
    @StateObject private var vm = NewsletterViewModel.shared
    @State private var selectedSection = 0          // 0=Artículos 1=Cabecera 2=Orden 3=Bloques
    @State private var showBlockEditor = false
    @State private var editingBlock: NewsletterBlock? = nil
    @State private var isGeneratingPreview = false
    @State private var showPreview = false
    @State private var showPublishConfirm = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {

                // Selector de sección
                Picker("Sección", selection: $selectedSection) {
                    Text("Artículos").tag(0)
                    Text("Cabecera").tag(1)
                    Text("Orden (\(vm.selectedItems.count))").tag(2)
                    Text("Bloques (\(vm.extraBlocks.count))").tag(3)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)

                // Aviso cabecera incompleta
                if !vm.selectedItems.isEmpty && (vm.hero.titular.isEmpty || vm.hero.lead.isEmpty) {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.circle.fill").foregroundColor(.orange)
                        Text("Genera el titular y la apertura en la pestaña Cabecera antes de previsualizar.")
                            .font(.caption).foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 6)
                    .background(Color.orange.opacity(0.08))
                }

                // Error
                if let error = vm.error {
                    HStack {
                        Image(systemName: "exclamationmark.triangle").foregroundColor(.orange)
                        Text(error).font(.caption).foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                }

                // Contenido por sección
                Group {
                    if selectedSection == 0 {
                        ArticleSelectionSection(vm: vm)
                    } else if selectedSection == 1 {
                        HeroEditorSection(vm: vm)
                    } else if selectedSection == 2 {
                        SelectedOrderSection(vm: vm)
                    } else {
                        BlocksSection(vm: vm)
                    }
                }
            }
            .navigationTitle(draftTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        Task { await vm.loadDraft() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(vm.isLoading)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        // Vista previa
                        Button {
                            isGeneratingPreview = true
                            Task {
                                _ = vm.generatePreview()
                                isGeneratingPreview = false
                                showPreview = true
                            }
                        } label: {
                            if isGeneratingPreview {
                                ProgressView().scaleEffect(0.8)
                            } else {
                                Image(systemName: "eye")
                                    .foregroundColor(canPreview ? .primary : .secondary)
                            }
                        }
                        .disabled(!canPreview || isGeneratingPreview)

                        // Publicar
                        Button {
                            showPublishConfirm = true
                        } label: {
                            if case .loading = vm.publishState {
                                ProgressView().scaleEffect(0.8)
                            } else {
                                Image(systemName: "arrow.up.circle.fill")
                                    .foregroundColor(.red)
                            }
                        }
                        .disabled(vm.selectedItems.isEmpty || vm.publishState == .loading)
                    }
                }
            }
            .sheet(isPresented: $showPreview) {
                NewsletterPreviewView(html: vm.generatedHTML)
            }
            .confirmationDialog(
                "Publicar Newsletter #\(vm.draft?.edicion ?? "")",
                isPresented: $showPublishConfirm,
                titleVisibility: .visible
            ) {
                Button("Publicar en insidelife.club", role: .none) {
                    Task { await vm.publish() }
                }
                Button("Cancelar", role: .cancel) {}
            } message: {
                Text("Se generará el HTML y se publicará en insidelife.club via GitHub. Vercel lo desplegará en ~30 segundos.")
            }
            .alert(publishAlertTitle, isPresented: publishAlertBinding) {
                Button("OK", role: .cancel) { vm.resetPublishState() }
            } message: {
                if case .success(let url) = vm.publishState {
                    Text("Publicado en GitHub. Estará disponible en ~30 segundos:\n\(url)")
                } else if case .error(let msg) = vm.publishState {
                    Text(msg)
                }
            }
        }
        .task {
            if vm.draft == nil { await vm.loadDraft() }
            vm.requestNotificationPermission()
        }
    }

    private var canPreview: Bool {
        !vm.selectedItems.isEmpty &&
        !vm.hero.titular.isEmpty &&
        !vm.hero.lead.isEmpty
    }

    private var draftTitle: String {
        let edicion = vm.edicionEditada.isEmpty ? (vm.draft?.edicion ?? "") : vm.edicionEditada
        return edicion.isEmpty ? "Newsletter" : "Newsletter #\(edicion)"
    }

    private var publishAlertTitle: String {
        switch vm.publishState {
        case .success: return "✅ Publicado"
        case .error:   return "❌ Error al publicar"
        default:       return ""
        }
    }

    private var publishAlertBinding: Binding<Bool> {
        Binding(
            get: {
                if case .success = vm.publishState { return true }
                if case .error   = vm.publishState { return true }
                return false
            },
            set: { if !$0 { vm.resetPublishState() } }
        )
    }
}

// MARK: - Sección 1: Selección de artículos del draft

struct ArticleSelectionSection: View {
    @ObservedObject var vm: NewsletterViewModel
    @State private var draftExpanded = true
    @State private var rssExpanded   = true
    @State private var urlExpanded   = true

    var n8nArticles: [SupabaseArticle] {
        vm.savedVM.savedArticles.filter {
            $0.selectedForNewsletter && $0.sourceType == "gmail"
        }
    }

    var rssArticles: [SupabaseArticle] {
        vm.savedVM.savedArticles.filter {
            $0.selectedForNewsletter && $0.sourceType == "rss"
        }
    }

    var urlArticles: [SupabaseArticle] {
        vm.savedVM.savedArticles.filter {
            $0.selectedForNewsletter && $0.sourceType == "url"
        }
    }

    // Count of selected Supabase items by source type
    private func selectedCount(prefix: String = "sb-", sourceTypes: [String]) -> Int {
        vm.selectedItems.filter { item in
            guard item.id.hasPrefix("sb-") else { return false }
            let sbId = String(item.id.dropFirst(3))
            guard let article = vm.savedVM.savedArticles.first(where: { $0.id == sbId }) else { return false }
            return sourceTypes.contains(article.sourceType)
        }.count
    }

    var body: some View {
        if vm.isLoading {
            Spacer()
            ProgressView("Cargando draft...").padding()
            Spacer()
        } else {
            ScrollView {
                VStack(spacing: 0) {

                    // MARK: Sección 1 — Email / n8n (Supabase)
                    CollapsibleSectionHeader(
                        title: "NOTICIAS N8N",
                        icon: "wand.and.stars",
                        count: n8nArticles.count,
                        selected: selectedCount(sourceTypes: ["gmail"]),
                        isExpanded: $draftExpanded
                    )

                    if draftExpanded {
                        if n8nArticles.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "wand.and.stars").font(.system(size: 32)).foregroundColor(.secondary)
                                Text("Sin noticias de email seleccionadas")
                                    .font(.caption).foregroundColor(.secondary).multilineTextAlignment(.center)
                                Text("Selecciónalas en Noticias → EMAIL / N8N")
                                    .font(.caption2).foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity).padding(24)
                        } else {
                            HStack {
                                Text("\(selectedCount(sourceTypes: ["gmail"])) de \(n8nArticles.count) seleccionadas")
                                    .font(.caption).foregroundColor(.secondary)
                                Spacer()
                                Button("Todas")   { vm.selectAllSupabase(sourceTypes: ["gmail"]) }.font(.caption)
                                Button("Ninguna") { vm.deselectAllSupabase(sourceTypes: ["gmail"]) }.font(.caption).padding(.leading, 8)
                            }
                            .padding(.horizontal).padding(.vertical, 6)
                            .background(Color.gray.opacity(0.05))

                            ForEach(n8nArticles) { article in
                                SupabaseArticleRow(
                                    article: article,
                                    isSelected: vm.isSelectedSupabase(article)
                                ) { vm.toggleSelectionSupabase(article) }
                                Divider().padding(.leading, 50)
                            }
                        }
                    }

                    // MARK: Sección 2 — RSS guardados
                    CollapsibleSectionHeader(
                        title: "NOTICIAS RSS",
                        icon: "dot.radiowaves.up.forward",
                        count: rssArticles.count,
                        selected: selectedCount(sourceTypes: ["rss"]),
                        isExpanded: $rssExpanded
                    )

                    if rssExpanded {
                        if rssArticles.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "tray").font(.system(size: 32)).foregroundColor(.secondary)
                                Text("Sin artículos RSS marcados para newsletter")
                                    .font(.caption).foregroundColor(.secondary).multilineTextAlignment(.center)
                                Text("Selecciónalos en Noticias → RSS")
                                    .font(.caption2).foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity).padding(24)
                        } else {
                            HStack {
                                Text("\(selectedCount(sourceTypes: ["rss"])) de \(rssArticles.count) seleccionadas")
                                    .font(.caption).foregroundColor(.secondary)
                                Spacer()
                                Button("Todas")   { vm.selectAllSupabase(sourceTypes: ["rss"]) }.font(.caption)
                                Button("Ninguna") { vm.deselectAllSupabase(sourceTypes: ["rss"]) }.font(.caption).padding(.leading, 8)
                            }
                            .padding(.horizontal).padding(.vertical, 6)
                            .background(Color.gray.opacity(0.05))

                            ForEach(rssArticles) { article in
                                SupabaseArticleRow(
                                    article: article,
                                    isSelected: vm.isSelectedSupabase(article)
                                ) { vm.toggleSelectionSupabase(article) }
                                Divider().padding(.leading, 50)
                            }
                        }
                    }

                    // MARK: Sección 3 — URLs manuales
                    CollapsibleSectionHeader(
                        title: "URLS MANUALES",
                        icon: "link",
                        count: urlArticles.count,
                        selected: selectedCount(sourceTypes: ["url"]),
                        isExpanded: $urlExpanded
                    )

                    if urlExpanded {
                        if urlArticles.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "link.badge.plus").font(.system(size: 32)).foregroundColor(.secondary)
                                Text("Sin URLs manuales marcadas para newsletter")
                                    .font(.caption).foregroundColor(.secondary).multilineTextAlignment(.center)
                                Text("Añádelas desde la pestaña Guardados")
                                    .font(.caption2).foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity).padding(24)
                        } else {
                            HStack {
                                Text("\(selectedCount(sourceTypes: ["url"])) de \(urlArticles.count) seleccionadas")
                                    .font(.caption).foregroundColor(.secondary)
                                Spacer()
                                Button("Todas")   { vm.selectAllSupabase(sourceTypes: ["url"]) }.font(.caption)
                                Button("Ninguna") { vm.deselectAllSupabase(sourceTypes: ["url"]) }.font(.caption).padding(.leading, 8)
                            }
                            .padding(.horizontal).padding(.vertical, 6)
                            .background(Color.gray.opacity(0.05))

                            ForEach(urlArticles) { article in
                                SupabaseArticleRow(
                                    article: article,
                                    isSelected: vm.isSelectedSupabase(article)
                                ) { vm.toggleSelectionSupabase(article) }
                                Divider().padding(.leading, 50)
                            }
                        }
                    }
                }
            }
        }
    }
}

struct CollapsibleSectionHeader: View {
    let title: String
    let icon: String
    let count: Int
    let selected: Int
    @Binding var isExpanded: Bool

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.caption).foregroundColor(.red)
                Text(title)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.primary)
                    .kerning(1)
                Spacer()
                if selected > 0 {
                    Text("\(selected) sel.")
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6).padding(.vertical, 3)
                        .background(Color.red)
                        .cornerRadius(4)
                }
                Text("\(count)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption2).foregroundColor(.secondary)
            }
            .padding(.horizontal).padding(.vertical, 10)
            .background(Color(.secondarySystemBackground))
        }
        .buttonStyle(.plain)
    }
}

struct SupabaseArticleRow: View {
    let article: SupabaseArticle
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(isSelected ? .red : .secondary)
                    .frame(width: 26)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: article.sourceTypeIcon)
                            .font(.caption2).foregroundColor(.secondary)
                        Text(article.category ?? article.sourceName)
                            .font(.caption.weight(.medium))
                            .foregroundColor(.secondary)
                    }
                    Text(article.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                    Text(article.summary ?? article.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
            }
            .padding(.vertical, 6).padding(.horizontal)
        }
        .buttonStyle(.plain)
    }
}

struct DraftArticleRow: View {
    let article: DraftArticle
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(isSelected ? .red : .secondary)
                    .frame(width: 26)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(article.categoria)
                            .font(.caption.weight(.medium))
                            .foregroundColor(.secondary)
                        if article.destacada {
                            Text("DESTACADA")
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 5).padding(.vertical, 2)
                                .background(Color.red.opacity(0.15))
                                .foregroundColor(.red)
                                .cornerRadius(4)
                        }
                    }
                    Text(article.titulo)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                    Text(article.resumen)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Sección 2: Editor de cabecera

struct HeroEditorSection: View {
    @ObservedObject var vm: NewsletterViewModel

    var body: some View {
        Form {

            // MARK: Edición + Fecha
            Section {
                HStack {
                    Text("Número de edición")
                    Spacer()
                    TextField("1", text: $vm.edicionEditada)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 60)
                }
                DatePicker("Fecha", selection: $vm.selectedDate, displayedComponents: .date)
                    .environment(\.locale, Locale(identifier: "es_ES"))
            } footer: {
                Text("#\(vm.edicionEditada) · \(vm.fechaEditada)")
                    .font(.caption).foregroundColor(.secondary)
            }

            // MARK: Generar todo de golpe
            if !vm.selectedItems.isEmpty {
                Section {
                    Button {
                        Task { await vm.generarHeroCompleto() }
                    } label: {
                        HStack {
                            Spacer()
                            if vm.isGeneratingHero {
                                ProgressView().scaleEffect(0.85)
                                Text("Generando...").font(.subheadline)
                            } else {
                                Label("Generar titular y apertura con IA", systemImage: "sparkles")
                                    .font(.subheadline.weight(.medium))
                            }
                            Spacer()
                        }
                    }
                    .disabled(vm.isGeneratingHero)
                    .foregroundColor(.purple)
                }
            }

            // MARK: Titular
            Section {
                TextField("Titular impactante...", text: $vm.hero.titular, axis: .vertical)
                    .lineLimit(2...4)
            } header: {
                HStack {
                    Text("Titular")
                    Spacer()
                    Button {
                        Task { await vm.generarTitular() }
                    } label: {
                        Label("Regenerar", systemImage: "arrow.clockwise")
                            .font(.caption)
                    }
                    .disabled(vm.selectedItems.isEmpty || vm.isGeneratingHero)
                }
            } footer: {
                Text("Impactante, máx. 8 palabras. Sin \"INSIDE Life\" ni número.")
                    .font(.caption).foregroundColor(.secondary)
            }

            // MARK: Texto de entrada
            Section {
                TextEditor(text: $vm.hero.lead)
                    .frame(minHeight: 100)
            } header: {
                HStack {
                    Text("Apertura")
                    Spacer()
                    Button {
                        Task { await vm.generarLead() }
                    } label: {
                        Label("Regenerar", systemImage: "arrow.clockwise")
                            .font(.caption)
                    }
                    .disabled(vm.selectedItems.isEmpty || vm.isGeneratingHero)
                }
            } footer: {
                Text("40-60 palabras. Aperitivo que engancha, sin listar artículos.")
                    .font(.caption).foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Sección 3: Orden de artículos seleccionados

struct SelectedOrderSection: View {
    @ObservedObject var vm: NewsletterViewModel

    var body: some View {
        if vm.selectedItems.isEmpty {
            Spacer()
            VStack(spacing: 10) {
                Image(systemName: "list.bullet").font(.system(size: 44)).foregroundColor(.secondary)
                Text("Ningún artículo seleccionado")
                    .font(.headline).foregroundColor(.secondary)
                Text("Selecciona artículos en la pestaña anterior")
                    .font(.caption).foregroundColor(.secondary)
            }
            Spacer()
        } else {
            List {
                ForEach($vm.selectedItems) { $item in
                    SelectedItemRow(item: $item, vm: vm)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                if let idx = vm.selectedItems.firstIndex(where: { $0.id == item.id }) {
                                    vm.removeItem(at: IndexSet([idx]))
                                }
                            } label: {
                                Label("Eliminar", systemImage: "trash")
                            }
                        }
                }
                .onMove { vm.moveItem(from: $0, to: $1) }
            }
            .listStyle(.plain)
            .environment(\.editMode, .constant(.active))
        }
    }
}

struct SelectedItemRow: View {
    @Binding var item: NewsletterItem
    @ObservedObject var vm: NewsletterViewModel
    @State private var expanded = false

    private var isAILoading: Bool { vm.aiLoadingItemId == item.id }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── Cabecera de la fila (siempre visible) ──
            Button { withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() } } label: {
                HStack(spacing: 8) {
                    // Estrella destacada
                    Button { vm.toggleDestacada(for: item) } label: {
                        Image(systemName: item.destacada ? "star.fill" : "star")
                            .foregroundColor(item.destacada ? .yellow : Color(.systemGray3))
                            .font(.system(size: 15))
                    }
                    .buttonStyle(.plain)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.titulo)
                            .font(.system(size: 14, weight: .semibold))
                            .lineLimit(2)
                            .foregroundColor(.primary)
                        Text(item.categoria)
                            .font(.caption).foregroundColor(.secondary)
                    }
                    Spacer()
                    Picker("", selection: $item.style) {
                        ForEach(ArticleStyle.allCases) { s in Text(s.label).tag(s) }
                    }
                    .pickerStyle(.menu)
                    .font(.caption)
                    .labelsHidden()

                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.caption2).foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
            .padding(.vertical, 6)

            // ── Panel expandible: titular + texto + opinión + IA ──
            if expanded {
                VStack(alignment: .leading, spacing: 10) {
                    Divider()

                    // Titular (editable)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("TITULAR")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(.secondary).kerning(1)
                        TextField("Titular", text: $item.titulo, axis: .vertical)
                            .font(.system(size: 13, weight: .semibold))
                            .lineLimit(1...3)
                            .padding(8)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(6)
                    }

                    // Texto final (editable)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("TEXTO FINAL")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundColor(.secondary).kerning(1)
                            Spacer()
                            if item.textoFinal != item.resumen {
                                Button("Restaurar") { vm.resetTexto(for: item) }
                                    .font(.caption2).foregroundColor(.red)
                            }
                        }
                        TextEditor(text: $item.textoFinal)
                            .font(.system(size: 13))
                            .frame(minHeight: 80)
                            .scrollContentBackground(.hidden)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(6)
                    }

                    // Opinión de Jorge
                    VStack(alignment: .leading, spacing: 4) {
                        Text("TU OPINIÓN / PUNTO DE VISTA")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(.secondary).kerning(1)
                        TextEditor(text: $item.opinion)
                            .font(.system(size: 13))
                            .frame(minHeight: 60)
                            .scrollContentBackground(.hidden)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(6)
                            .overlay(
                                item.opinion.isEmpty
                                ? Text("Escribe tu punto de vista sobre esta noticia...")
                                    .font(.system(size: 13)).foregroundColor(.secondary.opacity(0.6))
                                    .padding(8).allowsHitTesting(false)
                                : nil,
                                alignment: .topLeading
                            )
                    }

                    // Botones IA
                    HStack(spacing: 10) {
                        Button {
                            Task { await vm.expandirTexto(for: item) }
                        } label: {
                            Label("Ampliar", systemImage: "sparkles")
                                .font(.caption.weight(.medium))
                        }
                        .buttonStyle(.bordered)
                        .tint(.blue)
                        .disabled(isAILoading)

                        Button {
                            Task { await vm.pulirConOpinion(for: item) }
                        } label: {
                            Label("Pulir con mi opinión", systemImage: "wand.and.stars")
                                .font(.caption.weight(.medium))
                        }
                        .buttonStyle(.bordered)
                        .tint(.purple)
                        .disabled(isAILoading || item.opinion.isEmpty)

                        if isAILoading {
                            ProgressView().scaleEffect(0.8)
                        }
                        Spacer()
                    }
                }
                .padding(.bottom, 8)
            }
        }
    }
}

// MARK: - Sección 4: Bloques extra

struct BlocksSection: View {
    @ObservedObject var vm: NewsletterViewModel
    @State private var editingBlock: NewsletterBlock? = nil

    var body: some View {
        VStack(spacing: 0) {
            // Botones para añadir bloque
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(BlockType.allCases) { type in
                        Button {
                            vm.addBlock(type)
                        } label: {
                            Label(type.label, systemImage: type.icon)
                                .font(.caption.weight(.medium))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.secondary.opacity(0.12))
                                .cornerRadius(8)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            .background(Color.gray.opacity(0.05))

            if vm.extraBlocks.isEmpty {
                Spacer()
                VStack(spacing: 10) {
                    Image(systemName: "rectangle.stack.badge.plus")
                        .font(.system(size: 44)).foregroundColor(.secondary)
                    Text("Sin bloques añadidos")
                        .font(.headline).foregroundColor(.secondary)
                    Text("Añade Texto, Callout, Promo o Imagen")
                        .font(.caption).foregroundColor(.secondary)
                }
                Spacer()
            } else {
                List {
                    ForEach($vm.extraBlocks) { $block in
                        BlockRow(block: $block, vm: vm)
                    }
                    .onMove { vm.moveBlock(from: $0, to: $1) }
                    .onDelete { vm.removeBlock(at: $0) }
                }
                .listStyle(.plain)
                .environment(\.editMode, .constant(.active))
            }
        }
    }
}

struct BlockRow: View {
    @Binding var block: NewsletterBlock
    @ObservedObject var vm: NewsletterViewModel

    private var isAILoading: Bool { vm.aiLoadingBlockId == block.id }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: block.type.icon)
                    .foregroundColor(block.type == .columna ? .purple : .red)
                Text(block.type.label.uppercased())
                    .font(.caption.weight(.bold))
                    .foregroundColor(block.type == .columna ? .purple : .red)
                Spacer()
                if block.type != .columna {
                    Picker("", selection: $block.position) {
                        ForEach(BlockPosition.allCases, id: \.rawValue) { pos in
                            Text(pos == .top ? "↑ Antes" : "↓ Después").tag(pos)
                        }
                    }
                    .pickerStyle(.menu)
                    .font(.caption)
                }
            }

            switch block.type {
            case .texto:
                TextField("Título (opcional)", text: $block.textoTitle)
                    .font(.caption)
                TextField("Texto del párrafo...", text: $block.textoBody, axis: .vertical)
                    .font(.caption).lineLimit(3...6)

            case .callout:
                TextField("Etiqueta (ej: 📌 Por qué importa)", text: $block.calloutLabel)
                    .font(.caption)
                TextField("Texto del callout...", text: $block.calloutBody, axis: .vertical)
                    .font(.caption).lineLimit(2...4)

            case .promo:
                TextField("Título", text: $block.promoTitle).font(.caption)
                TextField("Descripción...", text: $block.promoBody, axis: .vertical)
                    .font(.caption).lineLimit(2...4)
                TextField("URL del enlace", text: $block.promoLink)
                    .font(.caption).keyboardType(.URL).autocapitalization(.none)
                TextField("Texto del botón", text: $block.promoBtn).font(.caption)

            case .imagen:
                TextField("URL de la imagen", text: $block.imagenURL)
                    .font(.caption).keyboardType(.URL).autocapitalization(.none)
                TextField("Pie de foto (opcional)", text: $block.imagenCaption).font(.caption)

            case .columna:
                // Titular de la columna
                VStack(alignment: .leading, spacing: 4) {
                    Text("TITULAR")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(.secondary).kerning(1)
                    TextField("Ej: Lo que el deporte me enseñó sobre liderar bajo presión", text: $block.columnaTitulo)
                        .font(.system(size: 13))
                }

                // Semilla / idea de Jorge
                VStack(alignment: .leading, spacing: 4) {
                    Text("TU IDEA O REFLEXIÓN")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(.secondary).kerning(1)
                    TextEditor(text: $block.columnaPrompt)
                        .font(.system(size: 13))
                        .frame(minHeight: 60)
                        .scrollContentBackground(.hidden)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(6)
                        .overlay(
                            block.columnaPrompt.isEmpty
                            ? Text("Ej: Quiero hablar sobre cómo el deporte me enseñó a liderar bajo presión...")
                                .font(.system(size: 12)).foregroundColor(.secondary.opacity(0.6))
                                .padding(8).allowsHitTesting(false)
                            : nil,
                            alignment: .topLeading
                        )
                }

                // Botón generar
                HStack {
                    Button {
                        Task { await vm.generarColumna(for: block) }
                    } label: {
                        Label("Generar columna", systemImage: "pencil.and.sparkles")
                            .font(.caption.weight(.medium))
                    }
                    .buttonStyle(.bordered)
                    .tint(.purple)
                    .disabled(isAILoading || block.columnaPrompt.isEmpty)

                    if isAILoading { ProgressView().scaleEffect(0.8) }
                }

                // Texto generado (editable)
                if !block.columnaTexto.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("TEXTO GENERADO (editable)")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(.secondary).kerning(1)
                        TextEditor(text: $block.columnaTexto)
                            .font(.system(size: 13))
                            .frame(minHeight: 100)
                            .scrollContentBackground(.hidden)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(6)
                    }
                }
            }
        }
        .padding(.vertical, 6)
    }
}

#Preview {
    NewsletterView()
}
