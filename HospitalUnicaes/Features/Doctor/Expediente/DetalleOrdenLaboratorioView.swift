import SwiftUI

/// Detalle de una orden de laboratorio en el flujo del doctor: cabecera de la orden y lista
/// de exámenes seleccionables para abrir su resultado o línea de tiempo.
struct DetalleOrdenLaboratorioView: View {
    @State private var viewModel: DetalleOrdenLaboratorioViewModel
    @Environment(\.dismiss) private var dismiss

    init(ordenId: UUID, laboratorio: any LaboratorioService) {
        _viewModel = State(initialValue: DetalleOrdenLaboratorioViewModel(
            ordenId: ordenId,
            laboratorioService: laboratorio
        ))
    }

    var body: some View {
        Group {
            switch viewModel.estado {
            case .cargando:
                DoctorLoadingList()
            case .sinPermiso:
                sinPermiso
            case .error:
                DoctorRetry(message: viewModel.errorMessage ?? "No se pudo cargar la orden de laboratorio.") {
                    Task { await viewModel.recargar() }
                }
            case .cargado:
                if let orden = viewModel.orden {
                    contenido(orden)
                }
            }
        }
        .doctorScreen()
        .navigationTitle("Orden de laboratorio")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.recargar() }
        .refreshable { await viewModel.recargar() }
    }

    private var sinPermiso: some View {
        ContentUnavailableView {
            Label("No tienes permiso para ver esta orden", systemImage: "lock")
        } description: {
            Text("Solo pueden verla el médico tratante, el propio paciente y la administración.")
        } actions: {
            Button("Volver") { dismiss() }
        }
        .doctorScreen()
    }

    private func contenido(_ orden: OrdenLaboratorioPaciente) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DSSpacing.medium) {
                cabecera(orden)
                Text("Exámenes (\(viewModel.examenes.count))")
                    .font(DSFont.subtitle)
                    .padding(.top, DSSpacing.tiny)
                if viewModel.examenes.isEmpty {
                    ContentUnavailableView("Sin exámenes registrados", systemImage: "testtube.2")
                } else {
                    VStack(spacing: DSSpacing.small) {
                        ForEach(viewModel.examenes) { examen in
                            NavigationLink(value: DoctorRoute.resultadoLaboratorio(examen)) {
                                ExamenOrdenRow(examen: examen)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(DSSpacing.regular)
        }
    }

    private func cabecera(_ orden: OrdenLaboratorioPaciente) -> some View {
        DSCard(spacing: DSSpacing.small) {
            HStack {
                DSStatusBadge(orden.estado.status, size: .large)
                Spacer()
                Text("Prioridad \(orden.prioridad.nombre)")
                    .font(DSFont.footnote)
                    .foregroundStyle(colorPrioridad(orden.prioridad))
            }
            Text("Solicitada el \(Formatting.fechaCortaConHora(orden.fechaSolicitud))")
                .font(DSFont.bodySecondaryEmphasis)
            Text(Formatting.unir(["Por \(orden.doctor.nombreCompleto)", orden.doctor.especialidad]))
                .font(DSFont.footnote)
                .foregroundStyle(DSColor.textSecondary)
            if let indicaciones = orden.indicaciones?.nilIfBlank {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Indicaciones")
                        .font(DSFont.footnote)
                        .foregroundStyle(DSColor.textSecondary)
                    Text(indicaciones)
                        .font(DSFont.bodySecondary)
                }
                .padding(.top, DSSpacing.tiny)
            }
        }
    }

    private func colorPrioridad(_ prioridad: PrioridadLaboratorio) -> Color {
        switch prioridad {
        case .critica: DSColor.dangerText
        case .urgente: DSTone.warning.foreground
        case .normal, .desconocido: DSColor.textSecondary
        }
    }
}

private struct ExamenOrdenRow: View {
    let examen: ExamenLaboratorioPaciente

    var body: some View {
        HStack(spacing: DSSpacing.small) {
            VStack(alignment: .leading, spacing: 2) {
                Text(examen.nombre)
                    .font(DSFont.bodySecondaryEmphasis)
                Text(detalle)
                    .font(DSFont.footnote)
                    .foregroundStyle(DSColor.textSecondary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            DSStatusBadge(examen.estado.status)
            Image(systemName: "chevron.right")
                .font(DSFont.footnote)
                .foregroundStyle(DSColor.textTertiary)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, DSSpacing.regular)
        .dsCardBackground()
        .frame(minHeight: 52)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(examen.nombre), \(examen.estado.status.title), \(detalle)")
        .accessibilityHint("Abre el detalle del resultado")
    }

    private var detalle: String {
        if examen.estado == .completado {
            let valorTexto = examen.resultado?.valor?.nilIfBlank.map { valor in
                [valor, examen.resultado?.unidad?.nilIfBlank].compactMap { $0 }.joined(separator: " ")
            }
            let archivoTexto: String? = examen.tieneArchivo
                ? (examen.esImagen ? "Imagen adjunta" : "PDF adjunto")
                : nil
            let resumen = Formatting.unir([valorTexto, archivoTexto])
            if !resumen.isEmpty { return resumen }
            return "Resultado disponible"
        }
        if examen.estado == .enProceso, let inicio = examen.fechaInicio {
            return Formatting.unir([examen.tipoMuestra, "Iniciado \(Formatting.fechaCorta(inicio))"])
        }
        return Formatting.unir([examen.tipoMuestra, "Pendiente de resultado"])
    }
}

#Preview("Orden con resultados") {
    NavigationStack {
        DetalleOrdenLaboratorioView(
            ordenId: DoctorPreviewData.ordenMarioId,
            laboratorio: DoctorDependencies.preview.laboratorio
        )
        .navigationDestination(for: DoctorRoute.self) { route in
            DoctorDestination(route: route, dependencies: .preview)
        }
    }
}
