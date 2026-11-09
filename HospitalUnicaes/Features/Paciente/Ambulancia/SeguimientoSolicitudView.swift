import SwiftUI

/// iOS-P11 Seguimiento de solicitud (Figma 44:3179). Se actualiza en vivo desde el ViewModel.
struct SeguimientoSolicitudView: View {
    let solicitud: SolicitudAmbulancia
    let error: String?
    let reintentar: () async -> Void
    let solicitarOtra: () -> Void

    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if let error {
            DSBanner(error)
            DSButton("Reintentar", systemImage: "arrow.clockwise", kind: .secondary, size: .compact) {
                Task { await reintentar() }
            }
        }
        EstadoSolicitudCard(solicitud: solicitud)
            .animation(reduceMotion ? nil : .default, value: solicitud.estado)
        DSCard(spacing: 0) {
            let pasos = solicitud.pasos
            ForEach(Array(pasos.enumerated()), id: \.element.id) { indice, paso in
                Paso(titulo: paso.titulo, detalle: paso.detalle, hecho: paso.hecho, esUltimo: indice == pasos.count - 1)
            }
        }
        .animation(reduceMotion ? nil : .default, value: solicitud.pasos)
        if solicitud.estado.estaAbierta {
            nota("Otros finales posibles: Rechazada (con motivo de recepción) o No disponible.")
        }
        if let ubicacion = solicitud.ubicacionTexto {
            nota(ubicacion)
        }
        if let telefono = AppConfig.hospitalTelefono, let url = URL(string: "tel://\(telefono.filter(\.isNumber))") {
            DSButton("Llamar al hospital", systemImage: "phone", kind: .secondary) { openURL(url) }
        }
        if !solicitud.estado.estaAbierta {
            DSButton("Solicitar ambulancia", systemImage: "light.beacon.max", action: solicitarOtra)
        }
    }

    private func nota(_ texto: String) -> some View {
        Text(texto)
            .font(DSFont.footnote)
            .foregroundStyle(DSColor.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Tarjeta de estado con fondo y borde del tono del estado.
private struct EstadoSolicitudCard: View {
    let solicitud: SolicitudAmbulancia

    var body: some View {
        let tono = solicitud.estado.tono
        VStack(alignment: .leading, spacing: DSSpacing.small) {
            DSStatusBadge(solicitud.estado.status, size: .large)
            Text(solicitud.titulo).font(DSFont.subtitle)
            if let subtitulo = solicitud.subtitulo {
                Text(subtitulo).font(DSFont.bodySecondary).foregroundStyle(DSColor.textSecondary)
            }
        }
        .foregroundStyle(DSColor.textPrimary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DSSpacing.regular)
        .background(tono.background, in: RoundedRectangle(cornerRadius: DSRadius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: DSRadius.card, style: .continuous).strokeBorder(tono.border)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Sin solicitud activa (handoff §10.1).
struct SeguimientoVacioView: View {
    let solicitarOtra: () -> Void

    var body: some View {
        DSCard(spacing: DSSpacing.small) {
            Text("No tienes solicitudes activas").font(DSFont.subtitle)
            Text("Tus solicitudes de ambulancia aparecerán aquí.")
                .font(DSFont.bodySecondary)
                .foregroundStyle(DSColor.textSecondary)
        }
        DSButton("Solicitar ambulancia", systemImage: "light.beacon.max", action: solicitarOtra)
    }
}

private struct Paso: View {
    let titulo: String
    let detalle: String
    let hecho: Bool
    var esUltimo = false

    var body: some View {
        HStack(alignment: .top, spacing: DSSpacing.medium) {
            VStack(spacing: 0) {
                Image(systemName: hecho ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(hecho ? DSColor.action : DSColor.textTertiary)
                    .font(.title3)
                if !esUltimo {
                    Rectangle().fill(DSColor.border).frame(width: 2).frame(minHeight: 24)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(titulo).font(DSFont.bodySecondaryEmphasis)
                    .foregroundStyle(hecho ? DSColor.textPrimary : DSColor.textSecondary)
                if !detalle.isEmpty {
                    Text(detalle).font(DSFont.footnote).foregroundStyle(DSColor.textSecondary)
                }
            }
            .padding(.bottom, esUltimo ? 0 : DSSpacing.medium)
            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(hecho ? "Completado" : "Pendiente")
    }
}
