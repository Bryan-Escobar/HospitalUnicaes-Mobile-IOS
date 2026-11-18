import SwiftUI

/// iOS-C5 Información pública (sin sesión desde el login y con sesión desde Inicio).
struct InformacionPublicaView: View {
    @State private var viewModel: InformacionPublicaViewModel
    @Environment(\.scenePhase) private var scenePhase

    init(service: any EstadoPublicoService) {
        _viewModel = State(initialValue: InformacionPublicaViewModel(service: service))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: DSSpacing.medium) {
                contenido
            }
            .pantallaPrincipal()
        }
        .refreshable { await viewModel.cargar() }
        .background(DSColor.backgroundGrouped)
        .navigationTitle("Hospital hoy")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .task { await viewModel.cargar() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await viewModel.cargar() } }
        }
    }

    @ViewBuilder
    private var contenido: some View {
        if viewModel.isLoading {
            ProgressView("Cargando información del hospital…")
                .frame(maxWidth: .infinity, minHeight: 200)
        } else if let message = viewModel.errorSinDatos {
            VStack(spacing: DSSpacing.medium) {
                DSBanner(message)
                DSButton("Reintentar", systemImage: "arrow.clockwise") { Task { await viewModel.cargar() } }
            }
        } else if viewModel.cargado {
            if let message = viewModel.errorRecarga {
                DSBanner(message)
            }
            ocupacion
            medicos
            avisos
            if let actualizado = viewModel.actualizado {
                Text(actualizado)
                    .font(DSFont.footnote)
                    .foregroundStyle(DSColor.textTertiary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    @ViewBuilder
    private var ocupacion: some View {
        SeccionTitulo("Ocupación")
        ForEach(viewModel.ocupacion) { planta in
            OcupacionCard(planta: planta)
        }
        if let total = viewModel.ocupacionTotal {
            ResumenRow(titulo: total.titulo, detalle: "\(total.resumen) · \(total.detalle)")
                .padding(.horizontal, DSSpacing.regular)
                .dsCardBackground()
        }
    }

    @ViewBuilder
    private var medicos: some View {
        SeccionTitulo("Médicos de turno ahora")
        if viewModel.sinMedicos {
            MensajeVacio("No hay médicos de turno registrados en este momento.")
        } else {
            ListaTarjeta(items: viewModel.medicosDeTurno) { medico in
                ResumenRow(
                    titulo: medico.nombre,
                    detalle: "\(medico.area) · \(medico.horario)",
                    status: DSStatus(domain: "Especialidad", title: medico.especialidad, systemImage: nil, tone: .neutral)
                )
            }
        }
    }

    @ViewBuilder
    private var avisos: some View {
        SeccionTitulo("Avisos")
        if viewModel.sinAvisos {
            MensajeVacio("No hay avisos vigentes.")
        } else {
            ForEach(viewModel.avisos) { aviso in
                DSBanner("\(aviso.titulo): \(aviso.detalle)", kind: .notice)
            }
        }
    }
}

private struct OcupacionCard: View {
    let planta: OcupacionPlanta

    var body: some View {
        DSCard {
            HStack {
                Text(planta.titulo).font(DSFont.subtitle)
                Spacer()
                Text(planta.resumen).font(DSFont.bodySecondary).foregroundStyle(DSColor.textSecondary)
            }
            ProgressView(value: planta.progreso)
                .tint(DSColor.action)
                .accessibilityHidden(true)
            Text(planta.detalle)
                .font(DSFont.footnote)
                .foregroundStyle(DSColor.textSecondary)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Texto gris dentro de una tarjeta para una sección sin datos.
struct MensajeVacio: View {
    let texto: String

    init(_ texto: String) {
        self.texto = texto
    }

    var body: some View {
        Text(texto)
            .font(DSFont.bodySecondary)
            .foregroundStyle(DSColor.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DSSpacing.regular)
            .dsCardBackground()
    }
}

#if DEBUG
#Preview {
    NavigationStack { InformacionPublicaView(service: PreviewEstadoPublicoService()) }
}
#endif
