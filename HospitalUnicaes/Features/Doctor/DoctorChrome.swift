import SwiftUI

struct DoctorRetry: View {
    let message: String
    var detail: String?
    let action: () -> Void

    var body: some View {
        VStack(spacing: DSSpacing.medium) {
            DSBanner(message)
            if let detail {
                Text(detail)
                    .font(DSFont.bodySecondary)
                    .foregroundStyle(DSColor.textSecondary)
                    .multilineTextAlignment(.center)
            }
            DSButton("Reintentar", kind: .secondary, action: action)
        }
        .padding(DSSpacing.regular)
    }
}

struct DoctorLoadingList: View {
    var body: some View {
        VStack(spacing: DSSpacing.small) {
            ForEach(0..<4, id: \.self) { _ in
                DoctorPlaceholderRow()
            }
        }
        .padding(DSSpacing.regular)
        .redacted(reason: .placeholder)
        .accessibilityLabel("Cargando…")
    }
}

private struct DoctorPlaceholderRow: View {
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: DSSpacing.tiny) {
                Text("Nombre del paciente")
                Text("Detalle de la fila")
            }
            Spacer()
            Text("Estado")
        }
        .frame(minHeight: 52)
    }
}

struct AlergiaBanner: View {
    let texto: String

    var body: some View {
        DSBanner(texto, kind: .notice)
    }
}

extension View {
    func doctorScreen() -> some View {
        frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(DSColor.backgroundGrouped)
    }
}
