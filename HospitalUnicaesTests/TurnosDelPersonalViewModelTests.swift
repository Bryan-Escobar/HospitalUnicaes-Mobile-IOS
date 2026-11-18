import Foundation
import Testing
@testable import HospitalUnicaes

final class FakeTurnosDelPersonalService: TurnosDelPersonalService, @unchecked Sendable {
    var result: Result<[TurnoDelPersonal], Error> = .success([])
    private(set) var rangos: [(desde: Date, hasta: Date)] = []

    func turnos(desde: Date, hasta: Date) async throws -> [TurnoDelPersonal] {
        rangos.append((desde, hasta))
        return try result.get()
    }
}

/// Consulta de turnos del personal para el paciente (HUNI-76), con turnos de `v_turnos`.
@MainActor
struct TurnosDelPersonalViewModelTests {
    /// Miércoles 21 oct 2026, 10:00 en El Salvador.
    let hoy = salvador(2026, 10, 21, 10)
    let service = FakeTurnosDelPersonalService()

    private func make(ahora: Date? = nil) -> TurnosDelPersonalViewModel {
        let ahora = ahora ?? hoy
        return TurnosDelPersonalViewModel(service: service, hoy: { ahora })
    }

    @Test func pideElDiaElegidoDesdeElDiaAnterior() async {
        let viewModel = make()

        await viewModel.cargar()

        #expect(service.rangos.first?.desde == salvador(2026, 10, 20))
        #expect(service.rangos.first?.hasta == salvador(2026, 10, 21))
        #expect(viewModel.titulo == "Miércoles 21 de octubre")
    }

    @Test func soloLosTurnosQueCubrenElDiaConEstado() async {
        service.result = .success([
            turno("Rosa", "Hernández", 2026, 10, 20, 7, 15),
            turno("Jorge", "Peña", 2026, 10, 20, 19, 7, tipo: "Médico de emergencia", area: "Emergencia"),
            turno("Ana", "Rivas", 2026, 10, 21, 8, 14),
            turno("Carlos", "Molina", 2026, 10, 21, 6, 9),
            turno("Luis", "Alas", 2026, 10, 21, 15, 23),
        ])
        let viewModel = make()

        await viewModel.cargar()

        #expect(viewModel.turnosDelDia.map(\.nombres) == ["Jorge", "Carlos", "Ana", "Luis"])
        #expect(viewModel.grupos.map(\.area) == ["Consulta externa", "Emergencia"])
        let consulta = viewModel.grupos[0].filas
        #expect(consulta.map(\.nombre) == ["Carlos Molina", "Ana Rivas", "Luis Alas"])
        #expect(consulta.map(\.estado) == [.terminado, .enCurso, .programado])
        #expect(consulta[1].horario == "08:00–14:00")
        #expect(consulta[1].puesto == "Doctor · Alergología")
        let noche = viewModel.grupos[1].filas
        #expect(noche.first?.horario == "19:00–07:00 · nocturno")
        #expect(noche.first?.puesto == "Médico de emergencia · Alergología")
        #expect(!viewModel.estaVacio)
    }

    @Test func filtraPorTipoDePersonalYArea() async {
        service.result = .success([
            turno("Ana", "Rivas", 2026, 10, 21, 8, 14),
            turno("María", "López", 2026, 10, 21, 7, 15, tipo: "Enfermero/a", especialidad: nil, area: "Hospitalización"),
            turno("Rosa", "Hernández", 2026, 10, 21, 15, 23, tipo: "Enfermero/a", especialidad: nil, area: "Emergencia"),
        ])
        let viewModel = make()
        await viewModel.cargar()

        #expect(viewModel.tiposDisponibles == ["Doctor", "Enfermero/a"])
        #expect(viewModel.areasDisponibles == ["Consulta externa", "Emergencia", "Hospitalización"])

        viewModel.tipoSeleccionado = "Enfermero/a"
        #expect(viewModel.turnosFiltrados.map(\.nombres) == ["María", "Rosa"])
        #expect(viewModel.hayFiltros)

        viewModel.areaSeleccionada = "Emergencia"
        #expect(viewModel.turnosFiltrados.map(\.nombres) == ["Rosa"])
        #expect(viewModel.grupos.map(\.area) == ["Emergencia"])

        viewModel.tipoSeleccionado = "Doctor"
        #expect(viewModel.estaVacio)
        #expect(viewModel.mensajeVacio == "No hay turnos con estos filtros este día.")

        viewModel.quitarFiltros()
        #expect(!viewModel.hayFiltros)
        #expect(viewModel.turnosFiltrados.count == 3)
    }

    @Test func elFiltroElegidoSigueEnLasOpcionesAunqueElDiaNoLoTenga() async {
        service.result = .success([turno("Ana", "Rivas", 2026, 10, 21, 8, 14)])
        let viewModel = make()
        await viewModel.cargar()

        viewModel.areaSeleccionada = "Laboratorio"

        #expect(viewModel.areasDisponibles == ["Consulta externa", "Laboratorio"])
        #expect(viewModel.estaVacio)
    }

