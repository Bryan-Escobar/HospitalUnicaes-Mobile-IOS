import SwiftUI

/// Selector Lun–Dom. El día elegido usa el color de acción del design system.
struct WeekStripView: View {
    let semana: [Date]
    let seleccionado: Date
    let onSelect: (Date) -> Void
    let onPrevious: () -> Void
    let onNext: () -> Void

    var body: some View {
        HStack(spacing: DSSpacing.tiny) {
            flecha("chevron.left", "Semana anterior", onPrevious)
            HStack(spacing: DSSpacing.tiny) {
                ForEach(semana, id: \.self) { dia in
                    diaButton(dia)
                }
            }
            flecha("chevron.right", "Semana siguiente", onNext)
        }
        .padding(.horizontal, DSSpacing.small)
    }

    private func diaButton(_ dia: Date) -> some View {
        let activo = Formatting.esMismoDia(dia, seleccionado)
        return Button {
            onSelect(dia)
        } label: {
            VStack(spacing: 2) {
                Text(Formatting.diaCorto(dia))
                Text(Formatting.diaNumero(dia))
            }
            .font(DSFont.footnoteEmphasis)
            .foregroundStyle(activo ? DSColor.onAction : DSColor.textSecondary)
            .frame(maxWidth: .infinity, minHeight: DSSize.minTapTarget)
            .background(activo ? DSColor.action : Color.clear, in: RoundedRectangle(cornerRadius: DSRadius.chip))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(Formatting.diaCorto(dia)) \(Formatting.diaNumero(dia))")
        .accessibilityAddTraits(activo ? .isSelected : [])
    }

    private func flecha(_ icon: String, _ label: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .frame(width: DSSize.minTapTarget, height: DSSize.minTapTarget)
        }
        .buttonStyle(.plain)
        .foregroundStyle(DSColor.tint)
        .accessibilityLabel(label)
    }
}
