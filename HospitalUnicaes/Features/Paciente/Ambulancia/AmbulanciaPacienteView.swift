import SwiftUI

/// Pestaña Ambulancia: iOS-P10 Solicitar ambulancia (Figma 44:3073) e iOS-P11 Seguimiento
/// (44:3179), con el chip de conexión en tiempo real.
struct AmbulanciaPacienteView: View {
    @State private var viewModel: AmbulanciaPacienteViewModel
    @Environment(\.scenePhase) private var scenePhase

    init(dependencies: PacienteDependencies) {
        _viewModel = State(initialValue: AmbulanciaPacienteViewModel(
            ambulancias: dependencies.ambulancias,
            realtime: dependencies.ambulanciaRealtime,
            ubicacion: dependencies.ubicacion()
        ))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DSSpacing.medium) {
                    contenido
                }
                .pantallaPrincipal()
            }
            .background(DSColor.backgroundGrouped)
            .navigationTitle(titulo)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    DSLiveIndicator(viewModel.conexion)
                }
            }
            .refreshable { await viewModel.recargar() }
        }
        .task { await viewModel.iniciar() }
        .onChange(of: scenePhase) { _, fase in
            if fase == .active { Task { await viewModel.recargar() } }
        }
        .onChange(of: viewModel.estadoAmbulancia) { anterior, nuevo in
            guard anterior != nil, let nuevo, viewModel.pantalla == .formulario else { return }
            anunciar("\(nuevo.status.domain), estado \(nuevo.status.title)")
        }
        .onChange(of: viewModel.solicitud?.estado) { anterior, nuevo in
            guard anterior != nil, nuevo != anterior, let solicitud = viewModel.solicitud else { return }
            anunciar(solicitud.titulo)
        }
    }

    private var titulo: String {
        switch viewModel.pantalla {
        case .seguimiento, .vacio: "Tu solicitud"
        case .cargando, .formulario: "Ambulancia"
        }
    }

    @ViewBuilder
    private var contenido: some View {
        switch viewModel.pantalla {
        case .cargando:
            SolicitarAmbulanciaForm(viewModel: viewModel)
                .redacted(reason: .placeholder)
                .disabled(true)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Cargando…")
        case .formulario:
            SolicitarAmbulanciaForm(viewModel: viewModel)
        case let .seguimiento(solicitud):
            SeguimientoSolicitudView(
                solicitud: solicitud,
                error: viewModel.errorRecarga,
                reintentar: { await viewModel.recargar() },
                solicitarOtra: viewModel.solicitarOtra
            )
        case .vacio:
            SeguimientoVacioView(solicitarOtra: viewModel.solicitarOtra)
        }
    }

    private func anunciar(_ texto: String) {
        AccessibilityNotification.Announcement(texto).post()
    }
}

// MARK: - P10

/// iOS-P10 y su variante "No disponible" (handoff §7.3).
private struct SolicitarAmbulanciaForm: View {
    @Bindable var viewModel: AmbulanciaPacienteViewModel
    @Environment(\.openURL) private var openURL

