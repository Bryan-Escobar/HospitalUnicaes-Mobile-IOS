import Foundation
import Observation

/// iOS-D2. Pide solo el día seleccionado, en hora de El Salvador.
@MainActor
@Observable
final class AgendaViewModel {
    private let citasService: any CitasService
    private let hoy: () -> Date
    private var carga = UUID()

    private(set) var diaSeleccionado: Date
    private(set) var citas: [Cita] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    init(citasService: any CitasService, hoy: @escaping () -> Date = Date.init) {
        self.citasService = citasService
        self.hoy = hoy
        diaSeleccionado = Formatting.startOfDay(hoy())
    }

    var semana: [Date] { Formatting.semana(conteniendo: diaSeleccionado) }
    var estaVacio: Bool { !isLoading && errorMessage == nil && citas.isEmpty }
    var encabezado: String { Formatting.encabezadoAgenda(diaSeleccionado, cantidad: citas.count) }

    func seleccionar(_ fecha: Date) {
        let dia = Formatting.startOfDay(fecha)
        guard !Formatting.esMismoDia(dia, diaSeleccionado) else { return }
        diaSeleccionado = dia
        citas = []
        errorMessage = nil
        isLoading = true
    }

    func irAHoy() { seleccionar(hoy()) }
    func semanaAnterior() { seleccionar(Formatting.sumarDias(-7, a: diaSeleccionado)) }
    func semanaSiguiente() { seleccionar(Formatting.sumarDias(7, a: diaSeleccionado)) }

    func recargar() async { await cargar() }

    func cargar() async {
        let dia = diaSeleccionado
        let token = UUID()
        carga = token
        if citas.isEmpty { isLoading = true }
        errorMessage = nil
        let rango = Formatting.rangoDelDia(dia)
        do {
            let resultado = try await citasService.citas(desde: rango.desde, hasta: rango.hasta)
            guard carga == token, Formatting.esMismoDia(diaSeleccionado, dia) else { return }
            citas = resultado.sorted { $0.fechaHora < $1.fechaHora }
            isLoading = false
        } catch {
            guard carga == token else { return }
            errorMessage = "No se pudo cargar la agenda."
            isLoading = false
        }
    }
}
