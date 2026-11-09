import SwiftUI

/// iOS-C5 Información pública (sin sesión y desde Inicio).
struct InformacionPublicaView: View {
    @State private var viewModel = InformacionPublicaViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: DSSpacing.medium) {
                SeccionTitulo("Ocupación")
                ForEach(viewModel.ocupacion) { planta in
                    DSCard {
                        HStack {
                            Text(planta.titulo).font(DSFont.subtitle)
                            Spacer()
                            Text(planta.resumen).font(DSFont.bodySecondary).foregroundStyle(DSColor.textSecondary)
                        }
                        ProgressView(value: planta.progreso)
                            .tint(DSColor.action)
                            .accessibilityHidden(true)
                    }
                    .accessibilityElement(children: .combine)
                }
                SeccionTitulo("Médicos de turno ahora")
                ListaTarjeta(items: viewModel.medicosDeTurno) { medico in
                    ResumenRow(
                        titulo: medico.nombre,
                        detalle: medico.horario,
                        status: DSStatus(domain: "Especialidad", title: medico.especialidad, systemImage: nil, tone: .neutral)
                    )
                }
                SeccionTitulo("Avisos")
                ForEach(viewModel.avisos) { aviso in
                    DSBanner("\(aviso.titulo): \(aviso.detalle)", kind: .notice)
                }
            }
            .pantallaPrincipal()
        }
        .background(DSColor.backgroundGrouped)
        .navigationTitle("Hospital hoy")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }
}

#Preview {
    NavigationStack { InformacionPublicaView() }
}
