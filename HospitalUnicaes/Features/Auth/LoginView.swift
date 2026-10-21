import SwiftUI

struct LoginView: View {
    @State var viewModel: LoginViewModel

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Correo electrónico", text: $viewModel.email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                    SecureField("Contraseña", text: $viewModel.password)
                        .textContentType(.password)
                }

                if let error = viewModel.errorMessage {
                    Text(error).foregroundStyle(.red)
                }

                Button {
                    Task { await viewModel.signIn() }
                } label: {
                    if viewModel.isLoading {
                        ProgressView()
                    } else {
                        Text("Iniciar sesión")
                    }
                }
                .disabled(!viewModel.canSubmit)
            }
            .navigationTitle("Hospital Universitario")
        }
    }
}
