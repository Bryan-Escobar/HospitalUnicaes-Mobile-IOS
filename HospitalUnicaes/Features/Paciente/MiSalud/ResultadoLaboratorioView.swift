import QuickLook
import SwiftUI

/// iOS-P8 Resultado de laboratorio. Lee la versión más nueva del examen desde el ViewModel
/// de la lista, así que cambia sola a Completado si el laboratorio lo termina con la pantalla abierta.
struct ResultadoLaboratorioView: View {
    let examen: ExamenLaboratorioPaciente
    @Environment(LaboratorioPacienteViewModel.self) private var laboratorio: LaboratorioPacienteViewModel?
    @Environment(\.pacienteDependencies) private var dependencies

    var body: some View {
        ResultadoLaboratorioContenido(
            examen: laboratorio?.examen(id: examen.id) ?? examen,
            laboratorio: laboratorio,
            archivo: ResultadoArchivoViewModel(
                examen: examen,
                service: dependencies.laboratorio,
                archivos: dependencies.resultadoArchivos
            )
        )
    }
}

private struct ResultadoLaboratorioContenido: View {
    let examen: ExamenLaboratorioPaciente
    let laboratorio: LaboratorioPacienteViewModel?
    @State private var archivo: ResultadoArchivoViewModel
    @State private var vistaPrevia: URL?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(examen: ExamenLaboratorioPaciente, laboratorio: LaboratorioPacienteViewModel?, archivo: ResultadoArchivoViewModel) {
        self.examen = examen
        self.laboratorio = laboratorio
        _archivo = State(initialValue: archivo)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DSSpacing.medium) {
                DSStatusBadge(examen.estado.status, size: .large)
                Text(examen.nombre)
                    .font(DSFont.largeTitle)
                    .accessibilityAddTraits(.isHeader)
                Text(subtitulo)
                    .font(DSFont.footnote)
                    .foregroundStyle(DSColor.textSecondary)
                if examen.estado == .completado {
                    completado
                } else {
                    ResultadoPendienteView(examen: examen)
                }
            }
            .foregroundStyle(DSColor.textPrimary)
            .pantallaPrincipal()
        }
        .background(DSColor.backgroundGrouped)
        .navigationTitle("Laboratorio")
        .navigationBarTitleDisplayMode(.inline)
        .animation(reduceMotion ? nil : .default, value: examen.estado)
        .quickLookPreview($vistaPrevia)
        .task(id: examen.estado) {
            await archivo.preparar(para: examen)
        }
        .onChange(of: examen.estado) { _, estado in
            AccessibilityNotification.Announcement("\(examen.nombre), estado \(estado.status.title)").post()
        }
        .onAppear {
            if laboratorio?.aviso?.id == examen.id { laboratorio?.descartarAviso() }
        }
        .onDisappear { archivo.limpiar() }
    }

    private var subtitulo: String {
        if examen.estado == .completado, let completado = examen.fechaCompletado {
            return "Ordenada por \(examen.doctor) · Completada \(Formatting.fechaCortaConHora(completado))"
        }
        return "Ordenada por \(examen.doctor) · \(Formatting.fechaCorta(examen.fechaSolicitud))"
    }

    @ViewBuilder
    private var completado: some View {
        ResultadoTextoCard(resultado: examen.resultado)
        if examen.tieneArchivo {
            ResultadoPDFCard(nombreArchivo: examen.nombreArchivo, archivo: archivo)
            HStack(spacing: DSSpacing.medium) {
                compartir
                DSButton("Abrir PDF", systemImage: "doc.text") {
                    vistaPrevia = archivo.archivoLocal
                }
                .disabled(archivo.archivoLocal == nil)
            }
        }
    }

    @ViewBuilder
    private var compartir: some View {
        if let local = archivo.archivoLocal {
            ShareLink(item: local, preview: SharePreview(examen.nombreArchivo)) {
                Label("Compartir", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(DSButtonStyle(kind: .secondary))
        } else {
            DSButton("Compartir", systemImage: "square.and.arrow.up", kind: .secondary) {}
                .disabled(true)
        }
    }
}

/// Tarjeta "Resultado": valor con su unidad, rango de referencia y observaciones.
private struct ResultadoTextoCard: View {
    let resultado: ResultadoExamen?

    var body: some View {
        DSCard {
            Text("Resultado").font(DSFont.subtitle)
            if let valor = resultado?.valor?.nilIfBlank {
                Text([valor, resultado?.unidad?.nilIfBlank].compactMap { $0 }.joined(separator: " "))
                    .font(DSFont.body)
            } else {
                Text("El resultado está en el PDF adjunto.")
                    .font(DSFont.body)
                    .foregroundStyle(DSColor.textSecondary)
            }
            if let rango = resultado?.rangoReferencia?.nilIfBlank {
                detalle("Rango de referencia", rango)
            }
            if let observaciones = resultado?.observaciones?.nilIfBlank {
                detalle("Observaciones", observaciones)
            }
        }
    }

    private func detalle(_ titulo: String, _ valor: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(titulo).font(DSFont.footnote).foregroundStyle(DSColor.textSecondary)
            Text(valor).font(DSFont.bodySecondary)
        }
        .padding(.top, DSSpacing.tiny)
        .accessibilityElement(children: .combine)
    }
}

