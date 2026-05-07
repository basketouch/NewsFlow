import SwiftUI

struct AgentTriggerView: View {
    @ObservedObject var viewModel: ContentDailyViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var description = ""
    @State private var url = ""
    @State private var extraText = ""
    @State private var showSuccess = false
    @State private var showError = false
    @State private var inputMode: InputMode = .manual

    enum InputMode: String, CaseIterable {
        case manual = "Manual"
        case url    = "URL"
    }

    var canGenerate: Bool {
        !title.isEmpty || !extraText.isEmpty || (!url.isEmpty && inputMode == .url)
    }

    var body: some View {
        NavigationStack {
            Form {
                // Modo de entrada
                Section {
                    Picker("Fuente", selection: $inputMode) {
                        ForEach(InputMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Tipo de entrada")
                }

                if inputMode == .url {
                    Section {
                        TextField("https://...", text: $url)
                            .keyboardType(.URL)
                            .autocapitalization(.none)
                    } header: {
                        Text("URL del artículo")
                    } footer: {
                        Text("El agente leerá el título y descripción desde la URL")
                    }
                }

                Section {
                    TextField("Título del artículo o tema", text: $title)

                    if inputMode == .manual {
                        ZStack(alignment: .topLeading) {
                            if description.isEmpty {
                                Text("Descripción o resumen...")
                                    .foregroundColor(.secondary)
                                    .padding(.top, 8)
                                    .padding(.leading, 4)
                            }
                            TextEditor(text: $description)
                                .frame(minHeight: 80)
                        }
                    }
                } header: {
                    Text("Contenido")
                }

                Section {
                    ZStack(alignment: .topLeading) {
                        if extraText.isEmpty {
                            Text("Texto adicional, contexto, citas...")
                                .foregroundColor(.secondary)
                                .padding(.top, 8)
                                .padding(.leading, 4)
                        }
                        TextEditor(text: $extraText)
                            .frame(minHeight: 60)
                    }
                } header: {
                    Text("Contexto extra (opcional)")
                } footer: {
                    Text("Añade citas, datos, o cualquier texto que quieras que el agente considere")
                }

                // Info
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "sparkles")
                            .foregroundColor(.purple)
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("El agente generará:")
                                .font(.footnote.weight(.semibold))
                            Text("Post LinkedIn · Instagram · Twitter · TikTok script")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                // Botón generar
                Section {
                    Button {
                        Task { await generate() }
                    } label: {
                        HStack {
                            Spacer()
                            if viewModel.isGenerating {
                                ProgressView()
                                    .padding(.trailing, 8)
                                Text("Generando...")
                            } else {
                                Image(systemName: "sparkles")
                                Text("Generar posts con IA")
                                    .fontWeight(.semibold)
                            }
                            Spacer()
                        }
                    }
                    .disabled(!canGenerate || viewModel.isGenerating)
                    .foregroundColor(canGenerate ? .white : .secondary)
                    .listRowBackground(canGenerate ? Color.purple : Color.gray.opacity(0.3))
                }
            }
            .navigationTitle("Nuevo post IA")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancelar") { dismiss() }
                }
            }
            .alert("¡Listo!", isPresented: $showSuccess) {
                Button("Ver posts") { dismiss() }
            } message: {
                Text("El agente ha generado los posts. Puedes revisarlos en la sección IA.")
            }
            .alert("Error al generar", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.error ?? "Error desconocido")
            }
        }
    }

    private func generate() async {
        let success = await viewModel.generateContent(
            title: title,
            description: description,
            url: inputMode == .url ? url : "",
            extraText: extraText
        )
        if success {
            showSuccess = true
        } else {
            showError = true
        }
    }
}

#Preview {
    AgentTriggerView(viewModel: ContentDailyViewModel.shared)
}
