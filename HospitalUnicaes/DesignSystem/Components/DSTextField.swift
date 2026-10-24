import SwiftUI

/// Campo de texto con etiqueta arriba (handoff §5.1 y §6).
///
/// Estados: normal, foco (borde 2 teal + halo), error (borde rojo + mensaje con icono),
/// deshabilitado (`.disabled(true)`), contraseña con botón mostrar/ocultar y área de texto
/// (`axis: .vertical`). Los modificadores de teclado (`.keyboardType`, `.textContentType`,
/// `.submitLabel`…) se aplican desde fuera y llegan al campo interno.
///
/// ```swift
/// DSTextField("Correo electrónico", text: $viewModel.email, prompt: "nombre@correo.com")
///     .keyboardType(.emailAddress)
///     .textContentType(.emailAddress)
/// ```
struct DSTextField: View {
    private let label: LocalizedStringKey
    @Binding private var text: String
    private let prompt: LocalizedStringKey?
    private let errorMessage: String?
    private let isSecure: Bool
    private let axis: Axis

    @FocusState private var isFocused: Bool
    @State private var isRevealed = false
    @Environment(\.isEnabled) private var isEnabled
    @ScaledMetric(relativeTo: .body) private var fieldHeight = DSSize.fieldHeight

    init(
        _ label: LocalizedStringKey,
        text: Binding<String>,
        prompt: LocalizedStringKey? = nil,
        errorMessage: String? = nil,
        isSecure: Bool = false,
        axis: Axis = .horizontal
    ) {
        self.label = label
        _text = text
        self.prompt = prompt
        self.errorMessage = errorMessage
        self.isSecure = isSecure
        self.axis = axis
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(DSFont.fieldLabel)
                .foregroundStyle(DSColor.textLabel)
                .accessibilityHidden(true)

            inputContainer

            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.circle")
                    .font(DSFont.footnote)
                    .foregroundStyle(DSColor.dangerText)
                    .accessibilityLabel("Error: \(errorMessage)")
            }
        }
    }

    // MARK: Partes

    private var isMultiline: Bool { axis == .vertical }

    private var inputContainer: some View {
        let shape = RoundedRectangle(cornerRadius: DSRadius.field, style: .continuous)

        return HStack(alignment: isMultiline ? .top : .center, spacing: DSSpacing.small) {
            input
                .font(DSFont.body)
                .foregroundStyle(isEnabled ? DSColor.textPrimary : DSColor.disabledText)
                .tint(DSColor.action)
                .focused($isFocused)

            if isSecure {
                Button {
                    isRevealed.toggle()
                } label: {
                    Image(systemName: isRevealed ? "eye.slash" : "eye")
                        .frame(minWidth: DSSize.minTapTarget, minHeight: DSSize.minTapTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(DSColor.textTertiary)
                .accessibilityLabel(isRevealed ? "Ocultar contraseña" : "Mostrar contraseña")
            }
        }
        .padding(.leading, 14)
        .padding(.trailing, isSecure ? 4 : 14)
        .padding(.vertical, isMultiline ? 14 : 0)
        .frame(
            minHeight: isMultiline ? fieldHeight * 2 : fieldHeight,
            alignment: isMultiline ? .topLeading : .leading
        )
        .background(isEnabled ? DSColor.surface : DSColor.disabledFill, in: shape)
        .overlay { shape.strokeBorder(borderColor, lineWidth: borderWidth) }
        .background {
            // Halo de foco de 3 pt por fuera del borde.
            if isFocused && errorMessage == nil {
                RoundedRectangle(cornerRadius: DSRadius.field + 3, style: .continuous)
                    .fill(DSColor.focusHalo)
                    .padding(-3)
            }
        }
        .contentShape(shape)
        .onTapGesture { isFocused = true }
        .animation(.easeOut(duration: 0.15), value: isFocused)
    }

    @ViewBuilder
    private var input: some View {
        let promptText: Text? = prompt.map { Text($0).foregroundStyle(DSColor.textTertiary) }

        if isSecure && !isRevealed {
            SecureField(label, text: $text, prompt: promptText)
        } else {
            TextField(label, text: $text, prompt: promptText, axis: axis)
                .lineLimit(isMultiline ? 3...8 : 1...1)
        }
    }

    private var borderColor: Color {
        if !isEnabled { return DSColor.border }
        if errorMessage != nil { return DSColor.dangerText }
        return isFocused ? DSColor.focusRing : DSColor.borderInput
    }

    private var borderWidth: CGFloat {
        isEnabled && (errorMessage != nil || isFocused) ? 2 : 1.5
    }
}

// MARK: - Previews

private struct DSTextFieldPreview: View {
    @State private var email = ""
    @State private var password = "secreto123"
    @State private var documento = "0123-45"
    @State private var notas = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DSSpacing.regular) {
                DSTextField("Correo electrónico", text: $email, prompt: "nombre@correo.com")
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                DSTextField("Contraseña", text: $password, isSecure: true)
                DSTextField("Documento", text: $documento, errorMessage: "Formato: 00000000-0")
                DSTextField("Teléfono", text: .constant("7000-0000"))
                    .disabled(true)
                DSTextField("Notas", text: $notas, prompt: "Indicaciones para recepción", axis: .vertical)
            }
            .padding(DSSpacing.large)
        }
        .background(DSColor.background)
    }
}

#Preview("Campos de texto") {
    DSTextFieldPreview()
}

#Preview("Campos · oscuro + texto grande") {
    DSTextFieldPreview()
        .preferredColorScheme(.dark)
        .dynamicTypeSize(.accessibility2)
}
