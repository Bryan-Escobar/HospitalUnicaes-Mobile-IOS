import SwiftUI

/// iOS-D11 Mis turnos (HUNI-54): esta semana y la siguiente, el turno en curso arriba.
struct TurnosView: View {
    @State private var viewModel: TurnosViewModel
    @Environment(\.scenePhase) private var scenePhase

    init(service: any TurnosService, hoy: @escaping () -> Date = Date.init) {
        _viewModel = State(initialValue: TurnosViewModel(service: service, hoy: hoy))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DSSpacing.medium) {
                    Picker("Semana", selection: $viewModel.semana) {
                        ForEach(TurnosSemana.allCases) { semana in
                            Text(semana.titulo).tag(semana)
                        }
                    }
                    .pickerStyle(.segmented)
                    contenido
                }
                .pantallaPrincipal()
            }
            .refreshable { await viewModel.cargar() }
            .doctorScreen()
            .navigationTitle("Turnos")
        }
        .task { await viewModel.cargar() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await viewModel.cargar() } }
        }
    }

    @ViewBuilder
    private var contenido: some View {
        if viewModel.isLoading {
            DoctorLoadingList()
        } else if let message = viewModel.errorMessage {
            DoctorRetry(message: message) { Task { await viewModel.cargar() } }
        } else if viewModel.estaVacio {
            ContentUnavailableView {
                Label("Sin turnos asignados", systemImage: "clock")
            } description: {
                Text(viewModel.semana == .actual
                    ? "No tienes turnos esta semana. Consulta la siguiente o pregunta a recepción."
                    : "Todavía no tienes turnos la semana siguiente.")
            } actions: {
                if viewModel.semana == .actual {
                    Button("Ver semana siguiente") { viewModel.semana = .siguiente }
                }
            }
        } else {
            if let hoy = viewModel.turnoDeHoy {
                turnoDeHoy(hoy)
            }
            ListaTarjeta(items: viewModel.restantes) { turno in
                ResumenRow(
                    titulo: titulo(turno),
                    detalle: detalle(turno),
                    status: turno.estado == .programado ? especialidad(turno) : nil
                )
                .opacity(turno.estado == .terminado ? 0.6 : 1)
            }
        }
    }

    private func turnoDeHoy(_ turno: TurnoDia) -> some View {
        VStack(alignment: .leading, spacing: DSSpacing.tiny) {
            HStack {
                Text(titulo(turno))
                    .font(DSFont.subtitle)
                    .frame(maxWidth: .infinity, alignment: .leading)
                DSStatusBadge(.turnoEnCurso)
            }
            Text(Formatting.unir([turno.area, turno.especialidad]))
                .font(DSFont.bodySecondary)
                .foregroundStyle(DSColor.textSecondary)
        }
        .foregroundStyle(DSColor.textPrimary)
        .padding(.vertical, 14)
        .padding(.horizontal, DSSpacing.regular)
        .dsCardBackground()
        .overlay {
            RoundedRectangle(cornerRadius: DSRadius.card, style: .continuous)
                .strokeBorder(DSColor.action, lineWidth: 2)
        }
        .accessibilityElement(children: .combine)
    }

    private func titulo(_ turno: TurnoDia) -> String {
        let dia = "\(Formatting.diaCorto(turno.dia)) \(Formatting.diaNumero(turno.dia))"
        guard let horario = turno.horario else { return dia }
        return "\(dia) · \(horario)"
    }

    private func detalle(_ turno: TurnoDia) -> String {
        guard let area = turno.area else { return "Sin turno" }
        return turno.estado == .terminado ? "\(area) · Terminado" : area
    }

    private func especialidad(_ turno: TurnoDia) -> DSStatus? {
        turno.especialidad.map { DSStatus(domain: "Especialidad", title: $0, systemImage: nil, tone: .neutral) }
    }
}

#Preview {
    TurnosView(service: PreviewTurnosService())
}
