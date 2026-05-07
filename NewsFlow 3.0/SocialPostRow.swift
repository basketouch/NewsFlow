import SwiftUI

struct SocialPostRow: View {
    let post: SocialPost

    private var networkColor: Color {
        switch post.redSocialEnum {
        case .linkedin: return Color(red: 0.0, green: 0.47, blue: 0.71)
        case .twitter:  return Color.primary
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            // Franja lateral de color de red social
            Rectangle()
                .fill(networkColor)
                .frame(width: 4)
                .cornerRadius(2)

            VStack(alignment: .leading, spacing: 8) {
                // Cabecera: badge de red social + estado
                HStack {
                    NetworkBadge(network: post.redSocialEnum)
                    Spacer()
                    PostStatusBadge(post: post)
                }

                // Texto principal
                Text(post.textoEnriquecido.isEmpty ? post.texto : post.textoEnriquecido)
                    .font(.subheadline)
                    .lineLimit(3)
                    .foregroundColor(.primary)

                // Hashtags
                if !post.hashtags.isEmpty {
                    Text(post.hashtags)
                        .font(.caption)
                        .foregroundColor(.blue)
                        .lineLimit(1)
                }

                // Footer: fecha + media + aprobado
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    Text(post.formattedPublishDate)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if post.hasMedia {
                        Image(systemName: post.mediaTypeEnum.iconName)
                            .font(.caption2)
                            .foregroundColor(.purple)
                    }

                    Spacer()

                    if post.aprobado {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

// MARK: - NetworkBadge

struct NetworkBadge: View {
    let network: SocialNetwork

    var body: some View {
        HStack(spacing: 4) {
            Text(symbol)
                .font(.caption.weight(.bold))
            Text(network.rawValue)
                .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(badgeColor.opacity(0.12))
        .foregroundColor(badgeColor)
        .cornerRadius(6)
    }

    private var symbol: String {
        switch network {
        case .linkedin: return "in"
        case .twitter:  return "𝕏"
        }
    }

    private var badgeColor: Color {
        switch network {
        case .linkedin: return Color(red: 0.0, green: 0.47, blue: 0.71)
        case .twitter:  return Color.primary
        }
    }
}

// MARK: - PostStatusBadge

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

    private var statusText: String {
        if post.publicado       { return "Publicado" }
        else if post.aprobado   { return "Aprobado"  }
        else                    { return "Revisión"  }
    }

    private var backgroundColor: Color {
        if post.publicado       { return Color.blue.opacity(0.15)  }
        else if post.aprobado   { return Color.green.opacity(0.15) }
        else                    { return Color.orange.opacity(0.15) }
    }

    private var foregroundColor: Color {
        if post.publicado       { return .blue   }
        else if post.aprobado   { return .green  }
        else                    { return .orange }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 12) {
        SocialPostRow(post: SocialPost.nuevo(
            texto: "Descubre cómo la IA está transformando el mundo del marketing digital en 2026.",
            redSocial: .linkedin,
            fecha: Date(),
            tematica: "IA",
            objetivo: "Informar"
        ))
        SocialPostRow(post: SocialPost.nuevo(
            texto: "El futuro del emprendimiento pasa por la automatización inteligente.",
            redSocial: .twitter,
            fecha: Date().addingTimeInterval(3600),
            tematica: "Emprendimiento",
            objetivo: "Motivar"
        ))
    }
    .padding()
}
