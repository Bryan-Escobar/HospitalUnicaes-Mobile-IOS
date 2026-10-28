#if DEBUG
import Foundation

extension DoctorDependencies {
    /// Datos de ejemplo del handoff (Dra. Ana Rivas no está en `/me`; los pacientes sí).
    static var preview: DoctorDependencies {
        DoctorDependencies(
            citas: PreviewCitasService(),
            pacientes: PreviewPacientesService(),
            hospitalizaciones: PreviewHospitalizacionesService(),
            consultas: PreviewConsultasService(),
            laboratorio: PreviewLaboratorioService(),
            onIniciarConsulta: { _ in }
        )
    }
}

enum DoctorPreviewData {
    static let luis = UUID(uuidString: "aaaaaaaa-aaaa-4aaa-8aaa-000000000001") ?? UUID()
    static let elena = UUID(uuidString: "aaaaaaaa-aaaa-4aaa-8aaa-000000000002") ?? UUID()
    static let mario = UUID(uuidString: "aaaaaaaa-aaaa-4aaa-8aaa-000000000003") ?? UUID()
    static let pedro = UUID(uuidString: "aaaaaaaa-aaaa-4aaa-8aaa-000000000004") ?? UUID()
    static let rosa = UUID(uuidString: "aaaaaaaa-aaaa-4aaa-8aaa-000000000005") ?? UUID()
    static let pruebaCutanea = ExamenCatalogo(
        id: UUID(uuidString: "dddddddd-dddd-4ddd-8ddd-000000000001") ?? UUID(),
        nombre: "Prueba cutánea de alergias", categoria: "Alergia", tipoMuestra: nil
    )
    static let doctor = UUID(uuidString: "bbbbbbbb-bbbb-4bbb-8bbb-000000000001") ?? UUID()
    static let citaLuis = UUID(uuidString: "cccccccc-cccc-4ccc-8ccc-000000000001") ?? UUID()

    static let pacientes: [Paciente] = [
        paciente(luis, "Luis", "Martínez", "01234567-8", "1992-03-14", "7000-1111"),
        paciente(elena, "Elena", "Cruz", "02345678-9", "1988-07-02", "7000-2222"),
        paciente(mario, "Mario", "Ruiz", nil, "1979-11-20", nil),
        paciente(pedro, "Pedro", "Alas", "03456789-0", "2001-01-09", "7000-4444"),
        paciente(rosa, "Rosa", "Méndez", "04567890-1", "1995-05-30", "7000-5555"),
    ]

    static var citas: [Cita] {
        [
            cita(citaLuis, luis, "Luis", "Martínez", 10, 30, .programada, "Control de alergia"),
            cita(UUID(), elena, "Elena", "Cruz", 11, 0, .confirmada, "Dolor de cabeza"),
            cita(UUID(), mario, "Mario", "Ruiz", 14, 15, .atendida, nil),
            cita(UUID(), pedro, "Pedro", "Alas", 16, 0, .cancelada, "Control"),
            cita(UUID(), rosa, "Rosa", "Méndez", 17, 0, .noAsistio, "Resultados"),
        ]
    }

    static func historial(de id: UUID) -> HistorialClinico? {
        guard let paciente = pacientes.first(where: { $0.id == id }) else { return nil }
        let alergias = id == luis ? "Penicilina, polen" : nil
        return HistorialClinico(
            paciente: paciente,
            expediente: Expediente(
                id: UUID(), pacienteId: id, numeroExpediente: paciente.numeroExpediente,
                tipoSangre: "O+", alergias: alergias, antecedentes: nil, enfermedadesCronicas: nil,
                createdAt: Date(), updatedAt: Date()
            ),
            consultas: id == mario ? [consultaMario] : []
        )
    }

    private static var consultaMario: ConsultaDetalle {
        ConsultaDetalle(
            id: UUID(), expedienteId: UUID(),
            paciente: PersonaResumen(id: mario, nombres: "Mario", apellidos: "Ruiz"),
            doctor: DoctorResumen(id: doctor, nombres: "Ana", apellidos: "Rivas", especialidad: "Alergista"),
            citaId: citas.first { $0.pacienteId == mario }?.id,
            fecha: Date(), motivoConsulta: "Control", signosVitales: nil, examenFisico: nil,
            notas: "Sin datos de alarma.", cerradaEn: Date(),
            diagnosticos: [Diagnostico(id: UUID(), codigoCie10: "J30.1", descripcion: "Rinitis alérgica", tipo: .principal)],
            recetas: [], ordenesLaboratorio: []
        )
    }

    private static func paciente(
        _ id: UUID, _ nombres: String, _ apellidos: String, _ documento: String?, _ nacimiento: String, _ telefono: String?
    ) -> Paciente {
        Paciente(
            id: id, perfilId: nil, nombres: nombres, apellidos: apellidos, documentoIdentidad: documento,
            fechaNacimiento: nacimiento, sexo: .masculino, telefono: telefono, direccion: nil,
            contactoEmergencia: nil, telefonoEmergencia: nil, numeroExpediente: "EXP-2026-\(nombres.prefix(3).uppercased())",
            activo: true, createdAt: Date()
        )
    }