    @Test func cambiarDeDiaPideEseDia() async {
        service.result = .success([turno("Ana", "Rivas", 2026, 10, 21, 8, 14)])
        let viewModel = make()
        await viewModel.cargar()

        viewModel.seleccionar(salvador(2026, 10, 23, 12))
        #expect(viewModel.isLoading)
        #expect(!viewModel.cargado)
        #expect(viewModel.turnosDelDia.isEmpty, "No se muestran los turnos de otro día")

        service.result = .success([turno("Luis", "Alas", 2026, 10, 23, 8, 14)])
        await viewModel.cargar()

        #expect(service.rangos.last?.desde == salvador(2026, 10, 22))
        #expect(service.rangos.last?.hasta == salvador(2026, 10, 23))
        #expect(viewModel.turnosDelDia.map(\.nombres) == ["Luis"])
        #expect(viewModel.grupos.first?.filas.first?.estado == .programado)

        viewModel.semanaSiguiente()
        #expect(Formatting.esMismoDia(viewModel.diaSeleccionado, salvador(2026, 10, 30)))
        viewModel.irAHoy()
        #expect(Formatting.esMismoDia(viewModel.diaSeleccionado, hoy))
    }

    @Test func vacioSinTurnos() async {
        let viewModel = make()
        #expect(!viewModel.estaVacio, "Antes de cargar no se muestra el vacío")

        await viewModel.cargar()

        #expect(viewModel.estaVacio)
        #expect(viewModel.mensajeVacio == "No hay turnos registrados este día.")
    }

    @Test func errorConReintentarYRecargaQueConservaLosDatos() async {
        service.result = .failure(URLError(.notConnectedToInternet))
        let viewModel = make()

        await viewModel.cargar()
        #expect(viewModel.errorSinDatos == TurnosDelPersonalViewModel.mensajeError)
        #expect(!viewModel.estaVacio)
        #expect(!viewModel.isLoading)

        service.result = .success([turno("Ana", "Rivas", 2026, 10, 21, 8, 14)])
        await viewModel.cargar()
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.turnosDelDia.count == 1)

        service.result = .failure(APIError(statusCode: 500, code: "HTTP_500"))
        await viewModel.cargar()
        #expect(viewModel.errorSinDatos == nil)
        #expect(viewModel.errorRecarga == TurnosDelPersonalViewModel.mensajeError)
        #expect(viewModel.turnosDelDia.count == 1)
    }

    // MARK: Privacidad y decodificación

    @Test func soloPideColumnasDelTurnoSinDatosPersonales() {
        let columnas = Set(TurnoDelPersonal.columnas.split(separator: ",").map(String.init))

        #expect(columnas == [
            "id", "nombres", "apellidos", "tipo_personal", "especialidad", "area", "tipo_turno",
            "fecha", "hora_inicio", "hora_fin", "inicio", "fin",
        ])
        #expect(!columnas.contains("notas"))
        #expect(!columnas.contains("personal_id"))
    }

    @Test func decodificaLaFilaDeLaVista() throws {
        let json = """
        {"id":"11111111-1111-4111-8111-000000000001","nombres":"Fernando","apellidos":"Ramos",
         "tipo_personal":"Médico de emergencia","especialidad":null,"area":"Emergencia","tipo_turno":"noche",
         "fecha":"2026-10-25","hora_inicio":"19:00:00","hora_fin":"07:00:00",
         "inicio":"2026-10-26T01:00:00+00:00","fin":"2026-10-26T13:00:00+00:00"}
        """
        let turno = try SupabaseClientFactory.postgrestDecoder.decode(TurnoDelPersonal.self, from: Data(json.utf8))

        #expect(turno.nombre == "Fernando Ramos")
        #expect(turno.horario == "19:00–07:00")
        #expect(turno.esNocturno)
        #expect(turno.inicio == salvador(2026, 10, 25, 19))
        #expect(turno.fin == salvador(2026, 10, 26, 7))
    }

    private func turno(
        _ nombres: String, _ apellidos: String,
        _ year: Int, _ month: Int, _ day: Int, _ desde: Int, _ hasta: Int,
        tipo: String = "Doctor", especialidad: String? = "Alergología", area: String = "Consulta externa"
    ) -> TurnoDelPersonal {
        let inicio = salvador(year, month, day, desde)
        let fin = salvador(year, month, hasta > desde ? day : day + 1, hasta)
        return TurnoDelPersonal(
            id: UUID(), nombres: nombres, apellidos: apellidos, tipoPersonal: tipo, especialidad: especialidad,
            area: area, tipoTurno: hasta > desde ? "manana" : "noche",
            fecha: String(format: "%04d-%02d-%02d", year, month, day),
            horaInicio: String(format: "%02d:00:00", desde), horaFin: String(format: "%02d:00:00", hasta),
            inicio: inicio, fin: fin
        )
    }
}

private func salvador(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0) -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "America/El_Salvador") ?? .gmt
    return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour)) ?? Date()
}
