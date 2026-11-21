import QuickLook
import SwiftUI

enum AudienciaResultado {
    case paciente
    case doctor
}

/// iOS-P8 Resultado de laboratorio (rol Paciente). Lee la versión más nueva del examen desde el
/// ViewModel de la lista, así que cambia sola a Completado si el laboratorio lo termina con la pantalla abierta.
struct ResultadoLaboratorioView: View {
    let examen: ExamenLaboratorioPaciente
    @Environment(LaboratorioPacienteViewModel.self) private var laboratorio: LaboratorioPacienteViewModel?
    @Environment(\.pacienteDependencies) private var dependencies

    var body: some View {
        ResultadoExamenDetalleView(
            examen: laboratorio?.examen(id: examen.id) ?? examen,
            laboratorio: laboratorio,
            archivoService: dependencies.laboratorio,
            archivos: dependencies.resultadoArchivos,
            audiencia: .paciente
        )
    }
}

/// Detalle reutilizable de un examen de laboratorio (usado por Paciente en iOS-P8 y por Doctor desde el expediente).
struct ResultadoExamenDetalleView: View {
    let examen: ExamenLaboratorioPaciente
    let laboratorio: LaboratorioPacienteViewModel?
    let audiencia: AudienciaResultado
    @State private var archivo: ResultadoArchivoViewModel
    @State private var vistaPrevia: URL?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        examen: ExamenLaboratorioPaciente,
        laboratorio: LaboratorioPacienteViewModel? = nil,
        archivoService: any ResultadoArchivoURLService,
        archivos: any ResultadoArchivoService,
        audiencia: AudienciaResultado
    ) {
        self.examen = examen
        self.laboratorio = laboratorio
        self.audiencia = audiencia
        _archivo = State(initialValue: ResultadoArchivoViewModel(
            examen: examen,
            service: archivoService,
            archivos: archivos
        ))
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
                if let muestra = examen.tipoMuestra?.nilIfBlank {
                    Text("Muestra: \(muestra)")
                        .font(DSFont.footnote)
                        .foregroundStyle(DSColor.textSecondary)
                }
                if examen.estado == .completado {
                    completado
                } else {
                    ResultadoPendienteView(examen: examen, audiencia: audiencia)
                }
            }
            .foregroundStyle(DSColor.textPrimary)
            .pantallaPrincipal()
        }
        .background(DSColor.backgroundGrouped)
        .navigationTitle("Resultado")
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
        ResultadoTextoCard(resultado: examen.resultado, esImagen: archivo.esImagen)
        if examen.tieneArchivo {
            ResultadoArchivoCard(archivo: archivo) {
                if let local = archivo.archivoLocal { vistaPrevia = local }
            }
            HStack(spacing: DSSpacing.medium) {
                compartir
                DSButton(
                    archivo.esImagen ? "Abrir imagen" : "Abrir PDF",
                    systemImage: archivo.esImagen ? "photo" : "doc.text"
                ) {
                    vistaPrevia = archivo.archivoLocal
                }
                .disabled(archivo.archivoLocal == nil)
            }
        }
    }

    @ViewBuilder
    private var compartir: some View {
        if let local = archivo.archivoLocal {
            ShareLink(item: local, preview: SharePreview(archivo.nombreArchivoMostrado)) {
                Label("Compartir", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(DSButtonStyle(kind: .secondary))
        } else {
            DSButton("Compartir", systemImage: "square.and.arrow.up", kind: .secondary) {}
                .disabled(true)
        }
    }
}

/// Tarjeta "Resultado": valor con su unidad, rango de referencia, observaciones y quien validó.
private struct ResultadoTextoCard: View {
    let resultado: ResultadoExamen?
    let esImagen: Bool

    var body: some View {
        DSCard {
            Text("Resultado").font(DSFont.subtitle)
            if let valor = resultado?.valor?.nilIfBlank {
                Text([valor, resultado?.unidad?.nilIfBlank].compactMap { $0 }.joined(separator: " "))
                    .font(DSFont.body)
            } else {
                Text(esImagen ? "El resultado está en la imagen adjunta." : "El resultado está en el PDF adjunto.")
                    .font(DSFont.body)
                    .foregroundStyle(DSColor.textSecondary)
            }
            if let rango = resultado?.rangoReferencia?.nilIfBlank {
                detalle("Rango de referencia", rango)
            }
            if let observaciones = resultado?.observaciones?.nilIfBlank {
                detalle("Observaciones", observaciones)
            }
            if let validado = resultado?.validadoPor?.nombreCompleto.nilIfBlank {
                detalle("Validado por", validado)
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

/// Tarjeta del archivo adjunto (PDF o imagen): miniatura, nombre y tamaño.
private struct ResultadoArchivoCard: View {
    let archivo: ResultadoArchivoViewModel
    let onAbrir: () -> Void

    var body: some View {
        DSCard(spacing: DSSpacing.medium) {
            Button(action: onAbrir) {
                vistaPrevia
            }
            .buttonStyle(.plain)
            .disabled(archivo.archivoLocal == nil)

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
                Image(systemName: archivo.esImagen ? "photo" : "doc.richtext")
                    .font(.title2)
                    .foregroundStyle(archivo.esImagen ? DSColor.tint : DSColor.dangerText)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(archivo.nombreArchivoMostrado)
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

    private var etiquetaTipo: String {
        archivo.esImagen ? "Imagen" : "PDF"
    }

    private var detalle: String {
        if case .listo(_, let tamano, _) = archivo.estado { return "\(etiquetaTipo) · \(tamano)" }
        return etiquetaTipo
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
                    Image(systemName: archivo.esImagen ? "photo" : "doc.text")
                        .font(.largeTitle)
                    Text(archivo.esImagen ? "Vista previa de la imagen" : "Vista previa del PDF")
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
        .accessibilityLabel(
            archivo.estado == .descargando
                ? "Descargando el archivo"
                : (archivo.esImagen ? "Vista previa de la imagen" : "Vista previa del PDF")
        )
    }
}

/// Examen Pendiente o En Proceso: línea de tiempo y mensaje según el rol.
private struct ResultadoPendienteView: View {
    let examen: ExamenLaboratorioPaciente
    let audiencia: AudienciaResultado

    var body: some View {
        DSCard {
            LineaDeTiempoEstado(pasos: [
                .init(titulo: "Pendiente", fecha: examen.fechaSolicitud),
                .init(titulo: "En Proceso", fecha: examen.fechaInicio),
                .init(titulo: "Completado", fecha: examen.fechaCompletado),
            ])
        }
        ContentUnavailableView(
            audiencia == .paciente ? "Tu resultado aún no está listo" : "Resultado aún no disponible",
            systemImage: "hourglass",
            description: Text(
                audiencia == .paciente
                    ? "Te avisaremos cuando esté Completado."
                    : "El laboratorio todavía no ha completado este examen."
            )
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
