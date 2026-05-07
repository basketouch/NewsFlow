import SwiftUI

struct SocialPostRow: View {
    let post: SocialPost
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Encabezado: Red social e información de estado
            HStack {
                // Indicador de red social
                Label(post.redSocial, systemImage: "network")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                // Estado de la publicación
                PostStatusBadge(post: post)
            }
            
            // Contenido principal de la publicación
            VStack(alignment: .leading, spacing: 6) {
                Text(post.textoEnriquecido.isEmpty ? post.texto : post.textoEnriquecido)
                    .font(.subheadline)
                    .lineLimit(3)

                if !post.hashtags.isEmpty {
                    Text(post.hashtags)
                        .font(.caption)
                        .foregroundColor(.blue)
                        .lineLimit(1)
                }
                
                // Fecha de publicación
                HStack {
                    Image(systemName: "calendar")
                        .font(.caption)

                    Text(post.formattedPublishDate)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    // Indicador de media
                    if post.hasMedia {
                        Image(systemName: post.mediaTypeEnum.iconName)
                            .font(.caption)
                            .foregroundColor(.purple)
                    }

                    // Si está aprobado, mostrar un check
                    if post.aprobado {
                        Spacer()

                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                    }
                }
            }
            
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .shadow(radius: 1)
    }
}

// Badge para mostrar el estado de la publicación
struct PostStatusBadge: View {
    let post: SocialPost
    
    var body: some View {
        Text(statusText)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(backgroundColor)
            .foregroundColor(foregroundColor)
            .cornerRadius(8)
    }
    
    // Texto según el estado
    private var statusText: String {
        if post.publicado {
            return "Publicado"
        } else if post.aprobado {
            return "Aprobadas"
        } else {
            return "Revisión"
        }
    }
    
    // Color de fondo según el estado
    private var backgroundColor: Color {
        if post.publicado {
            return Color.blue.opacity(0.2)
        } else if post.aprobado {
            return Color.green.opacity(0.2)
        } else {
            return Color.red.opacity(0.2)
        }
    }
    
    // Color del texto según el estado
    private var foregroundColor: Color {
        if post.publicado {
            return Color.blue
        } else if post.aprobado {
            return Color.green
        } else {
            return Color.red
        }
    }
}

#Preview {
    SocialPostRow(post: SocialPost.nuevo(
        texto: "Post de ejemplo para previsualización",
        redSocial: .linkedin,
        fecha: Date(),
        tematica: "IA",
        objetivo: "Interesante"
    ))
} 