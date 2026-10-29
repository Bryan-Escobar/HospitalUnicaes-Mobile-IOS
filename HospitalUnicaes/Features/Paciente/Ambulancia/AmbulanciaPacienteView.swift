import SwiftUI

/// iOS-P10 Solicitar ambulancia y iOS-P11 Seguimiento de solicitud.
struct AmbulanciaPacienteView: View {
    @State private var viewModel = AmbulanciaPacienteViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DSSpacing.medium) {
                    if let solicitud = viewModel.solicitud {
                        seguimiento(solicitud)
                    } else {
                        formulario
                    }
                }
                .pantallaPrincipal()
            }
            .background(DSColor.backgroundGrouped)
            .navigationTitle(viewModel.solicitud == nil ? "Ambulancia" : "Tu solicitud")
        }
    }

    // MARK: P10

    @ViewBuilder
    private var formulario: some View {
        DSCard {
            HStack {
                Text("Estado actual").font(DSFont.bodySecondaryEmphasis)
                Spacer()
                DSStatusBadge(viewModel.estado.status)
            }
        }
        DSCard(spacing: DSSpacing.medium) {
            Text("Ubicación").font(DSFont.subtitle)
            Button { viewModel.usarUbicacion.toggle() } label: {
                HStack(spacing: DSSpacing.medium) {
                    Image(systemName: "location").font(.title3).foregroundStyle(DSColor.tint)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Usar mi ubicación").font(DSFont.bodySecondaryEmphasis)
                        Text(AmbulanciaPacienteViewModel.ubicacionActual)
                            .font(DSFont.footnote)
                            .foregroundStyle(DSColor.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: viewModel.usarUbicacion ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(viewModel.usarUbicacion ? DSColor.tint : DSColor.textTertiary)
                }
                .foregroundStyle(DSColor.textPrimary)
                .padding(.vertical, 10)
                .padding(.horizontal, DSSpacing.medium)
                .background(
                    viewModel.usarUbicacion ? DSColor.selection : DSColor.surface,
                    in: RoundedRectangle(cornerRadius: DSRadius.field)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: DSRadius.field)
                        .strokeBorder(viewModel.usarUbicacion ? DSColor.action : DSColor.borderInput, lineWidth: 2)
                }
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(viewModel.usarUbicacion ? .isSelected : [])
            if !viewModel.usarUbicacion {
                DSTextField("O escribe la dirección", text: $viewModel.direccion, prompt: "Calle, número, referencia")
            }
        }
        DSCard(spacing: DSSpacing.medium) {
            Text("Tipo de emergencia").font(DSFont.subtitle)
            Chips(
                opciones: AmbulanciaPacienteViewModel.tipos,
                seleccion: Binding(get: { viewModel.tipo ?? "" }, set: { viewModel.tipo = $0 })
            )
            DSTextField(
                "Descripción",
                text: $viewModel.descripcion,
                prompt: "Describe brevemente qué ocurre",
                axis: .vertical
            )
        }
        if let ayuda = viewModel.ayuda {
            Text(ayuda)
                .font(DSFont.footnote)
                .foregroundStyle(DSColor.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        DSButton("Confirmar solicitud de ambulancia", systemImage: "light.beacon.max", kind: .destructive) {
            viewModel.confirmar()
        }
        .disabled(!viewModel.puedeConfirmar)
    }

    // MARK: P11

    @ViewBuilder
    private func seguimiento(_ solicitud: SolicitudAmbulancia) -> some View {
        VStack(alignment: .leading, spacing: DSSpacing.small) {
            DSStatusBadge(.solicitudEnviada, size: .large)
            Text("Recepción está revisando tu solicitud.").font(DSFont.subtitle)
            Text("Mantén tu teléfono cerca.").font(DSFont.bodySecondary).foregroundStyle(DSColor.textSecondary)
        }
        .foregroundStyle(DSColor.textPrimary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DSSpacing.regular)
        .background(DSTone.danger.background, in: RoundedRectangle(cornerRadius: DSRadius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: DSRadius.card, style: .continuous).strokeBorder(DSTone.danger.border)
        }
        DSCard(spacing: 0) {
            Paso(titulo: "Enviada", detalle: "\(Formatting.hora(solicitud.enviadaA)) · \(solicitud.tipo)", hecho: true)
            Paso(titulo: "Despachada (En Servicio)", detalle: "Aún no", hecho: solicitud.estado != .enviada)
            Paso(titulo: "Finalizada", detalle: "Aún no", hecho: solicitud.estado == .finalizada, esUltimo: true)
        }
        Text(solicitud.ubicacion)
            .font(DSFont.footnote)
            .foregroundStyle(DSColor.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
        DSButton("Nueva solicitud", kind: .secondary, action: viewModel.nuevaSolicitud)
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
                Text(detalle).font(DSFont.footnote).foregroundStyle(DSColor.textSecondary)
            }
            .padding(.bottom, esUltimo ? 0 : DSSpacing.medium)
            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(hecho ? "Completado" : "Pendiente")
    }
}

#Preview {
    AmbulanciaPacienteView()
}