    var body: some View {
        if let error = viewModel.errorCarga {
            DSBanner(error)
            DSButton("Reintentar", systemImage: "arrow.clockwise", kind: .secondary, size: .compact) {
                Task { await viewModel.recargar() }
            }
        }
        EstadoActualCard(estado: viewModel.estadoAmbulancia)
        if let estado = viewModel.estadoAmbulancia, estado != .disponible {
            NoDisponibleCard(estado: estado)
            EmergenciaNacionalCard { abrir("tel://911") }
        }
        Group {
            UbicacionCard(viewModel: viewModel)
            TipoEmergenciaCard(viewModel: viewModel)
        }
        .disabled(!viewModel.disponible)
        if let error = viewModel.errorEnvio {
            DSBanner(error)
        }
        if let ayuda = viewModel.ayuda {
            Text(ayuda)
                .font(DSFont.footnote)
                .foregroundStyle(DSColor.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        DSButton(
            LocalizedStringKey(botonTitulo),
            systemImage: "light.beacon.max",
            kind: .destructive,
            isLoading: viewModel.enviando,
            loadingTitle: "Enviando…",
            action: viewModel.pedirConfirmacion
        )
        .disabled(!viewModel.puedeConfirmar)
        .padding(.top, DSSpacing.small)
        .alert("¿Solicitar la ambulancia?", isPresented: $viewModel.mostrarConfirmacion) {
            Button("Solicitar", role: .destructive) {
                Task { await viewModel.solicitar() }
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Recepción recibirá tu ubicación y el tipo de emergencia.")
        }
    }

    private var botonTitulo: String {
        if let estado = viewModel.estadoAmbulancia, estado != .disponible { return "No disponible ahora" }
        return "Confirmar solicitud de ambulancia"
    }

    private func abrir(_ texto: String) {
        if let url = URL(string: texto) { openURL(url) }
    }
}

private struct EstadoActualCard: View {
    let estado: EstadoAmbulancia?

    var body: some View {
        DSCard {
            HStack {
                Text("Estado actual").font(DSFont.bodySecondaryEmphasis)
                Spacer()
                DSStatusBadge((estado ?? .disponible).status)
                    .redacted(reason: estado == nil ? .placeholder : [])
                    .animation(.default, value: estado)
            }
        }
    }
}

private struct NoDisponibleCard: View {
    let estado: EstadoAmbulancia

    var body: some View {
        let tono: DSTone = estado == .enMantenimiento ? .neutral : .danger
        Text(mensaje)
            .font(DSFont.bodySecondary)
            .foregroundStyle(DSColor.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DSSpacing.regular)
            .background(tono.background, in: RoundedRectangle(cornerRadius: DSRadius.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: DSRadius.card, style: .continuous).strokeBorder(tono.border)
            }
    }

    private var mensaje: String {
        let causa = estado == .enMantenimiento
            ? "La ambulancia está en mantenimiento."
            : "La ambulancia está atendiendo otra emergencia."
        return "\(causa) Te avisaremos aquí cuando vuelva a estar Disponible."
    }
}

private struct EmergenciaNacionalCard: View {
    let llamar: () -> Void

    var body: some View {
        DSCard(spacing: DSSpacing.medium) {
            Text("¿Es una emergencia grave? Llama al sistema de emergencias nacional o acude a la emergencia más cercana.")
                .font(DSFont.bodySecondary)
                .foregroundStyle(DSColor.textPrimary)
            DSButton("Llamar a emergencias", systemImage: "phone", kind: .secondary, size: .compact, action: llamar)
        }
    }
}

private struct UbicacionCard: View {
    @Bindable var viewModel: AmbulanciaPacienteViewModel

    var body: some View {
        DSCard(spacing: DSSpacing.medium) {
            Text("Ubicación").font(DSFont.subtitle)
            Button {
                Task { await viewModel.alternarUbicacion() }
            } label: {
                opcionGPS
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(viewModel.usarGPS ? .isSelected : [])
            DSTextField("O escribe la dirección", text: $viewModel.direccion, prompt: "Calle, número, referencia")
        }
    }

    private var opcionGPS: some View {
        let elegida = viewModel.usarGPS
        return HStack(spacing: DSSpacing.medium) {
            Image(systemName: "scope")
                .font(.title3)
                .foregroundStyle(DSColor.tint)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("Usar mi ubicación").font(DSFont.bodySecondaryEmphasis)
                HStack(spacing: DSSpacing.tiny) {
                    if viewModel.gps == .buscando {
                        ProgressView().controlSize(.mini)
                    }
                    Text(subtitulo)
                        .font(DSFont.footnote)
                        .foregroundStyle(DSColor.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if elegida {
                Image(systemName: "checkmark")
                    .fontWeight(.semibold)
                    .foregroundStyle(DSColor.tint)
                    .accessibilityHidden(true)
            }
        }
        .foregroundStyle(DSColor.textPrimary)
        .padding(.vertical, 10)
        .padding(.horizontal, DSSpacing.medium)
        .frame(minHeight: DSSize.minTapTarget)
        .background(elegida ? DSColor.selection : DSColor.surface, in: RoundedRectangle(cornerRadius: DSRadius.field))
        .overlay {
            RoundedRectangle(cornerRadius: DSRadius.field)
                .strokeBorder(elegida ? DSColor.action : DSColor.borderInput, lineWidth: elegida ? 2 : 1)
        }
        .contentShape(Rectangle())
    }

    private var subtitulo: String {
        switch viewModel.gps {
        case .inactivo: "Toca para usar tu ubicación actual"
        case .buscando: "Obteniendo ubicación…"
        case let .listo(lectura): viewModel.usarGPS ? lectura.resumen : "Toca para usar tu ubicación actual"
        case .sinPermiso: "Permiso de ubicación desactivado · Escribe la dirección"
        case let .error(mensaje): mensaje
        }
    }
}

private struct TipoEmergenciaCard: View {
    @Bindable var viewModel: AmbulanciaPacienteViewModel

    var body: some View {
        DSCard(spacing: DSSpacing.medium) {
            Text("Tipo de emergencia").font(DSFont.subtitle)
            Chips(
                opciones: TipoEmergencia.opcionesPaciente.map(\.etiqueta),
                seleccion: Binding(
                    get: { viewModel.tipo?.etiqueta ?? "" },
                    set: { etiqueta in
                        viewModel.tipo = TipoEmergencia.opcionesPaciente.first { $0.etiqueta == etiqueta }
                    }
                )
            )
            DSTextField(
                "Descripción",
                text: $viewModel.descripcion,
                prompt: "Describe brevemente qué ocurre",
                axis: .vertical
            )
        }
    }
}

#if DEBUG
#Preview("Disponible") {
    AmbulanciaPacienteView(dependencies: .preview)
}

#Preview("No disponible") {
    AmbulanciaPacienteView(dependencies: .preview(estado: .enServicio))
}

#Preview("Seguimiento") {
    AmbulanciaPacienteView(dependencies: .preview(solicitud: PacientePreviewData.solicitud(.despachada)))
}
#endif
