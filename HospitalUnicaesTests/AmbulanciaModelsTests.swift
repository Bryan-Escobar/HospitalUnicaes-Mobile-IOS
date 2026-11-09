import Foundation
import Testing
@testable import HospitalUnicaes

struct AmbulanciaModelsTests {
    @Test func ambulanciaConYSinSolicitudActiva() throws {
        let libre = try decode(Ambulancia.self, ambulanciaJSON(estado: "disponible", activa: "null", fecha: "2026-11-09T16:12:00Z"))
        #expect(libre.estado == .disponible)
        #expect(libre.solicitudActiva == nil)

        let activa = """
        { "id": "\(id)", "prioridad": "urgente", "estado": "despachada", "tipo_emergencia": "cardiaca",
          "direccion_origen": null, "latitud": 13.69, "longitud": -89.21, "fecha_despacho": "2026-11-09T16:14:00.123Z" }
        """
        let ocupada = try decode(Ambulancia.self, ambulanciaJSON(estado: "en_servicio", activa: activa, fecha: "2026-11-09T16:12:00.500Z"))
        #expect(ocupada.estado == .enServicio)
        #expect(ocupada.solicitudActiva?.estado == .despachada)
        #expect(ocupada.solicitudActiva?.fechaDespacho != nil)
    }

    @Test func estadosDesconocidosNoRompenLaPantalla() throws {
        let ambulancia = try decode(Ambulancia.self, ambulanciaJSON(estado: "en_taller", activa: "null", fecha: "2026-11-09T16:12:00Z"))
        #expect(ambulancia.estado == .enServicio)
        let estado = try decode(EstadoSolicitudAmbulancia.self, "\"reasignada\"")
        #expect(estado == .pendiente)
    }

    @Test(arguments: ["pendiente", "despachada", "en_curso", "finalizada", "cancelada"])
    func solicitudDeCadaEstado(_ estado: String) throws {
        let solicitud = try decode(SolicitudAmbulancia.self, solicitudJSON(estado: estado))
        #expect(solicitud.estado.rawValue == estado)
        #expect(solicitud.tipoEmergencia == .cardiaca)
        #expect(solicitud.precisionM == 20)
        #expect(Formatting.hora(solicitud.fechaSolicitud) == "10:12")
    }

    @Test func paginaDeSolicitudes() throws {
        let json = """
        { "items": [\(solicitudJSON(estado: "finalizada"))],
          "paginacion": { "pagina": 1, "por_pagina": 1, "total": 3, "total_paginas": 3 } }
        """
        let pagina = try decode(Pagina<SolicitudAmbulancia>.self, json)
        #expect(pagina.items.first?.estado == .finalizada)
        #expect(pagina.paginacion.total == 3)
    }

    @Test func cuerpoEnSnakeCaseSinNulos() throws {
        let cuerpo = NuevaSolicitudAmbulancia(
            latitud: 13.6929, longitud: -89.2182, precisionM: 20, tipoEmergencia: .cardiaca
        )
        let data = try APIClient.encoder.encode(cuerpo)
        let objeto = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])

        #expect(objeto["tipo_emergencia"] as? String == "cardiaca")
        #expect(objeto["precision_m"] as? Int == 20)
        #expect(objeto["latitud"] as? Double == 13.6929)
        #expect(objeto["direccion_origen"] == nil)
        #expect(objeto["descripcion_emergencia"] == nil)
        #expect(!String(decoding: data, as: UTF8.self).contains("null"))
    }

    @Test func presentacionDeLaLineaDeTiempo() {
        let base = AmbulanciaFixtures.enviada
        let cancelada = AmbulanciaFixtures.solicitud(.cancelada, cierre: base.addingTimeInterval(600), motivo: "Duplicada")
        #expect(cancelada.pasos.map(\.titulo) == ["Enviada", "Despachada (En Servicio)", "Rechazada"])
        #expect(cancelada.pasos[1].detalle == "No aplica")
        #expect(cancelada.subtitulo == "Motivo: Duplicada")

        let despachada = AmbulanciaFixtures.solicitud(.despachada, despacho: base.addingTimeInterval(120))
        #expect(despachada.pasos.map(\.detalle) == ["10:12 · Dolor de pecho", "10:14 · por recepción", "Aún no"])
        #expect(despachada.pasos.map(\.hecho) == [true, true, false])
        #expect(despachada.estado.status.title == "Despachada · En Servicio")

        let sinFecha = AmbulanciaFixtures.solicitud(.despachada)
        #expect(sinFecha.pasos[1].hecho)
        #expect(sinFecha.pasos[1].detalle == "por recepción")
    }

    private let id = "3f1c2a9e-7b4d-4c1e-9f0a-2d6b8e5c1a7f"

    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try APIClient.decoder.decode(T.self, from: Data(json.utf8))
    }

    private func ambulanciaJSON(estado: String, activa: String, fecha: String) -> String {
        """
        { "id": "\(id)", "placa": "AMB-001", "estado": "\(estado)", "ubicacion_actual": null,
          "updated_at": "\(fecha)", "solicitud_activa": \(activa) }
        """
    }

    private func solicitudJSON(estado: String) -> String {
        """
        { "id": "\(id)", "ambulancia_id": "\(id)", "canal": "app",
          "solicitada_por": { "id": "\(id)", "nombres": "Carlos", "apellidos": "Martínez", "rol": "paciente" },
          "paciente": { "id": "\(id)", "nombres": "Carlos", "apellidos": "Martínez" },
          "direccion_origen": "Col. Escalón", "latitud": 13.69, "longitud": -89.21, "precision_m": 20,
          "destino": null, "descripcion_emergencia": null, "tipo_emergencia": "cardiaca", "prioridad": "urgente",
          "estado": "\(estado)", "telefono_contacto": null, "nombre_contacto": null,
          "fecha_solicitud": "2026-11-09T16:12:00.000Z", "fecha_despacho": null, "fecha_en_curso": null,
          "fecha_cierre": null, "notas_cierre": null, "motivo_cancelacion": null }
        """
    }
}