    private static func cita(
        _ id: UUID, _ pacienteId: UUID, _ nombres: String, _ apellidos: String,
        _ hora: Int, _ minuto: Int, _ estado: EstadoCita, _ motivo: String?
    ) -> Cita {
        let inicio = Formatting.calendar.date(
            bySettingHour: hora, minute: minuto, second: 0, of: Date()
        ) ?? Date()
        let fin = inicio.addingTimeInterval(30 * 60)
        return Cita(
            id: id, pacienteId: pacienteId, doctorId: doctor, especialidadId: nil,
            pacienteNombres: nombres, pacienteApellidos: apellidos,
            doctorNombres: "Ana", doctorApellidos: "Rivas", especialidad: "Alergista",
            fechaHora: inicio, fechaHoraFin: fin, createdAt: Date(), duracionMinutos: 30,
            motivo: motivo, estado: estado
        )
    }
}

private struct PreviewCitasService: CitasService {
    func citas(desde: Date, hasta: Date) async throws -> [Cita] {
        DoctorPreviewData.citas.filter { $0.fechaHora >= desde && $0.fechaHora < hasta }
    }

    func cita(id: UUID) async throws -> Cita? {
        DoctorPreviewData.citas.first { $0.id == id }
    }
}

private struct PreviewPacientesService: PacientesService {
    func pacientes(buscar: String?, pagina: Int, porPagina: Int) async throws -> Pagina<Paciente> {
        let base = DoctorPreviewData.pacientes.filter { paciente in
            guard let buscar else { return true }
            let texto = "\(paciente.nombreCompleto) \(paciente.documentoIdentidad ?? "")".lowercased()
            return texto.contains(buscar.lowercased())
        }
        return Pagina(
            items: base,
            paginacion: Paginacion(pagina: pagina, porPagina: porPagina, total: base.count, totalPaginas: 1)
        )
    }

    func historial(pacienteId: UUID) async throws -> HistorialClinico {
        if pacienteId == DoctorPreviewData.rosa {
            throw APIError(statusCode: 403, code: "ACCESO_DENEGADO")
        }
        guard let historial = DoctorPreviewData.historial(de: pacienteId) else {
            throw APIError(statusCode: 404, code: "NO_ENCONTRADO")
        }
        return historial
    }
}

private struct PreviewHospitalizacionesService: HospitalizacionesService {
    func activa(pacienteId: UUID) async throws -> Hospitalizacion? {
        guard pacienteId == DoctorPreviewData.luis else { return nil }
        return Hospitalizacion(
            id: UUID(),
            paciente: PersonaResumen(id: pacienteId, nombres: "Luis", apellidos: "Martínez"),
            cama: CamaResumen(
                id: UUID(), codigo: "HAB-204-A",
                habitacion: HabitacionResumen(id: UUID(), codigo: "HAB-204", planta: 2, tipo: .semiprivada)
            ),
            doctorTratante: DoctorResumen(id: DoctorPreviewData.doctor, nombres: "Ana", apellidos: "Rivas", especialidad: "Alergista"),
            fechaIngreso: Date().addingTimeInterval(-6 * 86_400),
            fechaAlta: nil, motivoIngreso: "Observación", estado: .activa
        )
    }
}

struct PreviewConsultasService: ConsultasService {
    /// Simula que la API rechaza las recetas, para ver el guardado a medias de iOS-D7.
    var fallarRecetas = false

    func crearConsulta(_ body: CrearConsultaRequest) async throws -> ConsultaCreada {
        ConsultaCreada(id: UUID(), citaId: body.citaId, cerradaEn: nil)
    }
    func agregarDiagnostico(consultaId: UUID, _ body: CrearDiagnosticoRequest) async throws -> RegistroCreado {
        RegistroCreado(id: UUID())
    }
    func emitirReceta(consultaId: UUID, _ body: CrearRecetaRequest) async throws -> RegistroCreado {
        if fallarRecetas { throw APIError(statusCode: 500, code: "HTTP_500") }
        return RegistroCreado(id: UUID())
    }
    func cerrarConsulta(id: UUID) async throws -> ConsultaCreada {
        ConsultaCreada(id: id, citaId: nil, cerradaEn: "2026-10-25T16:00:00Z")
    }
}

private struct PreviewLaboratorioService: LaboratorioService {
    func examenes() async throws -> [ExamenCatalogo] {
        [
            ExamenCatalogo(id: UUID(), nombre: "Hemograma completo", categoria: "Hematología", tipoMuestra: "Sangre"),
            DoctorPreviewData.pruebaCutanea,
        ]
    }

    func crearOrden(_ body: CrearOrdenRequest) async throws -> OrdenCreada {
        OrdenCreada(id: UUID(), estado: "pendiente")
    }
}

extension NuevaConsultaContexto {
    static let preview = NuevaConsultaContexto(
        pacienteId: DoctorPreviewData.luis,
        pacienteNombre: "Luis Martínez",
        citaId: DoctorPreviewData.citaLuis,
        citaHora: "10:30",
        motivo: "Control de alergia",
        alergias: "Penicilina, polen"
    )
}

extension NuevaConsultaViewModel {
    static func preview(fallarRecetas: Bool = false) -> NuevaConsultaViewModel {
        NuevaConsultaViewModel(
            contexto: .preview,
            consultas: PreviewConsultasService(fallarRecetas: fallarRecetas),
            laboratorio: DoctorDependencies.preview.laboratorio
        )
    }
}
#endif
