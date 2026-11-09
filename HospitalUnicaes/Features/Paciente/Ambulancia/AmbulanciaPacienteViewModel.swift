import Foundation
import Observation

/// iOS-P10 Solicitar ambulancia e iOS-P11 Seguimiento (HUNI-73).
///
/// Los datos siempre vienen de la API; Supabase Realtime solo avisa cuándo recargar
/// (así la API decide qué ve el paciente). Si el canal no está en vivo, recarga cada
/// `intervaloRespaldo`. La regla de despacho vive en la API: bloquear el formulario cuando
/// la ambulancia no está disponible es solo UX.
@MainActor
@Observable
final class AmbulanciaPacienteViewModel {
    enum Pantalla: Equatable {
        case cargando
        case formulario
        case seguimiento(SolicitudAmbulancia)
        /// Se esperaba una solicitud abierta y la API no devolvió ninguna.
        case vacio
    }

    enum EstadoGPS: Equatable {
        case inactivo
        case buscando
        case listo(Ubicacion)
        case sinPermiso
        case error(String)
    }

    static let errorEstado = "No se pudo cargar el estado de la ambulancia."
    static let errorSeguimiento = "No se pudo cargar el estado de tu solicitud."

    private(set) var pantalla: Pantalla = .cargando
    private(set) var estadoAmbulancia: EstadoAmbulancia?
    private(set) var conexion: DSLiveIndicator.Status = .reconnecting
    /// Falló `GET /ambulancia` y no se conoce el estado: el formulario queda deshabilitado.
    private(set) var errorCarga: String?
    /// Falló la recarga de la solicitud en P11; se sigue mostrando la última conocida.
    private(set) var errorRecarga: String?

    var tipo: TipoEmergencia?
    var descripcion = ""
    var direccion = ""
    private(set) var usarGPS = false
    private(set) var gps: EstadoGPS = .inactivo

    private(set) var enviando = false
    private(set) var errorEnvio: String?
    var mostrarConfirmacion = false

    private let ambulancias: any AmbulanciaService
    private let realtime: any AmbulanciaRealtimeService
    private let ubicacion: any UbicacionService
    private let intervaloRespaldo: Duration
    private var respaldo: Task<Void, Never>?
    private var recargando = false
    private var recargaPendiente = false

    init(
        ambulancias: any AmbulanciaService,
        realtime: any AmbulanciaRealtimeService,
        ubicacion: any UbicacionService,
        intervaloRespaldo: Duration = .seconds(15)
    ) {
        self.ambulancias = ambulancias
        self.realtime = realtime
        self.ubicacion = ubicacion
        self.intervaloRespaldo = intervaloRespaldo
    }

    // MARK: Derivados

    var disponible: Bool { estadoAmbulancia == .disponible }

    var solicitud: SolicitudAmbulancia? {
        if case let .seguimiento(solicitud) = pantalla { return solicitud }
        return nil
    }

    private var lecturaGPS: Ubicacion? {
        guard usarGPS, case let .listo(lectura) = gps else { return nil }
        return lectura
    }

    private var direccionEscrita: String? {
        guard let texto = direccion.nilIfBlank, texto.count >= 3 else { return nil }
        return texto
    }

    var tieneUbicacion: Bool { lecturaGPS != nil || direccionEscrita != nil }

    var puedeConfirmar: Bool {
        disponible && tipo != nil && tieneUbicacion && !enviando
    }

    /// Motivo por el que "Confirmar" está deshabilitado (la variante no disponible se explica sola).
    var ayuda: String? {
        guard disponible else { return nil }
        if tipo == nil { return "Elige el tipo de emergencia." }
        if !tieneUbicacion { return "Escribe la dirección o usa tu ubicación." }
        return nil
    }

    /// Cuerpo del POST. La dirección escrita gana sobre la del geocoder; las coordenadas van si hay GPS.
    var cuerpoSolicitud: NuevaSolicitudAmbulancia? {
        guard let tipo, tieneUbicacion else { return nil }
        var cuerpo = NuevaSolicitudAmbulancia(tipoEmergencia: tipo)
        if let lectura = lecturaGPS {
            cuerpo.latitud = lectura.latitud
            cuerpo.longitud = lectura.longitud
            cuerpo.precisionM = lectura.precisionM
            cuerpo.direccionOrigen = lectura.direccion.flatMap { $0.count >= 3 ? $0 : nil }
        }
        if let escrita = direccionEscrita {
            cuerpo.direccionOrigen = String(escrita.prefix(300))
        }
        cuerpo.descripcionEmergencia = descripcion.nilIfBlank.map { String($0.prefix(2000)) }
        return cuerpo
    }

    // MARK: Ciclo de vida

