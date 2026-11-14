import Foundation
import Observation

/// Datos de las tarjetas de Inicio del doctor.
struct DoctorInicioResumen: Equatable {
    struct Turno: Equatable {
        let horario: String
        let area: String
        let especialidad: String
    }

    struct ProximaCita: Equatable {
        let hora: String
        let paciente: String
        let motivo: String
    }

    struct Laboratorio: Equatable {
        let pendientes: Int
        let enProceso: Int
        let completados: Int
    }

    /// Turno en curso de hoy; `nil` si no tiene turno hoy.
    var turno: Turno?
    var proximaCita: ProximaCita?
    var laboratorio = Laboratorio(pendientes: 0, enProceso: 0, completados: 0)
    /// `nil` mientras no se conoce.
    var ambulancia: EstadoAmbulancia?
    var aviso: Aviso?
}

/// iOS-D1 Inicio del doctor con datos reales (HUNI-112): turno de hoy (`v_turnos`), próxima cita
/// (`v_citas`), laboratorio de las órdenes que el doctor emitió, estado de la ambulancia y aviso vigente.
///
/// Cada sección se pide por separado: si una falla, las demás se muestran igual y un aviso lista las
/// que faltan. Solo si todas fallan en la primera carga se muestra el error a pantalla completa.
/// Una recarga que falla conserva los datos anteriores.
@MainActor
@Observable
final class DoctorInicioViewModel {
    static let mensajeError = "No se pudo cargar tu información."

    let saludo: String
    private(set) var resumen = DoctorInicioResumen()
    private(set) var cargado = false
    private(set) var isLoading = false
    /// Error a pantalla completa: solo si nada cargó nunca.
    private(set) var errorMessage: String?
    /// "No se pudieron cargar: turno, ambulancia." cuando solo fallaron algunas secciones.
    private(set) var errorParcial: String?

    private let personalId: UUID?
    private let turnos: any TurnosService
    private let citas: any CitasService
    private let laboratorio: any LaboratorioPacienteService
    private let ambulancias: any AmbulanciaService
    private let avisos: any AvisosService
    private let hoy: () -> Date
    private var carga = UUID()

    init(
        me: Me,
        turnos: any TurnosService,
        citas: any CitasService,
        laboratorio: any LaboratorioPacienteService,
        ambulancias: any AmbulanciaService,
        avisos: any AvisosService,
        hoy: @escaping () -> Date = Date.init
    ) {
        saludo = "Hola, \(me.nombres.split(separator: " ").first.map(String.init) ?? me.nombres)"
        personalId = me.personal?.id
        self.turnos = turnos
        self.citas = citas
        self.laboratorio = laboratorio
        self.ambulancias = ambulancias
        self.avisos = avisos
        self.hoy = hoy
    }

    var fecha: String { Formatting.fechaLarga(hoy()) }

    var conteosLaboratorio: [(estado: EstadoLaboratorio, cantidad: Int)] {
        [
            (.pendiente, resumen.laboratorio.pendientes),
            (.enProceso, resumen.laboratorio.enProceso),
            (.completado, resumen.laboratorio.completados),
        ]
    }

    /// Recarga todo. Se llama al abrir, al volver a primer plano y al reintentar.
    func cargar() async {
        let token = UUID()
        carga = token
        if !cargado { isLoading = true }
        errorMessage = nil

        let ahora = hoy()
        let turnos = turnos, citas = citas, laboratorio = laboratorio
        let ambulancias = ambulancias, avisos = avisos
        // Desde ayer: un turno de noche puede seguir en curso de madrugada.
        let desdeTurnos = Formatting.sumarDias(-1, a: Formatting.startOfDay(ahora))
        let hastaTurnos = Formatting.sumarDias(1, a: Formatting.startOfDay(ahora))
        let hastaCitas = Formatting.sumarDias(7, a: Formatting.startOfDay(ahora))

        async let listaTurnos = Self.capturar { try await turnos.misTurnos(desde: desdeTurnos, hasta: hastaTurnos) }
        async let listaCitas = Self.capturar { try await citas.citas(desde: ahora, hasta: hastaCitas) }
        async let ordenes = Self.capturar { try await laboratorio.misOrdenes() }
        async let ambulancia = Self.capturar { try await ambulancias.estado() }
        async let avisoVigente = Self.capturar { try await avisos.vigente() }

        let (rTurnos, rCitas, rOrdenes, rAmbulancia, rAviso) =
            await (listaTurnos, listaCitas, ordenes, ambulancia, avisoVigente)
        guard carga == token else { return }

        var fallidas: [String] = []

        switch rTurnos {
        case .success(let lista):
            resumen.turno = Self.turnoDeHoy(lista, ahora: ahora)
        case .failure:
            fallidas.append("turno")
        }
        switch rCitas {
        case .success(let lista):
            resumen.proximaCita = Self.proximaCita(lista, ahora: ahora)
        case .failure:
            fallidas.append("cita")
        }
        switch rOrdenes {
        case .success(let lista):
            resumen.laboratorio = Self.conteos(lista, personalId: personalId)
        case .failure:
            fallidas.append("laboratorio")
        }
        switch rAmbulancia {
        case .success(let valor):
            resumen.ambulancia = valor.estado
        case .failure:
            fallidas.append("ambulancia")
        }
        switch rAviso {
        case .success(let valor):
            resumen.aviso = valor
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

    /// El turno en curso; si no hay uno en curso, el siguiente que empieza hoy.
    static func turnoDeHoy(_ turnos: [TurnoPersonal], ahora: Date) -> DoctorInicioResumen.Turno? {
        let enCurso = turnos.first { $0.inicio <= ahora && ahora < $0.fin }
        let restoDeHoy = turnos
            .filter { Formatting.esMismoDia($0.inicio, ahora) && $0.inicio > ahora }
            .min { $0.inicio < $1.inicio }
        guard let turno = enCurso ?? restoDeHoy else { return nil }
        return DoctorInicioResumen.Turno(
            horario: turno.horario,
            area: turno.esNocturno ? "\(turno.area) · nocturno" : turno.area,
            especialidad: turno.especialidad ?? ""
        )
    }

    /// La siguiente cita programada o confirmada que aún no empieza.
    static func proximaCita(_ citas: [Cita], ahora: Date) -> DoctorInicioResumen.ProximaCita? {
        let cita = citas
            .filter { ($0.estado == .programada || $0.estado == .confirmada) && $0.fechaHora >= ahora }
            .min { $0.fechaHora < $1.fechaHora }
        return cita.map {
            DoctorInicioResumen.ProximaCita(
                hora: Formatting.hora($0.fechaHora),
                paciente: $0.pacienteNombre,
                motivo: $0.motivo ?? "Sin motivo"
            )
        }
    }

    /// Exámenes por estado, solo de las órdenes que emitió este doctor (la API también devuelve las
    /// de otros doctores que atienden a los mismos pacientes).
    static func conteos(_ ordenes: [OrdenLaboratorioPaciente], personalId: UUID?) -> DoctorInicioResumen.Laboratorio {
        let examenes = ordenes.filter { $0.doctor.id == personalId }.flatMap(\.examenes)
        return DoctorInicioResumen.Laboratorio(
            pendientes: examenes.filter { $0.estado == .pendiente }.count,
            enProceso: examenes.filter { $0.estado == .enProceso }.count,
            completados: examenes.filter { $0.estado == .completado }.count
        )
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
