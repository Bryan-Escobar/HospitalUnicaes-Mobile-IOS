import SwiftUI

/// Escala de espaciado, base 4 (handoff §4.5).
enum DSSpacing {
    static let tiny: CGFloat = 4
    static let small: CGFloat = 8
    static let medium: CGFloat = 12
    static let regular: CGFloat = 16
    static let large: CGFloat = 24
    static let xLarge: CGFloat = 32
    static let xxLarge: CGFloat = 48

    /// Margen lateral de pantalla (Login usa `large`).
    static let screenMargin: CGFloat = 16
}

/// Radios de esquina observados en la alta fidelidad iOS (handoff §4.5).
enum DSRadius {
    static let chip: CGFloat = 8
    static let field: CGFloat = 12
    static let button: CGFloat = 14
    static let iconContainer: CGFloat = 14
    static let card: CGFloat = 18
    static let sheet: CGFloat = 28
}

/// Medidas de controles (handoff §5.1). Las vistas las escalan con `@ScaledMetric`.
enum DSSize {
    /// Botón primario/secundario grande.
    static let buttonHeight: CGFloat = 52
    /// Botón dentro de tarjeta (emergencia "Solicitar").
    static let buttonCompactHeight: CGFloat = 48
    /// Alto del input de un campo de texto.
    static let fieldHeight: CGFloat = 50
    /// Área táctil mínima de iOS.
    static let minTapTarget: CGFloat = 44
}
