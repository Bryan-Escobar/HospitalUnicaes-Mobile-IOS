import SwiftUI

/// Global 401: el refresh del token falló o `/me` respondió 401. La sesión ya se borró del
/// Keychain; "Ingresar de nuevo" lleva a Login.
struct SessionExpiredView: View {
    @Environment(SessionViewModel.self) private var session

    var body: some View {
        VStack(spacing: DSSpacing.regular) {
            Image(systemName: "arrow.counterclockwise")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(DSTone.info.foreground)
                .frame(width: 72, height: 72)
                .background(DSTone.info.background, in: Circle())
                .overlay { Circle().strokeBorder(DSTone.info.border, lineWidth: 2) }
                .accessibilityHidden(true)

            Text("Tu sesión expiró")
                .font(.system(.title2, weight: .bold))
                .foregroundStyle(DSColor.textPrimary)
                .accessibilityAddTraits(.isHeader)

            Text("Por seguridad, vuelve a ingresar con tu correo y contraseña.")
                .font(DSFont.body)
                .foregroundStyle(DSColor.textSecondary)

            DSButton("Ingresar de nuevo") {
                session.acknowledgeExpiredSession()
            }
            .padding(.horizontal, DSSpacing.medium)
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, DSSpacing.regular)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DSColor.background)
    }
}
