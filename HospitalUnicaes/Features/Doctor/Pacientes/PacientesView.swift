import SwiftUI

/// iOS-D4 Mis pacientes.
struct PacientesView: View {
    @State private var viewModel: PacientesViewModel
    private let dependencies: DoctorDependencies

    init(dependencies: DoctorDependencies) {
        self.dependencies = dependencies
        _viewModel = State(initialValue: PacientesViewModel(pacientesService: dependencies.pacientes))
    }

    var body: some View {
        NavigationStack {
            contenido
                .doctorScreen()
                .navigationTitle("Pacientes")
                .searchable(text: $viewModel.texto, prompt: "Buscar por nombre o documento")
                .onChange(of: viewModel.texto) { _, _ in
                    viewModel.programarBusqueda()
                }
                .navigationDestination(for: DoctorRoute.self) { route in
                    DoctorDestination(route: route, dependencies: dependencies)
                }
        }
        .task { await viewModel.cargarPrimeraPagina() }
    }

    private var descripcionVacio: String {
        viewModel.buscando
            ? "Prueba con otro nombre o documento."
            : "Aparecerán cuando atiendas tu primera cita."
    }

    @ViewBuilder
    private var contenido: some View {
        if viewModel.isLoading && viewModel.pacientes.isEmpty && viewModel.errorMessage == nil {
            DoctorLoadingList()
        } else if let message = viewModel.errorMessage, viewModel.pacientes.isEmpty {
            DoctorRetry(message: message) { Task { await viewModel.recargar() } }
        } else if viewModel.estaVacio {
            ContentUnavailableView(
                viewModel.buscando ? "No encontramos pacientes con ese nombre" : "Aún no tienes pacientes",
                systemImage: "person.2",
                description: Text(descripcionVacio)
            )
        } else {
            lista
        }
    }

    private var lista: some View {
        List(viewModel.pacientes) { paciente in
            NavigationLink(value: DoctorRoute.expediente(pacienteId: paciente.id, nombre: paciente.nombreCompleto)) {
                PacienteRow(paciente: paciente)
            }
            .listRowBackground(DSColor.surface)
            .onAppear {
                Task { await viewModel.cargarSiguienteSiHaceFalta(actual: paciente) }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .refreshable { await viewModel.recargar() }
    }
}

private struct PacienteRow: View {
    let paciente: Paciente

    var body: some View {
        HStack(spacing: DSSpacing.medium) {
            DSAvatar(name: paciente.nombreCompleto)
            VStack(alignment: .leading, spacing: 2) {
                Text(paciente.nombreCompleto)
                    .font(DSFont.bodySecondaryEmphasis)
                    .foregroundStyle(DSColor.textPrimary)
                Text(subtitulo)
                    .font(DSFont.footnote)
                    .foregroundStyle(DSColor.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minHeight: 52)
    }

    private var subtitulo: String {
        let edad = Formatting.edad(fechaNacimiento: paciente.fechaNacimiento)
        return Formatting.subtituloLista(
            edad: edad,
            documento: paciente.documentoIdentidad,
            expediente: paciente.numeroExpediente
        )
    }
}
