import SwiftUI

/// Tipos de botón del sistema de diseño (handoff §5.1 y §6).
enum DSButtonKind {
    /// Acción principal: relleno teal, texto blanco ("Ingresar").
    case primary
    /// Acción alternativa: fondo blanco, borde y texto teal ("Ver información").
    case secondary
    /// Acción destructiva o de emergencia: relleno rojo ("Dar de alta", "Solicitar" ambulancia).
    case destructive
    /// Enlace: solo texto teal, área táctil 44.
    case text
}

enum DSButtonSize {
    /// Alto 52, texto 17/600. Botones de pantalla y formularios.
    case regular
    /// Alto 48, texto 15/600. Botones dentro de tarjetas.
    case compact
}

/// Botón del sistema de diseño con estados normal, presionado, deshabilitado y cargando.
///
/// ```swift
/// DSButton("Iniciar sesión", isLoading: viewModel.isLoading) {
///     Task { await viewModel.signIn() }
/// }
/// .disabled(!viewModel.canSubmit)
/// ```
struct DSButton: View {
    private let title: LocalizedStringKey
    private let systemImage: String?
    private let kind: DSButtonKind
    private let size: DSButtonSize
    private let isFullWidth: Bool
    private let isLoading: Bool
    private let loadingTitle: LocalizedStringKey
    private let action: () -> Void

    init(
        _ title: LocalizedStringKey,
        systemImage: String? = nil,
        kind: DSButtonKind = .primary,
        size: DSButtonSize = .regular,
        isFullWidth: Bool = true,
        isLoading: Bool = false,
        loadingTitle: LocalizedStringKey = "Guardando…",
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.kind = kind
        self.size = size
        self.isFullWidth = isFullWidth
        self.isLoading = isLoading
        self.loadingTitle = loadingTitle
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            if isLoading {
                HStack(spacing: DSSpacing.small) {
                    ProgressView()
                        .tint(loadingTint)
                    Text(loadingTitle)
                }
            } else if let systemImage {
                Label(title, systemImage: systemImage)
            } else {
                Text(title)
            }
        }
        .buttonStyle(DSButtonStyle(kind: kind, size: size, isFullWidth: isFullWidth))
        // Mientras carga no se puede volver a pulsar, pero conserva su color (no se ve deshabilitado).
        .allowsHitTesting(!isLoading)
    }

    private var loadingTint: Color {
        switch kind {
        case .primary, .destructive: DSColor.onAction
        case .secondary, .text: DSColor.tint
        }
    }
}

/// Estilo reutilizable para aplicar el aspecto del sistema de diseño a cualquier `Button`.
struct DSButtonStyle: ButtonStyle {
    var kind: DSButtonKind = .primary
    var size: DSButtonSize = .regular
    var isFullWidth = true

    func makeBody(configuration: Configuration) -> some View {
        DSButtonBody(configuration: configuration, kind: kind, size: size, isFullWidth: isFullWidth)
    }
}

private struct DSButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let kind: DSButtonKind
    let size: DSButtonSize
    let isFullWidth: Bool

    @Environment(\.isEnabled) private var isEnabled
    @ScaledMetric(relativeTo: .body) private var regularHeight = DSSize.buttonHeight
    @ScaledMetric(relativeTo: .subheadline) private var compactHeight = DSSize.buttonCompactHeight

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: DSRadius.button, style: .continuous)

        configuration.label
            .font(size == .regular ? DSFont.button : DSFont.buttonCompact)
            .multilineTextAlignment(.center)
            .foregroundStyle(foreground)
            .padding(.horizontal, kind == .text ? 0 : DSSpacing.regular)
            .padding(.vertical, kind == .text ? 0 : DSSpacing.small)
            .frame(maxWidth: isFullWidth && kind != .text ? .infinity : nil, minHeight: height)
            .background(background, in: shape)
            .overlay {
                if kind == .secondary {
                    shape.strokeBorder(borderColor, lineWidth: 1)
                }
            }
            .contentShape(shape)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }

    private var height: CGFloat {
        if kind == .text { return DSSize.minTapTarget }
        return size == .regular ? regularHeight : compactHeight
    }

    private var isPressed: Bool { configuration.isPressed }

    private var foreground: Color {
        switch kind {
        case .primary, .destructive:
            isEnabled ? DSColor.onAction : DSColor.disabledText
        case .secondary, .text:
            !isEnabled ? DSColor.disabledText : (isPressed ? DSColor.tintPressed : DSColor.tint)
        }
    }

    private var background: Color {
        switch kind {
        case .primary:
            !isEnabled ? DSColor.disabledFill : (isPressed ? DSColor.actionPressed : DSColor.action)
        case .destructive:
            !isEnabled ? DSColor.disabledFill : (isPressed ? DSColor.dangerPressed : DSColor.danger)
        case .secondary:
            isPressed && isEnabled ? DSColor.selection : DSColor.surface
        case .text:
            .clear
        }
    }

    private var borderColor: Color {
        guard isEnabled else { return DSColor.border }
        return isPressed ? DSColor.tintPressed : DSColor.tint
    }
}

// MARK: - Previews

#Preview("Botones") {
    ScrollView {
        VStack(alignment: .leading, spacing: DSSpacing.medium) {
            DSButton("Ingresar") {}
            DSButton("Ver información", kind: .secondary) {}
            DSButton("Dar de alta", kind: .destructive) {}
            DSButton("Despachar") {}
                .disabled(true)
            DSButton("Ver información", kind: .secondary) {}
                .disabled(true)
            DSButton("Guardar", isLoading: true) {}
            DSButton("Solicitar", systemImage: "light.beacon.max", kind: .destructive, size: .compact, isFullWidth: false) {}
            DSButton("¿Olvidaste tu contraseña?", kind: .text) {}
            Button("Estilo sobre un Button nativo") {}
                .buttonStyle(DSButtonStyle(kind: .secondary, size: .compact))
        }
        .padding(DSSpacing.regular)
    }
    .background(DSColor.background)
}

#Preview("Botones · oscuro + texto grande") {
    VStack(spacing: DSSpacing.medium) {
        DSButton("Ingresar") {}
        DSButton("Ver información", kind: .secondary) {}
        DSButton("Solicitar", systemImage: "light.beacon.max", kind: .destructive, size: .compact) {}
        DSButton("Guardar", isLoading: true) {}
    }
    .padding(DSSpacing.regular)
    .background(DSColor.background)
    .preferredColorScheme(.dark)
    .dynamicTypeSize(.accessibility2)
}
