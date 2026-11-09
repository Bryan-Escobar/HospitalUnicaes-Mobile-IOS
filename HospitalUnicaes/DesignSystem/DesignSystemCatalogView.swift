import SwiftUI

/// Catálogo de tokens y componentes para revisar el sistema de diseño en las Previews de Xcode.
/// No forma parte de la navegación de la app.
struct DesignSystemCatalogView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var documento = "0123-45"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DSSpacing.large) {
                section("Color") { colors }
                section("Tipografía") { typography }
                section("Botones") { buttons }
                section("Campos de texto") { fields }
                section("Badges de estado") { badges }
                section("En vivo y avatar") { liveAndAvatar }
            }
            .padding(DSSpacing.regular)
        }
        .background(DSColor.backgroundGrouped)
    }

    // MARK: Secciones

    private var colors: some View {
        let swatches: [(String, Color)] = [
            ("action", DSColor.action),
            ("tint", DSColor.tint),
            ("selection", DSColor.selection),
            ("danger", DSColor.danger),
            ("textPrimary", DSColor.textPrimary),
            ("textSecondary", DSColor.textSecondary),
            ("textTertiary", DSColor.textTertiary),
            ("border", DSColor.border),
            ("background", DSColor.background),
            ("surface", DSColor.surface),
        ]
        return LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 90), spacing: DSSpacing.small)],
            spacing: DSSpacing.small
        ) {
            ForEach(swatches, id: \.0) { swatch in
                VStack(alignment: .leading, spacing: DSSpacing.tiny) {
                    RoundedRectangle(cornerRadius: DSRadius.chip, style: .continuous)
                        .fill(swatch.1)
                        .frame(height: 44)
                        .overlay {
                            RoundedRectangle(cornerRadius: DSRadius.chip, style: .continuous)
                                .strokeBorder(DSColor.border, lineWidth: 1)
                        }
                    Text(swatch.0)
                        .font(DSFont.footnote)
                        .foregroundStyle(DSColor.textSecondary)
                }
            }
        }
    }

    private var typography: some View {
        VStack(alignment: .leading, spacing: DSSpacing.small) {
            Text("Mis citas").font(DSFont.largeTitle)
            Text("Próxima cita").font(DSFont.title)
            Text("Dra. Ana Rivas · Alergista").font(DSFont.subtitle)
            Text("Recepción revisará tu solicitud.").font(DSFont.body)
            Text("Hemograma completo").font(DSFont.bodySecondary)
            Text("Actualizado hace 5 s").font(DSFont.footnote)
        }
        .foregroundStyle(DSColor.textPrimary)
    }

    private var buttons: some View {
        VStack(spacing: DSSpacing.medium) {
            DSButton("Ingresar") {}
            DSButton("Ver información", kind: .secondary) {}
            DSButton("Dar de alta", kind: .destructive) {}
            DSButton("Despachar") {}
                .disabled(true)
            DSButton("Guardar", isLoading: true) {}
            DSButton("¿Olvidaste tu contraseña?", kind: .text) {}
        }
    }

    private var fields: some View {
        VStack(spacing: DSSpacing.regular) {
            DSTextField("Correo electrónico", text: $email, prompt: "nombre@correo.com")
            DSTextField("Contraseña", text: $password, prompt: "Tu contraseña", isSecure: true)
            DSTextField("Documento", text: $documento, errorMessage: "Formato: 00000000-0")
        }
    }

    private var badges: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 150), alignment: .leading)],
            alignment: .leading,
            spacing: DSSpacing.small
        ) {
            ForEach(DSStatus.allCases) { status in
                DSStatusBadge(status)
            }
        }
    }

    private var liveAndAvatar: some View {
        HStack(spacing: DSSpacing.small) {
            DSLiveIndicator(.live)
            DSLiveIndicator(.reconnecting)
            Spacer(minLength: 0)
            DSAvatar(name: "Luis Martínez")
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        DSCard(spacing: DSSpacing.medium) {
            Text(title).font(DSFont.subtitle)
            content()
        }
    }
}

#Preview("Catálogo · claro") {
    DesignSystemCatalogView()
}

#Preview("Catálogo · oscuro") {
    DesignSystemCatalogView()
        .preferredColorScheme(.dark)
}

#Preview("Catálogo · texto grande") {
    DesignSystemCatalogView()
        .dynamicTypeSize(.accessibility3)
}
