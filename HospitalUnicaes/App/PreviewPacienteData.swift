#if DEBUG
import Foundation

extension PacienteDependencies {
    /// Exámenes de ejemplo del Figma y ambulancia disponible sin solicitudes, sin red, Realtime ni GPS reales.
    static var preview: PacienteDependencies { preview() }

    static func preview(
        estado: EstadoAmbulancia = .disponible,
        solicitud: SolicitudAmbulancia? = nil
    ) -> PacienteDependencies {
        PacienteDependencies(
            laboratorio: PreviewLaboratorioPacienteService(),
            laboratorioRealtime: PreviewLaboratorioRealtime(),
            resultadoArchivos: PreviewResultadoArchivoService(),
            ambulancias: PreviewAmbulanciaService(estadoInicial: estado, solicitudInicial: solicitud),
            ambulanciaRealtime: PreviewAmbulanciaRealtime(),
            ubicacion: { PreviewUbicacionService() }
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

    static let ambulanciaId = UUID(uuidString: "eeeeeeee-eeee-4eee-8eee-000000000001") ?? UUID()

    static func ambulancia(_ estado: EstadoAmbulancia) -> Ambulancia {
        Ambulancia(id: ambulanciaId, placa: "AMB-001", estado: estado, updatedAt: Date(), solicitudActiva: nil)
    }

    /// Solicitud de las 10:12 por dolor de pecho, como en el Figma.
    static func solicitud(_ estado: EstadoSolicitudAmbulancia) -> SolicitudAmbulancia {
        let enviada = Formatting.fecha(Date(), hora: 10, minuto: 12)
        let despachada = estado == .pendiente ? nil : Formatting.fecha(Date(), hora: 10, minuto: 14)
        return SolicitudAmbulancia(
            id: UUID(uuidString: "eeeeeeee-eeee-4eee-8eee-000000000002") ?? UUID(),
            estado: estado, tipoEmergencia: .cardiaca, descripcionEmergencia: nil,
            direccionOrigen: "Col. Escalón, San Salvador", latitud: 13.6929, longitud: -89.2182, precisionM: 20,
            destino: nil, fechaSolicitud: enviada, fechaDespacho: despachada,
            fechaEnCurso: estado == .enCurso ? Formatting.fecha(Date(), hora: 10, minuto: 20) : nil,
            fechaCierre: estado == .finalizada || estado == .cancelada ? Formatting.fecha(Date(), hora: 11, minuto: 2) : nil,
            notasCierre: nil, motivoCancelacion: estado == .cancelada ? "Solicitud duplicada" : nil
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

struct PreviewAmbulanciaService: AmbulanciaService {
    let estadoInicial: EstadoAmbulancia
    let solicitudInicial: SolicitudAmbulancia?

    func estado() async throws -> Ambulancia { PacientePreviewData.ambulancia(estadoInicial) }
    func ultimaSolicitud() async throws -> SolicitudAmbulancia? { solicitudInicial }

    func solicitud(id: UUID) async throws -> SolicitudAmbulancia {
        solicitudInicial ?? PacientePreviewData.solicitud(.pendiente)
    }

    func solicitar(_ nueva: NuevaSolicitudAmbulancia) async throws -> SolicitudAmbulancia {
        PacientePreviewData.solicitud(.pendiente)
    }
}

/// Siempre "En vivo" y sin eventos.
struct PreviewAmbulanciaRealtime: AmbulanciaRealtimeService {
    func eventos() -> AsyncStream<EventoAmbulancia> {
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

@MainActor
final class PreviewUbicacionService: UbicacionService {
    var autorizacion: EstadoPermisoUbicacion { .permitido }

    func ubicacionActual() async throws -> Ubicacion {
        Ubicacion(latitud: 13.6929, longitud: -89.2182, precisionM: 20, direccion: "Col. Escalón, San Salvador")
    }
}
#endif
