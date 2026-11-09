import Foundation
@testable import HospitalUnicaes

final class FakeCitasService: CitasService, @unchecked Sendable {
    var citasResult: Result<[Cita], Error> = .success([])
    var citaResult: Result<Cita?, Error> = .success(nil)
    private(set) var rangos: [(desde: Date, hasta: Date)] = []
    private(set) var citaIds: [UUID] = []

    func citas(desde: Date, hasta: Date) async throws -> [Cita] {
        rangos.append((desde, hasta))
        return try citasResult.get()
    }

    func cita(id: UUID) async throws -> Cita? {
        citaIds.append(id)
        return try citaResult.get()
    }
}

final class FakePacientesService: PacientesService, @unchecked Sendable {
    var paginaResult: Result<Pagina<Paciente>, Error> = .success(
        Pagina(items: [], paginacion: Paginacion(pagina: 1, porPagina: 50, total: 0, totalPaginas: 1))
    )
    var paginas: [Int: Pagina<Paciente>] = [:]
    var historialResult: Result<HistorialClinico, Error> = .failure(APIError(statusCode: 404, code: "NO_ENCONTRADO"))
    private(set) var busquedas: [(buscar: String?, pagina: Int, porPagina: Int)] = []

    func pacientes(buscar: String?, pagina: Int, porPagina: Int) async throws -> Pagina<Paciente> {
        busquedas.append((buscar, pagina, porPagina))
        if let paginaLista = paginas[pagina] { return paginaLista }
        return try paginaResult.get()
    }

    func historial(pacienteId: UUID) async throws -> HistorialClinico {
        try historialResult.get()
    }
}

final class FakeHospitalizacionesService: HospitalizacionesService, @unchecked Sendable {
    var result: Result<Hospitalizacion?, Error> = .success(nil)
    func activa(pacienteId: UUID) async throws -> Hospitalizacion? {
        try result.get()
    }
}

enum DoctorFixtures {
    static func cita(
        id: UUID = UUID(),
        pacienteId: UUID = UUID(),
        fecha: Date = Date(),
        estado: EstadoCita = .programada,
        motivo: String? = "Control",
        nombres: String = "Luis",
        apellidos: String = "Martínez"
    ) -> Cita {
        Cita(
            id: id, pacienteId: pacienteId, doctorId: UUID(), especialidadId: nil,
            pacienteNombres: nombres, pacienteApellidos: apellidos,
            doctorNombres: "Ana", doctorApellidos: "Rivas", especialidad: "Alergista",
            fechaHora: fecha, fechaHoraFin: fecha.addingTimeInterval(1800), createdAt: fecha,
            duracionMinutos: 30, motivo: motivo, estado: estado
        )
    }

    static func paciente(
        id: UUID = UUID(),
        nombres: String = "Luis",
        apellidos: String = "Martínez",
        documento: String? = "01234567-8",
        expediente: String = "EXP-2026-00015"
    ) -> Paciente {
        Paciente(
            id: id, perfilId: nil, nombres: nombres, apellidos: apellidos,
            documentoIdentidad: documento, fechaNacimiento: "1992-03-14", sexo: .masculino,
            telefono: "7000-1111", direccion: nil, contactoEmergencia: "María", telefonoEmergencia: "7000-9999",
            numeroExpediente: expediente, activo: true, createdAt: Date()
        )
    }

    static func historial(paciente: Paciente = paciente(), consultas: [ConsultaDetalle] = []) -> HistorialClinico {
        HistorialClinico(
            paciente: paciente,
            expediente: Expediente(
                id: UUID(), pacienteId: paciente.id, numeroExpediente: paciente.numeroExpediente,
                tipoSangre: "O+", alergias: "Penicilina", antecedentes: nil, enfermedadesCronicas: nil,
                createdAt: Date(), updatedAt: Date()
            ),
            consultas: consultas
        )
    }

    static func consulta(id: UUID = UUID(), citaId: UUID?, fecha: Date = Date()) -> ConsultaDetalle {
        ConsultaDetalle(
            id: id, expedienteId: UUID(),
            paciente: PersonaResumen(id: UUID(), nombres: "Luis", apellidos: "Martínez"),
            doctor: DoctorResumen(id: UUID(), nombres: "Ana", apellidos: "Rivas", especialidad: "Alergista"),
            citaId: citaId, fecha: fecha, motivoConsulta: "Control", signosVitales: nil, examenFisico: nil,
            notas: nil, cerradaEn: fecha,
            diagnosticos: [Diagnostico(id: UUID(), codigoCie10: nil, descripcion: "Rinitis", tipo: .principal)],
            recetas: [], ordenesLaboratorio: []
        )
    }

    static func orden(fecha: Date, id: UUID = UUID()) -> OrdenLaboratorioResumen {
        OrdenLaboratorioResumen(
            id: id, fechaSolicitud: fecha, prioridad: .normal, estado: .pendiente, totalExamenes: 1
        )
    }

    static func hospitalizacion() -> Hospitalizacion {
        Hospitalizacion(
            id: UUID(),
            paciente: PersonaResumen(id: UUID(), nombres: "Luis", apellidos: "Martínez"),
            cama: CamaResumen(
                id: UUID(), codigo: "HAB-204-A",
                habitacion: HabitacionResumen(id: UUID(), codigo: "HAB-204", planta: 2, tipo: .semiprivada)
            ),
            doctorTratante: DoctorResumen(id: UUID(), nombres: "Ana", apellidos: "Rivas", especialidad: nil),
            fechaIngreso: Date(), fechaAlta: nil, motivoIngreso: nil, estado: .activa
        )
    }
}
