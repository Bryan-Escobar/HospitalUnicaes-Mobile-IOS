import Foundation
import Testing
@testable import HospitalUnicaes

/// iOS-D1 Inicio del doctor con datos reales (HUNI-112).
@MainActor
struct DoctorInicioViewModelTests {
    /// Miércoles 21 oct 2026, 10:00 en El Salvador.
    let ahora = Date(timeIntervalSince1970: 1_792_598_400)
    let me = Me.fixture(rol: .doctor)

    private struct Servicios {
        let turnos = FakeTurnosService()
        let citas = FakeCitasService()
        let laboratorio = FakeLaboratorioPacienteService()
        let ambulancias = FakeAmbulanciaService()
        let avisos = FakeAvisosService()
    }

    private func viewModel(_ s: Servicios, me: Me? = nil) -> DoctorInicioViewModel {
        DoctorInicioViewModel(
            me: me ?? self.me, turnos: s.turnos, citas: s.citas, laboratorio: s.laboratorio,
            ambulancias: s.ambulancias, avisos: s.avisos, hoy: { ahora }
        )
    }

    private func turno(desde: TimeInterval, hasta: TimeInterval, area: String = "Consulta externa") -> TurnoPersonal {
        TurnoPersonal(
            id: UUID(), personalId: UUID(), area: area, tipoTurno: "manana", fecha: "2026-10-21",
            horaInicio: "08:00:00", horaFin: "14:00:00",
            inicio: ahora.addingTimeInterval(desde), fin: ahora.addingTimeInterval(hasta),
            especialidad: "Alergista", notas: nil
        )
    }

    private func orden(doctor: UUID, _ estados: [EstadoLaboratorio]) -> OrdenLaboratorioPaciente {
        OrdenLaboratorioPaciente(
            id: UUID(), fechaSolicitud: ahora, prioridad: .normal, estado: .pendiente,
            doctor: DoctorResumen(id: doctor, nombres: "Ana", apellidos: "Rivas", especialidad: nil),
            indicaciones: nil, examenes: estados.map { LabFixtures.examen(id: UUID(), estado: $0) }
        )
    }

    @Test func saludaPorNombreYFormateaLaFecha() {
        let vm = viewModel(Servicios())

        #expect(vm.saludo == "Hola, Ana")
        #expect(vm.fecha == "Miércoles 21 de octubre")
    }

    @Test func cargaTurnoDeHoyEnCurso() async {
        let s = Servicios()
        s.turnos.result = .success([turno(desde: -7200, hasta: 14400)])
        let vm = viewModel(s)

        await vm.cargar()

        #expect(vm.resumen.turno == .init(horario: "08:00–14:00", area: "Consulta externa", especialidad: "Alergista"))
        #expect(vm.cargado)
        #expect(vm.errorMessage == nil)
    }

    @Test func sinTurnoHoyNoHayTurno() async {
        let s = Servicios()
        s.turnos.result = .success([turno(desde: -86400 * 2, hasta: -86400 * 2 + 3600)])
        let vm = viewModel(s)

        await vm.cargar()

        #expect(vm.resumen.turno == nil)
        #expect(vm.errorParcial == nil)
    }

    @Test func proximaCitaEsLaSiguienteProgramadaOConfirmada() async {
        let s = Servicios()
        s.citas.citasResult = .success([
            DoctorFixtures.cita(fecha: ahora.addingTimeInterval(600), estado: .cancelada, nombres: "Cancelada"),
            DoctorFixtures.cita(fecha: ahora.addingTimeInterval(-600), estado: .programada, nombres: "Pasada"),
            DoctorFixtures.cita(fecha: ahora.addingTimeInterval(7200), estado: .programada, nombres: "Tarde"),
            DoctorFixtures.cita(fecha: ahora.addingTimeInterval(1800), estado: .confirmada, motivo: "Control de alergia", nombres: "Luis", apellidos: "Martínez"),
        ])
        let vm = viewModel(s)

        await vm.cargar()

        #expect(vm.resumen.proximaCita?.paciente == "Luis Martínez")
        #expect(vm.resumen.proximaCita?.motivo == "Control de alergia")
    }

