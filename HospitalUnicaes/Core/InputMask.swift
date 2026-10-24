import Foundation

/// Máscaras de entrada para formularios: reciben lo que escribió el usuario y devuelven el
/// texto formateado. Solo conservan dígitos y respetan el largo máximo.
enum InputMask {
    /// DUI: `00000000-0`.
    static func dui(_ text: String) -> String {
        format(digits(text, max: 9), separator: "-", after: [8])
    }

    /// Teléfono de El Salvador: `0000-0000`.
    static func telefono(_ text: String) -> String {
        format(digits(text, max: 8), separator: "-", after: [4])
    }

    /// Fecha: `dd/mm/aaaa`.
    static func fecha(_ text: String) -> String {
        format(digits(text, max: 8), separator: "/", after: [2, 4])
    }

    private static func digits(_ text: String, max: Int) -> String {
        String(text.filter(\.isASCIIDigit).prefix(max))
    }

    private static func format(_ digits: String, separator: Character, after positions: Set<Int>) -> String {
        var result = ""
        for (index, digit) in digits.enumerated() {
            if positions.contains(index) { result.append(separator) }
            result.append(digit)
        }
        return result
    }
}

private extension Character {
    var isASCIIDigit: Bool { isASCII && isNumber }
}
