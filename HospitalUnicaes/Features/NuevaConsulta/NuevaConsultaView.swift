import SwiftUI

/// iOS-D7 Nueva consulta. Las recetas y órdenes se arman aquí y se envían al guardar.
struct NuevaConsultaView: View {
    @State private var viewModel: NuevaConsultaViewModel
    @Environment(\.dismiss) private var dismiss
    private let onGuardada: () -> Void

    @State private var muestraReceta = false
    @State private var muestraOrden = false
    @State private var confirmaDescarte = false
    @State private var confirmaParcial = false

    init(viewModel: NuevaConsultaViewModel, onGuardada: @escaping () -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.onGuardada = onGuardada
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                formulario
            }
            .doctorScreen()
            .navigationTitle("Nueva consulta")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { barra }
            .safeAreaInset(edge: .bottom) { guardar }
        }
        .interactiveDismissDisabled(viewModel.debeConfirmarSalida)
        .onChange(of: viewModel.guardada) { _, guardada in
            if guardada {
                onGuardada()
                dismiss()
            }
        }
        .sheet(isPresented: $muestraReceta) { hojaReceta }
        .sheet(isPresented: $muestraOrden) { hojaOrden }
        .confirmationDialog("¿Descartar la consulta?", isPresented: $confirmaDescarte, titleVisibility: .visible) {
            Button("Descartar", role: .destructive) { dismiss() }
            Button("Seguir editando", role: .cancel) {}
        }
        .confirmationDialog("La consulta quedó abierta", isPresented: $confirmaParcial, titleVisibility: .visible) {
            Button("Reintentar") { Task { await viewModel.guardar() } }
            Button("Salir de todos modos", role: .destructive) { dismiss() }
        } message: {
            Text("Ya se registró parte de la consulta y la cita quedó como Atendida. Si sales ahora, lo que falta no se guardará.")
        }
    }

    private var formulario: some View {
        VStack(alignment: .leading, spacing: DSSpacing.medium) {
            contexto
            DSTextField(
                "Diagnóstico (obligatorio)",
                text: $viewModel.diagnostico,
                prompt: "Ej. Rinitis alérgica estacional",
                errorMessage: viewModel.diagnosticoError,
                onFocusChange: { focused in
                    if !focused { viewModel.diagnosticoPerdioFoco() }
                }
            )
            .disabled(viewModel.diagnosticoBloqueado)
            DSTextField(
                "Notas",
                text: $viewModel.notas,
                prompt: "Síntomas, exploración, indicaciones",
                errorMessage: viewModel.notasError,
                axis: .vertical
            )
            .disabled(viewModel.notasBloqueadas)
            recetas
            ordenes
            if let message = viewModel.errorMessage {
                DSBanner(message)
                if viewModel.tieneAvanceParcial {
                    Text("La consulta quedó guardada a medias. Toca Reintentar para terminar.")
                        .font(DSFont.footnote)
                        .foregroundStyle(DSColor.textSecondary)
                }
            }
        }
        .padding(DSSpacing.regular)
    }

    private var contexto: some View {
        VStack(alignment: .leading, spacing: DSSpacing.tiny) {
            Text(viewModel.contexto.linea)
                .font(DSFont.bodySecondary)
                .foregroundStyle(DSColor.textSecondary)
            if let alergias = viewModel.contexto.alergias?.nilIfBlank {
                Label("Alergia: \(alergias)", systemImage: "exclamationmark.triangle")
                    .font(DSFont.footnoteEmphasis)
                    .foregroundStyle(DSTone.warning.foreground)
            }
        }
    }

    @ToolbarContentBuilder
    private var barra: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancelar", action: solicitarSalida)
                .disabled(viewModel.isSaving)
        }
        ToolbarItem(placement: .confirmationAction) {
            Button("Guardar") { Task { await viewModel.guardar() } }
                .disabled(!viewModel.canSave)
        }
    }

    private var guardar: some View {
        DSButton(
            viewModel.tieneAvanceParcial ? "Reintentar" : "Guardar consulta",
            isLoading: viewModel.isSaving,
            loadingTitle: "Guardando…"
        ) {
            Task { await viewModel.guardar() }
        }
        .disabled(!viewModel.canSave)
        .padding(DSSpacing.regular)
        .background(DSColor.backgroundGrouped)
    }

    private var recetas: some View {
        VStack(alignment: .leading, spacing: DSSpacing.small) {
            Text("RECETAS (\(viewModel.recetas.count))")
                .font(DSFont.footnoteEmphasis)
                .foregroundStyle(DSColor.textSecondary)
            if viewModel.recetas.isEmpty {
                Text("Sin recetas.")
                    .font(DSFont.bodySecondary)
                    .foregroundStyle(DSColor.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(DSSpacing.regular)
                    .background(DSColor.disabledFill, in: RoundedRectangle(cornerRadius: DSRadius.card))
            } else {
                ForEach(viewModel.recetas) { receta in
                    RecetaCard(receta: receta) { viewModel.quitarReceta(id: receta.id) }
                }
            }
            DSButton("+ Agregar receta", kind: .text) { muestraReceta = true }
                .disabled(viewModel.isSaving)
        }
    }

    private var ordenes: some View {
        VStack(alignment: .leading, spacing: DSSpacing.small) {
            Text("ÓRDENES DE LABORATORIO (\(viewModel.ordenes.count))")
                .font(DSFont.footnoteEmphasis)
                .foregroundStyle(DSColor.textSecondary)
            if viewModel.ordenes.isEmpty {
                Text("Sin órdenes. Se crean en estado Pendiente.")
                    .font(DSFont.bodySecondary)
                    .foregroundStyle(DSColor.textSecondary)
            } else {
                ForEach(viewModel.ordenes) { orden in
                    OrdenCard(orden: orden) { viewModel.quitarOrden(id: orden.id) }
                }
            }
            DSButton("+ Agregar orden", kind: .text) { muestraOrden = true }
                .disabled(viewModel.isSaving)
        }
    }

    private var hojaReceta: some View {
        AgregarRecetaView(alergias: viewModel.contexto.alergias) { receta in
            viewModel.agregarReceta(receta)
        }
        .presentationDetents([.medium, .large])
    }

    private var hojaOrden: some View {
        OrdenLaboratorioView(
            service: viewModel.laboratorio,
            excluidos: viewModel.examenesYaAgregados
        ) { orden in
            viewModel.agregarOrden(orden)
        }
    }

    private func solicitarSalida() {
        switch viewModel.prepararSalida() {
        case .cerrar: dismiss()
        case .descartar: confirmaDescarte = true
        case .parcial: confirmaParcial = true
        }
    }
}

