import SwiftUI

/// iOS-C1 Splash / restaurando sesión (Figma 44:747). Lo muestra `RootView` mientras
/// `SessionViewModel.restore()` lee el Keychain y pide `/me`.
struct SplashView: View {
    var body: some View {
        VStack(spacing: DSSpacing.medium) {
            VStack(spacing: 17.5) {
                DSLogo()

                VStack(spacing: 0) {
                    Text("HospitalUnicaes")
                        .font(.system(.title, weight: .bold))
                        .foregroundStyle(.white)
                    Text("Hospital Universitario Central")
                        .font(DSFont.bodySecondary)
                        .foregroundStyle(DSColor.Brand.splashText)
                }
                .multilineTextAlignment(.center)
                .accessibilityElement(children: .combine)

                HStack(spacing: 10) {
                    SplashSpinner()
                    Text("Restaurando sesión…")
                        .font(DSFont.bodySecondary)
                        .foregroundStyle(DSColor.Brand.splashText)
                }
                .accessibilityElement(children: .combine)
            }
            .frame(maxHeight: .infinity)

            Text("Universidad Católica de El Salvador")
                .font(.system(.caption))
                .foregroundStyle(DSColor.Brand.gold)
                .multilineTextAlignment(.center)
                .padding(.bottom, DSSpacing.regular)
        }
        .padding(.horizontal, DSSpacing.large)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DSColor.Brand.splashBackground)
        // Barra de estado en blanco solo sobre el fondo granate.
        .preferredColorScheme(.dark)
    }
}

/// Aro de 18 pt dorado que gira (44:768). Con "Reducir movimiento" queda quieto.
private struct SplashSpinner: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isRotating = false

    var body: some View {
        Circle()
            .trim(from: 0, to: 0.75)
            .stroke(DSColor.Brand.gold, style: StrokeStyle(lineWidth: 2, lineCap: .round))
            .frame(width: 16, height: 16)
            .padding(1)
            .rotationEffect(.degrees(isRotating ? 360 : 0))
            .animation(
                reduceMotion ? nil : .linear(duration: 0.9).repeatForever(autoreverses: false),
                value: isRotating
            )
            .onAppear { isRotating = true }
            .accessibilityHidden(true)
    }
}

#Preview("Splash") {
    SplashView()
}
