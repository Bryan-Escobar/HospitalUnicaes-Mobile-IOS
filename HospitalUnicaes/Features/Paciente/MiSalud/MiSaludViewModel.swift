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

/// iOS-P5 y P9 Mi salud: historial clínico (HUNI-60) y habitación asignada (HUNI-94) del propio
/// paciente. El laboratorio (iOS-P7) vive en `LaboratorioPacienteViewModel`.
/// Lo crea la TabView del paciente para que Inicio pueda abrir un segmento concreto.
///
/// El historial (`GET pacientes/{id}/historial`) trae alergias y consultas con diagnósticos y
/// recetas, pero las órdenes de laboratorio solo resumidas; el detalle por examen sale de
/// `GET laboratorio/ordenes`, que se pide en paralelo. Si solo fallan las órdenes, el historial se
/// muestra igual y el detalle de cada consulta avisa que no cargaron.
///
/// La habitación (`GET hospitalizaciones?estado=activa`) se pide en la misma carga, pero tiene su
/// propio estado: si falla, el historial se muestra igual y viceversa. La API solo le devuelve al
/// paciente su propia hospitalización (privacidad, context.md §3.4). El traslado sale del detalle
/// (`GET hospitalizaciones/{id}`); si ese detalle falla, la habitación se muestra sin el aviso.
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
    static let mensajeErrorHabitacion = "No se pudo cargar tu habitación."

    var segmento: MiSaludSegmento = .historial
    private(set) var estado: Carga = .cargando
    /// Alergias del expediente; `nil` si no hay registradas.
    private(set) var alergias: String?
    /// Más recientes primero.
    private(set) var consultas: [ConsultaPaciente] = []
    private(set) var estadoHabitacion: Carga = .cargando
    /// Hospitalización activa; `nil` si el paciente no está hospitalizado.
    private(set) var habitacion: HabitacionPaciente?

    private let pacienteId: UUID?
    private let historial: any HistorialPacienteService
    private let laboratorio: any LaboratorioPacienteService
    private let hospitalizaciones: any HospitalizacionesService
    private var cargoAlgunaVez = false
    private var cargoHabitacion = false
    private var recargando = false

    init(
        pacienteId: UUID?,
        historial: any HistorialPacienteService,
        laboratorio: any LaboratorioPacienteService,
        hospitalizaciones: any HospitalizacionesService
    ) {
        self.pacienteId = pacienteId
        self.historial = historial
        self.laboratorio = laboratorio
        self.hospitalizaciones = hospitalizaciones
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
            estadoHabitacion = .error(Self.mensajeSinExpediente)
            return
        }
        if !cargoAlgunaVez { estado = .cargando }
        if !cargoHabitacion { estadoHabitacion = .cargando }

        let historial = historial, laboratorio = laboratorio, hospitalizaciones = hospitalizaciones
        async let rHistorial = Self.capturar { try await historial.historial(pacienteId: pacienteId) }
        async let rOrdenes = Self.capturar { try await laboratorio.misOrdenes() }
        async let rHabitacion = Self.capturar { try await Self.habitacion(pacienteId: pacienteId, en: hospitalizaciones) }
        let (resultadoHistorial, resultadoOrdenes, resultadoHabitacion) = await (rHistorial, rOrdenes, rHabitacion)

        switch resultadoHabitacion {
        case .success(let cargada):
            habitacion = cargada
            cargoHabitacion = true
            estadoHabitacion = .listo
        case .failure(let error) where error is CancellationError:
            return
        case .failure:
            if !cargoHabitacion { estadoHabitacion = .error(Self.mensajeErrorHabitacion) }
        }

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

    /// Hospitalización activa con su último traslado. Si solo falla el detalle, la habitación se
    /// muestra sin el aviso de traslado.
    private nonisolated static func habitacion(
        pacienteId: UUID,
        en hospitalizaciones: any HospitalizacionesService
    ) async throws -> HabitacionPaciente? {
        guard let activa = try await hospitalizaciones.activa(pacienteId: pacienteId) else { return nil }
        do {
            return HabitacionPaciente(try await hospitalizaciones.detalle(id: activa.id))
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            return HabitacionPaciente(activa)
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
