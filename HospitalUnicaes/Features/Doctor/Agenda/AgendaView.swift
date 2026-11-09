import SwiftUI

/// iOS-D2 Agenda del día.
struct AgendaView: View {
    @State private var viewModel: AgendaViewModel
    @State private var path = NavigationPath()
    private let dependencies: DoctorDependencies
    @Environment(\.scenePhase) private var scenePhase

    init(dependencies: DoctorDependencies, hoy: @escaping () -> Date = Date.init) {
        self.dependencies = dependencies
        _viewModel = State(initialValue: AgendaViewModel(citasService: dependencies.citas, hoy: hoy))
    }

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                WeekStripView(
                    semana: viewModel.semana,
                    seleccionado: viewModel.diaSeleccionado,
                    onSelect: viewModel.seleccionar,
                    onPrevious: viewModel.semanaAnterior,
                    onNext: viewModel.semanaSiguiente
                )
                contenido
            }
            .doctorScreen()
            .navigationTitle("Agenda")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Hoy", action: viewModel.irAHoy)
                }
            }
            .navigationDestination(for: DoctorRoute.self) { route in
                DoctorDestination(route: route, dependencies: dependencies) {
                    path = NavigationPath()
                    Task { await viewModel.recargar() }
                }
            }
        }
        .task(id: viewModel.diaSeleccionado) { await viewModel.cargar() }
        .onAppear { Task { await viewModel.recargar() } }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await viewModel.recargar() } }
        }
    }

    @ViewBuilder
    private var contenido: some View {
        if viewModel.isLoading && viewModel.citas.isEmpty && viewModel.errorMessage == nil {
            DoctorLoadingList()
        } else if let message = viewModel.errorMessage, viewModel.citas.isEmpty {
            DoctorRetry(message: message) { Task { await viewModel.recargar() } }
        } else if viewModel.estaVacio {
            ContentUnavailableView {
                Label("Sin citas este día", systemImage: "calendar")
            } description: {
                Text("Elige otra fecha en el selector.")
            } actions: {
                Button("Ir a hoy", action: viewModel.irAHoy)
            }
        } else {
            lista
        }
    }

    private var lista: some View {
        List {
            Section {
                ForEach(viewModel.citas) { cita in
                    NavigationLink(value: DoctorRoute.cita(cita)) {
                        CitaRow(cita: cita)
                    }
                    .listRowBackground(DSColor.surface)
                }
            } header: {
                Text(viewModel.encabezado)
                    .font(DSFont.footnoteEmphasis)
                    .foregroundStyle(DSColor.textSecondary)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .refreshable { await viewModel.recargar() }
    }
}

private struct CitaRow: View {
    let cita: Cita

    var body: some View {
        HStack(alignment: .center, spacing: DSSpacing.medium) {
            Text(Formatting.hora(cita.fechaHora))
                .font(DSFont.bodySecondaryEmphasis)
                .foregroundStyle(DSColor.textPrimary)
                .frame(minWidth: 48, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(cita.pacienteNombre)
                    .font(DSFont.bodySecondaryEmphasis)
                    .foregroundStyle(DSColor.textPrimary)
                Text(cita.motivo?.nilIfBlank ?? "Sin motivo")
                    .font(DSFont.footnote)
                    .foregroundStyle(DSColor.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            DSStatusBadge(cita.estado.status)
        }
        .frame(minHeight: 52)
    }
}
