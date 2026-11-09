import Foundation
import Testing
@testable import HospitalUnicaes

/// iOS-P10/P11 (HUNI-73): carga, formulario, envío y tiempo real.
@MainActor
struct AmbulanciaPacienteViewModelTests {
    let api = FakeAmbulanciaService()
    let realtime = FakeAmbulanciaRealtime()
    let gps = FakeUbicacionService()

    private func viewModel(intervalo: Duration = .seconds(15)) -> AmbulanciaPacienteViewModel {
        AmbulanciaPacienteViewModel(ambulancias: api, realtime: realtime, ubicacion: gps, intervaloRespaldo: intervalo)
    }

    @Test func conSolicitudAbiertaAbreElSeguimiento() async {
        api.ultimaResult = .success(AmbulanciaFixtures.solicitud(.despachada))
        let vm = viewModel()
        await vm.recargar()
        #expect(vm.solicitud?.estado == .despachada)
    }

    @Test(arguments: [EstadoSolicitudAmbulancia.finalizada, .cancelada])
    func conLaUltimaCerradaAbreElFormulario(_ estado: EstadoSolicitudAmbulancia) async {
        api.ultimaResult = .success(AmbulanciaFixtures.solicitud(estado))
        let vm = viewModel()
        await vm.recargar()
        #expect(vm.pantalla == .formulario)
    }

    @Test func sinSolicitudesAbreElFormulario() async {
        let vm = viewModel()
        await vm.recargar()
        #expect(vm.pantalla == .formulario)
        #expect(vm.disponible)
    }

    @Test func confirmarPideTipoYUbicacion() async {
        let vm = viewModel()
        await vm.recargar()
        #expect(!vm.puedeConfirmar)
        #expect(vm.ayuda == "Elige el tipo de emergencia.")

        vm.tipo = .cardiaca
        #expect(vm.ayuda == "Escribe la dirección o usa tu ubicación.")
        vm.direccion = "  Av"
        #expect(!vm.puedeConfirmar)
        vm.direccion = "Calle Arce 12"
        #expect(vm.puedeConfirmar)
        #expect(vm.ayuda == nil)
    }

    @Test(arguments: [EstadoAmbulancia.enServicio, .enMantenimiento])
    func noDisponibleNoSePuedeConfirmar(_ estado: EstadoAmbulancia) async {
        api.estadoResult = .success(AmbulanciaFixtures.ambulancia(estado))
        let vm = viewModel()
        await vm.recargar()
        vm.tipo = .accidente
        vm.direccion = "Calle Arce 12"
        #expect(!vm.puedeConfirmar)
        #expect(vm.ayuda == nil)
    }

    @Test func gpsListoVaEnElCuerpoConLaDireccionDelGeocoder() async throws {
        let vm = viewModel()
        await vm.recargar()
        vm.tipo = .cardiaca
        await vm.alternarUbicacion()

        let cuerpo = try #require(vm.cuerpoSolicitud)
        #expect(cuerpo.latitud == 13.6929)
        #expect(cuerpo.longitud == -89.2182)
        #expect(cuerpo.precisionM == 20)
        #expect(cuerpo.direccionOrigen == "Col. Escalón, San Salvador")

        vm.direccion = " Pasaje 3, casa 5 "
        vm.descripcion = "  "
        let conEscrita = try #require(vm.cuerpoSolicitud)
        #expect(conEscrita.direccionOrigen == "Pasaje 3, casa 5")
        #expect(conEscrita.latitud == 13.6929)
        #expect(conEscrita.descripcionEmergencia == nil)
    }

    @Test func permisoDenegadoDesmarcaElGPS() async {
        gps.result = .failure(UbicacionError.permisoDenegado)
        let vm = viewModel()
        await vm.alternarUbicacion()
        #expect(vm.gps == .sinPermiso)
        #expect(!vm.usarGPS)
    }

    @Test func solicitarPasaAlSeguimientoUnaSolaVez() async {
        api.demoraSolicitar = .milliseconds(50)
        let vm = viewModel()
        await vm.recargar()
        vm.tipo = .accidente
        vm.direccion = "Calle Arce 12"

        async let primero: Void = vm.solicitar()
        async let segundo: Void = vm.solicitar()
        _ = await (primero, segundo)

        #expect(api.enviadas.count == 1)
        #expect(api.enviadas.first?.tipoEmergencia == .accidente)
        #expect(vm.solicitud?.estado == .pendiente)
    }

