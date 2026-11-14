import Foundation
import Observation

/// iOS-P1 Inicio del paciente (HUNI-111). Resume las otras pestañas con datos reales:
/// próxima cita (`v_citas`), últimos resultados de laboratorio, estado de la ambulancia,
/// habitación (hospitalización activa) y aviso vigente.
///
/// Cada sección se pide por separado: si una falla, las demás se muestran igual y un aviso lista
/// las que faltan. Solo si todas fallan en la primera carga se muestra el error a pantalla completa.
/// Una recarga que falla conserva los datos anteriores.
@MainActor
@Observable
final class PacienteInicioViewModel {
    static let mensajeError = "No se pudo cargar tu información."

    let saludo: String
    private(set) var proximaCita: CitaPaciente?
    private(set) var habitacion: HabitacionPaciente?
    private(set) var ultimosResultados: [ExamenLaboratorioPaciente] = []
    /// `nil` mientras no se conoce: el botón "Solicitar" queda deshabilitado.
    private(set) var estadoAmbulancia: EstadoAmbulancia?
    private(set) var aviso: Aviso?
    private(set) var cargado = false
    private(set) var isLoading = false
    /// Error a pantalla completa: solo si nada cargó nunca.
    private(set) var errorMessage: String?
    /// "No se pudieron cargar: citas, ambulancia." cuando solo fallaron algunas secciones.
    private(set) var errorParcial: String?

    private let pacienteId: UUID?
    private let citas: any CitasPacienteService
    private let laboratorio: any LaboratorioPacienteService
    private let ambulancias: any AmbulanciaService
    private let hospitalizaciones: any HospitalizacionesService
    private let avisos: any AvisosService
    private let hoy: () -> Date
    private var carga = UUID()

    init(
        me: Me,
        citas: any CitasPacienteService,
        laboratorio: any LaboratorioPacienteService,
        ambulancias: any AmbulanciaService,
        hospitalizaciones: any HospitalizacionesService,
        avisos: any AvisosService,
        hoy: @escaping () -> Date = Date.init
    ) {
        saludo = "Hola, \(me.nombres.split(separator: " ").first.map(String.init) ?? me.nombres)"
        pacienteId = me.pacienteId
        self.citas = citas
        self.laboratorio = laboratorio
        self.ambulancias = ambulancias
        self.hospitalizaciones = hospitalizaciones
        self.avisos = avisos
        self.hoy = hoy
    }

    var fecha: String { Formatting.fechaLarga(hoy()) }

    var puedeSolicitarAmbulancia: Bool { estadoAmbulancia == .disponible }

    /// Recarga todo. Se llama al abrir, al volver a primer plano y al reintentar.
    func cargar() async {
        let token = UUID()
        carga = token
        if !cargado { isLoading = true }
        errorMessage = nil

        let citas = citas, laboratorio = laboratorio, ambulancias = ambulancias
        let hospitalizaciones = hospitalizaciones, avisos = avisos, pacienteId = pacienteId

        async let listaCitas = Self.capturar { try await citas.citas() }
        async let ordenes = Self.capturar { try await laboratorio.misOrdenes() }
        async let ambulancia = Self.capturar { try await ambulancias.estado() }
        async let hospitalizacion = Self.capturar { () -> Hospitalizacion? in
            guard let pacienteId else { return nil }
            return try await hospitalizaciones.activa(pacienteId: pacienteId)
        }
        async let avisoVigente = Self.capturar { try await avisos.vigente() }

        let (rCitas, rOrdenes, rAmbulancia, rHospitalizacion, rAviso) =
            await (listaCitas, ordenes, ambulancia, hospitalizacion, avisoVigente)
        guard carga == token else { return }

        var fallidas: [String] = []

        switch rCitas {
        case .success(let lista):
            proximaCita = CitaPaciente.proxima(entre: lista.map(CitaPaciente.init), ahora: hoy())
        case .failure:
            fallidas.append("citas")
        }
        switch rOrdenes {
        case .success(let lista):
            ultimosResultados = Array(lista.filasLaboratorio.prefix(2))
        case .failure:
            fallidas.append("resultados")
        }
        switch rAmbulancia {
        case .success(let valor):
            estadoAmbulancia = valor.estado
        case .failure:
            fallidas.append("ambulancia")
        }
        switch rHospitalizacion {
        case .success(let valor):
            habitacion = valor.map(HabitacionPaciente.init)
        case .failure:
            fallidas.append("habitación")
        }
        switch rAviso {
        case .success(let valor):
            aviso = valor
        case .failure:
            fallidas.append("avisos")
        }

        isLoading = false
        if fallidas.count == Self.secciones, !cargado {
            errorMessage = Self.mensajeError
            errorParcial = nil
            return
        }
        if fallidas.count < Self.secciones { cargado = true }
        errorParcial = fallidas.isEmpty ? nil : "No se pudieron cargar: \(fallidas.joined(separator: ", "))."
    }

    private static let secciones = 5

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
