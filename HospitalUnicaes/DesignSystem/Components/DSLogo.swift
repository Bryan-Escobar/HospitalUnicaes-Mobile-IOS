import SwiftUI

/// Logo de HospitalUnicaes (Figma 44:757): cuadro granate 72×72 con aro dorado y cruz blanca.
/// Es el SVG exportado del Figma (`Assets.xcassets/Logo`), no un dibujo en código.
struct DSLogo: View {
    private let size: CGFloat

    init(size: CGFloat = 72) {
        self.size = size
    }

    var body: some View {
        Image("Logo")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            // El nombre del hospital siempre va junto al logo.
            .accessibilityHidden(true)
    }
}

/// Encabezado de marca de Login (44:785): logo, nombre y subtítulo con gap 12.
struct DSBrandHeader: View {
    var body: some View {
        VStack(spacing: DSSpacing.medium) {
            DSLogo()
            VStack(spacing: 0) {
                Text("HospitalUnicaes")
                    .font(.system(.title, weight: .bold))
                    .tracking(-0.28)
                    .foregroundStyle(DSColor.textPrimary)
                Text("Hospital Universitario Central")
                    .font(DSFont.bodySecondary)
                    .foregroundStyle(DSColor.textSecondary)
            }
            .multilineTextAlignment(.center)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview("Logo") {
    VStack(spacing: DSSpacing.large) {
        DSBrandHeader()
        HStack(spacing: DSSpacing.medium) {
            DSLogo(size: 40)
            DSLogo()
        }
    }
    .padding()
    .background(DSColor.background)
}
