import SwiftUI

/// iOS-P2 Mis citas.
struct CitasPacienteView: View {
    @State private var viewModel: CitasPacienteViewModel

    init(hoy: Date = Date()) {
        _viewModel = State(initialValue: CitasPacienteViewModel(hoy: hoy))
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
                    if viewModel.segmento == .proximas {
                        ForEach(viewModel.solicitudes) { solicitud in
                            SolicitudCard(solicitud: solicitud)
                        }
                    }
                    lista
                }
                .pantallaPrincipal()
            }
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
                SolicitarCitaView(onEnviada: viewModel.agregar)
            }
        }
    }

    @ViewBuilder
    private var lista: some View {
        if viewModel.visibles.isEmpty {
            ContentUnavailableView(
                viewModel.segmento == .proximas ? "Sin citas próximas" : "Sin citas pasadas",
                systemImage: "calendar",
                description: Text("Solicita una cita y recepción te asignará fecha y doctor.")
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

private struct SolicitudCard: View {
    let solicitud: SolicitudCita

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.tiny) {
            HStack {
                Text("Solicitud en revisión")
                    .font(DSFont.bodySecondaryEmphasis)
                    .frame(maxWidth: .infinity, alignment: .leading)
                DSStatusBadge(.solicitudEnviada)
            }
            Text("\(solicitud.especialidad) · preferencia: \(solicitud.preferencia)")
                .font(DSFont.footnote)
                .foregroundStyle(DSColor.textSecondary)
        }
        .foregroundStyle(DSColor.textPrimary)
        .padding(.vertical, 14)
        .padding(.horizontal, DSSpacing.regular)
        .background(DSTone.warning.background, in: RoundedRectangle(cornerRadius: DSRadius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: DSRadius.card, style: .continuous)
                .strokeBorder(DSTone.warning.border, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
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
    CitasPacienteView()
}

#Preview("Detalle") {
    NavigationStack {
        DetalleCitaPacienteView(cita: PacienteMuestra.citas(hoy: Date())[0])
    }
}
