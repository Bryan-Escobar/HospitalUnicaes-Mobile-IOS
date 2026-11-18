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
            citas: PreviewCitasPacienteService(),
            historial: PreviewHistorialPacienteService(),
            laboratorio: PreviewLaboratorioPacienteService(),
            laboratorioRealtime: PreviewLaboratorioRealtime(),
            resultadoArchivos: PreviewResultadoArchivoService(),
            ambulancias: PreviewAmbulanciaService(estadoInicial: estado, solicitudInicial: solicitud),
            ambulanciaRealtime: PreviewAmbulanciaRealtime(),
            hospitalizaciones: PreviewPacienteHospitalizacionesService(),
            avisos: PreviewAvisosService(),
            turnosPersonal: PreviewTurnosDelPersonalService(),
            ubicacion: { PreviewUbicacionService() }
        )
    }
}

enum PacientePreviewData {
    static let doctorRivas = DoctorResumen(
        id: UUID(uuidString: "bbbbbbbb-bbbb-4bbb-8bbb-000000000001") ?? UUID(),
        nombres: "Ana", apellidos: "Rivas", especialidad: "Alergología"
    )

    static let doctorMolina = DoctorResumen(
        id: UUID(uuidString: "bbbbbbbb-bbbb-4bbb-8bbb-000000000002") ?? UUID(),
        nombres: "Carlos", apellidos: "Molina", especialidad: "Medicina general"
    )

    /// Orden de la prueba cutánea: la pidió la consulta de rinitis del historial de ejemplo.
    static let ordenPruebaCutaneaId = UUID(uuidString: "ffffffff-ffff-4fff-8fff-000000000001") ?? UUID()

