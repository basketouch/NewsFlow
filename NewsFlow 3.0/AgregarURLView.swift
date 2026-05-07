import SwiftUI

struct AgregarURLView: View {
    @ObservedObject var viewModel: SupabaseArticlesViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var urlText = ""
    @State private var isValidURL = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Image(systemName: "link")
                            .foregroundColor(.blue)
                        TextField("https://...", text: $urlText)
                            .keyboardType(.URL)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .onChange(of: urlText) { value in
                                isValidURL = URL(string: value)?.scheme?.hasPrefix("http") == true
                            }
                        if !urlText.isEmpty {
                            Button {
                                urlText = ""
                                isValidURL = false
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                } header: {
                    Text("URL del artículo")
                } footer: {
                    Text("Se extraerán automáticamente el título, descripción e imagen.")
                        .font(.caption)
                }

                if let error = viewModel.error {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .foregroundColor(.red)
                            .font(.callout)
                    }
                }

                Section {
                    Button {
                        Task {
                            let ok = await viewModel.save(urlString: urlText)
                            if ok { dismiss() }
                        }
                    } label: {
                        HStack {
                            if viewModel.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.85)
                                Text("Obteniendo datos...")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            } else {
                                Text("Guardar artículo")
                                    .frame(maxWidth: .infinity)
                            }
                        }
                    }
                    .disabled(!isValidURL || viewModel.isLoading)
                    .buttonStyle(.borderedProminent)
                }
            }
            .navigationTitle("Añadir URL")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancelar") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    AgregarURLView(viewModel: SupabaseArticlesViewModel.shared)
}