/// Tarjeta del PDF: miniatura de la primera página, nombre y tamaño.
private struct ResultadoPDFCard: View {
    let nombreArchivo: String
    let archivo: ResultadoArchivoViewModel

    var body: some View {
        DSCard(spacing: DSSpacing.medium) {
            vistaPrevia
            if case .error(let mensaje) = archivo.estado {
                HStack(alignment: .firstTextBaseline) {
                    Text(mensaje)
                        .font(DSFont.bodySecondary)
                        .foregroundStyle(DSColor.dangerText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    DSButton("Reintentar", kind: .text, size: .compact, isFullWidth: false) {
                        Task { await archivo.reintentar() }
                    }
                }
            }
            HStack(spacing: DSSpacing.medium) {
                Image(systemName: "doc.richtext")
                    .font(.title2)
                    .foregroundStyle(DSColor.dangerText)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(nombreArchivo)
                        .font(DSFont.bodySecondaryEmphasis)
                        .lineLimit(2)
                    Text(detalle)
                        .font(DSFont.footnote)
                        .foregroundStyle(DSColor.textSecondary)
                }
            }
            .accessibilityElement(children: .combine)
        }
    }

    private var detalle: String {
        if case .listo(_, let tamano, _) = archivo.estado { return "PDF · \(tamano)" }
        return "PDF"
    }

    private var vistaPrevia: some View {
        ZStack {
            RoundedRectangle(cornerRadius: DSRadius.field, style: .continuous)
                .fill(DSColor.backgroundGrouped)
            if case .listo(_, _, let miniatura?) = archivo.estado {
                Image(uiImage: miniatura)
                    .resizable()
                    .scaledToFit()
                    .padding(DSSpacing.small)
            } else {
                VStack(spacing: DSSpacing.small) {
                    Image(systemName: "doc.text")
                        .font(.largeTitle)
                    Text("Vista previa del PDF")
                        .font(DSFont.footnote)
                    if archivo.estado == .descargando {
                        ProgressView().controlSize(.small)
                    }
                }
                .foregroundStyle(DSColor.textTertiary)
            }
        }
        .frame(height: 220)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(archivo.estado == .descargando ? "Descargando el PDF" : "Vista previa del PDF")
    }
}

/// Examen Pendiente o En Proceso: línea de tiempo y "Tu resultado aún no está listo".
private struct ResultadoPendienteView: View {
    let examen: ExamenLaboratorioPaciente

    var body: some View {
        DSCard {
            LineaDeTiempoEstado(pasos: [
                .init(titulo: "Pendiente", fecha: examen.fechaSolicitud),
                .init(titulo: "En Proceso", fecha: examen.fechaInicio),
                .init(titulo: "Completado", fecha: examen.fechaCompletado),
            ])
        }
        ContentUnavailableView(
            "Tu resultado aún no está listo",
            systemImage: "hourglass",
            description: Text("Te avisaremos cuando esté Completado.")
        )
    }
}

#Preview("Completado") {
    NavigationStack {
        ResultadoLaboratorioView(examen: PacienteMuestra.resultados(hoy: Date())[0])
    }
    .environment(\.pacienteDependencies, .preview)
}

#Preview("En proceso") {
    NavigationStack {
        ResultadoLaboratorioView(examen: PacienteMuestra.resultados(hoy: Date())[2])
    }
    .environment(\.pacienteDependencies, .preview)
}
