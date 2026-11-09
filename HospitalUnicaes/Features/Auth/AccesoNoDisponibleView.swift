import SwiftUI

/// iOS-C6 Acceso no disponible (Figma 44:1034), para administrador y recepcionista.
/// No carga datos: solo explica a dónde ir y permite cerrar sesión. Sin TabBar.
struct AccesoNoDisponibleView: View {
    @Environment(SessionViewModel.self) private var session
    let me: Me

    var body: some View {
        ScrollView {
            VStack(spacing: DSSpacing.regular) {
                Text("!")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(DSTone.warning.foreground)
                    .frame(width: 72, height: 72)
                    .background(DSTone.warning.background, in: Circle())
                    .overlay { Circle().strokeBorder(DSTone.warning.border, lineWidth: 2) }
                    .accessibilityHidden(true)

                Text("Esta app es para doctores y pacientes")
                    .font(.system(.title2, weight: .bold))
                    .foregroundStyle(DSColor.textPrimary)
                    .accessibilityAddTraits(.isHeader)

                Self.mensaje(for: me.rol)
                    .font(DSFont.body)
                    .foregroundStyle(DSColor.textSecondary)

                Self.nota(for: me.rol)
                    .font(DSFont.bodySecondary)
                    .foregroundStyle(DSColor.textTertiary)

                DSButton("Cerrar sesión", systemImage: "rectangle.portrait.and.arrow.right", kind: .secondary) {
                    Task { await session.signOut() }
                }
            }
            .multilineTextAlignment(.center)
            // 16 de margen + 12 del contenedor del Figma (textos y botón de 337 en 393).
            .padding(.horizontal, DSSpacing.regular + DSSpacing.medium)
            .containerRelativeFrame(.vertical, alignment: .center)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(DSColor.background)
    }

    /// "Tu cuenta es de **Recepcionista/Asistente**. Usa la app Android del hospital."
    static func mensaje(for rol: UserRole) -> Text {
        let destino = rol == .administrador
            ? "Entra al panel Web desde una computadora."
            : "Usa la app Android del hospital."
        return Text("Tu cuenta es de ")
            + Text(rol.displayName).fontWeight(.semibold).foregroundColor(DSColor.textPrimary)
            + Text(". \(destino)")
    }

    /// Nota en gris para el otro rol que no usa iOS.
    static func nota(for rol: UserRole) -> Text {
        if rol == .administrador {
            return Text("Si eres ") + Text("Recepcionista/Asistente").fontWeight(.semibold)
                + Text(", usa la app Android del hospital.")
        }
        return Text("Si eres ") + Text("Administrador").fontWeight(.semibold)
            + Text(", entra al panel Web desde una computadora.")
    }
}

#Preview("Recepcionista") {
    AccesoNoDisponibleView(me: .previewRecepcion)
        .environment(SessionViewModel.preview())
}

#Preview("Administrador · texto grande") {
    AccesoNoDisponibleView(me: .previewAdmin)
        .environment(SessionViewModel.preview())
        .dynamicTypeSize(.accessibility2)
}
