import Foundation
import Testing
@testable import HospitalUnicaes

struct DoctorModelsTests {
    @Test func historialConYSinMilisegundos() throws {
        let conMilisegundos = try APIClient.decoder.decode(HistorialClinico.self, from: Data(historialJSON(fraccion: true).utf8))
        let sinMilisegundos = try APIClient.decoder.decode(HistorialClinico.self, from: Data(historialJSON(fraccion: false).utf8))
        #expect(conMilisegundos.consultas.count == 1)
        #expect(sinMilisegundos.consultas[0].diagnosticos[0].codigoCie10 == "J30.1")
        #expect(conMilisegundos.paciente.numeroExpediente == "EXP-2026-00015")
        #expect(conMilisegundos.consultas[0].ordenesLaboratorio[0].totalExamenes == 1)
    }

    @Test func paginaDePacientesYHospitalizacion() throws {
        let pagina = try APIClient.decoder.decode(Pagina<Paciente>.self, from: Data(paginaJSON.utf8))
        #expect(pagina.items.count == 1)
        #expect(pagina.paginacion.totalPaginas == 2)
        #expect(pagina.items[0].documentoIdentidad == "01234567-8")

        let hospitalizacion = try APIClient.decoder.decode(Hospitalizacion.self, from: Data(hospitalizacionJSON.utf8))
        #expect(hospitalizacion.cama.letra == "A")
        #expect(hospitalizacion.tituloCama == "HAB-204 · Cama A")
        #expect(hospitalizacion.cama.habitacion.tipo == .semiprivada)
    }

    @Test func citaDeLaVistaYEstadoDesconocido() throws {
        let cita = try SupabaseClientFactory.postgrestDecoder.decode(Cita.self, from: Data(citaJSON.utf8))
        #expect(cita.pacienteNombre == "Luis Martínez")
        #expect(cita.estado == .programada)
        #expect(cita.duracionMinutos == 30)

        let desconocida = try SupabaseClientFactory.postgrestDecoder.decode(EstadoCita.self, from: Data("\"reprogramada\"".utf8))
        #expect(desconocida == .desconocido)
        let lista = try SupabaseClientFactory.postgrestDecoder.decode([Cita].self, from: Data("[\(citaJSON)]".utf8))
        #expect(lista.count == 1)
    }
}

private let citaJSON = """
{
  "id": "11111111-1111-4111-8111-000000000001",
  "paciente_id": "22222222-2222-4222-8222-000000000001",
  "doctor_id": "33333333-3333-4333-8333-000000000001",
  "especialidad_id": null,
  "paciente_nombres": "Luis",
  "paciente_apellidos": "Martínez",
  "doctor_nombres": "Ana",
  "doctor_apellidos": "Rivas",
  "especialidad": "Alergista",
  "fecha_hora": "2026-10-21T16:30:00.000Z",
  "fecha_hora_fin": "2026-10-21T17:00:00Z",
  "created_at": "2026-10-01T12:00:00Z",
  "duracion_minutos": 30,
  "motivo": "Control",
  "estado": "programada"
}
"""

private let paginaJSON = """
{
  "items": [{
    "id": "22222222-2222-4222-8222-000000000001",
    "perfil_id": null, "nombres": "Luis", "apellidos": "Martínez",
    "documento_identidad": "01234567-8", "fecha_nacimiento": "1992-03-14",
    "sexo": "masculino", "telefono": "7000-1111", "direccion": null,
    "contacto_emergencia": null, "telefono_emergencia": null,
    "numero_expediente": "EXP-2026-00015", "activo": true,
    "created_at": "2026-10-01T12:00:00Z"
  }],
  "paginacion": { "pagina": 1, "por_pagina": 50, "total": 60, "total_paginas": 2 }
}
"""

private let hospitalizacionJSON = """
{
  "id": "44444444-4444-4444-8444-000000000001",
  "paciente": { "id": "22222222-2222-4222-8222-000000000001", "nombres": "Luis", "apellidos": "Martínez" },
  "cama": {
    "id": "55555555-5555-4555-8555-000000000001",
    "codigo": "HAB-204-A",
    "habitacion": {
      "id": "66666666-6666-4666-8666-000000000001",
      "codigo": "HAB-204", "planta": 2, "tipo": "semiprivada"
    }
  },
  "doctor_tratante": {
    "id": "33333333-3333-4333-8333-000000000001",
    "nombres": "Ana", "apellidos": "Rivas", "especialidad": "Alergista"
  },
  "fecha_ingreso": "2026-10-19T14:00:00Z",
  "fecha_alta": null, "motivo_ingreso": "Observación", "estado": "activa"
}
"""

private func historialJSON(fraccion: Bool) -> String {
    let fecha = fraccion ? "2026-10-14T15:00:00.000Z" : "2026-10-14T15:00:00Z"
    return """
    {
      "paciente": {
        "id": "22222222-2222-4222-8222-000000000001",
        "nombres": "Luis", "apellidos": "Martínez",
        "documento_identidad": "01234567-8", "fecha_nacimiento": "1992-03-14",
        "numero_expediente": "EXP-2026-00015", "activo": true,
        "created_at": "2026-10-01T12:00:00Z"
      },
      "expediente": {
        "id": "77777777-7777-4777-8777-000000000001",
        "paciente_id": "22222222-2222-4222-8222-000000000001",
        "numero_expediente": "EXP-2026-00015",
        "alergias": "Penicilina",
        "created_at": "\(fecha)", "updated_at": "\(fecha)"
      },
      "consultas": [{
        "id": "88888888-8888-4888-8888-000000000001",
        "expediente_id": "77777777-7777-4777-8777-000000000001",
        "paciente": { "id": "22222222-2222-4222-8222-000000000001", "nombres": "Luis", "apellidos": "Martínez" },
        "doctor": { "id": "33333333-3333-4333-8333-000000000001", "nombres": "Ana", "apellidos": "Rivas", "especialidad": "Alergista" },
        "cita_id": "11111111-1111-4111-8111-000000000001",
        "fecha": "\(fecha)",
        "motivo_consulta": "Control",
        "cerrada_en": "\(fecha)",
        "diagnosticos": [{
          "id": "99999999-9999-4999-8999-000000000001",
          "codigo_cie10": "J30.1", "descripcion": "Rinitis alérgica", "tipo": "principal"
        }],
        "recetas": [],
        "ordenes_laboratorio": [{
          "id": "aaaaaaaa-aaaa-4aaa-8aaa-000000000009",
          "fecha_solicitud": "\(fecha)",
          "prioridad": "normal", "estado": "pendiente", "total_examenes": 1
        }]
      }]
    }
    """
}
