import Foundation

// Órdenes de laboratorio del paciente (`GET /laboratorio/ordenes`, HUNI-62). Solo se declaran
// los campos que usa la app: `registrado_por`, `paciente`, `consulta_id` y `validado_por` se ignoran.

struct OrdenLaboratorioPaciente: Decodable, Hashable, Identifiable, Sendable {
    let id: UUID
    let fechaSolicitud: Date
    let prioridad: PrioridadLaboratorio
    /// Derivado de los exámenes; la UI usa el estado de cada examen.
    let estado: EstadoLaboratorio
    let doctor: DoctorResumen
    let indicaciones: String?
    let examenes: [OrdenExamenPaciente]
}

struct OrdenExamenPaciente: Decodable, Hashable, Identifiable, Sendable {
    struct Examen: Decodable, Hashable, Sendable {
        let id: UUID
        let nombre: String
        let tipoMuestra: String?
    }

    /// `orden_examen_id`.
    let id: UUID
    let examen: Examen
    let estado: EstadoLaboratorio
    let fechaInicio: Date?
    let fechaCompletado: Date?
    /// Solo existe con el examen completado.
    let resultado: ResultadoExamen?
}

struct ResultadoExamen: Decodable, Hashable, Sendable {
    let id: UUID
    let valor: String?
    let unidad: String?
    let rangoReferencia: String?
    let observaciones: String?
    let tieneArchivo: Bool
    let fechaResultado: Date
}

/// URL firmada del PDF del resultado (válida 10 min).
struct ArchivoFirmado: Decodable, Hashable, Sendable {
    let url: URL
    let expiraEn: Date
}

/// Una fila de iOS-P7: un examen de una orden, con su propio estado. Es lo que viaja a iOS-P8.
struct ExamenLaboratorioPaciente: Hashable, Identifiable, Sendable {
    /// `orden_examen_id`.
    let id: UUID
    let ordenId: UUID
    let nombre: String
    let tipoMuestra: String?
    /// Nombre completo del doctor que ordenó, sin título (la API no trae sexo ni título).
    let doctor: String
    let fechaSolicitud: Date
    let indicaciones: String?
    let estado: EstadoLaboratorio
    let fechaInicio: Date?
    let fechaCompletado: Date?
    let resultado: ResultadoExamen?

    /// "resultado-prueba-cutanea-de-alergias.pdf".
    var nombreArchivo: String { "resultado-\(Formatting.slug(nombre)).pdf" }

    var tieneArchivo: Bool { estado == .completado && resultado?.tieneArchivo == true }
}

extension OrdenLaboratorioPaciente {
    /// Un elemento por examen, ordenados por nombre.
    var filas: [ExamenLaboratorioPaciente] {
        examenes
            .map { examen in
                ExamenLaboratorioPaciente(
                    id: examen.id,
                    ordenId: id,
                    nombre: examen.examen.nombre,
                    tipoMuestra: examen.examen.tipoMuestra,
                    doctor: doctor.nombreCompleto,
                    fechaSolicitud: fechaSolicitud,
                    indicaciones: indicaciones,
                    estado: examen.estado,
                    fechaInicio: examen.fechaInicio,
                    fechaCompletado: examen.fechaCompletado,
                    resultado: examen.resultado
                )
            }
            .sorted { $0.nombre.localizedStandardCompare($1.nombre) == .orderedAscending }
    }
}

extension Array where Element == OrdenLaboratorioPaciente {
    /// Más recientes primero por `fecha_solicitud`; dentro de una orden, por nombre.
    var filasLaboratorio: [ExamenLaboratorioPaciente] {
        sorted { $0.fechaSolicitud > $1.fechaSolicitud }.flatMap(\.filas)
    }
}
