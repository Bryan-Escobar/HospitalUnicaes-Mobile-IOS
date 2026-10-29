import Foundation
import Testing
@testable import HospitalUnicaes

/// ViewModels de las pestañas principales (HUNI-42), con datos de ejemplo.
@MainActor
struct NavegacionPrincipalTests {
    /// Miércoles 21 oct 2026, 10:00 en El Salvador.
    let hoy = Date(timeIntervalSince1970: 1_792_598_400)

    @Test func inicioDoctorSaludaPorNombreYMuestraConteos() {
        let viewModel = DoctorInicioViewModel(me: .fixture(rol: .doctor), hoy: hoy)

        #expect(viewModel.saludo == "Hola, Ana")
        #expect(viewModel.fecha == "Miércoles 21 de octubre")
        #expect(viewModel.conteosLaboratorio.map(\.cantidad) == [2, 1, 4])
    }

    @Test func turnosMarcanHoyEnCursoYDiasPasadosTerminados() {
        let viewModel = TurnosViewModel(hoy: hoy)

        #expect(viewModel.turnos.count == 7)
        #expect(viewModel.turnoDeHoy.map { Formatting.esMismoDia($0.dia, hoy) } == true)
        #expect(viewModel.turnos.map(\.estado) == [.terminado, .sinTurno, .enCurso, .programado, .programado, .sinTurno, .sinTurno])
        #expect(!viewModel.restantes.contains { $0.estado == .enCurso })
    }

    @Test func semanaSiguienteNoTieneTurnoEnCurso() {
        let viewModel = TurnosViewModel(hoy: hoy)
        viewModel.semana = .siguiente

        #expect(viewModel.turnoDeHoy == nil)
        #expect(viewModel.turnos.allSatisfy { $0.estado == .programado || $0.estado == .sinTurno })
        #expect(viewModel.turnos.first.map { Formatting.esMismoDia($0.dia, Formatting.sumarDias(5, a: hoy)) } == true)
    }

    @Test func inicioPacienteTomaLaCitaProgramadaMasCercana() throws {
        let viewModel = PacienteInicioViewModel(me: .fixture(rol: .paciente), hoy: hoy)

        let cita = try #require(viewModel.proximaCita)
        #expect(cita.fecha > hoy)
        #expect(cita.doctor == "Dra. Ana Rivas")
        #expect(viewModel.ultimosResultados.count == 2)
        #expect(viewModel.puedeSolicitarAmbulancia)
    }

    @Test func citasSeparanProximasDePasadas() {
        let viewModel = CitasPacienteViewModel(hoy: hoy)

        #expect(viewModel.visibles.allSatisfy { $0.fecha >= hoy })
        viewModel.segmento = .pasadas
        #expect(viewModel.visibles.allSatisfy { $0.fecha < hoy })
        #expect(viewModel.visibles.map(\.estado) == [.atendida, .cancelada])
    }

    @Test func solicitudDeCitaPideMotivoYSeAgregaArriba() throws {
        let formulario = SolicitarCitaViewModel(hoy: hoy)
        #expect(formulario.enviar() == nil)
        #expect(formulario.motivoError != nil)

        formulario.motivo = "  Dolor de garganta "
        formulario.franja = "Mañana"
        let solicitud = try #require(formulario.enviar())
        #expect(solicitud.motivo == "Dolor de garganta")
        #expect(solicitud.preferencia.hasSuffix("por la mañana"))

        let citas = CitasPacienteViewModel(hoy: hoy)
        citas.segmento = .pasadas
        citas.agregar(solicitud)
        #expect(citas.solicitudes.first == solicitud)
        #expect(citas.segmento == .proximas)
    }

    @Test func ambulanciaSoloSeConfirmaDisponibleConTipoYUbicacion() {
        let viewModel = AmbulanciaPacienteViewModel(ahora: { hoy })
        #expect(!viewModel.puedeConfirmar)

        viewModel.tipo = "Dolor de pecho"
        viewModel.usarUbicacion = false
        #expect(!viewModel.puedeConfirmar)
        viewModel.direccion = "Calle 1, casa 2"
        #expect(viewModel.puedeConfirmar)

        viewModel.confirmar()
        #expect(viewModel.solicitud?.estado == .enviada)
        #expect(viewModel.solicitud?.ubicacion == "Calle 1, casa 2")
        #expect(!viewModel.puedeConfirmar)

        viewModel.nuevaSolicitud()
        #expect(viewModel.solicitud == nil)
        #expect(viewModel.tipo == nil)
    }

    @Test func ambulanciaEnServicioNoSePuedeSolicitar() {
        let viewModel = AmbulanciaPacienteViewModel(estado: .enServicio)
        viewModel.tipo = "Accidente"

        #expect(!viewModel.puedeConfirmar)
        #expect(viewModel.ayuda == "La ambulancia no está disponible en este momento.")
    }

    @Test func miSaludAvisaCuandoHayResultadoListo() {
        let viewModel = MiSaludViewModel(hoy: hoy)

        #expect(viewModel.segmento == .historial)
        #expect(viewModel.consultas.map(\.fecha) == viewModel.consultas.map(\.fecha).sorted(by: >))
        #expect(viewModel.avisoLaboratorio != nil)
        #expect(viewModel.habitacion?.codigo == "HAB-204")
    }

    @Test func ocupacionPublicaEsSoloAgregada() {
        let viewModel = InformacionPublicaViewModel()

        #expect(viewModel.ocupacion.map(\.resumen) == ["3/5 ocupadas", "9/12 camas"])
        #expect(viewModel.ocupacion.allSatisfy { $0.progreso <= 1 })
    }
}