    @Test func limiteDeSolicitudesMuestraLaAbierta() async {
        let vm = viewModel()
        await vm.recargar()
        api.solicitarResult = .failure(APIError(statusCode: 429, code: "LIMITE_SOLICITUDES"))
        api.ultimaResult = .success(AmbulanciaFixtures.solicitud(.despachada))
        vm.tipo = .accidente
        vm.direccion = "Calle Arce 12"

        await vm.solicitar()
        #expect(vm.solicitud?.estado == .despachada)
        #expect(vm.errorEnvio == nil)
    }

    @Test func errorGenericoSeQuedaEnElFormulario() async {
        let vm = viewModel()
        await vm.recargar()
        api.solicitarResult = .failure(APIError(statusCode: 400, code: "VALIDACION"))
        vm.tipo = .accidente
        vm.direccion = "Calle Arce 12"

        await vm.solicitar()
        #expect(vm.pantalla == .formulario)
        #expect(vm.errorEnvio == "Revisa los datos del formulario.")
        #expect(vm.direccion == "Calle Arce 12")
    }

    @Test func errorAlCargarElEstadoDeshabilitaElFormulario() async {
        api.estadoResult = .failure(URLError(.notConnectedToInternet))
        let vm = viewModel()
        await vm.recargar()
        #expect(vm.errorCarga == AmbulanciaPacienteViewModel.errorEstado)
        #expect(vm.estadoAmbulancia == nil)
        #expect(!vm.puedeConfirmar)
    }

    @Test func eventoDeAmbulanciaHabilitaElFormulario() async {
        api.estadoResult = .success(AmbulanciaFixtures.ambulancia(.enServicio))
        let vm = viewModel()
        let tarea = Task { await vm.iniciar() }
        defer { tarea.cancel() }
        await esperar { realtime.suscrito && vm.estadoAmbulancia == .enServicio }

        api.estadoResult = .success(AmbulanciaFixtures.ambulancia(.disponible))
        realtime.enviar(.ambulanciaCambio)
        await esperar { vm.disponible }
        #expect(vm.disponible)
    }

    @Test func eventoDeSolicitudActualizaElSeguimiento() async {
        api.ultimaResult = .success(AmbulanciaFixtures.solicitud(.pendiente))
        let vm = viewModel()
        let tarea = Task { await vm.iniciar() }
        defer { tarea.cancel() }
        await esperar { realtime.suscrito && vm.solicitud != nil }
        #expect(vm.solicitud?.estado == .pendiente)

        api.solicitudResult = .success(
            AmbulanciaFixtures.solicitud(.despachada, despacho: AmbulanciaFixtures.enviada.addingTimeInterval(120))
        )
        realtime.enviar(.solicitudCambio(AmbulanciaFixtures.solicitudId))
        await esperar { vm.solicitud?.estado == .despachada }
        #expect(vm.solicitud?.estado == .despachada)
        #expect(api.idsSolicitud.contains(AmbulanciaFixtures.solicitudId))
    }

    @Test func respaldoRecargaMientrasNoHayConexion() async {
        let vm = viewModel(intervalo: .milliseconds(20))
        let tarea = Task { await vm.iniciar() }
        defer { tarea.cancel() }
        await esperar { realtime.suscrito && api.llamadasEstado == 1 }

        realtime.enviar(.conexion(.reconnecting))
        await esperar { api.llamadasEstado >= 3 }
        #expect(vm.conexion == .reconnecting)
        #expect(api.llamadasEstado >= 3)

        realtime.enviar(.conexion(.live))
        await esperar { vm.conexion == .live }
        try? await Task.sleep(for: .milliseconds(50))
        let despuesDeVolver = api.llamadasEstado
        try? await Task.sleep(for: .milliseconds(100))
        #expect(api.llamadasEstado == despuesDeVolver)
    }

    @Test func solicitarOtraLimpiaElFormulario() async {
        api.ultimaResult = .success(AmbulanciaFixtures.solicitud(.despachada))
        let vm = viewModel()
        await vm.recargar()
        vm.solicitarOtra()
        #expect(vm.pantalla == .formulario)
        #expect(vm.tipo == nil)
        #expect(vm.direccion.isEmpty)
    }
}
