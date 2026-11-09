import SwiftUI

/// Línea de tiempo vertical de estados (handoff §6): círculo teal con ✓ en los pasos hechos,
/// círculo vacío y "Aún no" en los que faltan.
struct LineaDeTiempoEstado: View {
    struct Paso: Identifiable {
        let titulo: String
        /// `nil` si el paso todavía no ocurre.
        let fecha: Date?

        var id: String { titulo }
        var hecho: Bool { fecha != nil }
        var detalle: String {
            guard let fecha else { return "Aún no" }
            return "\(Formatting.fechaCorta(fecha)) · \(Formatting.hora(fecha))"
        }
    }

    let pasos: [Paso]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(pasos.enumerated()), id: \.element.id) { index, paso in
                HStack(alignment: .top, spacing: DSSpacing.medium) {
                    VStack(spacing: 0) {
                        marcador(paso)
                        if index < pasos.count - 1 {
                            Rectangle()
                                .fill(pasos[index + 1].hecho ? DSColor.action : DSColor.border)
                                .frame(width: 2)
                                .frame(minHeight: 24)
                        }
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(paso.titulo)
                            .font(DSFont.bodySecondaryEmphasis)
                            .foregroundStyle(paso.hecho ? DSColor.textPrimary : DSColor.textSecondary)
                        Text(paso.detalle)
                            .font(DSFont.footnote)
                            .foregroundStyle(DSColor.textSecondary)
                    }
                    .padding(.bottom, index < pasos.count - 1 ? DSSpacing.regular : 0)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(paso.titulo): \(paso.hecho ? paso.detalle : "aún no")")
            }
        }
    }

    @ViewBuilder
    private func marcador(_ paso: Paso) -> some View {
        if paso.hecho {
            Image(systemName: "checkmark")
                .font(.caption.weight(.bold))
                .foregroundStyle(DSColor.onAction)
                .frame(width: 24, height: 24)
                .background(DSColor.action, in: Circle())
        } else {
            Circle()
                .strokeBorder(DSColor.borderStrong, lineWidth: 2)
                .frame(width: 24, height: 24)
        }
    }
}

#Preview {
    LineaDeTiempoEstado(pasos: [
        .init(titulo: "Pendiente", fecha: Date()),
        .init(titulo: "En Proceso", fecha: Date()),
        .init(titulo: "Completado", fecha: nil),
    ])
    .padding()
}
