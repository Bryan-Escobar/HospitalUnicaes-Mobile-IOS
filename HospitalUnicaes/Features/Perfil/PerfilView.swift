import SwiftUI

/// iOS-C7 Perfil (Figma 44:1060). En HUNI-39 solo cabecera, datos y cerrar sesión;
/// Notificaciones y Accesibilidad quedan visibles sin acción.
struct PerfilView: View {
    @State var viewModel: PerfilViewModel
    @Environment(SessionViewModel.self) private var session

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DSSpacing.medium) {
                    header
                    datos
                    ajustes
                    DSButton(
                        "Cerrar sesión",
                        systemImage: "rectangle.portrait.and.arrow.right",
                        kind: .destructive,
                        isLoading: viewModel.isSigningOut,
                        loadingTitle: "Cerrando sesión…"
                    ) {
                        viewModel.isConfirmingSignOut = true
                    }
                }
                .padding(.horizontal, DSSpacing.regular)
                .padding(.top, DSSpacing.small)
                .padding(.bottom, DSSpacing.regular)
            }
            .background(DSColor.backgroundGrouped)
            .navigationTitle("Perfil")
            .confirmationDialog(
                "¿Cerrar sesión?",
                isPresented: $viewModel.isConfirmingSignOut,
                titleVisibility: .visible
            ) {
                Button("Cerrar sesión", role: .destructive) {
                    Task { await viewModel.signOut(using: session) }
                }
                Button("Cancelar", role: .cancel) {}
            } message: {
                Text("Tendrás que ingresar de nuevo con tu correo y contraseña.")
            }
        }
    }

    // MARK: Tarjetas

    private var header: some View {
        HStack(spacing: 14) {
            DSAvatar(name: viewModel.nombre, size: 56)
            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.nombre)
                    .font(.system(.title3, weight: .semibold))
                    .foregroundStyle(DSColor.textPrimary)
                Text(viewModel.rolYTipo)
                    .font(DSFont.bodySecondary)
                    .foregroundStyle(DSColor.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, DSSpacing.regular)
        .dsCardBackground()
        .accessibilityElement(children: .combine)
    }

    private var datos: some View {
        VStack(spacing: 0) {
            ForEach(Array(viewModel.rows.enumerated()), id: \.element.id) { index, row in
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .firstTextBaseline, spacing: DSSpacing.medium) {
                        rowLabel(row)
                        Spacer(minLength: DSSpacing.small)
                        rowValue(row).multilineTextAlignment(.trailing)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        rowLabel(row)
                        rowValue(row)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.vertical, 9)
                .overlay(alignment: .bottom) {
                    if index < viewModel.rows.count - 1 { separator }
                }
                .accessibilityElement(children: .combine)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, DSSpacing.regular)
        .dsCardBackground()
    }

    private func rowLabel(_ row: PerfilViewModel.Row) -> some View {
        Text(row.label)
            .font(DSFont.bodySecondary)
            .foregroundStyle(DSColor.textSecondary)
    }

    private func rowValue(_ row: PerfilViewModel.Row) -> some View {
        Text(row.value)
            .font(DSFont.bodySecondaryEmphasis)
            .foregroundStyle(DSColor.textPrimary)
    }

    private var ajustes: some View {
        VStack(spacing: 0) {
            ajusteRow("Notificaciones")
                .overlay(alignment: .bottom) { separator }
            ajusteRow("Accesibilidad y texto")
        }
        .padding(.horizontal, DSSpacing.regular)
        .dsCardBackground()
    }

    private func ajusteRow(_ title: String) -> some View {
        HStack(spacing: DSSpacing.medium) {
            Text(title)
                .font(DSFont.bodySecondaryEmphasis)
                .foregroundStyle(DSColor.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DSColor.textTertiary)
                .accessibilityHidden(true)
        }
        .frame(minHeight: 52)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Próximamente")
    }

    private var separator: some View {
        Rectangle()
            .fill(DSColor.backgroundGrouped)
            .frame(height: 1)
    }
}

#Preview("Perfil · doctor") {
    PerfilView(viewModel: PerfilViewModel(me: .previewDoctor))
        .environment(SessionViewModel.preview())
}

#Preview("Perfil · paciente oscuro") {
    PerfilView(viewModel: PerfilViewModel(me: .previewPaciente))
        .environment(SessionViewModel.preview())
        .preferredColorScheme(.dark)
}
