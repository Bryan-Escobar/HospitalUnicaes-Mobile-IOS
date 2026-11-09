import Foundation

/// Textos y estados de iOS-P10/P11 (HUNI-73 §4.2). Viven aquí y no en el design system.
extension TipoEmergencia {
    /// Chips de P10, en el orden del Figma.
    static let opcionesPaciente: [TipoEmergencia] = [.accidente, .cardiaca, .respiratoria, .otra]

    var etiqueta: String {
        switch self {
        case .accidente: "Accidente"
        case .cardiaca: "Dolor de pecho"
        case .respiratoria: "Dificultad respiratoria"
        case .neurologica: "Neurológica"
        case .obstetrica: "Obstétrica"
        case .intoxicacion: "Intoxicación"
        case .traslado: "Traslado"
        case .otra: "Otro"
        }
    }
}

extension EstadoSolicitudAmbulancia {
    var status: DSStatus {
        switch self {
        case .pendiente: .solicitudEnviada
        case .despachada: .solicitudDespachada
        case .enCurso: .solicitudEnCurso
        case .finalizada: .solicitudFinalizada
        case .cancelada: .solicitudRechazada
        }
    }

    var tono: DSTone {
        switch self {
        case .pendiente: .warning
        case .despachada, .enCurso: .danger
        case .finalizada: .success
        case .cancelada: .neutral
        }
    }
}

/// Un paso de la línea de tiempo de P11.
struct PasoSeguimiento: Equatable, Identifiable {
    let titulo: String
    let detalle: String
    let hecho: Bool

    var id: String { titulo }
}

extension SolicitudAmbulancia {
    var titulo: String {
        switch estado {
        case .pendiente: "Recepción está revisando tu solicitud."
        case .despachada: "La ambulancia va en camino."
        case .enCurso: "El equipo de la ambulancia ya está contigo."
        case .finalizada: "El servicio terminó."
        case .cancelada: "Recepción cerró tu solicitud."
        }
    }

    var subtitulo: String? {
        switch estado {
        case .pendiente, .despachada:
            return "Mantén tu teléfono cerca."
        case .enCurso:
            return "Te llevarán \(destino?.nilIfBlank.map { "a \($0)" } ?? "al hospital")."
        case .finalizada:
            return notasCierre?.nilIfBlank
        case .cancelada:
            return motivoCancelacion?.nilIfBlank.map { "Motivo: \($0)" }
                ?? "Comunícate con el hospital si aún necesitas ayuda."
        }
    }

    var pasos: [PasoSeguimiento] {
        let enviada = Formatting.unir([Formatting.hora(fechaSolicitud), tipoEmergencia?.etiqueta])
        let cancelada = estado == .cancelada

        // El estado manda: si llega despachada sin fecha, el paso igual se marca.
        let despachada = fechaDespacho != nil || [.despachada, .enCurso, .finalizada].contains(estado)
        var despacho = cancelada ? "No aplica" : "Aún no"
        if despachada {
            var partes: [String?] = [fechaDespacho.map(Formatting.hora), "por recepción"]
            if estado == .enCurso, let fechaEnCurso {
                partes.append("en curso desde \(Formatting.hora(fechaEnCurso))")
            }
            despacho = Formatting.unir(partes)
        }

        let cierre = fechaCierre.map(Formatting.hora)
        let final = cancelada
            ? PasoSeguimiento(titulo: "Rechazada", detalle: cierre ?? "", hecho: true)
            : PasoSeguimiento(
                titulo: "Finalizada",
                detalle: estado == .finalizada ? (cierre ?? "") : "Aún no",
                hecho: estado == .finalizada
            )

        return [
            PasoSeguimiento(titulo: "Enviada", detalle: enviada, hecho: true),
            PasoSeguimiento(titulo: "Despachada (En Servicio)", detalle: despacho, hecho: despachada),
            final,
        ]
    }

    /// Dirección enviada, o las coordenadas si solo hubo GPS.
    var ubicacionTexto: String? {
        if let direccion = direccionOrigen?.nilIfBlank { return direccion }
        guard let latitud, let longitud else { return nil }
        return Ubicacion.coordenadas(latitud: latitud, longitud: longitud)
    }
}

extension Ubicacion {
    /// "Col. Escalón, San Salvador (±20 m)" o "13.9942, -89.5597 (±20 m)".
    var resumen: String {
        let lugar = direccion?.nilIfBlank ?? Self.coordenadas(latitud: latitud, longitud: longitud)
        return "\(lugar) (±\(precisionM) m)"
    }

    static func coordenadas(latitud: Double, longitud: Double) -> String {
        String(format: "%.4f, %.4f", latitud, longitud)
    }
}
