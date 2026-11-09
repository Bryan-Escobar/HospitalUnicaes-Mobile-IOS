import SwiftUI

/// iOS-D8 Agregar receta. Vuelve a la consulta sin llamar a la API.
struct AgregarRecetaView: View {
    @State private var viewModel: AgregarRecetaViewModel
    @Environment(\.dismiss) private var dismiss
    private let onAgregar: (RecetaBorrador) -> Void

    init(alergias: String?, onAgregar: @escaping (RecetaBorrador) -> Void) {
        self.init(viewModel: AgregarRecetaViewModel(alergias: alergias), onAgregar: onAgregar)
    }

    init(viewModel: AgregarRecetaViewModel, onAgregar: @escaping (RecetaBorrador) -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.onAgregar = onAgregar
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DSSpacing.medium) {
                    DSTextField("Medicamento", text: $viewModel.medicamento, prompt: "Buscar medicamento")
                    HStack(alignment: .top, spacing: DSSpacing.small) {
                        DSTextField("Dosis", text: $viewModel.dosis, prompt: "10 mg")
                        frecuencia
                    }
                    DSTextField("Duración", text: $viewModel.duracion, prompt: "7 días")
                    DSTextField(
                        "Indicaciones",
                        text: $viewModel.indicaciones,
                        prompt: "Tomar después de comer",
                        axis: .vertical
                    )
                    AlergiaBanner(
                        texto: "⚠ Si el medicamento coincide con una alergia registrada, se muestra una advertencia antes de agregar."
                    )
                }
                .padding(DSSpacing.regular)
            }
            .doctorScreen()
            .navigationTitle("Agregar receta")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { barra }
            .alert("Posible alergia", isPresented: alertaVisible) {
                Button("Agregar de todos modos", role: .destructive) {
                    entregar(viewModel.confirmarAgregar())
                }
                Button("Revisar", role: .cancel) { viewModel.cancelarAlerta() }
            } message: {
                Text(viewModel.mensajeAlerta ?? "")
            }
        }
    }

    @ToolbarContentBuilder
    private var barra: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancelar") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
            Button("Agregar", action: intentar)
                .disabled(!viewModel.canAdd)
        }
    }

    private var frecuencia: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Frecuencia")
                .font(DSFont.fieldLabel)
                .foregroundStyle(DSColor.textLabel)
            Menu {
                ForEach(AgregarRecetaViewModel.frecuencias, id: \.self) { opcion in
                    Button(opcion) { viewModel.frecuencia = opcion }
                }
            } label: {
                HStack {
                    Text(viewModel.frecuencia ?? "Cada 8 h")
                        .foregroundStyle(viewModel.frecuencia == nil ? DSColor.textTertiary : DSColor.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .foregroundStyle(DSColor.textTertiary)
                }
                .font(DSFont.body)
                .padding(.horizontal, 14)
                .frame(minHeight: DSSize.fieldHeight)
                .background(DSColor.surface, in: RoundedRectangle(cornerRadius: DSRadius.field))
                .overlay {
                    RoundedRectangle(cornerRadius: DSRadius.field).strokeBorder(DSColor.borderInput, lineWidth: 1)
                }
            }
        }
    }

    /// La alerta depende del ViewModel: aparece cuando `intentarAgregar()` encuentra una coincidencia.
    private var alertaVisible: Binding<Bool> {
        Binding(
            get: { viewModel.alertaAlergia != nil },
            set: { visible in if !visible { viewModel.cancelarAlerta() } }
        )
    }

    private func intentar() {
        if let receta = viewModel.intentarAgregar() {
            entregar(receta)
        }
    }

    private func entregar(_ receta: RecetaBorrador) {
        onAgregar(receta)
        dismiss()
    }
}

#if DEBUG
#Preview("Con alerta de alergia") {
    let viewModel = AgregarRecetaViewModel(alergias: NuevaConsultaContexto.preview.alergias)
    viewModel.medicamento = "Penicilina G benzatínica"
    viewModel.dosis = "1 ampolla"
    viewModel.frecuencia = "Dosis única"
    _ = viewModel.intentarAgregar()
    return AgregarRecetaView(viewModel: viewModel) { _ in }
}
#endif
