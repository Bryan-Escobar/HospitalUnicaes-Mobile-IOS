import Foundation
import Testing
@testable import HospitalUnicaes

struct LaboratorioPacienteModelsTests {
    @Test func decodificaLaPaginaDeOrdenesDeHUNI62() throws {
        let pagina = try APIClient.decoder.decode(Pagina<OrdenLaboratorioPaciente>.self, from: Data(paginaJSON.utf8))
        let orden = try #require(pagina.items.first)

        #expect(orden.doctor.nombreCompleto == "Ana Rivas")
        #expect(orden.estado == .enProceso)
        #expect(orden.examenes.count == 2)
        let completado = try #require(orden.examenes.first { $0.estado == .completado })
        #expect(completado.resultado?.tieneArchivo == true)
        #expect(completado.resultado?.unidad == "g/dL")
        #expect(completado.fechaCompletado != nil)
        #expect(orden.examenes.first { $0.estado == .enProceso }?.resultado == nil)
    }

    @Test func estadoDesconocidoNoRompeLaDecodificacion() throws {
        let json = paginaJSON.replacingOccurrences(of: "\"estado\": \"en_proceso\"", with: "\"estado\": \"cancelada\"")
        let pagina = try APIClient.decoder.decode(Pagina<OrdenLaboratorioPaciente>.self, from: Data(json.utf8))
        #expect(pagina.items[0].examenes.contains { $0.estado == .desconocido })
    }

    @Test func aplanaUnaFilaPorExamenConSuEstado() {
        let vieja = LabFixtures.orden(
            id: UUID(),
            fecha: Date(timeIntervalSince1970: 1_000),
            examenes: [LabFixtures.examen(id: UUID(), nombre: "Orina", estado: .pendiente)]
        )
        let nueva = LabFixtures.orden(fecha: Date(timeIntervalSince1970: 2_000), examenes: [
            LabFixtures.examen(id: LabFixtures.quimicaId, nombre: "Química sanguínea", estado: .enProceso),
            LabFixtures.examen(nombre: "Hemograma completo", estado: .completado),
        ])

        let filas = [vieja, nueva].filasLaboratorio

        #expect(filas.map(\.nombre) == ["Hemograma completo", "Química sanguínea", "Orina"])
        #expect(filas.map(\.estado) == [.completado, .enProceso, .pendiente])
        #expect(filas[0].ordenId == LabFixtures.ordenId)
        #expect(filas[0].doctor == "Ana Rivas")
    }

    @Test func slugYNombreDelPDF() {
        #expect(Formatting.slug("Prueba cutánea de alergias") == "prueba-cutanea-de-alergias")
        #expect(Formatting.slug("  Química sanguínea (perfil) ") == "quimica-sanguinea-perfil")
        let fila = LabFixtures.orden(examenes: [
            LabFixtures.examen(nombre: "Prueba cutánea de alergias", estado: .completado),
        ]).filas[0]
        #expect(fila.nombreArchivo == "resultado-prueba-cutanea-de-alergias.pdf")
    }

    @Test func fechaCortaConHoraEnElSalvador() {
        // 2026-10-16 17:25 UTC = 11:25 en El Salvador.
        let fecha = Date(timeIntervalSince1970: 1_792_171_500)
        #expect(Formatting.fechaCortaConHora(fecha) == "16 oct, 11:25")
    }

    @Test func archivoFirmadoDecodificaUrlYExpiracion() throws {
        let json = #"{"url": "https://x.supabase.co/storage/v1/object/sign/a.pdf?token=t", "expira_en": "2026-11-09T10:10:00.000Z"}"#
        let archivo = try APIClient.decoder.decode(ArchivoFirmado.self, from: Data(json.utf8))
        #expect(archivo.url.host == "x.supabase.co")
        #expect(archivo.expiraEn.timeIntervalSince1970 > 0)
    }

    private let paginaJSON = """
    {
      "items": [{
        "id": "11111111-1111-4111-8111-000000000001",
        "fecha_solicitud": "2026-10-14T16:40:00.000Z",
        "registrado_por": {"id": "33333333-3333-4333-8333-000000000001", "nombres": "Ana", "apellidos": "Rivas"},
        "prioridad": "normal",
        "estado": "en_proceso",
        "consulta_id": "44444444-4444-4444-8444-000000000001",
        "paciente": {"id": "55555555-5555-4555-8555-000000000001", "nombres": "Carlos", "apellidos": "Martínez Rivas"},
        "doctor": {"id": "33333333-3333-4333-8333-000000000001", "nombres": "Ana", "apellidos": "Rivas", "especialidad": null},
        "indicaciones": null,
        "examenes": [
          {
            "id": "22222222-2222-4222-8222-000000000002",
            "examen": {"id": "66666666-6666-4666-8666-000000000001", "nombre": "Química sanguínea", "tipo_muestra": "Sangre"},
            "estado": "en_proceso",
            "fecha_inicio": "2026-10-15T14:10:00Z",
            "fecha_completado": null,
            "resultado": null
          },
          {
            "id": "22222222-2222-4222-8222-000000000001",
            "examen": {"id": "66666666-6666-4666-8666-000000000002", "nombre": "Hemograma completo", "tipo_muestra": null},
            "estado": "completado",
            "fecha_inicio": "2026-10-15T14:10:00.000Z",
            "fecha_completado": "2026-10-16T17:25:00Z",
            "resultado": {
              "id": "77777777-7777-4777-8777-000000000001",
              "valor": "13.5", "unidad": "g/dL", "rango_referencia": "12.0 - 15.5", "observaciones": null,
              "tiene_archivo": true,
              "validado_por": {"id": "88888888-8888-4888-8888-000000000001", "nombres": "Rosa", "apellidos": "López"},
              "fecha_resultado": "2026-10-16T17:25:00.000Z"
            }
          }
        ]
      }],
      "paginacion": {"pagina": 1, "por_pagina": 100, "total": 1, "total_paginas": 1}
    }
    """
}
