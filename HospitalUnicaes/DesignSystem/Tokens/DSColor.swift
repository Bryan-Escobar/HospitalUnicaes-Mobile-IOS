import SwiftUI
import UIKit

/// Colores del sistema de diseño (handoff Figma §4.1 y §4.2).
///
/// Las vistas usan solo los tokens semánticos (`DSColor.textPrimary`, `DSColor.action`…);
/// las primitivas existen para documentar la paleta y para las previews.
/// Cada token semántico define su valor claro (el del Figma) y su valor oscuro.
enum DSColor {

    // MARK: Primitivas (paleta base, solo modo claro)

    enum Primitive {
        static let primary50 = Color(hex: 0xECFEFF)
        static let primary100 = Color(hex: 0xCFFAFE)
        static let primary200 = Color(hex: 0xA5F3FC)
        static let primary700 = Color(hex: 0x0E7490)
        static let primary800 = Color(hex: 0x155E75)
        static let primary900 = Color(hex: 0x164E63)

        static let neutral0 = Color(hex: 0xFFFFFF)
        static let neutral50 = Color(hex: 0xF8FAFC)
        static let neutral100 = Color(hex: 0xF1F5F9)
        static let neutral200 = Color(hex: 0xE2E8F0)
        static let neutral300 = Color(hex: 0xCBD5E1)
        static let neutral400 = Color(hex: 0x94A3B8)
        static let neutral500 = Color(hex: 0x64748B)
        static let neutral600 = Color(hex: 0x475569)
        static let neutral700 = Color(hex: 0x334155)
        static let neutral900 = Color(hex: 0x0F172A)

        static let danger50 = Color(hex: 0xFEF2F2)
        static let danger300 = Color(hex: 0xFCA5A5)
        static let danger700 = Color(hex: 0xB91C1C)
        static let danger900 = Color(hex: 0x7F1D1D)
    }

    // MARK: Fondos y superficies

    /// Fondo de formularios y Login (`neutral/50`).
    static let background = Color.dynamic(light: 0xF8FAFC, dark: 0x0F172A)
    /// Fondo de pantallas con tarjetas: Inicio, listas (`neutral/100`).
    static let backgroundGrouped = Color.dynamic(light: 0xF1F5F9, dark: 0x020617)
    /// Superficie de tarjetas y campos (`neutral/0`).
    static let surface = Color.dynamic(light: 0xFFFFFF, dark: 0x1E293B)

    // MARK: Bordes

    /// Borde sutil de tarjetas y divisores (`neutral/200`).
    static let border = Color.dynamic(light: 0xE2E8F0, dark: 0x334155)
    /// Borde por defecto de campos (`neutral/300`).
    static let borderInput = Color.dynamic(light: 0xCBD5E1, dark: 0x475569)
    /// Borde fuerte: chips sin seleccionar (`neutral/400`).
    static let borderStrong = Color.dynamic(light: 0x94A3B8, dark: 0x64748B)

    // MARK: Texto

    /// Texto 1, principal (`neutral/900`).
    static let textPrimary = Color.dynamic(light: 0x0F172A, dark: 0xF8FAFC)
    /// Texto 2, secundario (`neutral/600`).
    static let textSecondary = Color.dynamic(light: 0x475569, dark: 0xCBD5E1)
    /// Texto 3: iconos inactivos, pies, placeholders (`neutral/500`).
    static let textTertiary = Color.dynamic(light: 0x64748B, dark: 0x94A3B8)
    /// Etiquetas de campos (`neutral/700`).
    static let textLabel = Color.dynamic(light: 0x334155, dark: 0xE2E8F0)

    // MARK: Acción (teal clínico)

    /// Relleno de botón primario y tarjeta destacada (`primary/700`, 5,4:1 con texto blanco).
    static let action = Color.dynamic(light: 0x0E7490, dark: 0x0E7490)
    /// Botón primario presionado (`primary/800`).
    static let actionPressed = Color.dynamic(light: 0x155E75, dark: 0x155E75)
    /// Texto e iconos sobre `action`.
    static let onAction = Color.white
    /// Enlaces, texto de botón secundario, tab activo. En oscuro se aclara para mantener contraste.
    static let tint = Color.dynamic(light: 0x0E7490, dark: 0x67E8F9)
    /// `tint` presionado.
    static let tintPressed = Color.dynamic(light: 0x155E75, dark: 0xA5F3FC)
    /// Fondo de selección: segmentado activo, chip activo, botón secundario presionado (`primary/100`).
    static let selection = Color.dynamic(light: 0xCFFAFE, dark: 0x083344)

    // MARK: Foco

    /// Borde de campo con foco (2 pt).
    static let focusRing = Color.dynamic(light: 0x0E7490, dark: 0x22D3EE)
    /// Halo de foco alrededor del campo (3 pt, `primary/100`).
    static let focusHalo = Color.dynamic(light: 0xCFFAFE, dark: 0x164E63)

    // MARK: Peligro

    /// Relleno de botón destructivo y de emergencia (`danger/700`).
    static let danger = Color.dynamic(light: 0xB91C1C, dark: 0xB91C1C)
    /// Botón destructivo presionado.
    static let dangerPressed = Color.dynamic(light: 0x991B1B, dark: 0x991B1B)
    /// Borde y mensaje de campo con error.
    static let dangerText = Color.dynamic(light: 0xB91C1C, dark: 0xF87171)

