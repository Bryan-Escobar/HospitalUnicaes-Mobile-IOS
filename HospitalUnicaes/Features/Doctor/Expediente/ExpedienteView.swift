import SwiftUI

struct SinPermisoView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ContentUnavailableView {
            Label("No tienes permiso para ver este expediente", systemImage: "lock")
        } description: {
            Text("Solo lo ven el médico tratante, el propio paciente y la administración.")
        } actions: {
            Button("Volver") { dismiss() }
        }
        .doctorScreen()
    }
}

/// iOS-D5 Expediente del paciente.
struct ExpedienteView: View {
    @State private var viewModel: ExpedienteViewModel

    init(
        pacienteId: UUID,
        nombre: String,
        pacientes: any PacientesService,
        hospitalizaciones: any HospitalizacionesService
    ) {
        _viewModel = State(initialValue: ExpedienteViewModel(
            pacienteId: pacienteId,
            nombre: nombre,
            pacientesService: pacientes,
            hospitalizacionesService: hospitalizaciones
        ))
    }

    var body: some View {
        Group {
            switch viewModel.estado {
            case .cargando:
                DoctorLoadingList()
            case .sinPermiso:
                SinPermisoView()
            case .error:
                DoctorRetry(message: viewModel.errorMessage ?? "No se pudo cargar el expediente.") {
                    Task { await viewModel.recargar() }
                }
            case .cargado:
                cargado
            }
        }
        .doctorScreen()
        .navigationTitle(viewModel.nombre)
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.recargar() }
        .refreshable { await viewModel.recargar() }
    }

    private var cargado: some View {
        ScrollView {
            VStack(spacing: DSSpacing.medium) {
                cabecera
                if let alergias = viewModel.historial?.expediente.alergias?.nilIfBlank {
                    AlergiaBanner(texto: "⚠ Alergias: \(alergias)")
                }
                if let hospitalizacion = viewModel.hospitalizacion, hospitalizacion.estado == .activa {
                    DSCard {
                        Text("Hospitalización").font(DSFont.fieldLabel).foregroundStyle(DSColor.textLabel)
                        Text(hospitalizacion.tituloCama).font(DSFont.subtitle)
                        Text(hospitalizacion.detalleIngreso)
                            .font(DSFont.bodySecondary)
                            .foregroundStyle(DSColor.textSecondary)
                    }
                }
                Picker("Sección", selection: $viewModel.segmento) {
                    ForEach(ExpedienteSegmento.allCases) { segmento in
                        Text(segmento.titulo).tag(segmento)
                    }
                }
                .pickerStyle(.segmented)
                seccion
            }
            .padding(DSSpacing.regular)
        }
    }

    private var cabecera: some View {
        let paciente = viewModel.historial?.paciente
        let linea = Formatting.unir([
            Formatting.edad(fechaNacimiento: paciente?.fechaNacimiento).map(Formatting.edadTexto),
            paciente?.documentoIdentidad.map(Formatting.documento),
            paciente?.telefono,
        ])
        return DSCard {
            HStack(spacing: DSSpacing.medium) {
                DSAvatar(name: viewModel.nombre, size: 56)
                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.nombre).font(DSFont.subtitle)
                    if !linea.isEmpty {
                        Text(linea).font(DSFont.bodySecondary).foregroundStyle(DSColor.textSecondary)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var seccion: some View {
        switch viewModel.segmento {
        case .consultas: consultas
        case .laboratorio: laboratorio
        case .datos: datos
        }
    }

    @ViewBuilder
    private var consultas: some View {
        if viewModel.historial?.consultas.isEmpty != false {
            ContentUnavailableView(
                "Sin consultas registradas",
                systemImage: "text.page",
                description: Text("Inicia una consulta desde una cita.")
            )
        } else {
            VStack(spacing: DSSpacing.small) {
                ForEach(viewModel.historial?.consultas ?? []) { consulta in
                    NavigationLink(value: DoctorRoute.consulta(consulta)) {
                        ConsultaRow(consulta: consulta)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private var laboratorio: some View {
        if viewModel.ordenes.isEmpty {
            ContentUnavailableView("Sin órdenes de laboratorio", systemImage: "cross.case")
        } else {
            VStack(spacing: DSSpacing.small) {
                ForEach(viewModel.ordenes) { orden in
                    OrdenRow(orden: orden)
                }
            }
        }
    }

    private var datos: some View {
        let expediente = viewModel.historial?.expediente
        let paciente = viewModel.historial?.paciente
        return DSCard {
            dato("Número de expediente", expediente?.numeroExpediente)
            dato("Tipo de sangre", expediente?.tipoSangre)
            dato("Alergias", expediente?.alergias)
            dato("Antecedentes", expediente?.antecedentes)
            dato("Enfermedades crónicas", expediente?.enfermedadesCronicas)
            dato("Fecha de nacimiento", Formatting.fechaNacimiento(paciente?.fechaNacimiento))
            dato("Sexo", paciente?.sexo?.nombre)
            dato("Teléfono", paciente?.telefono)
            dato("Contacto de emergencia", paciente?.contactoEmergencia)
            dato("Teléfono de emergencia", paciente?.telefonoEmergencia)
        }
    }

    private func dato(_ titulo: String, _ valor: String?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(titulo).font(DSFont.footnote).foregroundStyle(DSColor.textSecondary)
            Text(titulo == "Fecha de nacimiento" ? (valor ?? "No registrado") : Formatting.valor(valor))
                .font(DSFont.bodySecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, DSSpacing.small)
    }
}

private struct ConsultaRow: View {
    let consulta: ConsultaDetalle

    var body: some View {
        HStack(spacing: DSSpacing.small) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(Formatting.fechaCorta(consulta.fecha)) · \(consulta.tituloDiagnostico)")
                    .font(DSFont.bodySecondaryEmphasis)
                Text(pie)
                    .font(DSFont.footnote)
                    .foregroundStyle(DSColor.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if consulta.estaAbierta {
                DSStatusBadge(ConsultaEstadoVisual.abierta)
            }
            Image(systemName: "chevron.right")
                .font(DSFont.footnote)
                .foregroundStyle(DSColor.textTertiary)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, DSSpacing.regular)
        .dsCardBackground()
        .frame(minHeight: 52)
    }

    private var pie: String {
        let recetas = Formatting.cantidad(consulta.recetas.count, singular: "receta", plural: "recetas")
        let ordenes = Formatting.cantidad(consulta.ordenesLaboratorio.count, singular: "orden", plural: "órdenes")
        return "\(consulta.doctor.nombreCompleto) · \(recetas) · \(ordenes)"
    }
}

private struct OrdenRow: View {
    let orden: OrdenVisible

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Orden · \(Formatting.fechaCorta(orden.fecha))")
                    .font(DSFont.bodySecondaryEmphasis)
                Text(pie)
                    .font(DSFont.footnote)
                    .foregroundStyle(DSColor.textSecondary)
            }
            Spacer()
            DSStatusBadge(orden.estado.status)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, DSSpacing.regular)
        .dsCardBackground()
        .frame(minHeight: 52)
    }

    private var pie: String {
        let examenes = Formatting.cantidad(orden.totalExamenes, singular: "examen", plural: "exámenes")
        return "\(examenes) · \(orden.prioridad.nombre)"
    }
}