    @Test func laboratorioSoloCuentaExamenesQueElDoctorOrdeno() async throws {
        let s = Servicios()
        let propio = try #require(me.personal?.id)
        s.laboratorio.ordenesResult = .success([
            orden(doctor: propio, [.pendiente, .pendiente, .enProceso]),
            orden(doctor: propio, [.completado]),
            orden(doctor: UUID(), [.pendiente, .completado, .completado]),
        ])
        let vm = viewModel(s)

        await vm.cargar()

        #expect(vm.conteosLaboratorio.map(\.cantidad) == [2, 1, 1])
    }

    @Test func ambulanciaYAvisoVienenDeLaApi() async {
        let s = Servicios()
        s.ambulancias.estadoResult = .success(AmbulanciaFixtures.ambulancia(.enMantenimiento))
        s.avisos.result = .success(Aviso(titulo: "Reunión", detalle: "Viernes 7:00 a. m."))
        let vm = viewModel(s)

        await vm.cargar()

        #expect(vm.resumen.ambulancia == .enMantenimiento)
        #expect(vm.resumen.aviso?.titulo == "Reunión")
    }

    @Test func sinAvisoVigenteNoHayAviso() async {
        let s = Servicios()
        let vm = viewModel(s)

        await vm.cargar()

        #expect(vm.resumen.aviso == nil)
    }

    @Test func siTodoFallaEnLaPrimeraCargaMuestraErrorYReintentaConExito() async {
        let s = Servicios()
        let fallo = APIError(statusCode: 500, code: "HTTP_500")
        s.turnos.result = .failure(fallo)
        s.citas.citasResult = .failure(fallo)
        s.laboratorio.ordenesResult = .failure(fallo)
        s.ambulancias.estadoResult = .failure(fallo)
        s.avisos.result = .failure(fallo)
        let vm = viewModel(s)

        await vm.cargar()
        #expect(vm.errorMessage == DoctorInicioViewModel.mensajeError)
        #expect(!vm.cargado)
        #expect(!vm.isLoading)

        s.turnos.result = .success([])
        s.citas.citasResult = .success([])
        s.laboratorio.ordenesResult = .success([])
        s.ambulancias.estadoResult = .success(AmbulanciaFixtures.ambulancia(.disponible))
        s.avisos.result = .success(nil)
        await vm.cargar()

        #expect(vm.errorMessage == nil)
        #expect(vm.cargado)
        #expect(vm.resumen.ambulancia == .disponible)
    }

    @Test func siFallaUnaSeccionLasDemasSeMuestran() async {
        let s = Servicios()
        s.ambulancias.estadoResult = .failure(APIError(statusCode: 500, code: "HTTP_500"))
        s.turnos.result = .success([turno(desde: -7200, hasta: 14400)])
        let vm = viewModel(s)

        await vm.cargar()

        #expect(vm.errorMessage == nil)
        #expect(vm.errorParcial == "No se pudieron cargar: ambulancia.")
        #expect(vm.resumen.turno != nil)
        #expect(vm.resumen.ambulancia == nil)
    }

    @Test func unaRecargaFallidaConservaLosDatos() async {
        let s = Servicios()
        s.ambulancias.estadoResult = .success(AmbulanciaFixtures.ambulancia(.disponible))
        let vm = viewModel(s)
        await vm.cargar()

        let fallo = APIError(statusCode: 500, code: "HTTP_500")
        s.turnos.result = .failure(fallo)
        s.citas.citasResult = .failure(fallo)
        s.laboratorio.ordenesResult = .failure(fallo)
        s.ambulancias.estadoResult = .failure(fallo)
        s.avisos.result = .failure(fallo)
        await vm.cargar()

        #expect(vm.errorMessage == nil)
        #expect(vm.resumen.ambulancia == .disponible)
        #expect(vm.errorParcial != nil)
    }
}