    // MARK: Deshabilitado

    static let disabledFill = Color.dynamic(light: 0xE2E8F0, dark: 0x334155)
    static let disabledText = Color.dynamic(light: 0x64748B, dark: 0x94A3B8)

    // MARK: Avatar de iniciales

    static let avatarBackground = Color.dynamic(light: 0xCFFAFE, dark: 0x164E63)
    static let avatarForeground = Color.dynamic(light: 0x155E75, dark: 0xCFFAFE)

    // MARK: Marca UNICAES (Figma 44:747, 44:757)

    /// Colores institucionales del logo y del Splash. No cambian con el modo oscuro.
    enum Brand {
        /// Fondo del Splash (`#5A1716`).
        static let splashBackground = Color(hex: 0x5A1716)
        /// Texto secundario sobre el Splash (`#F4DCDA`).
        static let splashText = Color(hex: 0xF4DCDA)
        /// Granate del logo (`#862524`).
        static let maroon = Color(hex: 0x862524)
        /// Dorado del aro del logo, spinner y pie del Splash (`#E8B840`).
        static let gold = Color(hex: 0xE8B840)
    }
}

// MARK: - Tonos de estado

/// Trío fondo + texto/icono + borde de un badge o banner (handoff §4.2).
/// Todos los pares cumplen ≥ 6:1 en claro y en oscuro.
struct DSTone {
    let background: Color
    let foreground: Color
    let border: Color
}

extension DSTone {
    /// Ámbar: Pendiente, solicitud enviada, stock bajo, reconectando.
    static let warning = DSTone(
        background: .dynamic(light: 0xFEF3C7, dark: 0x451A03),
        foreground: .dynamic(light: 0x92400E, dark: 0xFCD34D),
        border: .dynamic(light: 0xFCD34D, dark: 0x92400E)
    )
    /// Azul: En Proceso, cita programada.
    static let info = DSTone(
        background: .dynamic(light: 0xDBEAFE, dark: 0x172554),
        foreground: .dynamic(light: 0x1E40AF, dark: 0x93C5FD),
        border: .dynamic(light: 0x93C5FD, dark: 0x1E40AF)
    )
    /// Verde: Completado, Disponible, Libre, Atendida.
    static let success = DSTone(
        background: .dynamic(light: 0xDCFCE7, dark: 0x052E16),
        foreground: .dynamic(light: 0x166534, dark: 0x86EFAC),
        border: .dynamic(light: 0x86EFAC, dark: 0x166534)
    )
    /// Rojo: ambulancia En Servicio.
    static let danger = DSTone(
        background: .dynamic(light: 0xFEE2E2, dark: 0x450A0A),
        foreground: .dynamic(light: 0x991B1B, dark: 0xFCA5A5),
        border: .dynamic(light: 0xFCA5A5, dark: 0x991B1B)
    )
    /// Gris: En Mantenimiento, Cancelada, Rechazada, Vencido.
    static let neutral = DSTone(
        background: .dynamic(light: 0xE5E7EB, dark: 0x1F2937),
        foreground: .dynamic(light: 0x374151, dark: 0xD1D5DB),
        border: .dynamic(light: 0xD1D5DB, dark: 0x4B5563)
    )
    /// Teal: turno en curso, indicador "En vivo".
    static let accent = DSTone(
        background: .dynamic(light: 0xECFEFF, dark: 0x083344),
        foreground: .dynamic(light: 0x155E75, dark: 0xA5F3FC),
        border: .dynamic(light: 0xA5F3FC, dark: 0x155E75)
    )
    /// Gris claro: indicador "Sin conexión".
    static let offline = DSTone(
        background: .dynamic(light: 0xF1F5F9, dark: 0x1E293B),
        foreground: .dynamic(light: 0x334155, dark: 0xCBD5E1),
        border: .dynamic(light: 0xCBD5E1, dark: 0x475569)
    )
    /// Cama ocupada (relleno oscuro).
    static let occupied = DSTone(
        background: .dynamic(light: 0x334155, dark: 0xCBD5E1),
        foreground: .dynamic(light: 0xFFFFFF, dark: 0x0F172A),
        border: .dynamic(light: 0x334155, dark: 0xCBD5E1)
    )
    /// Cama elegida (selección).
    static let selected = DSTone(
        background: .dynamic(light: 0x0E7490, dark: 0x0E7490),
        foreground: .dynamic(light: 0xFFFFFF, dark: 0xFFFFFF),
        border: .dynamic(light: 0xA5F3FC, dark: 0x22D3EE)
    )
    /// Banner de aviso general.
    static let notice = DSTone(
        background: .dynamic(light: 0xFFFBEB, dark: 0x451A03),
        foreground: .dynamic(light: 0x78350F, dark: 0xFDE68A),
        border: .dynamic(light: 0xFCD34D, dark: 0x92400E)
    )
    /// Banner de error.
    static let error = DSTone(
        background: .dynamic(light: 0xFEF2F2, dark: 0x450A0A),
        foreground: .dynamic(light: 0x7F1D1D, dark: 0xFECACA),
        border: .dynamic(light: 0xFCA5A5, dark: 0x991B1B)
    )
}

// MARK: - Helpers

extension Color {
    /// Color sRGB a partir de un hexadecimal `0xRRGGBB`.
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }

    /// Color que cambia con el modo claro/oscuro del sistema.
    static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}
