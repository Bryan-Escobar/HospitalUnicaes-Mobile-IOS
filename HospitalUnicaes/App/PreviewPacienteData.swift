#if DEBUG
import Foundation

extension PacienteDependencies {
    /// Exámenes de ejemplo del Figma, sin red ni Realtime.
    static var preview: PacienteDependencies {
        PacienteDependencies(
            laboratorio: PreviewLaboratorioPacienteService(),
            laboratorioRealtime: PreviewLaboratorioRealtime(),
            resultadoArchivos: PreviewResultadoArchivoService()
        )
    }
}

enum PacientePreviewData {
    static let doctorRivas = DoctorResumen(
        id: UUID(uuidString: "bbbbbbbb-bbbb-4bbb-8bbb-000000000001") ?? UUID(),
        nombres: "Ana", apellidos: "Rivas", especialidad: "Alergología"
    )

    /// Prueba cutánea (Completada), química sanguínea (En Proceso) y orina (Pendiente).
    static func ordenes(hoy: Date = Date()) -> [OrdenLaboratorioPaciente] {
        [
            orden(dias: -7, examenes: [
                examen("Prueba cutánea de alergias", estado: .completado, dia: -7, resultado: ResultadoExamen(
                    id: UUID(),
                    valor: "Positivo a ácaros del polvo y polen de gramíneas. Negativo a epitelio de gato.",
                    unidad: nil, rangoReferencia: nil, observaciones: nil, tieneArchivo: false,
                    fechaResultado: Formatting.fecha(Formatting.sumarDias(-6, a: hoy), hora: 11, minuto: 25)
                ), hoy: hoy),
            ], hoy: hoy),
            orden(dias: 0, examenes: [
                examen("Química sanguínea", estado: .enProceso, dia: 0, hoy: hoy),
                examen("Examen general de orina", estado: .pendiente, dia: 0, hoy: hoy),
            ], hoy: hoy),
        ]
    }

    private static func orden(dias: Int, examenes: [OrdenExamenPaciente], hoy: Date) -> OrdenLaboratorioPaciente {
        OrdenLaboratorioPaciente(
            id: UUID(), fechaSolicitud: Formatting.fecha(Formatting.sumarDias(dias, a: hoy), hora: 10, minuto: 40),
            prioridad: .normal, estado: .pendiente, doctor: doctorRivas, indicaciones: nil, examenes: examenes
        )
    }

    private static func examen(
        _ nombre: String, estado: EstadoLaboratorio, dia: Int, resultado: ResultadoExamen? = nil, hoy: Date
    ) -> OrdenExamenPaciente {
        let base = Formatting.sumarDias(dia, a: hoy)
        return OrdenExamenPaciente(
            id: UUID(), examen: .init(id: UUID(), nombre: nombre, tipoMuestra: nil), estado: estado,
            fechaInicio: estado == .pendiente ? nil : Formatting.fecha(base, hora: 11, minuto: 10),
            fechaCompletado: resultado?.fechaResultado, resultado: resultado
        )
    }
}

struct PreviewLaboratorioPacienteService: LaboratorioPacienteService {
    func misOrdenes() async throws -> [OrdenLaboratorioPaciente] {
        PacientePreviewData.ordenes()
    }

    func urlArchivo(ordenId: UUID, examenId: UUID) async throws -> ArchivoFirmado {
        throw APIError(statusCode: 404, code: "NO_ENCONTRADO")
    }
}

/// Canal "En vivo" que nunca emite cambios.
struct PreviewLaboratorioRealtime: LaboratorioRealtimeService {
    func eventos() -> AsyncStream<EventoLaboratorio> {
        AsyncStream { continuation in
            continuation.yield(.conexion(.live))
        }
    }
}

struct PreviewResultadoArchivoService: ResultadoArchivoService {
    func descargar(_ url: URL, nombreArchivo: String) async throws -> URL {
        throw ResultadoArchivoError.fallo
    }

    func borrar(_ local: URL?) {}
}
#endif
