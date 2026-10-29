import Foundation

extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var nilIfBlank: String? {
        let text = trimmed
        return text.isEmpty ? nil : text
    }
}

/// Fechas y edades en `America/El_Salvador` (UTC−6, sin horario de verano).
enum Formatting {
    static let timeZone = TimeZone(identifier: "America/El_Salvador") ?? .gmt
    static let locale = Locale(identifier: "es_SV")

    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        calendar.locale = locale
        calendar.firstWeekday = 2
        return calendar
    }

    static func startOfDay(_ date: Date) -> Date {
        calendar.startOfDay(for: date)
    }

    /// `[desde, hasta)` del día civil en El Salvador.
    static func rangoDelDia(_ date: Date) -> (desde: Date, hasta: Date) {
        let desde = startOfDay(date)
        let hasta = calendar.date(byAdding: .day, value: 1, to: desde) ?? desde.addingTimeInterval(86_400)
        return (desde, hasta)
    }

    /// Lunes a domingo de la semana que contiene `date`.
    static func semana(conteniendo date: Date) -> [Date] {
        let start = startOfDay(date)
        let weekday = calendar.component(.weekday, from: start)
        let daysFromMonday = (weekday + 5) % 7
        let monday = calendar.date(byAdding: .day, value: -daysFromMonday, to: start) ?? start
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: monday) }
    }

    static func sumarDias(_ dias: Int, a date: Date) -> Date {
        calendar.date(byAdding: .day, value: dias, to: startOfDay(date)) ?? date
    }

    static func esMismoDia(_ lhs: Date, _ rhs: Date) -> Bool {
        calendar.isDate(lhs, inSameDayAs: rhs)
    }

    /// `dia` a la hora local indicada ("10:30" de ese día en El Salvador).
    static func fecha(_ dia: Date, hora: Int, minuto: Int = 0) -> Date {
        calendar.date(bySettingHour: hora, minute: minuto, second: 0, of: startOfDay(dia)) ?? dia
    }

    /// "Miércoles 21 de octubre", subtítulo de Inicio.
    static func fechaLarga(_ date: Date) -> String {
        let texto = texto(date, formato: "EEEE d 'de' MMMM")
        return texto.prefix(1).uppercased() + texto.dropFirst()
    }

    static func hora(_ date: Date) -> String {
        texto(date, formato: "HH:mm")
    }

    static func diaCorto(_ date: Date) -> String {
        texto(date, formato: "EEE").replacingOccurrences(of: ".", with: "").capitalized
    }

    static func diaNumero(_ date: Date) -> String {
        String(calendar.component(.day, from: date))
    }

    static func fechaCorta(_ date: Date) -> String {
        "\(diaNumero(date)) \(mes(date))"
    }

    static func fechaYHora(_ date: Date) -> String {
        "\(diaCorto(date)) \(fechaCorta(date)) · \(hora(date))"
    }

    static func encabezadoAgenda(_ date: Date, cantidad: Int) -> String {
        let nombre = texto(date, formato: "EEEE").localizedUppercase
        let citas = cantidad == 1 ? "1 CITA" : "\(cantidad) CITAS"
        return "\(nombre) \(diaNumero(date)) · \(citas)"
    }

    static func edad(fechaNacimiento: String?, en fecha: Date = Date()) -> Int? {
        guard let fechaNacimiento, let nacimiento = diaCalendario(fechaNacimiento) else { return nil }
        guard let years = calendar.dateComponents([.year], from: nacimiento, to: fecha).year else { return nil }
        guard years >= 0, years < 130 else { return nil }
        return years
    }

    static func edadTexto(_ years: Int) -> String {
        years == 1 ? "1 año" : "\(years) años"
    }

    static func subtituloLista(edad: Int?, documento: String?, expediente: String) -> String {
        if let documento = documento?.nilIfBlank {
            let visible = Self.documento(documento)
            if let edad { return "\(edadTexto(edad)) · \(visible)" }
            return visible
        }
        return "Expediente \(expediente)"
    }

    static func documento(_ value: String) -> String {
        let text = value.trimmed
        let dui = text.range(of: #"^\d{8}-\d$"#, options: .regularExpression) != nil
        return dui ? "DUI \(text)" : text
    }

    static func unir(_ partes: [String?]) -> String {
        partes.compactMap { $0?.nilIfBlank }.joined(separator: " · ")
    }

    static func valor(_ text: String?) -> String {
        text?.nilIfBlank ?? "No registrado"
    }

    static func fechaNacimiento(_ value: String?) -> String {
        guard let value, let date = diaCalendario(value) else { return valor(value) }
        return "\(diaNumero(date)) \(mes(date)) \(calendar.component(.year, from: date))"
    }

    static func cantidad(_ total: Int, singular: String, plural: String) -> String {
        total == 1 ? "1 \(singular)" : "\(total) \(plural)"
    }

    static func diaCalendario(_ value: String) -> Date? {
        let parts = value.split(separator: "-")
        guard parts.count == 3, let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2]) else {
            return nil
        }
        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = timeZone
        components.year = year
        components.month = month
        components.day = day
        return calendar.date(from: components)
    }

    private static func mes(_ date: Date) -> String {
        texto(date, formato: "MMM").replacingOccurrences(of: ".", with: "")
    }

    private static func texto(_ date: Date, formato: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.dateFormat = formato
        return formatter.string(from: date)
    }
}