    /// Prueba cutánea (Completada), química sanguínea (En Proceso) y orina (Pendiente).
    static func ordenes(hoy: Date = Date()) -> [OrdenLaboratorioPaciente] {
        [
            orden(id: ordenPruebaCutaneaId, dias: -7, examenes: [
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

    private static func orden(
        id: UUID = UUID(), dias: Int, examenes: [OrdenExamenPaciente], hoy: Date
    ) -> OrdenLaboratorioPaciente {
        OrdenLaboratorioPaciente(
            id: id, fechaSolicitud: Formatting.fecha(Formatting.sumarDias(dias, a: hoy), hora: 10, minuto: 40),
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

    /// Historial del Figma: rinitis (con recetas y la prueba cutánea), dermatitis y un control general.
    static func historial(pacienteId: UUID, hoy: Date = Date()) -> HistorialClinico {
        let paciente = Paciente(
            id: pacienteId, perfilId: nil, nombres: "Carlos", apellidos: "Martínez",
            documentoIdentidad: "01234567-8", fechaNacimiento: "1992-03-14", sexo: .masculino,
            telefono: "7000-1111", direccion: nil, contactoEmergencia: nil, telefonoEmergencia: nil,
            numeroExpediente: "EXP-2026-00015", activo: true, createdAt: hoy
        )
        return HistorialClinico(
            paciente: paciente,
            expediente: Expediente(
                id: UUID(), pacienteId: pacienteId, numeroExpediente: paciente.numeroExpediente,
                tipoSangre: "O+", alergias: "penicilina, polen", antecedentes: nil, enfermedadesCronicas: nil,
                createdAt: hoy, updatedAt: hoy
            ),
            consultas: [
                consulta(paciente, doctorRivas, dias: -7, diagnostico: "Rinitis alérgica estacional", recetas: [
                    medicamento("Loratadina 10 mg", "1 tableta cada 24 h", "14 días"),
                    medicamento("Fluticasona nasal", "2 aplicaciones cada 12 h"),
                ], ordenes: [
                    OrdenLaboratorioResumen(
                        id: ordenPruebaCutaneaId,
                        fechaSolicitud: Formatting.fecha(Formatting.sumarDias(-7, a: hoy), hora: 10, minuto: 40),
                        prioridad: .normal, estado: .completado, totalExamenes: 1
                    ),
                ], hoy: hoy),
                consulta(paciente, doctorMolina, dias: -49, diagnostico: "Dermatitis de contacto", recetas: [
                    medicamento("Hidrocortisona crema 1 %", "Cada 12 h", "7 días"),
                ], hoy: hoy),
                consulta(paciente, doctorMolina, dias: -110, diagnostico: "Control general", hoy: hoy),
            ]
        )
    }

    private static func consulta(
        _ paciente: Paciente,
        _ doctor: DoctorResumen,
        dias: Int,
        diagnostico: String,
        recetas: [RecetaDetalleItem] = [],
        ordenes: [OrdenLaboratorioResumen] = [],
        hoy: Date
    ) -> ConsultaDetalle {
        let fecha = Formatting.fecha(Formatting.sumarDias(dias, a: hoy), hora: 10)
        return ConsultaDetalle(
            id: UUID(), expedienteId: UUID(),
            paciente: PersonaResumen(id: paciente.id, nombres: paciente.nombres, apellidos: paciente.apellidos),
            doctor: doctor, citaId: nil, fecha: fecha, motivoConsulta: nil, signosVitales: nil,
            examenFisico: nil, notas: nil, cerradaEn: fecha.addingTimeInterval(1_800),
            diagnosticos: [Diagnostico(id: UUID(), codigoCie10: nil, descripcion: diagnostico, tipo: .principal)],
            recetas: recetas.isEmpty ? [] : [
                RecetaEmitida(
                    id: UUID(), fechaEmision: fecha, indicaciones: nil,
                    detalles: recetas
                ),
            ],
            ordenesLaboratorio: ordenes
        )
    }

    private static func medicamento(_ nombre: String, _ frecuencia: String, _ duracion: String? = nil) -> RecetaDetalleItem {
        RecetaDetalleItem(id: UUID(), medicamento: nombre, dosis: nil, frecuencia: frecuencia, duracion: duracion)
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

/// Citas de ejemplo del Figma y una solicitud en revisión; enviar devuelve la solicitud sin red.
struct PreviewCitasPacienteService: CitasPacienteService {
    func citas() async throws -> [Cita] {
        let hoy = Date()
        return [
            cita(Formatting.fecha(Formatting.sumarDias(1, a: hoy), hora: 10, minuto: 30), .programada, "Control de alergia"),
            cita(Formatting.fecha(Formatting.sumarDias(13, a: hoy), hora: 9), .confirmada, "Control general"),
            cita(Formatting.fecha(Formatting.sumarDias(-7, a: hoy), hora: 10), .atendida, "Rinitis alérgica"),
        ]
    }

    func solicitudes() async throws -> [SolicitudAtencion] {
        [solicitud("Revisión general", especialidad: "Medicina general")]
    }

    func especialidades() async throws -> [Especialidad] {
        ["Alergología", "Medicina general", "Pediatría"].map { Especialidad(id: UUID(), nombre: $0) }
    }

    func enviar(_ nueva: NuevaSolicitudAtencion) async throws -> SolicitudAtencion {
        solicitud(nueva.motivo, especialidad: nil, fecha: nueva.fechaPreferida, franja: nueva.franja)
    }

    private func cita(_ fecha: Date, _ estado: EstadoCita, _ motivo: String) -> Cita {
        Cita(
            id: UUID(), pacienteId: UUID(), doctorId: PacientePreviewData.doctorRivas.id, especialidadId: nil,
            pacienteNombres: "Carlos", pacienteApellidos: "Martínez", doctorNombres: "Ana", doctorApellidos: "Rivas",
            especialidad: "Alergología", fechaHora: fecha, fechaHoraFin: fecha.addingTimeInterval(1_800),
            createdAt: Date(), duracionMinutos: 30, motivo: motivo, estado: estado
        )
    }

    private func solicitud(
        _ motivo: String, especialidad: String?, fecha: String? = nil, franja: FranjaHoraria = .manana
    ) -> SolicitudAtencion {
        SolicitudAtencion(
            id: UUID(), motivo: motivo, especialidad: especialidad, fechaPreferida: fecha, franja: franja,
            estado: .pendiente, respuesta: nil, respondidaEn: nil, createdAt: Date()
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

/// Historial de ejemplo del Figma con alergias, recetas y la orden de la prueba cutánea.
struct PreviewHistorialPacienteService: HistorialPacienteService {
    func historial(pacienteId: UUID) async throws -> HistorialClinico {
        PacientePreviewData.historial(pacienteId: pacienteId)
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

/// Hospitalización activa de ejemplo (HAB-204, cama A, trasladado desde HAB-202 cama B) como en el Figma.
struct PreviewPacienteHospitalizacionesService: HospitalizacionesService {
    private static let id = UUID(uuidString: "eeeeeeee-eeee-4eee-8eee-000000000001") ?? UUID()

    func activa(pacienteId: UUID) async throws -> Hospitalizacion? {
        Hospitalizacion(
            id: Self.id,
            paciente: PersonaResumen(id: pacienteId, nombres: "Carlos", apellidos: "Martínez"),
            cama: CamaResumen(
                id: UUID(), codigo: "HAB-204-A",
                habitacion: HabitacionResumen(id: UUID(), codigo: "HAB-204", planta: 2, tipo: .semiprivada)
            ),
            doctorTratante: PacientePreviewData.doctorRivas,
            fechaIngreso: Formatting.sumarDias(-2, a: Date()),
            fechaAlta: nil, motivoIngreso: nil, estado: .activa
        )
    }

    func detalle(id: UUID) async throws -> HospitalizacionDetalle {
        guard let hospitalizacion = try await activa(pacienteId: UUID()) else { throw CancellationError() }
        let ingreso = hospitalizacion.fechaIngreso
        let anterior = CamaCodigo(id: UUID(), codigo: "HAB-202-B")
        let actual = CamaCodigo(id: hospitalizacion.cama.id, codigo: hospitalizacion.cama.codigo)
        return HospitalizacionDetalle(hospitalizacion: hospitalizacion, movimientos: [
            MovimientoCama(tipo: .ingreso, camaOrigen: nil, camaDestino: anterior, createdAt: ingreso),
            MovimientoCama(tipo: .traslado, camaOrigen: anterior, camaDestino: actual, createdAt: ingreso.addingTimeInterval(86_400)),
        ])
    }
}

struct PreviewAvisosService: AvisosService {
    func vigente() async throws -> Aviso? {
        Aviso(titulo: "Aviso", detalle: "el horario de visitas cambia a 2:00–6:00 p. m. desde el lunes.")
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

/// Estado público de ejemplo: ocupación del Figma, tres médicos de turno y un aviso.
struct PreviewEstadoPublicoService: EstadoPublicoService {
    func estado() async throws -> EstadoPublico {
        EstadoPublico(
            ocupacion: .init(
                vip: .init(ocupadas: 3, disponibles: 2, total: 5),
                semiprivada: .init(ocupadas: 9, disponibles: 3, total: 12),
                total: .init(ocupadas: 12, disponibles: 5, total: 17)
            ),
            medicosDeTurno: [
                .init(nombres: "Carlos", apellidos: "Molina", tipo: "Doctor", especialidad: "Medicina general",
                      area: "Consulta externa", horaInicio: "07:00:00", horaFin: "15:00:00"),
                .init(nombres: "Ana", apellidos: "Rivas", tipo: "Doctor", especialidad: "Alergología",
                      area: "Consulta externa", horaInicio: "08:00:00", horaFin: "14:00:00"),
                .init(nombres: "Jorge", apellidos: "Peña", tipo: "Médico de emergencia", especialidad: nil,
                      area: "Emergencia", horaInicio: "06:00:00", horaFin: "18:00:00"),
            ],
            avisos: [
                .init(id: UUID(), titulo: "Horario de visitas", contenido: "2:00–6:00 p. m. desde el lunes.",
                      fechaPublicacion: Date(), fechaExpiracion: nil),
            ],
            actualizadoEn: Date()
        )
    }
}

/// Turnos de ejemplo para cualquier día: mañana, tarde y noche en tres áreas.
struct PreviewTurnosDelPersonalService: TurnosDelPersonalService {
    private struct Plantilla {
        let desde: Int
        let hasta: Int
        let nombres: String
        let apellidos: String
        let tipo: String
        let especialidad: String?
        let area: String
    }

    private static let plantillas = [
        Plantilla(desde: 7, hasta: 15, nombres: "Carlos", apellidos: "Molina", tipo: "Doctor",
                  especialidad: "Medicina general", area: "Consulta externa"),
        Plantilla(desde: 8, hasta: 14, nombres: "Ana", apellidos: "Rivas", tipo: "Doctor",
                  especialidad: "Alergología", area: "Consulta externa"),
        Plantilla(desde: 7, hasta: 15, nombres: "María", apellidos: "López", tipo: "Enfermero/a",
                  especialidad: nil, area: "Hospitalización"),
        Plantilla(desde: 15, hasta: 23, nombres: "Rosa", apellidos: "Hernández", tipo: "Enfermero/a",
                  especialidad: nil, area: "Hospitalización"),
        Plantilla(desde: 19, hasta: 7, nombres: "Jorge", apellidos: "Peña", tipo: "Médico de emergencia",
                  especialidad: nil, area: "Emergencia"),
    ]

    func turnos(desde: Date, hasta: Date) async throws -> [TurnoDelPersonal] {
        var turnos: [TurnoDelPersonal] = []
        var dia = Formatting.startOfDay(desde)
        while dia <= hasta {
            turnos += Self.plantillas.map { Self.turno($0, dia: dia) }
            dia = Formatting.sumarDias(1, a: dia)
        }
        return turnos
    }

    private static func turno(_ plantilla: Plantilla, dia: Date) -> TurnoDelPersonal {
        let nocturno = plantilla.hasta < plantilla.desde
        let tipoTurno = nocturno ? "noche" : (plantilla.desde < 12 ? "manana" : "tarde")
        return TurnoDelPersonal(
            id: UUID(), nombres: plantilla.nombres, apellidos: plantilla.apellidos, tipoPersonal: plantilla.tipo,
            especialidad: plantilla.especialidad, area: plantilla.area, tipoTurno: tipoTurno,
            fecha: Formatting.diaISO(dia),
            horaInicio: String(format: "%02d:00:00", plantilla.desde),
            horaFin: String(format: "%02d:00:00", plantilla.hasta),
            inicio: Formatting.fecha(dia, hora: plantilla.desde),
            fin: Formatting.fecha(nocturno ? Formatting.sumarDias(1, a: dia) : dia, hora: plantilla.hasta)
        )
    }
}
#endif
