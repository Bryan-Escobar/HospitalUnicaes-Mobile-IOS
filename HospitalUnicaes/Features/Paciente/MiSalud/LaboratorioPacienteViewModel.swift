import Foundation
import Observation

/// iOS-P7 Laboratorio: exámenes del propio paciente, al día por Supabase Realtime.
/// Los eventos no se decodifican: solo disparan una recarga por la API, que aplica la privacidad.
/// Si el canal no está `live`, recarga cada `intervaloRespaldo` hasta que vuelva.
@MainActor
@Observable
final class LaboratorioPacienteViewModel {
    enum Carga: Equatable {
        case cargando
        case listo
        /// Solo cuando nunca hubo datos; si falla una recarga se conservan los anteriores.
        case error(String)
    }

    static let mensajeError = "No se pudieron cargar tus exámenes."

    private(set) var estado: Carga = .cargando
    /// Una fila por examen, más recientes primero.
    private(set) var examenes: [ExamenLaboratorioPaciente] = []
    /// Chip de la barra: el estado del canal, o "Reconectando…" si la última recarga falló.
    var conexion: DSLiveIndicator.Status {
        recargaFallida && canal == .live ? .reconnecting : canal
    }
    /// Examen que pasó a Completado con la app abierta (banner "Actualizado ahora").
    private(set) var aviso: ExamenLaboratorioPaciente?

    private let service: any LaboratorioPacienteService
    private let realtime: any LaboratorioRealtimeService
    private let intervaloRespaldo: Duration
    private var canal: DSLiveIndicator.Status = .reconnecting
    private var recargaFallida = false
    private var escuchando = false
    private var cargoAlgunaVez = false
    private var recargando = false
    private var recargaPendiente = false
    private var respaldo: Task<Void, Never>?

    init(
        service: any LaboratorioPacienteService,
        realtime: any LaboratorioRealtimeService,
        intervaloRespaldo: Duration = .seconds(15)
    ) {
        self.service = service
        self.realtime = realtime
        self.intervaloRespaldo = intervaloRespaldo
    }

    /// "Actualizado ahora: tu prueba cutánea de alergias ya tiene resultado."
    var textoAviso: String? {
        guard let aviso else { return nil }
        let nombre = aviso.nombre.prefix(1).lowercased() + aviso.nombre.dropFirst()
        return "Actualizado ahora: tu \(nombre) ya tiene resultado."
    }

    /// La versión más nueva de un examen (iOS-P8 la lee para cambiar en vivo).
    func examen(id: UUID) -> ExamenLaboratorioPaciente? {
        examenes.first { $0.id == id }
    }

    /// Carga la lista y escucha el canal hasta que se cancele la `Task` (la vista lo llama
    /// con `.task` mientras Mi salud está visible y la app activa).
    func escuchar() async {
        escuchando = true
        defer {
            escuchando = false
            canal = .reconnecting
            ajustarRespaldo()
        }
        await recargar()
        for await evento in realtime.eventos() {
            switch evento {
            case .conexion(let estado):
                canal = estado
                ajustarRespaldo()
            case .examenCambio:
                await recargar()
            }
        }
    }

    /// Pull-to-refresh, eventos y respaldo. Si ya hay una recarga en curso, se hace solo una más al terminar.
    func recargar() async {
        if recargando {
            recargaPendiente = true
            return
        }
        recargando = true
        repeat {
            recargaPendiente = false
            await cargar()
        } while recargaPendiente
        recargando = false
    }

    func descartarAviso() {
        aviso = nil
    }

    // MARK: Privado

    private func cargar() async {
        do {
            let nuevos = try await service.misOrdenes().filasLaboratorio
            if cargoAlgunaVez {
                detectarCompletados(antes: examenes, ahora: nuevos)
            }
            examenes = nuevos
            cargoAlgunaVez = true
            recargaFallida = false
            estado = .listo
        } catch is CancellationError {
            return
        } catch {
            if cargoAlgunaVez {
                recargaFallida = true
            } else {
                estado = .error(Self.mensajeError)
            }
        }
        ajustarRespaldo()
    }

    private func detectarCompletados(antes: [ExamenLaboratorioPaciente], ahora: [ExamenLaboratorioPaciente]) {
        let estadosAnteriores = Dictionary(antes.map { ($0.id, $0.estado) }, uniquingKeysWith: { lhs, _ in lhs })
        let recienCompletados = ahora.filter { examen in
            examen.estado == .completado && estadosAnteriores[examen.id] != .completado
        }
        let masReciente = recienCompletados.max {
            ($0.fechaCompletado ?? .distantPast) < ($1.fechaCompletado ?? .distantPast)
        }
        if let masReciente {
            aviso = masReciente
        }
    }

    /// El respaldo corre solo mientras se escucha y la conexión no está "En vivo".
    private func ajustarRespaldo() {
        guard escuchando, conexion != .live else {
            respaldo?.cancel()
            respaldo = nil
            return
        }
        guard respaldo == nil else { return }
        let intervalo = intervaloRespaldo
        respaldo = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: intervalo)
                guard !Task.isCancelled else { return }
                await self?.recargar()
            }
        }
    }
}
