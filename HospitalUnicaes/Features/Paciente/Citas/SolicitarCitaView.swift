import SwiftUI

/// iOS-P4 Solicitar cita (sheet).
struct SolicitarCitaView: View {
    @State private var viewModel = SolicitarCitaViewModel()
    @Environment(\.dismiss) private var dismiss
    let onEnviada: (SolicitudCita) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DSSpacing.medium) {
                    DSTextField(
                        "Motivo",
                        text: $viewModel.motivo,
                        prompt: "Cuéntanos qué necesitas",
                        errorMessage: viewModel.motivoError,
                        axis: .vertical
                    )
                    SeccionTitulo("Especialidad o tipo de doctor")
                    Chips(opciones: SolicitarCitaViewModel.especialidades, seleccion: $viewModel.especialidad)
                    SeccionTitulo("Preferencia de fecha")
                    DatePicker(
                        "Día preferido",
                        selection: $viewModel.diaPreferido,
                        in: Date()...,
                        displayedComponents: .date
                    )
                    .font(DSFont.bodySecondary)
                    .padding(.horizontal, DSSpacing.regular)
                    .frame(minHeight: 52)
                    .dsCardBackground()
                    Chips(opciones: SolicitarCitaViewModel.franjas, seleccion: $viewModel.franja)
                    DSButton("Enviar solicitud", systemImage: "paperplane") {
                        guard let solicitud = viewModel.enviar() else { return }
                        onEnviada(solicitud)
                        dismiss()
                    }
                    .padding(.top, DSSpacing.small)
                }
                .padding(DSSpacing.regular)
            }
            .background(DSColor.backgroundGrouped)
            .navigationTitle("Solicitar cita")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
            }
        }
    }
}

/// Chips de selección única (Figma `chips`).
struct Chips: View {
    let opciones: [String]
    @Binding var seleccion: String

    var body: some View {
        FlujoChips {
            ForEach(opciones, id: \.self) { opcion in
                let elegida = opcion == seleccion
                Button { seleccion = opcion } label: {
                    HStack(spacing: DSSpacing.tiny) {
                        if elegida {
                            Image(systemName: "checkmark").fontWeight(.bold).imageScale(.small)
                        }
                        Text(opcion)
                    }
                    .font(DSFont.bodySecondaryEmphasis)
                    .foregroundStyle(elegida ? DSColor.tint : DSColor.textPrimary)
                    .padding(.horizontal, DSSpacing.medium)
                    .frame(minHeight: DSSize.minTapTarget)
                    .background(elegida ? DSColor.selection : DSColor.surface, in: Capsule())
                    .overlay {
                        Capsule().strokeBorder(elegida ? DSColor.tint : DSColor.borderInput, lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(elegida ? .isSelected : [])
            }
        }
    }
}

/// Acomoda los chips en filas y pasa a la siguiente cuando no caben.
private struct FlujoChips: Layout {
    var espacio: CGFloat = DSSpacing.small

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let posiciones = acomodar(subviews, ancho: proposal.width ?? .infinity)
        let ancho = posiciones.map(\.maxX).max() ?? 0
        let alto = posiciones.map(\.maxY).max() ?? 0
        return CGSize(width: ancho, height: alto)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let posiciones = acomodar(subviews, ancho: bounds.width)
        for (vista, marco) in zip(subviews, posiciones) {
            vista.place(
                at: CGPoint(x: bounds.minX + marco.minX, y: bounds.minY + marco.minY),
                proposal: ProposedViewSize(marco.size)
            )
        }
    }

    private func acomodar(_ subviews: Subviews, ancho: CGFloat) -> [CGRect] {
        var origen = CGPoint.zero
        var altoFila: CGFloat = 0
        return subviews.map { vista in
            let tamano = vista.sizeThatFits(.unspecified)
            if origen.x > 0, origen.x + tamano.width > ancho {
                origen = CGPoint(x: 0, y: origen.y + altoFila + espacio)
                altoFila = 0
            }
            let marco = CGRect(origin: origen, size: tamano)
            origen.x += tamano.width + espacio
            altoFila = max(altoFila, tamano.height)
            return marco
        }
    }
}

#Preview {
    SolicitarCitaView { _ in }
}
