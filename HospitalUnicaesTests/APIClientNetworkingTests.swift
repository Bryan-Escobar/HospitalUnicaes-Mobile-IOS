import Foundation
import Testing
@testable import HospitalUnicaes

/// HUNI-24: `APIClient` contra respuestas simuladas (`MockURLProtocol`), sin red ni Supabase.
struct APIClientNetworkingTests {
    let base = URL(string: "http://localhost:3000/api")

    // MARK: JWT y DTOs

    @Test func inyectaElJWTYDecodificaElDTO() async throws {
        let session = MockURLProtocol.session { _ in (200, Data(Self.meEnvelope.utf8)) }
        let client = APIClient(baseURL: base, session: session) { "jwt-supabase" }

        let me: Me = try await client.send(.get, "auth/me")

        let request = try #require(MockURLProtocol.requests(of: session).first)
        #expect(request.httpMethod == "GET")
        #expect(request.url?.absoluteString == "http://localhost:3000/api/auth/me")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer jwt-supabase")
        #expect(request.value(forHTTPHeaderField: "Accept") == "application/json")
        #expect(me.nombres == "Ana")
        #expect(me.avatarUrl == nil)
        #expect(me.rol == .doctor)
        #expect(me.personal?.codigoEmpleado == "EMP-1")
    }

    @Test func codificaElBodyEnSnakeCase() async throws {
        let session = MockURLProtocol.session { _ in (201, Data(Self.meEnvelope.utf8)) }
        let client = APIClient(baseURL: base, session: session) { nil }
        let body = RegistroPacienteRequest(
            nombres: "Ana", apellidos: "Rivas", email: "ana@demo.test", password: "secreta123",
            documentoIdentidad: "01234567-8", fechaNacimiento: "1990-05-01"
        )

        let _: Me = try await client.send(.post, "auth/registro", body: body, authenticated: false)

        let request = try #require(MockURLProtocol.requests(of: session).first)
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
        let json = try JSONSerialization.jsonObject(with: request.httpBody ?? Data()) as? [String: Any]
        #expect(json?["fecha_nacimiento"] as? String == "1990-05-01")
        #expect(json?["documento_identidad"] as? String == "01234567-8")
    }

