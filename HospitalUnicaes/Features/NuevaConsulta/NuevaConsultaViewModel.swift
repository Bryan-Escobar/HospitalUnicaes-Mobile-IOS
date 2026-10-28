import Foundation
import Observation

/// iOS-D7. Guarda paso a paso y, si falla, el reintento continúa sin repetir lo ya enviado.
@MainActor
@Observable
final class NuevaConsultaViewModel {
    let contexto: NuevaConsultaContexto
    private let consultas: any ConsultasService
    let laboratorio: any LaboratorioService

    var diagnostico = ""
    var notas = ""
    private(set) var recetas: [RecetaBorrador] = []
    private(set) var ordenes: [OrdenBorrador] = []
    private(set) var isSaving = false
    private(set) var errorMessage: String?
    private(set) var guardada = false
    private(set) var erroresDeCampo: [String: String] = [:]
    private var diagnosticoIntentado = false
    private var guardadoBloqueado = false
    private var consultaId: UUID?
    private var diagnosticoEnviado = false

    init(
        contexto: NuevaConsultaContexto,
        consultas: any ConsultasService,
        laboratorio: any LaboratorioService
    ) {
        self.contexto = contexto
        self.consultas = consultas
        self.laboratorio = laboratorio
    }

    var canSave: Bool {
        !diagnostico.trimmed.isEmpty && !isSaving && !guardadoBloqueado
    }

    var tieneAvanceParcial: Bool { consultaId != nil && !guardada }
    var notasBloqueadas: Bool { consultaId != nil }
    var diagnosticoBloqueado: Bool { diagnosticoEnviado }
    var debeConfirmarSalida: Bool { isSaving || tieneDatosEscritos || consultaId != nil }

    var diagnosticoError: String? {
        if diagnosticoIntentado && diagnostico.trimmed.isEmpty {
            return "El diagnóstico es obligatorio"
        }
        return erroresDeCampo["descripcion"]
    }

    var notasError: String? { erroresDeCampo["notas"] }

    var tieneDatosEscritos: Bool {
        !diagnostico.trimmed.isEmpty || !notas.trimmed.isEmpty || !recetas.isEmpty || !ordenes.isEmpty
    }

    var examenesYaAgregados: Set<UUID> { Set(ordenes.map(\.examen.id)) }

    func diagnosticoPerdioFoco() {
        diagnosticoIntentado = true
    }

    func prepararSalida() -> SalidaConsulta {
        if consultaId != nil { return .parcial }
        if tieneDatosEscritos { return .descartar }
        return .cerrar
    }

    func agregarReceta(_ receta: RecetaBorrador) { recetas.append(receta) }

    func quitarReceta(id: UUID) {
        guard let index = recetas.firstIndex(where: { $0.id == id }), !recetas[index].enviada else { return }
        recetas.remove(at: index)
    }

    func agregarOrden(_ orden: OrdenBorrador) {
        guard !ordenes.contains(where: { $0.examen.id == orden.examen.id }) else { return }
        ordenes.append(orden)
    }

    func quitarOrden(id: UUID) {
        guard let index = ordenes.firstIndex(where: { $0.id == id }), !ordenes[index].enviada else { return }
        ordenes.remove(at: index)
    }

    func guardar() async {
        guard !isSaving else { return }
        diagnosticoIntentado = true
        guard canSave else { return }
        isSaving = true
        errorMessage = nil
        erroresDeCampo = [:]
        defer { isSaving = false }
        do {
            try await crearSiHaceFalta()
            try await diagnosticarSiHaceFalta()
            try await enviarRecetasPendientes()
            try await enviarOrdenesPendientes()
            try await cerrarSiHaceFalta()
            guardada = true
        } catch {
            errorMessage = Self.mensaje(de: error)
            erroresDeCampo = Self.campos(de: error)
            if consultaId == nil { guardadoBloqueado = Self.esTerminal(error) }
        }
    }

    private func crearSiHaceFalta() async throws {
        guard consultaId == nil else { return }
        let creada = try await consultas.crearConsulta(CrearConsultaRequest(
            pacienteId: contexto.pacienteId,
            citaId: contexto.citaId,
            motivoConsulta: contexto.motivo?.nilIfBlank,
            notas: notas.nilIfBlank
        ))
        consultaId = creada.id
    }

    private func diagnosticarSiHaceFalta() async throws {
        guard !diagnosticoEnviado, let consultaId else { return }
        _ = try await consultas.agregarDiagnostico(
            consultaId: consultaId,
            CrearDiagnosticoRequest(descripcion: diagnostico.trimmed)
        )
        diagnosticoEnviado = true
    }

    private func enviarRecetasPendientes() async throws {
        guard let consultaId else { return }
        for index in recetas.indices where !recetas[index].enviada {
            let receta = recetas[index]
            _ = try await consultas.emitirReceta(consultaId: consultaId, CrearRecetaRequest(
                indicaciones: receta.indicaciones.nilIfBlank,
                detalles: [detalle(de: receta)]
            ))
            recetas[index].enviada = true
        }
    }

    private func enviarOrdenesPendientes() async throws {
        guard let consultaId else { return }
        for index in ordenes.indices where !ordenes[index].enviada {
            let orden = ordenes[index]
            _ = try await laboratorio.crearOrden(CrearOrdenRequest(
                consultaId: consultaId,
                indicaciones: orden.indicaciones.nilIfBlank,
                examenIds: [orden.examen.id]
            ))
            ordenes[index].enviada = true
        }
    }

    private func cerrarSiHaceFalta() async throws {
        guard let consultaId else { return }
        do {
            _ = try await consultas.cerrarConsulta(id: consultaId)
        } catch let error as APIError where error.code == "CONSULTA_CERRADA" {
            return
        }
    }

    private func detalle(de receta: RecetaBorrador) -> CrearRecetaRequest.Detalle {
        CrearRecetaRequest.Detalle(
            medicamento: receta.medicamento,
            dosis: receta.dosis.nilIfBlank,
            frecuencia: receta.frecuencia.nilIfBlank,
            duracion: receta.duracion.nilIfBlank
        )
    }

    /// El texto global de `ACCESO_DENEGADO` habla de ver información; aquí se trata de registrar.
    private static func mensaje(de error: Error) -> String {
        if let api = error as? APIError, api.code == "ACCESO_DENEGADO" {
            return "No tienes permiso para registrar esta consulta."
        }
        return UserFacingError.message(for: error)
    }

    private static let terminales: Set<String> = ["REGISTRO_DUPLICADO", "TRANSICION_INVALIDA", "ACCESO_DENEGADO"]

    private static func esTerminal(_ error: Error) -> Bool {
        guard let api = error as? APIError else { return false }
        return terminales.contains(api.code)
    }

    private static func campos(de error: Error) -> [String: String] {
        guard let api = error as? APIError, api.code == "VALIDACION" else { return [:] }
        var mapa: [String: String] = [:]
        for campo in api.errors ?? [] where mapa[campo.field] == nil {
            mapa[campo.field] = campo.message
        }
        return mapa
    }
}
