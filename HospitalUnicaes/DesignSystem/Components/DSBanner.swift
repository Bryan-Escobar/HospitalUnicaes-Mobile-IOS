import SwiftUI

/// Banner de mensaje en línea (handoff §4.2): error de formulario o aviso.
///
/// ```swift
/// if let error = viewModel.errorMessage {
///     DSBanner(error)
/// }
/// ```
struct DSBanner: View {
    enum Kind {
        case error
        case notice
        case info

        var tone: DSTone {
            switch self {
            case .error: .error
            case .notice: .notice
            case .info: .info
            }
        }

        var systemImage: String {
            switch self {
            case .error: "exclamationmark.circle"
            case .notice: "exclamationmark.triangle"
            case .info: "info.circle"
            }
        }
    }

    private let message: String
    private let kind: Kind

    init(_ message: String, kind: Kind = .error) {
        self.message = message
        self.kind = kind
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: DSSpacing.small) {
            Image(systemName: kind.systemImage)
                .fontWeight(.semibold)
            Text(message)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(DSFont.bodySecondary)
        .foregroundStyle(kind.tone.foreground)
        .padding(.vertical, DSSpacing.medium)
        .padding(.horizontal, 14)
        .background(kind.tone.background, in: RoundedRectangle(cornerRadius: DSRadius.field, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: DSRadius.field, style: .continuous)
                .strokeBorder(kind.tone.border, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview("Banners") {
    VStack(spacing: DSSpacing.medium) {
        DSBanner("Correo o contraseña incorrectos")
        DSBanner("Supabase no está configurado.", kind: .notice)
        DSBanner("Te enviamos un correo para confirmar tu cuenta.", kind: .info)
    }
    .padding()
    .background(DSColor.background)
}
