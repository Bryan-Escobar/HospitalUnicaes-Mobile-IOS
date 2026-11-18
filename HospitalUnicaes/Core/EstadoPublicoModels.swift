import Foundation

/// Respuesta de `GET /api/publico/estado` (HUNI-74), sin sesión. La API copia campo por campo lo que
/// devuelve `public.estado_publico()`: solo cantidades de camas, médicos de turno ahora y avisos públicos
/// vigentes. Nunca pacientes, habitaciones ni datos personales del personal (`context.md` §3.4).
struct EstadoPublico: Decodable, Hashable {
    struct Conteo: Decodable, Hashable {
        let ocupadas: Int
        let disponibles: Int
        let total: Int
    }

    struct Ocupacion: Decodable, Hashable {
        let vip: Conteo
        let semiprivada: Conteo
        let total: Conteo
    }

    struct Medico: Decodable, Hashable {
        let nombres: String
        let apellidos: String
        /// Nombre del tipo de personal ("Doctor", "Médico de emergencia").
        let tipo: String
        let especialidad: String?
        let area: String
        /// `07:00:00`, hora de El Salvador.
        let horaInicio: String
        let horaFin: String
    }

    struct AvisoPublico: Decodable, Hashable {
        let id: UUID
        let titulo: String
        let contenido: String
        let fechaPublicacion: Date
        let fechaExpiracion: Date?
    }

    let ocupacion: Ocupacion
    let medicosDeTurno: [Medico]
    let avisos: [AvisoPublico]
    let actualizadoEn: Date
}