    /// Desde `.task` de la vista: carga y queda escuchando Realtime hasta que la vista desaparece.
    func iniciar() async {
        await recargar()
        for await evento in realtime.eventos() {
            manejar(evento)
        }
        detenerRespaldo()
        // El canal terminó sin que la vista desaparezca (sin cliente): respaldo en esta misma Task.
        guard !Task.isCancelled else { return }
        conexion = .offline
        while !Task.isCancelled {
            do {
                try await Task.sleep(for: intervaloRespaldo)
            } catch {
                return
            }
            await recargar()
        }
    }

    func manejar(_ evento: EventoAmbulancia) {
        switch evento {
        case let .conexion(estado):
            conexion = estado
            if estado == .live {
                detenerRespaldo()
                // Lo que cambió mientras el canal estaba caído.
                Task { await recargar() }
            } else {
                iniciarRespaldo()
            }
        case .ambulanciaCambio, .solicitudCambio:
            Task { await recargar() }
        }
    }

    /// Pull-to-refresh, volver a primer plano y eventos. Si ya hay una recarga en curso,
    /// deja una pendiente en lugar de lanzar otra.
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

    private func cargar() async {
        let actual = solicitud
        async let ambulancia = intentar { try await self.ambulancias.estado() }
        async let solicitud = intentar { () -> SolicitudAmbulancia? in
            if let actual { return try await self.ambulancias.solicitud(id: actual.id) }
            return try await self.ambulancias.ultimaSolicitud()
        }
        aplicar(ambulancia: await ambulancia)
        aplicar(solicitud: await solicitud, actual: actual)
    }

    private func aplicar(ambulancia: Result<Ambulancia, Error>) {
        switch ambulancia {
        case let .success(ambulancia):
            estadoAmbulancia = ambulancia.estado
            errorCarga = nil
        case .failure:
            if estadoAmbulancia == nil { errorCarga = Self.errorEstado }
        }
    }

    private func aplicar(solicitud resultado: Result<SolicitudAmbulancia?, Error>, actual: SolicitudAmbulancia?) {
        // El paciente pudo cambiar de pantalla mientras cargaba.
        guard actual == solicitud else { return }
        switch resultado {
        case let .success(nueva?) where actual != nil || nueva.estado.estaAbierta:
            pantalla = .seguimiento(nueva)
            errorRecarga = nil
        case .success:
            if pantalla == .cargando { pantalla = .formulario }
        case .failure:
            if actual != nil { errorRecarga = Self.errorSeguimiento }
            if pantalla == .cargando { pantalla = .formulario }
        }
    }

    private func intentar<T>(_ operacion: () async throws -> T) async -> Result<T, Error> {
        do {
            return .success(try await operacion())
        } catch {
            return .failure(error)
        }
    }

    private func iniciarRespaldo() {
        guard respaldo == nil else { return }
        let intervalo = intervaloRespaldo
        respaldo = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: intervalo)
                } catch {
                    return
                }
                await self?.recargar()
            }
        }
    }

    private func detenerRespaldo() {
        respaldo?.cancel()
        respaldo = nil
    }

    // MARK: Formulario

    func alternarUbicacion() async {
        if usarGPS {
            usarGPS = false
            return
        }
        usarGPS = true
        gps = .buscando
        do {
            gps = .listo(try await ubicacion.ubicacionActual())
        } catch UbicacionError.permisoDenegado {
            gps = .sinPermiso
            usarGPS = false
        } catch {
            gps = .error("No se pudo obtener tu ubicación · Escribe la dirección")
            usarGPS = false
        }
    }

    func pedirConfirmacion() {
        guard puedeConfirmar else { return }
        mostrarConfirmacion = true
    }

    func solicitar() async {
        guard !enviando, puedeConfirmar, let cuerpo = cuerpoSolicitud else { return }
        enviando = true
        errorEnvio = nil
        defer { enviando = false }
        do {
            pantalla = .seguimiento(try await ambulancias.solicitar(cuerpo))
        } catch let error as APIError where error.code == "LIMITE_SOLICITUDES" {
            // Ya había una abierta (p. ej. desde otro dispositivo): se muestra esa.
            if let abierta = try? await ambulancias.ultimaSolicitud(), abierta.estado.estaAbierta {
                pantalla = .seguimiento(abierta)
            } else {
                pantalla = .vacio
            }
        } catch {
            errorEnvio = UserFacingError.message(for: error)
        }
    }

    /// Desde P11 terminal o vacío: vuelve a P10 con el formulario limpio.
    func solicitarOtra() {
        tipo = nil
        descripcion = ""
        direccion = ""
        usarGPS = false
        gps = .inactivo
        errorEnvio = nil
        errorRecarga = nil
        pantalla = .formulario
    }
}
