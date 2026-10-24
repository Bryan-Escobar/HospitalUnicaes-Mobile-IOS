import Foundation
import Testing
@testable import HospitalUnicaes

struct ModelsTests {
    @Test func decodificaMeDelContrato() throws {
        let json = """
        {
          "statusCode": 200, "success": true, "message": "OK",
          "data": {
            "id": "11111111-1111-4111-8111-000000000002",
            "email": "doctor@demo.hospitalunicaes.test",
            "nombres": "Roberto", "apellidos": "Castillo Peña",
            "telefono": null, "avatar_url": null,
            "rol": "doctor", "activo": true, "created_at": "2026-10-24T10:00:00Z",
            "paciente_id": null,
            "personal": {
              "id": "22222222-2222-4222-8222-000000000001",
              "tipo": { "id": "33333333-3333-4333-8333-000000000001", "nombre": "Médico" },
              "especialidad": "Alergista",
              "codigo_empleado": "EMP-0002"
            }
          }
        }
        """
        struct Envelope: Decodable { let data: Me }
        let me = try APIClient.decoder.decode(Envelope.self, from: Data(json.utf8)).data

        #expect(me.rol == .doctor)
        #expect(me.nombreCompleto == "Roberto Castillo Peña")
        #expect(me.rolYTipo == "Doctor · Alergista")
        #expect(me.personal?.codigoEmpleado == "EMP-0002")
    }

    @Test(arguments: [
        ("asistente", UserRole.recepcionista), ("RECEPCIONISTA", .recepcionista), ("PACIENTE", .paciente),
    ])
    func rolesCompatibles(raw: String, esperado: UserRole) throws {
        let rol = try JSONDecoder().decode(UserRole.self, from: Data("\"\(raw)\"".utf8))
        #expect(rol == esperado)
    }

    @Test func soloDoctorYPacienteUsanIOS() {
        #expect(UserRole.allCases.filter(\.usesIOSApp) == [.doctor, .paciente])
    }

    @Test func registroSeCodificaEnSnakeCaseSinNulos() throws {
        let request = RegistroPacienteRequest(
            nombres: "Ana", apellidos: "Rivas", email: "ana@correo.com", password: "Hospital2026",
            documentoIdentidad: "01234567-8", fechaNacimiento: "1990-05-14"
        )
        let object = try JSONSerialization.jsonObject(with: APIClient.encoder.encode(request)) as? [String: String]
        #expect(object?["documento_identidad"] == "01234567-8")
        #expect(object?["fecha_nacimiento"] == "1990-05-14")
        #expect(object?["alergias"] == nil)
        #expect(object?.keys.contains("rol") == false)
    }

    @Test(arguments: [
        ("doctor@demo.hospitalunicaes.test", UserRole.doctor),
        ("recepcion@demo.hospitalunicaes.test", .recepcionista),
        ("administrador@demo.hospitalunicaes.test", .administrador),
        ("admin@x.com", .administrador),
        ("carlos@correo.com", .paciente),
    ])
    func mockAsignaRolPorCorreo(email: String, rol: UserRole) {
        #expect(MockMeService.role(forEmail: email) == rol)
    }
}
