import SwiftUI

/// iOS-C2 Login (Figma 44:775, alta fidelidad).
struct LoginView: View {
    @State var viewModel: LoginViewModel
    @FocusState private var focusedField: Field?

    private enum Field {
        case email
        case password
    }

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                ScrollView {
                    VStack(spacing: 28) {
                        DSBrandHeader()
                        form
                        Spacer(minLength: 0)
                        publicInfoFooter
                    }
                    .padding(.top, DSSpacing.xLarge)
                    .padding(.horizontal, DSSpacing.large)
                    .frame(minHeight: proxy.size.height)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
            .background(DSColor.background)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: LoginDestination.self) { _ in
                InformacionPublicaView()
            }
        }
        .sheet(isPresented: $viewModel.isShowingRegistro) {
            RegistroView(viewModel: RegistroViewModel(session: viewModel.session))
        }
        .sheet(isPresented: $viewModel.isShowingRecuperar) {
            RecuperarContrasenaView(viewModel: RecuperarContrasenaViewModel(session: viewModel.session))
        }
    }

    // MARK: Formulario (44:796, gap 16)

    private var form: some View {
        VStack(spacing: DSSpacing.regular) {
            if !viewModel.isSupabaseConfigured {
                DSBanner(AuthServiceError.missingConfiguration.localizedDescription, kind: .notice)
            }

            DSTextField("Correo electrónico", text: $viewModel.email, prompt: "nombre@correo.com")
                .keyboardType(.emailAddress)
                .textContentType(.username)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.next)
                .focused($focusedField, equals: .email)
                .onSubmit { focusedField = .password }

            DSTextField("Contraseña", text: $viewModel.password, prompt: "Tu contraseña", isSecure: true)
                .textContentType(.password)
                .submitLabel(.go)
                .focused($focusedField, equals: .password)
                .onSubmit(submit)

            Button("¿Olvidaste tu contraseña?") {
                viewModel.isShowingRecuperar = true
            }
            .font(.system(.subheadline, weight: .medium))
            .foregroundStyle(DSColor.tint)
            .frame(minHeight: DSSize.minTapTarget)
            .frame(maxWidth: .infinity, alignment: .trailing)
            // Área táctil de 44: arriba suma 12 al gap (28, como el Figma); abajo se compensa.
            .padding(.bottom, -DSSpacing.medium)

            if let error = viewModel.errorMessage {
                DSBanner(error)
                    .transition(.opacity)
            }

            DSButton("Ingresar", isLoading: viewModel.isLoading, loadingTitle: "Ingresando…", action: submit)
                .disabled(!viewModel.canSubmit)

            Button {
                viewModel.isShowingRegistro = true
            } label: {
                Text("¿Eres paciente nuevo? ")
                    .foregroundStyle(DSColor.textSecondary)
                + Text("Crear cuenta")
                    .fontWeight(.semibold)
                    .foregroundStyle(DSColor.tint)
            }
            .font(DSFont.bodySecondary)
            .multilineTextAlignment(.center)
            .accessibilityLabel("¿Eres paciente nuevo? Crear cuenta")
        }
        .onChange(of: viewModel.email) { viewModel.clearError() }
        .onChange(of: viewModel.password) { viewModel.clearError() }
        .animation(.easeOut(duration: 0.15), value: viewModel.errorMessage)
    }

    // MARK: Pie sin sesión (44:823, gap 12)

    private var publicInfoFooter: some View {
        VStack(spacing: DSSpacing.medium) {
            HStack(spacing: 10) {
                divider
                Text("sin iniciar sesión")
                    .font(DSFont.footnote)
                    .foregroundStyle(DSColor.textTertiary)
                    .layoutPriority(1)
                divider
            }

            NavigationLink(value: LoginDestination.informacionPublica) {
                Label("Ver información del hospital", systemImage: "info.circle")
            }
            .buttonStyle(DSButtonStyle(kind: .secondary))

            Text("Ocupación general, médicos de turno y avisos. No muestra datos de pacientes.")
                .font(DSFont.footnote)
                .foregroundStyle(DSColor.textTertiary)
                .multilineTextAlignment(.center)
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(DSColor.border)
            .frame(height: 1)
            .accessibilityHidden(true)
    }

    private func submit() {
        focusedField = nil
        Task { await viewModel.signIn() }
    }
}

private enum LoginDestination: Hashable {
    case informacionPublica
}

#Preview("Login") {
    LoginView(viewModel: LoginViewModel(session: .preview()))
}

#Preview("Login · oscuro + texto grande") {
    LoginView(viewModel: LoginViewModel(session: .preview()))
        .preferredColorScheme(.dark)
        .dynamicTypeSize(.accessibility2)
}
