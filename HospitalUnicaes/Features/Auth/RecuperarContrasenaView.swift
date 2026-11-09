import SwiftUI

/// iOS-C4 Recuperar contraseña (Figma 44:917), sheet desde Login.
struct RecuperarContrasenaView: View {
    @State var viewModel: RecuperarContrasenaViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DSSpacing.regular) {
                HStack {
                    Spacer()
                    Button("Cerrar") { dismiss() }
                        .font(DSFont.body)
                        .foregroundStyle(DSColor.tint)
                        .frame(minHeight: DSSize.minTapTarget)
                }
                .padding(.bottom, -DSSpacing.small)

                Text("Recuperar contraseña")
                    .font(.system(.title, weight: .bold))
                    .foregroundStyle(DSColor.textPrimary)
                    .accessibilityAddTraits(.isHeader)

                Text("Escribe el correo de tu cuenta y te enviaremos un enlace.")
                    .font(DSFont.body)
                    .foregroundStyle(DSColor.textSecondary)

                DSTextField("Correo electrónico", text: $viewModel.email, prompt: "nombre@correo.com")
                    .keyboardType(.emailAddress)
                    .textContentType(.username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.send)
                    .onSubmit { Task { await viewModel.send() } }

                if viewModel.didSend {
                    DSBanner("Si el correo tiene una cuenta, te llegará un enlace en unos minutos.", kind: .info)
                } else if let error = viewModel.errorMessage {
                    DSBanner(error)
                }

                DSButton("Enviar enlace", isLoading: viewModel.isLoading, loadingTitle: "Enviando…") {
                    Task { await viewModel.send() }
                }
                .disabled(!viewModel.canSubmit)

                Text("Por privacidad, la respuesta es la misma exista o no el correo.")
                    .font(DSFont.footnote)
                    .foregroundStyle(DSColor.textSecondary)
            }
            .padding(.horizontal, DSSpacing.regular)
            .padding(.top, DSSpacing.regular)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(DSColor.background)
        .presentationDetents([.fraction(0.62), .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(DSRadius.sheet)
    }
}

#Preview("Recuperar contraseña") {
    Color.black.sheet(isPresented: .constant(true)) {
        RecuperarContrasenaView(viewModel: RecuperarContrasenaViewModel(session: .preview()))
    }
}