private struct RecetaCard: View {
    let receta: RecetaBorrador
    let quitar: () -> Void

    var body: some View {
        DSCard {
            Text(receta.medicamento).font(DSFont.bodySecondaryEmphasis)
            Text(receta.subtitulo).font(DSFont.footnote).foregroundStyle(DSColor.textSecondary)
            if receta.enviada {
                Label("Guardada", systemImage: "checkmark")
                    .font(DSFont.footnote)
                    .foregroundStyle(DSColor.textTertiary)
            } else {
                Button("Quitar", action: quitar)
                    .frame(minHeight: DSSize.minTapTarget)
                    .accessibilityLabel("Quitar receta \(receta.medicamento)")
            }
        }
    }
}

private struct OrdenCard: View {
    let orden: OrdenBorrador
    let quitar: () -> Void

    var body: some View {
        DSCard {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(orden.examen.nombre).font(DSFont.bodySecondaryEmphasis)
                    if let indicaciones = orden.indicaciones.nilIfBlank {
                        Text(indicaciones).font(DSFont.footnote).foregroundStyle(DSColor.textSecondary)
                    }
                }
                Spacer()
                DSStatusBadge(.labPendiente)
            }
            if orden.enviada {
                Label("Guardada", systemImage: "checkmark")
                    .font(DSFont.footnote)
                    .foregroundStyle(DSColor.textTertiary)
            } else {
                Button("Quitar", action: quitar)
                    .frame(minHeight: DSSize.minTapTarget)
                    .accessibilityLabel("Quitar orden \(orden.examen.nombre)")
            }
        }
    }
}

#if DEBUG
#Preview("Vacía") {
    NuevaConsultaView(viewModel: .preview()) {}
}

#Preview("Con una receta") {
    let viewModel = NuevaConsultaViewModel.preview()
    viewModel.diagnostico = "Rinitis alérgica estacional"
    viewModel.notas = "Congestión nasal y estornudos desde hace dos semanas."
    viewModel.agregarReceta(RecetaBorrador(
        id: UUID(), medicamento: "Loratadina 10 mg", dosis: "1 tableta", frecuencia: "Cada 24 h",
        duracion: "14 días", indicaciones: "Tomar después de comer"
    ))
    return NuevaConsultaView(viewModel: viewModel) {}
}

#Preview("Guardado a medias") {
    let viewModel = NuevaConsultaViewModel.preview(fallarRecetas: true)
    viewModel.diagnostico = "Rinitis alérgica estacional"
    viewModel.agregarReceta(RecetaBorrador(
        id: UUID(), medicamento: "Loratadina 10 mg", dosis: "1 tableta", frecuencia: "Cada 24 h",
        duracion: "14 días", indicaciones: ""
    ))
    return NuevaConsultaView(viewModel: viewModel) {}
        .task { await viewModel.guardar() }
}
#endif
