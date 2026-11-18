import Foundation
import Observation

/// Una fila de "Turnos del personal": quién está de turno y a qué hora (sin datos personales).
struct FilaTurnoDelPersonal: Hashable, Identifiable {
    enum Estado: Hashable {
        case terminado
        case enCurso
        case programado
    }

    let id: UUID
    let nombre: String
    /// "Doctor · Pediatría".
    let puesto: String
    /// "07:00–15:00", con "nocturno" si termina al día siguiente.
    let horario: String
    let estado: Estado
}

/// Turnos de un área en el día elegido.
struct GrupoTurnosDelPersonal: Hashable, Identifiable {
    let area: String
    let filas: [FilaTurnoDelPersonal]

    var id: String { area }
}

/// Consulta de turnos del personal para el paciente (HUNI-76). Pide a `v_turnos` el día elegido (y el
/// anterior, porque su turno de noche sigue de madrugada) y filtra en memoria por tipo de personal y área.
/// Las opciones de los filtros salen de los turnos del día.
@MainActor
@Observable
final class TurnosDelPersonalViewModel {
    static let mensajeError = "No se pudieron cargar los turnos del personal."

    private let service: any TurnosDelPersonalService
    private let hoy: () -> Date
    private var carga = UUID()

    private(set) var diaSeleccionado: Date
    /// `nil` = todos los tipos.
    var tipoSeleccionado: String?
    /// `nil` = todas las áreas.
    var areaSeleccionada: String?
    private(set) var turnosCargados: [TurnoDelPersonal] = []
    /// Día al que corresponden `turnosCargados`.
    private(set) var diaCargado: Date?
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    init(service: any TurnosDelPersonalService, hoy: @escaping () -> Date = Date.init) {
        self.service = service
        self.hoy = hoy
        diaSeleccionado = Formatting.startOfDay(hoy())
    }

    var semana: [Date] { Formatting.semana(conteniendo: diaSeleccionado) }

    /// "Miércoles 21 de octubre".
    var titulo: String { Formatting.fechaLarga(diaSeleccionado) }

    var hayFiltros: Bool { tipoSeleccionado != nil || areaSeleccionada != nil }

    /// Turnos que cubren alguna parte del día elegido, en orden de inicio.
    var turnosDelDia: [TurnoDelPersonal] {
        guard let diaCargado, Formatting.esMismoDia(diaCargado, diaSeleccionado) else { return [] }
        let rango = Formatting.rangoDelDia(diaSeleccionado)
        return turnosCargados
            .filter { $0.inicio < rango.hasta && $0.fin > rango.desde }
            .sorted { ($0.inicio, $0.apellidos, $0.nombres) < ($1.inicio, $1.apellidos, $1.nombres) }
    }

    var tiposDisponibles: [String] { Self.opciones(turnosDelDia.map(\.tipoPersonal), elegida: tipoSeleccionado) }
    var areasDisponibles: [String] { Self.opciones(turnosDelDia.map(\.area), elegida: areaSeleccionada) }

    var turnosFiltrados: [TurnoDelPersonal] {
        turnosDelDia.filter { turno in
            (tipoSeleccionado.map { $0 == turno.tipoPersonal } ?? true)
                && (areaSeleccionada.map { $0 == turno.area } ?? true)
        }
    }

    /// Por área (orden alfabético) y dentro de cada una por hora de inicio.
    var grupos: [GrupoTurnosDelPersonal] {
        let ahora = hoy()
        let porArea = Dictionary(grouping: turnosFiltrados, by: \.area)
        return porArea.keys.sorted(by: Self.antes).map { area in
            GrupoTurnosDelPersonal(area: area, filas: (porArea[area] ?? []).map { Self.fila($0, ahora: ahora) })
        }
    }

    var cargado: Bool { diaCargado.map { Formatting.esMismoDia($0, diaSeleccionado) } ?? false }

    var estaVacio: Bool { cargado && errorMessage == nil && turnosFiltrados.isEmpty }

    /// Sin datos del día por un error (una recarga fallida conserva la lista).
    var errorSinDatos: String? { cargado ? nil : errorMessage }
    var errorRecarga: String? { cargado ? errorMessage : nil }

    var mensajeVacio: String {
        if hayFiltros { return "No hay turnos con estos filtros este día." }
        return "No hay turnos registrados este día."
    }

    func seleccionar(_ fecha: Date) {
        let dia = Formatting.startOfDay(fecha)
        guard !Formatting.esMismoDia(dia, diaSeleccionado) else { return }
        diaSeleccionado = dia
        errorMessage = nil
        isLoading = true
    }

    func irAHoy() { seleccionar(hoy()) }
    func semanaAnterior() { seleccionar(Formatting.sumarDias(-7, a: diaSeleccionado)) }
    func semanaSiguiente() { seleccionar(Formatting.sumarDias(7, a: diaSeleccionado)) }

    func quitarFiltros() {
        tipoSeleccionado = nil
        areaSeleccionada = nil
    }

    func cargar() async {
        let dia = diaSeleccionado
        let token = UUID()
        carga = token
        if !cargado { isLoading = true }
        errorMessage = nil
        do {
            // Desde el día anterior: su turno de noche puede seguir en curso de madrugada.
            let resultado = try await service.turnos(desde: Formatting.sumarDias(-1, a: dia), hasta: dia)
            guard carga == token, Formatting.esMismoDia(diaSeleccionado, dia) else { return }
            turnosCargados = resultado
            diaCargado = dia
            isLoading = false
        } catch {
            // Un día distinto ya está cargando (o la tarea se canceló al cambiar de día).
            guard carga == token, Formatting.esMismoDia(diaSeleccionado, dia), !(error is CancellationError) else { return }
            errorMessage = Self.mensajeError
            isLoading = false
        }
    }

    private static func fila(_ turno: TurnoDelPersonal, ahora: Date) -> FilaTurnoDelPersonal {
        let estado: FilaTurnoDelPersonal.Estado
        if turno.inicio <= ahora && ahora < turno.fin {
            estado = .enCurso
        } else {
            estado = turno.fin <= ahora ? .terminado : .programado
        }
        return FilaTurnoDelPersonal(
            id: turno.id,
            nombre: turno.nombre,
            puesto: Formatting.unir([turno.tipoPersonal, turno.especialidad]),
            horario: turno.esNocturno ? "\(turno.horario) · nocturno" : turno.horario,
            estado: estado
        )
    }

    /// Valores distintos ordenados; la opción elegida se conserva aunque el día no la tenga.
    private static func opciones(_ valores: [String], elegida: String?) -> [String] {
        Set(valores + [elegida].compactMap { $0 }).sorted(by: antes)
    }

    private static func antes(_ lhs: String, _ rhs: String) -> Bool {
        lhs.compare(rhs, locale: Formatting.locale) == .orderedAscending
    }
}
