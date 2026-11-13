import Foundation

/// Franja preferida (`franja_horaria` en la base).
enum FranjaHoraria: String, Codable, CaseIterable, Identifiable {
    case manana
    case tarde
    case cualquiera

    var id: String { rawValue }

    var titulo: String {
        switch self {
        case .manana: "Mañana"
        case .tarde: "Tarde"
        case .cualquiera: "Cualquiera"
        }
    }
}

enum EstadoSolicitudAtencion: String, Decodable {
    case pendiente
    case atendida
    case rechazada
}

/// Fila de `v_solicitudes_atencion` (HUNI-56): lo que el paciente pidió y, si ya respondió, la respuesta de recepción.
struct SolicitudAtencion: Decodable, Hashable, Identifiable {
    let id: UUID
    let motivo: String
    let especialidad: String?
    let fechaPreferida: String?
    let franja: FranjaHoraria
    let estado: EstadoSolicitudAtencion
    let respuesta: String?
    let respondidaEn: Date?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, motivo, especialidad, franja, estado, respuesta
        case fechaPreferida = "fecha_preferida"
        case respondidaEn = "respondida_en"
        case createdAt = "created_at"
    }

    /// "Mar 17 nov por la mañana", "Cualquier día".
    var preferencia: String {
        let dia = fechaPreferida.flatMap(Formatting.diaCalendario).map {
            "\(Formatting.diaCorto($0)) \(Formatting.fechaCorta($0))"
        }
        switch (dia, franja) {
        case (nil, .cualquiera): return "Cualquier día"
        case (nil, _): return "Cualquier día por la \(franja.titulo.lowercased())"
        case let (dia?, .cualquiera): return dia
        case let (dia?, _): return "\(dia) por la \(franja.titulo.lowercased())"
        }
    }
}

/// Catálogo `especialidades` (lectura para cualquier usuario con sesión).
struct Especialidad: Decodable, Hashable, Identifiable {
    let id: UUID
    let nombre: String
}

/// Lo que el formulario envía a `crear_solicitud_atencion()`.
struct NuevaSolicitudAtencion: Encodable, Equatable {
    let motivo: String
    let especialidadId: UUID?
    let fechaPreferida: String?
    let franja: FranjaHoraria

    enum CodingKeys: String, CodingKey {
        case motivo = "p_motivo"
        case especialidadId = "p_especialidad_id"
        case fechaPreferida = "p_fecha_preferida"
        case franja = "p_franja"
    }
}

extension CitaPaciente {
    /// Cita de `v_citas` en el formato de las pantallas del paciente.
    init(_ cita: Cita) {
        self.init(
            id: cita.id,
            fecha: cita.fechaHora,
            doctor: [cita.doctorNombres, cita.doctorApellidos.split(separator: " ").first.map(String.init)]
                .compactMap { $0?.nilIfBlank }
                .joined(separator: " "),
            especialidad: cita.especialidad ?? "Medicina general",
            motivo: cita.motivo?.nilIfBlank ?? "Consulta",
            estado: cita.estado
        )
    }
}
