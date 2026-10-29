import Foundation
import Observation

/// Solicitud de ambulancia del paciente y sus pasos (iOS-P11).
struct SolicitudAmbulancia: Equatable {
    enum Estado: Equatable {
        case enviada
        case despachada
        case finalizada
    }

    let tipo: String
    let ubicacion: String
    let enviadaA: Date
    var estado: Estado
}

/// iOS-P10 / P11 Ambulancia. Sin backend todavía: confirmar deja la solicitud "Enviada"
/// y la pantalla pasa al seguimiento. El despacho real lo hace recepción (`context.md` §3.5).
@MainActor
@Observable
final class AmbulanciaPacienteViewModel {
    static let tipos = ["Accidente", "Dolor de pecho", "Dificultad respiratoria", "Otro"]
    static let ubicacionActual = "Col. Escalón, San Salvador (±20 m)"

    private(set) var estado: EstadoAmbulancia
    var usarUbicacion = true
    var direccion = ""
    var tipo: String?
    var descripcion = ""
    private(set) var solicitud: SolicitudAmbulancia?
    private let ahora: () -> Date

    init(estado: EstadoAmbulancia = .disponible, ahora: @escaping () -> Date = Date.init) {
        self.estado = estado
        self.ahora = ahora
    }

    var ubicacion: String? {
        usarUbicacion ? Self.ubicacionActual : direccion.nilIfBlank
    }

    var puedeConfirmar: Bool {
        estado == .disponible && tipo != nil && ubicacion != nil && solicitud == nil
    }

    /// Motivo por el que el botón de confirmar está deshabilitado.
    var ayuda: String? {
        if estado != .disponible { return "La ambulancia no está disponible en este momento." }
        if tipo == nil { return "Elige el tipo de emergencia." }
        if ubicacion == nil { return "Escribe la dirección o usa tu ubicación." }
        return nil
    }

    func confirmar() {
        guard puedeConfirmar, let tipo, let ubicacion else { return }
        solicitud = SolicitudAmbulancia(tipo: tipo, ubicacion: ubicacion, enviadaA: ahora(), estado: .enviada)
    }

    func nuevaSolicitud() {
        solicitud = nil
        tipo = nil
        descripcion = ""
    }
}
