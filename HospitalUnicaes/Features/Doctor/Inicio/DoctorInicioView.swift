import SwiftUI

/// iOS-D1 Inicio (Figma). La próxima cita abre la pestaña Agenda.
struct DoctorInicioView: View {
    @State private var viewModel: DoctorInicioViewModel
    @Environment(\.scenePhase) private var scenePhase
    private let onAbrir: (DoctorTab) -> Void

    init(
        me: Me,
        dependencies: DoctorDependencies,
        hoy: @escaping () -> Date = Date.init,
        onAbrir: @escaping (DoctorTab) -> Void
    ) {
        _viewModel = State(initialValue: DoctorInicioViewModel(
            me: me,
            turnos: dependencies.turnos,
            citas: dependencies.citas,
            laboratorio: dependencies.ordenesLaboratorio,
            ambulancias: dependencies.ambulancias,
            avisos: dependencies.avisos,
            hoy: hoy
        ))
        self.onAbrir = onAbrir
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DSSpacing.medium) {
                    Text(viewModel.fecha)
                        .font(DSFont.bodySecondary)
                        .foregroundStyle(DSColor.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    contenido
                    InformacionHospitalLink()
                }
                .pantallaPrincipal()
            }
            .refreshable { await viewModel.cargar() }
            .doctorScreen()
            .navigationTitle(viewModel.saludo)
        }
        .task { await viewModel.cargar() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await viewModel.cargar() } }
        }
    }

    @ViewBuilder
    private var contenido: some View {
        if viewModel.isLoading {
            ProgressView("Cargando tu información…")
                .frame(maxWidth: .infinity, minHeight: 200)
        } else if let message = viewModel.errorMessage {
            VStack(spacing: DSSpacing.medium) {
                DSBanner(message)
                DSButton("Reintentar", systemImage: "arrow.clockwise") { Task { await viewModel.cargar() } }
            }
        } else {
            if let parcial = viewModel.errorParcial {
                DSBanner(parcial)
            }
            if let turno = viewModel.resumen.turno {
                turnoCard(turno)
            } else {
                sinTurnoCard
            }
            if let cita = viewModel.resumen.proximaCita {
                proximaCitaCard(cita)
            }
            laboratorioCard
            if viewModel.resumen.ambulancia != nil {
                ambulanciaCard
            }
            if let aviso = viewModel.resumen.aviso {
                DSBanner("\(aviso.titulo): \(aviso.detalle)", kind: .notice)
            }
        }
    }

    private var sinTurnoCard: some View {
        Button { onAbrir(.turnos) } label: {
            DSCard {
                Text("Turno de hoy").dsEyebrow().foregroundStyle(DSColor.textSecondary)
                Text("No tienes turno hoy").font(DSFont.subtitle)
            }
        }
        .buttonStyle(.plain)
        .accessibilityHint("Abre tus turnos")
    }

    private func turnoCard(_ turno: DoctorInicioResumen.Turno) -> some View {
        Button { onAbrir(.turnos) } label: {
            VStack(alignment: .leading, spacing: DSSpacing.tiny) {
                Text("Turno en curso").dsEyebrow().foregroundStyle(DSColor.textSecondary)
                HStack {
                    Text("\(turno.horario) · \(turno.area)")
                        .font(DSFont.subtitle)
                        .foregroundStyle(DSColor.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    DSStatusBadge(.turnoEnCurso)
                }
                Text(turno.especialidad)
                    .font(DSFont.bodySecondary)
                    .foregroundStyle(DSColor.textSecondary)
            }
            .padding(.vertical, 14)
            .padding(.horizontal, DSSpacing.regular)
            .dsCardBackground()
            .overlay {
                RoundedRectangle(cornerRadius: DSRadius.card, style: .continuous)
                    .strokeBorder(DSColor.action, lineWidth: 2)
            }
        }
        .buttonStyle(.plain)
        .accessibilityHint("Abre tus turnos")
    }

    private func proximaCitaCard(_ cita: DoctorInicioResumen.ProximaCita) -> some View {
        Button { onAbrir(.agenda) } label: {
            DSCard(style: .highlighted) {
                Text("Próxima cita").dsEyebrow().opacity(0.9)
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(cita.hora) · \(cita.paciente)").font(DSFont.title)
                        Text(cita.motivo).font(DSFont.bodySecondary).opacity(0.9)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "chevron.right").fontWeight(.semibold).accessibilityHidden(true)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityHint("Abre la agenda")
    }

    private var laboratorioCard: some View {
        DSCard {
            Text("Laboratorio de mis pacientes").font(DSFont.subtitle)
            ForEach(viewModel.conteosLaboratorio, id: \.estado) { conteo in
                HStack(spacing: DSSpacing.medium) {
                    Text("\(conteo.cantidad)")
                        .font(.system(.title2, weight: .bold))
                        .frame(minWidth: 28, alignment: .leading)
                    DSStatusBadge(conteo.estado.status)
                    Spacer()
                }
                .frame(minHeight: DSSize.minTapTarget)
                .accessibilityElement(children: .combine)
            }
        }
    }

    private var ambulanciaCard: some View {
        DSCard {
            HStack(spacing: DSSpacing.medium) {
                Image(systemName: "light.beacon.max")
                    .font(.title3)
                    .foregroundStyle(DSColor.textSecondary)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Ambulancia").font(DSFont.bodySecondaryEmphasis)
                    Text("Solo lectura").font(DSFont.footnote).foregroundStyle(DSColor.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if let estado = viewModel.resumen.ambulancia { DSStatusBadge(estado.status) }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    DoctorInicioView(me: .previewDoctor, dependencies: .preview) { _ in }
}
