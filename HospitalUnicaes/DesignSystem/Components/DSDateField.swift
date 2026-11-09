import SwiftUI

/// Campo de fecha con calendario gráfico. El día elegido no se guarda hasta que
/// la persona confirma "Elegir esta fecha", para no asumir el día que el calendario resalta.
struct DSDateField: View {
    private let label: LocalizedStringKey
    @Binding private var date: Date?
    private let errorMessage: String?
    private let range: ClosedRange<Date>

    @State private var isOpen = false
    @State private var draft: Date
    @Environment(\.isEnabled) private var isEnabled
    @ScaledMetric(relativeTo: .body) private var fieldHeight = DSSize.fieldHeight

    init(
        _ label: LocalizedStringKey,
        date: Binding<Date?>,
        errorMessage: String? = nil,
        in range: ClosedRange<Date>
    ) {
        self.label = label
        _date = date
        self.errorMessage = errorMessage
        self.range = range
        _draft = State(initialValue: date.wrappedValue ?? range.upperBound)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(DSFont.fieldLabel)
                .foregroundStyle(DSColor.textLabel)
                .accessibilityHidden(true)

            trigger

            if isOpen {
                calendar
            }

            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.circle")
                    .font(DSFont.footnote)
                    .foregroundStyle(DSColor.dangerText)
                    .accessibilityLabel("Error: \(errorMessage)")
            }
        }
    }

    private var trigger: some View {
        let shape = RoundedRectangle(cornerRadius: DSRadius.field, style: .continuous)
        return Button {
            if !isOpen {
                draft = date ?? suggestedDate
            }
            isOpen.toggle()
        } label: {
            HStack(spacing: DSSpacing.small) {
                Text(date.map(Self.display.string(from:)) ?? "Selecciona una fecha")
                    .font(DSFont.body)
                    .foregroundStyle(date == nil ? DSColor.textTertiary : DSColor.textPrimary)
                Spacer(minLength: DSSpacing.small)
                Image(systemName: "calendar")
                    .foregroundStyle(DSColor.tint)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: fieldHeight, alignment: .leading)
            .background(isEnabled ? DSColor.surface : DSColor.disabledFill, in: shape)
            .overlay { shape.strokeBorder(borderColor, lineWidth: borderWidth) }
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel(label)
        .accessibilityValue(date.map(Self.display.string(from:)) ?? "Sin seleccionar")
        .accessibilityHint(isOpen ? "Oculta el calendario" : "Muestra el calendario")
    }

    private var calendar: some View {
        VStack(alignment: .leading, spacing: DSSpacing.small) {
            DatePicker(
                label,
                selection: $draft,
                in: range,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .labelsHidden()
            .tint(DSColor.action)
            .environment(\.locale, Locale(identifier: "es_SV"))
            .padding(DSSpacing.small)
            .background(DSColor.surface, in: RoundedRectangle(cornerRadius: DSRadius.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: DSRadius.card, style: .continuous)
                    .strokeBorder(DSColor.border, lineWidth: 1)
            }

            DSButton("Elegir esta fecha", kind: .secondary, size: .compact) {
                date = draft
                isOpen = false
            }
        }
    }

    /// Unos 25 años antes de hoy, para no abrir el calendario en el mes actual.
    private var suggestedDate: Date {
        let calendar = Calendar(identifier: .gregorian)
        let suggested = calendar.date(byAdding: .year, value: -25, to: range.upperBound) ?? range.upperBound
        return min(max(suggested, range.lowerBound), range.upperBound)
    }

    private var borderColor: Color {
        if !isEnabled { return DSColor.border }
        if errorMessage != nil { return DSColor.dangerText }
        return isOpen ? DSColor.focusRing : DSColor.borderInput
    }

    private var borderWidth: CGFloat {
        isEnabled && (errorMessage != nil || isOpen) ? 2 : 1
    }

    private static let display: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_SV")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "d 'de' MMMM 'de' yyyy"
        return formatter
    }()
}

#Preview("Fecha de nacimiento") {
    struct Preview: View {
        @State private var date: Date?
        private var range: ClosedRange<Date> {
            let calendar = Calendar(identifier: .gregorian)
            let start = calendar.date(from: DateComponents(year: 1900, month: 1, day: 1)) ?? .distantPast
            return start...Date()
        }

        var body: some View {
            DSDateField("Fecha de nacimiento", date: $date, in: range)
                .padding(DSSpacing.regular)
                .background(DSColor.background)
        }
    }
    return Preview()
}
