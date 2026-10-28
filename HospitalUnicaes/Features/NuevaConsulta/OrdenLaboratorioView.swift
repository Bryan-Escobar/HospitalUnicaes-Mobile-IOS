import SwiftUI

/// iOS-D9 Orden de laboratorio. El estado inicial siempre es Pendiente.
struct OrdenLaboratorioView: View {
    @State private var viewModel: OrdenLaboratorioViewModel
    @Environment(\.dismiss) private var dismiss
    private let onCrear: (OrdenBorrador) -> Void

    init(service: any LaboratorioService, excluidos: Set<UUID>, onCrear: @escaping (OrdenBorrador) -> Void) {
        self.init(viewModel: OrdenLaboratorioViewModel(service: service, excluidos: excluidos), onCrear: onCrear)
    }

    init(viewModel: OrdenLaboratorioViewModel, onCrear: @escaping (OrdenBorrador) -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.onCrear = onCrear
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DSSpacing.medium) {
                    Text("TIPO DE EXAMEN")
                        .font(DSFont.footnoteEmphasis)
                        .foregroundStyle(DSColor.textSecondary)
                    catalogo
                    DSTextField(
                        "Indicaciones",
                        text: $viewModel.indicaciones,
                        prompt: "Suspender antihistamínicos 72 h antes",
                        axis: .vertical
                    )
                    HStack {
                        Text("Estado inicial").font(DSFont.bodySecondary)
                        Spacer()
                        DSStatusBadge(.labPendiente)
                    }
                    .frame(minHeight: 52)
                }
                .padding(DSSpacing.regular)
            }
            .doctorScreen()
            .navigationTitle("Orden de laboratorio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Crear", action: crear)
                        .disabled(!viewModel.canCreate)
                }
            }
            .task { await viewModel.cargar() }
        }
    }

    @ViewBuilder
    private var catalogo: some View {
        if viewModel.isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, minHeight: DSSize.minTapTarget)
        } else if let message = viewModel.errorMessage {
            DoctorRetry(message: message) { Task { await viewModel.reintentar() } }
        } else {
            VStack(spacing: 0) {
                ForEach(viewModel.examenes) { examen in
                    examenFila(examen)
                }
            }
            .dsCardBackground()
        }
    }

    private func examenFila(_ examen: ExamenCatalogo) -> some View {
        let excluido = viewModel.excluidos.contains(examen.id)
        let elegido = viewModel.seleccionado?.id == examen.id
        return Button {
            viewModel.seleccionar(examen)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(examen.nombre).font(DSFont.bodySecondaryEmphasis)
                    if let categoria = examen.categoria?.nilIfBlank {
                        Text(categoria).font(DSFont.footnote).foregroundStyle(DSColor.textSecondary)
                    }
                }
                Spacer()
                if elegido {
                    Image(systemName: "checkmark").foregroundStyle(DSColor.tint)
                }
            }
            .padding(.horizontal, DSSpacing.regular)
            .frame(minHeight: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(excluido)
        .opacity(excluido ? 0.4 : 1)
        .accessibilityAddTraits(elegido ? .isSelected : [])
    }

    private func crear() {
        guard let orden = viewModel.crear() else { return }
        onCrear(orden)
        dismiss()
    }
}

#if DEBUG
#Preview("Prueba cutánea elegida") {
    let viewModel = OrdenLaboratorioViewModel(service: DoctorDependencies.preview.laboratorio, excluidos: [])
    viewModel.seleccionar(DoctorPreviewData.pruebaCutanea)
    return OrdenLaboratorioView(viewModel: viewModel) { _ in }
}
#endif
