import Foundation
import Observation

enum MiSaludSegmento: String, CaseIterable, Identifiable {
    case historial
    case laboratorio
    case habitacion

    var id: String { rawValue }

    var titulo: String {
        switch self {
        case .historial: "Historial"
        case .laboratorio: "Laboratorio"
        case .habitacion: "Habitación"
        }
    }
}

/// iOS-P5 y P9 Mi salud: historial clínico (HUNI-60) y habitación del propio paciente (datos de
/// ejemplo hasta HUNI-94). El laboratorio (iOS-P7) vive en `LaboratorioPacienteViewModel`.
/// Lo crea la TabView del paciente para que Inicio pueda abrir un segmento concreto.
///
/// El historial (`GET pacientes/{id}/historial`) trae alergias y consultas con diagnósticos y
/// recetas, pero las órdenes de laboratorio solo resumidas; el detalle por examen sale de
/// `GET laboratorio/ordenes`, que se pide en paralelo. Si solo fallan las órdenes, el historial se
/// muestra igual y el detalle de cada consulta avisa que no cargaron.
@MainActor
@Observable
final class MiSaludViewModel {
    enum Carga: Equatable {
        case cargando
        case listo
        /// Solo cuando nunca hubo datos; si falla una recarga se conservan los anteriores.
        case error(String)
    }

    static let mensajeError = "No se pudo cargar tu historial clínico."
    static let mensajeSinExpediente = "Tu cuenta todavía no tiene un expediente clínico."

    var segmento: MiSaludSegmento = .historial
    private(set) var estado: Carga = .cargando
    /// Alergias del expediente; `nil` si no hay registradas.
    private(set) var alergias: String?
    /// Más recientes primero.
    private(set) var consultas: [ConsultaPaciente] = []
    let habitacion: HabitacionPaciente?

    private let pacienteId: UUID?
    private let historial: any HistorialPacienteService
    private let laboratorio: any LaboratorioPacienteService
    private var cargoAlgunaVez = false
    private var recargando = false

    init(
        pacienteId: UUID?,
        historial: any HistorialPacienteService,
        laboratorio: any LaboratorioPacienteService,
        hoy: Date = Date()
    ) {
        self.pacienteId = pacienteId
        self.historial = historial
        self.laboratorio = laboratorio
        habitacion = PacienteMuestra.habitacion(hoy: hoy)
    }

    /// Primera carga al abrir Mi salud; si ya cargó, no hace nada (el resto es pull-to-refresh).
    func cargarSiHaceFalta() async {
        guard !cargoAlgunaVez else { return }
        await recargar()
    }

    /// Pull-to-refresh y "Reintentar". Si ya hay una carga en curso, no se lanza otra.
    func recargar() async {
        guard !recargando else { return }
        recargando = true
        defer { recargando = false }

        guard let pacienteId else {
            estado = .error(Self.mensajeSinExpediente)
            return
        }
        if !cargoAlgunaVez { estado = .cargando }

        let historial = historial, laboratorio = laboratorio
        async let rHistorial = Self.capturar { try await historial.historial(pacienteId: pacienteId) }
        async let rOrdenes = Self.capturar { try await laboratorio.misOrdenes() }
        let (resultadoHistorial, resultadoOrdenes) = await (rHistorial, rOrdenes)

        switch resultadoHistorial {
        case .success(let cargado):
            let ordenes = try? resultadoOrdenes.get()
            alergias = cargado.expediente.alergias?.nilIfBlank
            consultas = cargado.consultas
                .map { ConsultaPaciente($0, ordenesLaboratorio: ordenes) }
                .sorted { $0.fecha > $1.fecha }
            cargoAlgunaVez = true
            estado = .listo
        case .failure(let error) where error is CancellationError:
            return
        case .failure:
            if !cargoAlgunaVez { estado = .error(Self.mensajeError) }
        }
    }

    private nonisolated static func capturar<T: Sendable>(
        _ operacion: @Sendable () async throws -> T
    ) async -> Result<T, Error> {
        do {
            return .success(try await operacion())
        } catch {
            return .failure(error)
        }
    }
}
