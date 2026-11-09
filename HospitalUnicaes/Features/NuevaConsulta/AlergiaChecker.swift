import Foundation

/// No detecta familias de fármacos (penicilina frente a amoxicilina): es una ayuda, no un bloqueo.
enum AlergiaChecker {
    private static let ignorados: Set<String> = ["ninguna", "ninguno", "no", "n/a", "sin alergias"]

    static func coincidencias(medicamento: String, alergias: String?) -> [String] {
        guard let alergias else { return [] }
        let medicamentoNormalizado = normalizar(medicamento)
        guard !medicamentoNormalizado.isEmpty else { return [] }
        let primera = primeraPalabra(medicamentoNormalizado)
        return tokens(alergias).filter { coincide($0, medicamento: medicamentoNormalizado, primera: primera) }
    }

    private static func coincide(_ token: String, medicamento: String, primera: String) -> Bool {
        let normalizado = normalizar(token)
        guard normalizado.count >= 3, !ignorados.contains(normalizado) else { return false }
        if medicamento.contains(normalizado) { return true }
        return primera.count >= 4 && normalizado.contains(primera)
    }

    private static func tokens(_ raw: String) -> [String] {
        var text = raw
        for separator in [",", ";", "/", "\n", " y "] {
            text = text.replacingOccurrences(of: separator, with: "|", options: .caseInsensitive)
        }
        return text.split(separator: "|").map { String($0).trimmed }.filter { !$0.isEmpty }
    }

    private static func normalizar(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "es")).trimmed
    }

    private static func primeraPalabra(_ text: String) -> String {
        text.split(separator: " ").first.map(String.init) ?? ""
    }
}
