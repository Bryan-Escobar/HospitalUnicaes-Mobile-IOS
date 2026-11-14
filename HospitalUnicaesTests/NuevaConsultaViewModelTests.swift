import Foundation
import Testing
@testable import HospitalUnicaes

@MainActor
struct NuevaConsultaViewModelTests {
    let consultas = FakeConsultasService()
    let laboratorio = FakeLaboratorioService()

    private func make(notas: String = "") -> NuevaConsultaViewModel {
        let viewModel = NuevaConsultaViewModel(
            contexto: NuevaConsultaContexto(
                pacienteId: UUID(), pacienteNombre: "Luis Martínez",
                citaId: UUID(), citaHora: "10:30", motivo: "Control de alergia", alergias: "Penicilina"
            ),
            consultas: consultas, laboratorio: laboratorio
        )
        viewModel.notas = notas
        return viewModel
    }

    @Test func canSaveExigeDiagnostico() {
        let viewModel = make()
        #expect(!viewModel.canSave)
        viewModel.diagnostico = "   "
        #expect(!viewModel.canSave)
        viewModel.diagnostico = "Rinitis"
        #expect(viewModel.canSave)
    }

    @Test func guardadoFelizRespetaElOrden() async {
        let viewModel = make()
        viewModel.diagnostico = "Rinitis alérgica"
        viewModel.agregarReceta(receta("Loratadina"))
        viewModel.agregarReceta(receta("Paracetamol"))
        viewModel.agregarOrden(orden())
        let sink = CallSink()
        consultas.sink = sink
        laboratorio.sink = sink
        await viewModel.guardar()
        #expect(sink.calls == [
            "crearConsulta", "agregarDiagnostico", "emitirReceta", "emitirReceta", "crearOrden", "cerrarConsulta",
        ])
        #expect(viewModel.guardada)
        #expect(consultas.consultas.first?.motivoConsulta == "Control de alergia")
        #expect(consultas.consultas.first?.citaId != nil)
        #expect(consultas.consultas.first?.notas == nil)
        #expect(consultas.recetas.allSatisfy { $0.detalles.count == 1 })
        #expect(laboratorio.ordenes.first?.examenIds.count == 1)
        #expect(laboratorio.ordenes.first?.prioridad == "normal")
    }

    @Test func reintentoNoRepiteLoEnviado() async {
        let viewModel = make()
        viewModel.diagnostico = "Rinitis"
        viewModel.agregarReceta(receta("Uno"))
        viewModel.agregarReceta(receta("Dos"))
        viewModel.agregarOrden(orden())
        consultas.failCall = ("emitirReceta", 2)
        await viewModel.guardar()
        #expect(viewModel.errorMessage != nil)
        #expect(viewModel.tieneAvanceParcial)
        consultas.failCall = nil
        await viewModel.guardar()
        #expect(consultas.calls.filter { $0 == "crearConsulta" }.count == 1)
        #expect(consultas.calls.filter { $0 == "agregarDiagnostico" }.count == 1)
        #expect(consultas.calls.filter { $0 == "emitirReceta" }.count == 3)
        #expect(viewModel.guardada)
    }

    @Test func cierreRepetidoCuentaComoExito() async {
        let viewModel = make()
        viewModel.diagnostico = "Rinitis"
        consultas.failCall = ("cerrarConsulta", 1)
        consultas.error = APIError(statusCode: 409, code: "CONSULTA_CERRADA")
        await viewModel.guardar()
        #expect(viewModel.guardada)
        #expect(viewModel.errorMessage == nil)
    }

    @Test func duplicadoBloqueaElGuardado() async {
        let viewModel = make()
        viewModel.diagnostico = "Rinitis"
        consultas.failCall = ("crearConsulta", 1)
        consultas.error = APIError(statusCode: 409, code: "REGISTRO_DUPLICADO")
        await viewModel.guardar()
        #expect(!viewModel.canSave)
        #expect(viewModel.errorMessage == "Esta cita ya tiene una consulta registrada.")
    }

    @Test func accesoDenegadoHablaDeRegistrar() async {
        let viewModel = make()
        viewModel.diagnostico = "Rinitis"
        consultas.failCall = ("crearConsulta", 1)
        consultas.error = APIError(statusCode: 403, code: "ACCESO_DENEGADO")
        await viewModel.guardar()
        #expect(viewModel.errorMessage == "No tienes permiso para registrar esta consulta.")
        #expect(!viewModel.canSave)
    }

    @Test func validacionMarcaElCampo() async {
        let viewModel = make()
        viewModel.diagnostico = "Rinitis"
        consultas.failCall = ("agregarDiagnostico", 1)
        consultas.error = APIError(
            statusCode: 400, code: "VALIDACION",
            errors: [APIError.FieldError(field: "descripcion", message: "Máximo 1000 caracteres")]
        )
        await viewModel.guardar()
        #expect(viewModel.errorMessage == "Revisa los datos del formulario.")
        #expect(viewModel.diagnosticoError == "Máximo 1000 caracteres")
    }

    @Test func recetaAgregadaDespuesDelFalloSeEnviaEnElReintento() async {
        let viewModel = make()
        viewModel.diagnostico = "Rinitis"
        viewModel.agregarReceta(receta("Uno"))
        consultas.failCall = ("emitirReceta", 1)
        await viewModel.guardar()
        #expect(viewModel.tieneAvanceParcial)
        consultas.failCall = nil
        viewModel.agregarReceta(receta("Dos"))
        await viewModel.guardar()
        #expect(consultas.recetas.map { $0.detalles[0].medicamento } == ["Uno", "Dos"])
        #expect(viewModel.guardada)
    }

    @Test func noQuitaUnaRecetaEnviada() async {
        let viewModel = make()
        viewModel.diagnostico = "Rinitis"
        viewModel.agregarReceta(receta("Uno"))
        consultas.failCall = ("cerrarConsulta", 1)
        await viewModel.guardar()
        let id = viewModel.recetas[0].id
        viewModel.quitarReceta(id: id)
        #expect(viewModel.recetas.count == 1)
        #expect(viewModel.recetas[0].enviada)
    }

    @Test func sinDiagnosticoNoGuardaYMarcaElCampo() async {
        let viewModel = make()
        viewModel.diagnostico = "  "

        await viewModel.guardar()

        #expect(consultas.calls.isEmpty)
        #expect(!viewModel.guardada)
        #expect(viewModel.diagnosticoError == "El diagnóstico es obligatorio")
    }

    @Test func errorDeRedNoBloqueaYElReintentoGuarda() async {
        let viewModel = make()
        viewModel.diagnostico = "Rinitis"
        consultas.failCall = ("crearConsulta", 1)
        consultas.error = URLError(.notConnectedToInternet)

        await viewModel.guardar()

        #expect(viewModel.errorMessage == "No hay conexión. Revisa tu internet e intenta de nuevo.")
        #expect(viewModel.canSave)
        #expect(!viewModel.isSaving)
        #expect(!viewModel.tieneAvanceParcial)

        await viewModel.guardar()

        #expect(viewModel.guardada)
        #expect(viewModel.errorMessage == nil)
    }

    @Test func lasNotasSeEnvianYSeBloqueanCuandoLaConsultaYaExiste() async {
        let viewModel = make(notas: "  Paciente con tos seca ")
        viewModel.diagnostico = "Rinitis"
        #expect(!viewModel.notasBloqueadas)
        consultas.failCall = ("agregarDiagnostico", 1)

        await viewModel.guardar()

        #expect(consultas.consultas.first?.notas == "Paciente con tos seca")
        #expect(viewModel.notasBloqueadas)
        #expect(!viewModel.diagnosticoBloqueado)
    }

    @Test func siFallaUnaOrdenElReintentoSoloEnviaLaFaltante() async {
        let viewModel = make()
        viewModel.diagnostico = "Rinitis"
        viewModel.agregarReceta(receta("Uno"))
        viewModel.agregarOrden(orden("Hemograma completo"))
        viewModel.agregarOrden(orden("Glucosa"))
        laboratorio.failCall = ("crearOrden", 2)

        await viewModel.guardar()

        #expect(viewModel.errorMessage != nil)
        #expect(viewModel.diagnosticoBloqueado)
        #expect(viewModel.tieneAvanceParcial)
        #expect(viewModel.ordenes.map(\.enviada) == [true, false])
        #expect(laboratorio.ordenes.count == 1)

        laboratorio.failCall = nil
        await viewModel.guardar()

        #expect(consultas.calls.filter { $0 == "crearConsulta" }.count == 1)
        #expect(consultas.calls.filter { $0 == "emitirReceta" }.count == 1)
        #expect(laboratorio.ordenes.count == 2)
        #expect(laboratorio.calls.filter { $0 == "crearOrden" }.count == 3)
        #expect(viewModel.ordenes.allSatisfy { $0.enviada })
        #expect(viewModel.guardada)
    }

    @Test func noAgregaDosVecesElMismoExamen() {
        let viewModel = make()
        let examen = ExamenCatalogo(id: UUID(), nombre: "Glucosa", categoria: nil, tipoMuestra: nil)

        viewModel.agregarOrden(OrdenBorrador(id: UUID(), examen: examen, indicaciones: ""))
        viewModel.agregarOrden(OrdenBorrador(id: UUID(), examen: examen, indicaciones: ""))

        #expect(viewModel.ordenes.count == 1)
        #expect(viewModel.examenesYaAgregados == [examen.id])
    }

    @Test func laSalidaDependeDelAvance() async {
        let viewModel = make()
        #expect(viewModel.prepararSalida() == .cerrar)
        #expect(!viewModel.debeConfirmarSalida)

        viewModel.diagnostico = "Rinitis"
        #expect(viewModel.prepararSalida() == .descartar)
        #expect(viewModel.debeConfirmarSalida)

        consultas.failCall = ("agregarDiagnostico", 1)
        await viewModel.guardar()
        #expect(viewModel.prepararSalida() == .parcial)
        #expect(viewModel.debeConfirmarSalida)
    }

    private func receta(_ nombre: String) -> RecetaBorrador {
        RecetaBorrador(
            id: UUID(), medicamento: nombre, dosis: "1 tableta", frecuencia: "Cada 24 h",
            duracion: "7 días", indicaciones: ""
        )
    }

    private func orden(_ nombre: String = "Hemograma completo") -> OrdenBorrador {
        OrdenBorrador(
            id: UUID(),
            examen: ExamenCatalogo(id: UUID(), nombre: nombre, categoria: nil, tipoMuestra: nil),
            indicaciones: ""
        )
    }
}
