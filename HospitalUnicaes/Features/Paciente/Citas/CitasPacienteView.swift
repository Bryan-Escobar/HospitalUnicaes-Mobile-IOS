import SwiftUI

/// iOS-P2 Mis citas (HUNI-56): próximas y pasadas desde `v_citas`, y las solicitudes de atención arriba.
struct CitasPacienteView: View {
    @State private var viewModel: CitasPacienteViewModel
    @Environment(\.scenePhase) private var scenePhase
    private let service: any CitasPacienteService

    init(service: any CitasPacienteService, hoy: @escaping () -> Date = Date.init) {
        self.service = service
        _viewModel = State(initialValue: CitasPacienteViewModel(service: service, hoy: hoy))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DSSpacing.medium) {
                    Picker("Citas", selection: $viewModel.segmento) {
                        ForEach(CitasSegmento.allCases) { segmento in
                            Text(segmento.titulo).tag(segmento)
                        }
                    }
                    .pickerStyle(.segmented)
                    contenido
                }
                .pantallaPrincipal()
            }
            .refreshable { await viewModel.cargar() }
            .background(DSColor.backgroundGrouped)
            .navigationTitle("Citas")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Solicitar", systemImage: "plus") { viewModel.isSolicitando = true }
                        .labelStyle(.titleAndIcon)
                }
            }
            .navigationDestination(for: PacienteRoute.self) { PacienteDestination(route: $0) }
            .sheet(isPresented: $viewModel.isSolicitando) {
                SolicitarCitaView(service: service) { solicitud in
                    viewModel.agregar(solicitud)
                    Task { await viewModel.cargar() }
                }
            }
        }
        .task { await viewModel.cargar() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await viewModel.cargar() } }
        }
    }

    @ViewBuilder
    private var contenido: some View {
        if viewModel.isLoading {
            ProgressView("Cargando tus citas…")
                .frame(maxWidth: .infinity, minHeight: 200)
        } else if let message = viewModel.errorMessage {
            VStack(spacing: DSSpacing.medium) {
                DSBanner(message)
                DSButton("Reintentar", systemImage: "arrow.clockwise") { Task { await viewModel.cargar() } }
            }
        } else {
            if viewModel.segmento == .proximas {
                ForEach(viewModel.solicitudes) { solicitud in
                    SolicitudCard(solicitud: solicitud)
                }
            }
            lista
        }
    }

    @ViewBuilder
    private var lista: some View {
        if viewModel.visibles.isEmpty {
            ContentUnavailableView(
                viewModel.segmento == .proximas ? "Sin citas próximas" : "Sin citas pasadas",
                systemImage: "calendar",
                description: Text("Solicita atención y recepción te asignará fecha y doctor.")
            )
        } else {
            ListaTarjeta(items: viewModel.visibles) { cita in
                NavigationLink(value: PacienteRoute.cita(cita)) {
                    ResumenRow(
                        titulo: Formatting.fechaYHora(cita.fecha),
                        detalle: "\(cita.doctor) · \(cita.especialidad)",
                        status: cita.estado.status,
                        muestraChevron: true
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// Solicitud de atención: "en revisión" mientras está pendiente; rechazada con la respuesta de recepción.
private struct SolicitudCard: View {
    let solicitud: SolicitudAtencion

    private var pendiente: Bool { solicitud.estado == .pendiente }
    private var tono: DSTone { pendiente ? .warning : .neutral }

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.tiny) {
            HStack {
                Text(pendiente ? "Solicitud en revisión" : "Solicitud no aceptada")
                    .font(DSFont.bodySecondaryEmphasis)
                    .frame(maxWidth: .infinity, alignment: .leading)
                DSStatusBadge(pendiente ? .solicitudEnviada : .solicitudRechazada)
            }
            Text(solicitud.motivo)
                .font(DSFont.bodySecondary)
            Text(Formatting.unir([solicitud.especialidad, "preferencia: \(solicitud.preferencia)"]))
                .font(DSFont.footnote)
                .foregroundStyle(DSColor.textSecondary)
            if let respuesta = solicitud.respuesta?.nilIfBlank {
                Text("Recepción: \(respuesta)")
                    .font(DSFont.footnote)
                    .foregroundStyle(DSColor.textSecondary)
            }
        }
        .foregroundStyle(DSColor.textPrimary)
        .padding(.vertical, 14)
        .padding(.horizontal, DSSpacing.regular)
        .background(tono.background, in: RoundedRectangle(cornerRadius: DSRadius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: DSRadius.card, style: .continuous)
                .strokeBorder(tono.border, style: StrokeStyle(lineWidth: 1.5, dash: pendiente ? [5, 4] : []))
        }
        .accessibilityElement(children: .combine)
    }
}

/// iOS-P3 Detalle de cita.
struct DetalleCitaPacienteView: View {
    let cita: CitaPaciente

    var body: some View {
        ScrollView {
            VStack(spacing: DSSpacing.medium) {
                DSCard {
                    HStack(spacing: DSSpacing.medium) {
                        DSAvatar(name: cita.doctor.replacingOccurrences(of: "Dra. ", with: "")
                            .replacingOccurrences(of: "Dr. ", with: ""), size: 48)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(cita.doctor).font(DSFont.subtitle)
                            Text(cita.especialidad).font(DSFont.bodySecondary).foregroundStyle(DSColor.textSecondary)
                        }
                    }
                }
                ListaTarjeta(items: filas) { fila in
                    HStack {
                        Text(fila.titulo).font(DSFont.bodySecondary).foregroundStyle(DSColor.textSecondary)
                        Spacer()
                        Text(fila.valor).font(DSFont.bodySecondaryEmphasis)
                    }
                    .frame(minHeight: 44)
                    .accessibilityElement(children: .combine)
                }
                HStack {
                    Text("Estado").font(DSFont.bodySecondary).foregroundStyle(DSColor.textSecondary)
                    Spacer()
                    DSStatusBadge(cita.estado.status)
                }
                .padding(.horizontal, DSSpacing.regular)
                .frame(minHeight: 52)
                .dsCardBackground()
                if cita.estado == .programada || cita.estado == .confirmada {
                    DSBanner("Llega 15 minutos antes y presenta tu documento en recepción.", kind: .info)
                }
            }
            .pantallaPrincipal()
        }
        .background(DSColor.backgroundGrouped)
        .navigationTitle(cita.motivo)
        .navigationBarTitleDisplayMode(.inline)
    }

    private struct Fila: Identifiable {
        let titulo: String
        let valor: String
        var id: String { titulo }
    }

    private var filas: [Fila] {
        [
            Fila(titulo: "Fecha", valor: "\(Formatting.diaCorto(cita.fecha)) \(Formatting.fechaCorta(cita.fecha))"),
            Fila(titulo: "Hora", valor: Formatting.hora(cita.fecha)),
            Fila(titulo: "Motivo", valor: cita.motivo),
        ]
    }
}

#Preview("Citas") {
    CitasPacienteView(service: PreviewCitasPacienteService())
}

#Preview("Detalle") {
    NavigationStack {
        DetalleCitaPacienteView(cita: PacienteMuestra.citas(hoy: Date())[0])
    }
}
