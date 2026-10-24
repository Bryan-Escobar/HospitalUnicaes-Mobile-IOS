import SwiftUI

/// iOS-C3 Registro (Figma 44:838), en sheet desde Login. "Nombre completo" del diseño va como
/// "Nombres" + "Apellidos" porque así lo exige el contrato (decisión del 24 oct).
struct RegistroView: View {
    @State var viewModel: RegistroViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: RegistroViewModel.Field?

    typealias Field = RegistroViewModel.Field

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DSSpacing.medium) {
                    FieldPair {
                        field(.nombres, "Nombres", prompt: "Nombres", text: \.nombres)
                            .textContentType(.givenName)
                    } trailing: {
                        field(.apellidos, "Apellidos", prompt: "Apellidos", text: \.apellidos)
                            .textContentType(.familyName)
                    }

                    field(.documento, "Documento (DUI)", prompt: "00000000-0", text: \.documento, mask: InputMask.dui)
                        .keyboardType(.numberPad)

                    DSDateField(
                        "Fecha de nacimiento",
                        date: fechaNacimiento,
                        errorMessage: viewModel.error(for: .fechaNacimiento),
                        in: viewModel.rangoFechaNacimiento
                    )

                    field(.telefono, "Teléfono", prompt: "0000-0000", text: \.telefono, mask: InputMask.telefono)
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)

                    field(.email, "Correo electrónico", prompt: "nombre@correo.com", text: \.email)
                        .keyboardType(.emailAddress)
                        .textContentType(.username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    field(.password, "Contraseña", prompt: "Mínimo 8 caracteres", text: \.password, isSecure: true)
                        .textContentType(.newPassword)

                    Text("Contacto de emergencia")
                        .dsEyebrow()
                        .foregroundStyle(DSColor.textSecondary)
                        .padding(.top, DSSpacing.tiny)
                        .accessibilityAddTraits(.isHeader)

                    FieldPair {
                        field(.contactoNombre, "Nombre", prompt: "Nombre", text: \.contactoNombre)
                            .textContentType(.name)
                    } trailing: {
                        field(.contactoTelefono, "Teléfono", prompt: "0000-0000", text: \.contactoTelefono, mask: InputMask.telefono)
                            .keyboardType(.phonePad)
                    }

                    field(.alergias, "Alergias (opcional)", prompt: "Ej. penicilina", text: \.alergias)
                        .submitLabel(.done)
                }
                .padding(.horizontal, DSSpacing.regular)
                .padding(.top, DSSpacing.medium)
                .padding(.bottom, DSSpacing.large)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(DSColor.background)
            .safeAreaInset(edge: .bottom) { footer }
            .navigationTitle("Crear cuenta")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(DSColor.background, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                        .foregroundStyle(DSColor.tint)
                }
            }
            .onChange(of: focusedField) { previous, _ in
                if let previous { viewModel.didLeave(previous) }
            }
        }
        .interactiveDismissDisabled(viewModel.isLoading)
    }

    // MARK: Botón fijo al pie (44:912)

    private var footer: some View {
        VStack(spacing: DSSpacing.medium) {
            if let info = viewModel.infoMessage {
                DSBanner(info, kind: .info)
            }
            if let error = viewModel.errorMessage {
                DSBanner(error)
            }
            DSButton("Crear cuenta", isLoading: viewModel.isLoading, loadingTitle: "Creando cuenta…") {
                focusedField = nil
                Task { await viewModel.submit() }
            }
        }
        .padding(.horizontal, DSSpacing.regular)
        .padding(.top, DSSpacing.medium)
        .padding(.bottom, DSSpacing.small)
        .background(DSColor.background)
    }

    // MARK: Campos

    private func field(
        _ field: Field,
        _ label: LocalizedStringKey,
        prompt: LocalizedStringKey,
        text keyPath: ReferenceWritableKeyPath<RegistroViewModel, String>,
        mask: ((String) -> String)? = nil,
        isSecure: Bool = false
    ) -> some View {
        let binding = Binding<String>(
            get: { viewModel[keyPath: keyPath] },
            set: { newValue in
                let value = mask?(newValue) ?? newValue
                guard value != viewModel[keyPath: keyPath] else { return }
                viewModel[keyPath: keyPath] = value
                viewModel.didEdit(field)
            }
        )
        return DSTextField(label, text: binding, prompt: prompt, errorMessage: viewModel.error(for: field), isSecure: isSecure)
            .focused($focusedField, equals: field)
            .submitLabel(.next)
            .onSubmit { focusNext(after: field) }
    }

    /// El calendario no es un campo de texto: el teclado salta de documento a teléfono.
    private var fechaNacimiento: Binding<Date?> {
        Binding(
            get: { viewModel.fechaNacimiento },
            set: { newValue in
                viewModel.fechaNacimiento = newValue
                viewModel.didEdit(.fechaNacimiento)
                if newValue != nil { viewModel.didLeave(.fechaNacimiento) }
            }
        )
    }

    private func focusNext(after field: Field) {
        let fields = Field.allCases.filter { $0 != .fechaNacimiento }
        guard let index = fields.firstIndex(of: field), index + 1 < fields.count else {
            focusedField = nil
            return
        }
        focusedField = fields[index + 1]
    }
}

/// Dos campos lado a lado con gap 10. Con texto de accesibilidad se apilan.
private struct FieldPair<Leading: View, Trailing: View>: View {
    @ViewBuilder let leading: Leading
    @ViewBuilder let trailing: Trailing
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: DSSpacing.medium))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 10))
        layout {
            leading.frame(maxWidth: .infinity)
            trailing.frame(maxWidth: .infinity)
        }
    }
}

#Preview("Registro") {
    RegistroView(viewModel: RegistroViewModel(session: .preview()))
}
