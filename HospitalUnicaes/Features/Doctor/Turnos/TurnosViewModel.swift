import Foundation
import Observation

/// Una fila de "Mis turnos": un turno del doctor o un día sin turno (`horario == nil`).
struct TurnoDia: Hashable, Identifiable {
    enum Estado: Hashable {
        case terminado
        case enCurso
        case programado
        case sinTurno
    }

    let id: String
    let dia: Date
    let horario: String?
    let area: String?
    let especialidad: String?
    let estado: Estado
}

enum TurnosSemana: String, CaseIterable, Identifiable {
    case actual
    case siguiente

    var id: String { rawValue }

    var titulo: String {
        switch self {
        case .actual: "Esta semana"
        case .siguiente: "Siguiente"
        }
    }
}

/// iOS-D11 Mis turnos (HUNI-54). Pide a `v_turnos` los turnos del doctor de esta semana y la siguiente
/// (lunes a domingo, El Salvador). El turno en curso se calcula con la hora real, así que el de noche que
/// empezó ayer sigue "En curso" de madrugada.
@MainActor
@Observable
final class TurnosViewModel {
    private let service: any TurnosService
    private let hoy: () -> Date
    private var carga = UUID()

    var semana: TurnosSemana = .actual
    private(set) var turnosCargados: [TurnoPersonal] = []
    private(set) var cargado = false
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    init(service: any TurnosService, hoy: @escaping () -> Date = Date.init) {
        self.service = service
        self.hoy = hoy
    }

    /// Lunes a domingo de la semana elegida.
    var dias: [Date] {
        let referencia = semana == .actual ? hoy() : Formatting.sumarDias(7, a: hoy())
        return Formatting.semana(conteniendo: referencia)
    }

    /// La semana elegida, día por día: sus turnos en orden o una fila "Sin turno".
    var turnos: [TurnoDia] {
        let ahora = hoy()
        return dias.flatMap { dia -> [TurnoDia] in
            let delDia = turnosCargados
                .filter { $0.dia.map { Formatting.esMismoDia($0, dia) } ?? false }
                .sorted { $0.inicio < $1.inicio }
            guard !delDia.isEmpty else {
                return [TurnoDia(
                    id: "sin-\(dia.timeIntervalSince1970)", dia: dia, horario: nil, area: nil,
                    especialidad: nil, estado: .sinTurno
                )]
            }
            return delDia.map { Self.fila($0, dia: dia, ahora: ahora) }
        }
    }

    /// El turno en curso, destacado arriba (solo en la semana actual). Puede ser el de noche del domingo
    /// anterior, que no sale entre los días de la semana.
    var turnoDeHoy: TurnoDia? {
        guard semana == .actual else { return nil }
        let ahora = hoy()
        guard let turno = turnosCargados.first(where: { $0.inicio <= ahora && ahora < $0.fin }) else { return nil }
        return Self.fila(turno, dia: turno.dia ?? ahora, ahora: ahora)
    }

    var restantes: [TurnoDia] {
        let enCurso = turnoDeHoy?.id
        return turnos.filter { $0.id != enCurso }
    }

    /// Sin ningún turno asignado en la semana elegida.
    var estaVacio: Bool {
        cargado && errorMessage == nil && turnoDeHoy == nil && turnos.allSatisfy { $0.estado == .sinTurno }
    }

    func cargar() async {
        let token = UUID()
        carga = token
        if !cargado { isLoading = true }
        errorMessage = nil
        let lunes = Formatting.semana(conteniendo: hoy()).first ?? Formatting.startOfDay(hoy())
        // Desde el domingo anterior: su turno de noche puede seguir en curso el lunes de madrugada.
        let desde = Formatting.sumarDias(-1, a: lunes)
        let hasta = Formatting.sumarDias(13, a: lunes)
        do {
            let resultado = try await service.misTurnos(desde: desde, hasta: hasta)
            guard carga == token else { return }
            turnosCargados = resultado
            cargado = true
            isLoading = false
        } catch {
            guard carga == token else { return }
            errorMessage = "No se pudieron cargar tus turnos."
            isLoading = false
        }
    }

    private static func fila(_ turno: TurnoPersonal, dia: Date, ahora: Date) -> TurnoDia {
        TurnoDia(
            id: turno.id.uuidString,
            dia: dia,
            horario: turno.horario,
            area: turno.esNocturno ? "\(turno.area) · nocturno" : turno.area,
            especialidad: turno.especialidad,
            estado: estado(de: turno, ahora: ahora)
        )
    }

    private static func estado(de turno: TurnoPersonal, ahora: Date) -> TurnoDia.Estado {
        if turno.inicio <= ahora && ahora < turno.fin { return .enCurso }
        return turno.fin <= ahora ? .terminado : .programado
    }
}
