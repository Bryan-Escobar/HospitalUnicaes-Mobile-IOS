import SwiftUI

/// iOS-D3 Detalle de cita. "Iniciar consulta" abre un placeholder hasta HUNI-59.
struct DetalleCitaView: View {
    @State private var viewModel: DetalleCitaViewModel
    @State private var mostrarNuevaConsulta = false
    private let dependencies: DoctorDependencies
    /// HUNI-59: se llama cuando el formulario guarda la consulta (la agenda vuelve a la raíz y recarga).
    private let onConsultaGuardada: () -> Void
    @Environment(\.dismiss) private var dismiss

    init(cita: Cita, dependencies: DoctorDependencies, onConsultaGuardada: @escaping () -> Void = {}) {
        self.dependencies = dependencies
        self.onConsultaGuardada = onConsultaGuardada
        _viewModel = State(initialValue: DetalleCitaViewModel(
            cita: cita,
            citasService: dependencies.citas,
            pacientesService: dependencies.pacientes
        ))
    }

    var body: some View {
        Group {
            if viewModel.citaNoDisponible {
                noDisponible
            } else {
                detalle
            }
        }
        .doctorScreen()
        .navigationTitle("Cita \(Formatting.hora(viewModel.cita.fechaHora))")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.recargar() }
        .refreshable { await viewModel.recargar() }
        // HUNI-59: abrir iOS-D7
        .sheet(isPresented: $mostrarNuevaConsulta) {
            NuevaConsultaPlaceholder()
        }
    }

    private var detalle: some View {
        ScrollView {
            VStack(spacing: DSSpacing.medium) {
                paciente
                DSCard {
                    Text("Motivo").font(DSFont.fieldLabel).foregroundStyle(DSColor.textLabel)
                    Text(viewModel.cita.motivo?.nilIfBlank ?? "Sin motivo")
                        .font(DSFont.body)
                }
                datos
                if let alergias = viewModel.alergias {
                    AlergiaBanner(texto: "⚠ Alergia registrada: \(alergias)")
                }
                if viewModel.estado == .error {
                    DoctorRetry(message: "No se pudo cargar la cita.") {
                        Task { await viewModel.recargar() }
                    }
                }
            }
            .padding(DSSpacing.regular)
        }
        .safeAreaInset(edge: .bottom) { accion }
    }

    private var paciente: some View {
        DSCard {
            HStack(spacing: DSSpacing.medium) {
                DSAvatar(name: viewModel.cita.pacienteNombre, size: 56)
                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.cita.pacienteNombre).font(DSFont.subtitle)
                    if !viewModel.lineaPaciente.isEmpty {
                        Text(viewModel.lineaPaciente)
                            .font(DSFont.bodySecondary)
                            .foregroundStyle(DSColor.textSecondary)
                    }
                }
                Spacer(minLength: 0)
            }
            if viewModel.puedeVerExpediente {
                NavigationLink(value: DoctorRoute.expediente(
                    pacienteId: viewModel.cita.pacienteId,
                    nombre: viewModel.cita.pacienteNombre
                )) {
                    Text("Ver expediente")
                        .font(DSFont.buttonCompact)
                        .frame(maxWidth: .infinity, minHeight: DSSize.buttonCompactHeight)
                }
                .buttonStyle(DSButtonStyle(kind: .secondary, size: .compact))
            }
        }
    }

    private var datos: some View {
        DSCard {
            fila("Fecha y hora", Formatting.fechaYHora(viewModel.cita.fechaHora))
            HStack {
                Text("Estado").font(DSFont.bodySecondary).foregroundStyle(DSColor.textSecondary)
                Spacer()
                DSStatusBadge(viewModel.cita.estado.status)
            }
            .frame(minHeight: 52)
            fila("Duración", "\(viewModel.cita.duracionMinutos) min")
        }
    }

    private func fila(_ titulo: String, _ valor: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(titulo).font(DSFont.bodySecondary).foregroundStyle(DSColor.textSecondary)
            Spacer(minLength: DSSpacing.small)
            Text(valor).font(DSFont.bodySecondaryEmphasis).multilineTextAlignment(.trailing)
        }
        .frame(minHeight: 52)
    }

    @ViewBuilder
    private var accion: some View {
        switch viewModel.accionPrincipal {
        case .iniciarConsulta:
            DSButton("Iniciar consulta") { iniciarConsulta() }
                .padding(DSSpacing.regular)
                .background(DSColor.backgroundGrouped)
        case .verConsulta:
            verConsulta
        case .ninguna:
            EmptyView()
        }
    }

    @ViewBuilder
    private var verConsulta: some View {
        if let consulta = viewModel.consultaDeLaCita {
            NavigationLink(value: DoctorRoute.consulta(consulta)) {
                Text("Ver consulta")
                    .font(DSFont.button)
                    .frame(maxWidth: .infinity, minHeight: DSSize.buttonHeight)
            }
            .buttonStyle(DSButtonStyle())
            .padding(DSSpacing.regular)
            .background(DSColor.backgroundGrouped)
        } else if viewModel.puedeVerExpediente {
            NavigationLink(value: DoctorRoute.expediente(
                pacienteId: viewModel.cita.pacienteId,
                nombre: viewModel.cita.pacienteNombre
            )) {
                Text("Ver consulta")
                    .font(DSFont.button)
                    .frame(maxWidth: .infinity, minHeight: DSSize.buttonHeight)
            }
            .buttonStyle(DSButtonStyle())
            .padding(DSSpacing.regular)
        } else {
            EmptyView()
        }
    }

    private var noDisponible: some View {
        ContentUnavailableView {
            Label("Esta cita ya no está disponible", systemImage: "calendar.badge.exclamationmark")
        } description: {
            Text("Pudo ser cancelada o reprogramada por recepción.")
        } actions: {
            Button("Volver a la agenda") { dismiss() }
        }
    }

    private func iniciarConsulta() {
        dependencies.onIniciarConsulta(viewModel.cita)
        mostrarNuevaConsulta = true
    }
}

private struct NuevaConsultaPlaceholder: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Disponible pronto",
                systemImage: "stethoscope",
                description: Text("El registro de la consulta llega con HUNI-59.")
            )
            .navigationTitle("Nueva consulta")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
