import Foundation
import Testing
@testable import HospitalUnicaes

/// iOS-D11 Mis turnos (HUNI-54) con turnos de `v_turnos`.
@MainActor
struct TurnosViewModelTests {
    /// Miércoles 21 oct 2026, 10:00 en El Salvador.
    let hoy = salvador(2026, 10, 21, 10)

    @Test func pideEstaSemanaYLaSiguienteDesdeElDomingoAnterior() async {
        let service = FakeTurnosService()
        let viewModel = TurnosViewModel(service: service, hoy: { hoy })

        await viewModel.cargar()

        #expect(service.rangos.first?.desde == salvador(2026, 10, 18))
        #expect(service.rangos.first?.hasta == salvador(2026, 11, 1))
        #expect(SupabaseTurnosService.dia(salvador(2026, 11, 1, 23)) == "2026-11-01")
    }

    @Test func marcaElTurnoEnCursoTerminadosYDiasSinTurno() async {
        let service = FakeTurnosService()
        service.result = .success([
            turno(2026, 10, 19, 8, 14),
            turno(2026, 10, 21, 8, 14),
            turno(2026, 10, 22, 8, 14),
        ])
        let viewModel = TurnosViewModel(service: service, hoy: { hoy })

        await viewModel.cargar()

        #expect(viewModel.turnos.count == 7)
        #expect(viewModel.turnos.map(\.estado) == [.terminado, .sinTurno, .enCurso, .programado, .sinTurno, .sinTurno, .sinTurno])
        #expect(viewModel.turnoDeHoy?.horario == "08:00–14:00")
        #expect(!viewModel.restantes.contains { $0.estado == .enCurso })
        #expect(!viewModel.estaVacio)
    }

    @Test func elTurnoDeNocheDeAyerSigueEnCursoDeMadrugada() async {
        let service = FakeTurnosService()
        // Domingo 25 oct 19:00 → lunes 26 oct 07:00; son las 02:00 del lunes.
        service.result = .success([turno(2026, 10, 25, 19, 7, area: "Emergencia", tipo: "noche")])
        let madrugada = salvador(2026, 10, 26, 2)
        let viewModel = TurnosViewModel(service: service, hoy: { madrugada })

        await viewModel.cargar()

        #expect(viewModel.turnoDeHoy?.area == "Emergencia · nocturno")
        #expect(viewModel.turnoDeHoy?.horario == "19:00–07:00")
        #expect(!viewModel.estaVacio)
    }

    @Test func semanaSiguienteSinTurnoEnCurso() async {
        let service = FakeTurnosService()
        service.result = .success([turno(2026, 10, 21, 8, 14), turno(2026, 10, 27, 8, 14)])
        let viewModel = TurnosViewModel(service: service, hoy: { hoy })
        await viewModel.cargar()

        viewModel.semana = .siguiente

        #expect(viewModel.turnoDeHoy == nil)
        #expect(viewModel.turnos.first.map { Formatting.esMismoDia($0.dia, salvador(2026, 10, 26)) } == true)
        #expect(viewModel.turnos.map(\.estado) == [.sinTurno, .programado, .sinTurno, .sinTurno, .sinTurno, .sinTurno, .sinTurno])
    }

    @Test func vacioSiNoHayTurnosAsignados() async {
        let viewModel = TurnosViewModel(service: FakeTurnosService(), hoy: { hoy })
        #expect(!viewModel.estaVacio, "Antes de cargar no se muestra el vacío")

        await viewModel.cargar()

        #expect(viewModel.estaVacio)
        #expect(viewModel.turnoDeHoy == nil)
    }

    @Test func errorConReintentar() async {
        let service = FakeTurnosService()
        service.result = .failure(URLError(.notConnectedToInternet))
        let viewModel = TurnosViewModel(service: service, hoy: { hoy })

        await viewModel.cargar()
        #expect(viewModel.errorMessage == "No se pudieron cargar tus turnos.")
        #expect(!viewModel.estaVacio)

        service.result = .success([turno(2026, 10, 21, 8, 14)])
        await viewModel.cargar()
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.turnoDeHoy != nil)
    }

    @Test func decodificaLaFilaDeLaVista() throws {
        let json = """
        {"id":"11111111-1111-4111-8111-000000000001","personal_id":"22222222-2222-4222-8222-000000000002",
         "nombres":"Fernando","apellidos":"Ramos","tipo_personal":"Médico de emergencia","es_medico":true,
         "especialidad_id":null,"especialidad":null,"area":"Emergencia","tipo_turno":"noche",
         "fecha":"2026-10-25","hora_inicio":"19:00:00","hora_fin":"07:00:00",
         "inicio":"2026-10-26T01:00:00+00:00","fin":"2026-10-26T13:00:00+00:00","notas":null}
        """
        let turno = try SupabaseClientFactory.postgrestDecoder.decode(TurnoPersonal.self, from: Data(json.utf8))

        #expect(turno.horario == "19:00–07:00")
        #expect(turno.esNocturno)
        #expect(turno.inicio == salvador(2026, 10, 25, 19))
        #expect(turno.dia == salvador(2026, 10, 25))
    }

    private func turno(
        _ year: Int, _ month: Int, _ day: Int, _ desde: Int, _ hasta: Int,
        area: String = "Consulta externa", tipo: String = "manana"
    ) -> TurnoPersonal {
        let inicio = salvador(year, month, day, desde)
        let fin = salvador(year, month, hasta > desde ? day : day + 1, hasta)
        return TurnoPersonal(
            id: UUID(), personalId: UUID(), area: area, tipoTurno: tipo,
            fecha: String(format: "%04d-%02d-%02d", year, month, day),
            horaInicio: String(format: "%02d:00:00", desde), horaFin: String(format: "%02d:00:00", hasta),
            inicio: inicio, fin: fin, especialidad: "Alergista", notas: nil
        )
    }
}

private func salvador(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0) -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "America/El_Salvador") ?? .gmt
    return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour)) ?? Date()
}
