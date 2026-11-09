import SwiftUI

/// Fila de tarjeta del Figma (título, detalle, badge y chevron opcionales) que comparten
/// Inicio, Turnos, Citas y Mi salud.
struct ResumenRow: View {
    let titulo: String
    var detalle: String?
    var status: DSStatus?
    var muestraChevron = false

    var body: some View {
        HStack(spacing: DSSpacing.small) {
            VStack(alignment: .leading, spacing: 2) {
                Text(titulo)
                    .font(DSFont.bodySecondaryEmphasis)
                    .foregroundStyle(DSColor.textPrimary)
                if let detalle {
                    Text(detalle)
                        .font(DSFont.footnote)
                        .foregroundStyle(DSColor.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let status {
                DSStatusBadge(status)
            }
            if muestraChevron {
                Image(systemName: "chevron.right")
                    .font(DSFont.footnote)
                    .foregroundStyle(DSColor.textTertiary)
                    .accessibilityHidden(true)
            }
        }
        .padding(.vertical, DSSpacing.small)
        .frame(minHeight: 52)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

/// Tarjeta con filas separadas por una línea (padding 4/16 del Figma).
struct ListaTarjeta<Item: Identifiable, Row: View>: View {
    let items: [Item]
    @ViewBuilder let row: (Item) -> Row

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                row(item)
                    .overlay(alignment: .bottom) {
                        if index < items.count - 1 {
                            Rectangle().fill(DSColor.border).frame(height: 1)
                        }
                    }
            }
        }
        .padding(.vertical, DSSpacing.tiny)
        .padding(.horizontal, DSSpacing.regular)
        .dsCardBackground()
    }
}

/// Rótulo de sección en mayúsculas ("MÉDICOS DE TURNO AHORA").
struct SeccionTitulo: View {
    let texto: String

    init(_ texto: String) {
        self.texto = texto
    }

    var body: some View {
        Text(texto)
            .dsEyebrow()
            .foregroundStyle(DSColor.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, DSSpacing.tiny)
            .accessibilityAddTraits(.isHeader)
    }
}

/// Fila que abre la información pública del hospital desde Inicio.
struct InformacionHospitalLink: View {
    var body: some View {
        NavigationLink {
            InformacionPublicaView()
        } label: {
            HStack(spacing: DSSpacing.medium) {
                Image(systemName: "building.2")
                    .font(.title3)
                    .foregroundStyle(DSColor.tint)
                    .accessibilityHidden(true)
                ResumenRow(
                    titulo: "Información del hospital",
                    detalle: "Ocupación, médicos de turno y avisos",
                    muestraChevron: true
                )
            }
            .padding(.horizontal, DSSpacing.regular)
            .dsCardBackground()
        }
        .buttonStyle(.plain)
    }
}

extension EstadoAmbulancia {
    var status: DSStatus {
        switch self {
        case .disponible: .ambulanciaDisponible
        case .enServicio: .ambulanciaEnServicio
        case .enMantenimiento: .ambulanciaEnMantenimiento
        }
    }
}

extension View {
    /// Fondo y margen de las pestañas principales (ScrollView de tarjetas).
    func pantallaPrincipal() -> some View {
        padding(.horizontal, DSSpacing.regular)
            .padding(.top, DSSpacing.small)
            .padding(.bottom, DSSpacing.regular)
    }
}