    @Test func sinSesionNoLlegaALaRed() async throws {
        let session = MockURLProtocol.session { _ in (200, Data()) }
        let client = APIClient(baseURL: base, session: session) { nil }

        await #expect(throws: APIClientError.self) {
            let _: Me = try await client.send(.get, "auth/me")
        }
        #expect(MockURLProtocol.requests(of: session).isEmpty)
    }

    @Test func sinURLBaseFallaSinLlamarAlServidor() async {
        let client = APIClient(baseURL: nil) { "jwt" }

        do {
            let _: Me = try await client.send(.get, "auth/me")
            Issue.record("Debió fallar")
        } catch APIClientError.missingBaseURL {
        } catch {
            Issue.record("Error inesperado: \(error)")
        }
    }

    @Test func dtoQueNoCoincideEsErrorDeDecodificacion() async {
        let session = MockURLProtocol.session { _ in
            (200, Data(#"{"statusCode":200,"success":true,"message":"OK","data":{"otro":1}}"#.utf8))
        }
        let client = APIClient(baseURL: base, session: session) { "jwt" }

        do {
            let _: Me = try await client.send(.get, "auth/me")
            Issue.record("Debió fallar")
        } catch APIClientError.decoding {
        } catch {
            Issue.record("Error inesperado: \(error)")
        }
    }

    // MARK: /health

    @Test func healthVaALaRaizDelServidorSinToken() async throws {
        let body = #"""
        {"statusCode":200,"success":true,"message":"Servidor operativo",
         "data":{"status":"ok","timestamp":"2026-10-27T12:00:00.000Z","uptime":42.5,"database":"down"}}
        """#
        let session = MockURLProtocol.session { _ in (200, Data(body.utf8)) }
        let client = APIClient(baseURL: base, session: session) {
            Issue.record("/health es público: no debe pedir el token")
            return "jwt"
        }

        let status = try await APIHealthService(client: client).check()

        let request = try #require(MockURLProtocol.requests(of: session).first)
        #expect(request.url?.absoluteString == "http://localhost:3000/health")
        #expect(request.value(forHTTPHeaderField: "Authorization") == nil)

        #expect(status.status == "ok")
        #expect(status.uptime == 42.5)
        #expect(status.database == .down)
    }

    // MARK: Errores → mensajes para el usuario

    @Test(arguments: [
        ErrorCase(
            statusCode: 401,
            body: #"{"statusCode":401,"success":false,"code":"NO_AUTENTICADO","message":"Falta el token Bearer."}"#,
            code: "NO_AUTENTICADO",
            message: "Tu sesión expiró. Vuelve a ingresar."
        ),
        ErrorCase(
            statusCode: 403,
            body: #"{"statusCode":403,"success":false,"code":"ACCESO_DENEGADO","message":"Sin permiso"}"#,
            code: "ACCESO_DENEGADO",
            message: "No tienes permiso para realizar esta acción."
        ),
        ErrorCase(
            statusCode: 403,
            body: #"{"statusCode":403,"success":false,"code":"PERFIL_INCOMPLETO","message":"x"}"#,
            code: "PERFIL_INCOMPLETO",
            message: "Tu cuenta no tiene un perfil de paciente o de personal. Contacta a recepción."
        ),
        ErrorCase(
            statusCode: 500,
            body: #"{"statusCode":500,"success":false,"code":"ERROR_INTERNO","message":"Error interno"}"#,
            code: "ERROR_INTERNO",
            message: "El servidor del hospital no está disponible en este momento. Intenta más tarde."
        ),
        ErrorCase(
            statusCode: 502,
            body: "<html><body>502 Bad Gateway</body></html>",
            code: "HTTP_502",
            message: "El servidor del hospital no está disponible en este momento. Intenta más tarde."
        ),
    ])
    func erroresHTTPSeMapeanAMensajes(_ errorCase: ErrorCase) async {
        let session = MockURLProtocol.session { _ in (errorCase.statusCode, Data(errorCase.body.utf8)) }
        let client = APIClient(baseURL: base, session: session) { "jwt" }

        do {
            let _: Me = try await client.send(.get, "auth/me")
            Issue.record("Debió fallar")
        } catch let error as APIError {
            #expect(error.statusCode == errorCase.statusCode)
            #expect(error.code == errorCase.code)
            #expect(error.isUnauthorized == (errorCase.statusCode == 401))
            #expect(error.isForbidden == (errorCase.statusCode == 403))
            #expect(error.isServerError == (errorCase.statusCode >= 500))
            #expect(UserFacingError.message(for: error) == errorCase.message)
        } catch {
            Issue.record("Error inesperado: \(error)")
        }
    }

    @Test func sinInternetEsMensajeDeConexion() async {
        let session = MockURLProtocol.session { _ in throw URLError(.notConnectedToInternet) }
        let client = APIClient(baseURL: base, session: session) { "jwt" }

        do {
            let _: Me = try await client.send(.get, "auth/me")
            Issue.record("Debió fallar")
        } catch {
            #expect(UserFacingError.message(for: error) == "No hay conexión. Revisa tu internet e intenta de nuevo.")
        }
    }

    @Test func servidorQueNoRespondeNoCulpaAlInternet() async {
        let session = MockURLProtocol.session { _ in throw URLError(.cannotConnectToHost) }
        let client = APIClient(baseURL: base, session: session) { "jwt" }

        do {
            let _: HealthStatus = try await client.send(.get, "/health", authenticated: false)
            Issue.record("Debió fallar")
        } catch {
            #expect(UserFacingError.message(for: error) == "No se pudo conectar con el servidor del hospital. Intenta más tarde.")
        }
    }

    @Test func erroresDelClienteTienenMensaje() {
        #expect(UserFacingError.message(for: APIClientError.notAuthenticated) == "Tu sesión expiró. Vuelve a ingresar.")
        #expect(
            UserFacingError.message(for: APIClientError.missingBaseURL)
                == "No se pudo conectar con el servidor del hospital. Intenta más tarde."
        )
    }

    // MARK: Datos

    struct ErrorCase: Sendable, CustomTestStringConvertible {
        let statusCode: Int
        let body: String
        let code: String
        let message: String

        var testDescription: String { "\(statusCode) \(code)" }
    }

    static let meEnvelope = #"""
    {"statusCode":200,"success":true,"message":"OK","data":{
      "id":"6F9619FF-8B86-D011-B42D-00C04FC964FF","email":"doctor@demo.test","nombres":"Ana","apellidos":"Rivas",
      "telefono":null,"avatar_url":null,"rol":"doctor","activo":true,"paciente_id":null,
      "personal":{"id":"7F9619FF-8B86-D011-B42D-00C04FC964FF",
        "tipo":{"id":"8F9619FF-8B86-D011-B42D-00C04FC964FF","nombre":"Médico"},
        "especialidad":"Alergista","codigo_empleado":"EMP-1"}}}
    """#
}
