import Foundation
import Testing
@testable import HospitalUnicaes

@Suite(.serialized)
struct APIClientTests {
    @Test func armaQueryYBearer() async throws {
        let base = try #require(URL(string: "http://localhost:3000/api"))
        let session = session { request in
            #expect(request.url?.path == "/api/pacientes")
            let items = URLComponents(url: request.url ?? base, resolvingAgainstBaseURL: false)?.queryItems ?? []
            #expect(items.contains(URLQueryItem(name: "buscar", value: "mar")))
            #expect(items.contains(URLQueryItem(name: "pagina", value: "1")))
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer abc")
            let body = #"{"statusCode":200,"success":true,"message":"OK","data":{"items":[],"paginacion":{"pagina":1,"por_pagina":50,"total":0,"total_paginas":0}}}"#
            return (200, Data(body.utf8))
        }
        let client = APIClient(baseURL: base, session: session) { "abc" }
        let pagina: Pagina<Paciente> = try await client.send(
            .get, "pacientes",
            query: [URLQueryItem(name: "buscar", value: "mar"), URLQueryItem(name: "pagina", value: "1")]
        )
        #expect(pagina.items.isEmpty)
    }

    @Test func forbiddenEsAccesoDenegado() async throws {
        let base = try #require(URL(string: "http://localhost:3000/api"))
        let session = session { _ in
            let body = #"{"statusCode":403,"success":false,"code":"ACCESO_DENEGADO","message":"no"}"#
            return (403, Data(body.utf8))
        }
        let client = APIClient(baseURL: base, session: session) { "abc" }
        do {
            let _: Paciente = try await client.send(.get, "pacientes/x")
            Issue.record("Debió fallar")
        } catch let error as APIError {
            #expect(error.code == "ACCESO_DENEGADO")
            #expect(error.statusCode == 403)
        }
    }

    private func session(_ handler: @escaping (URLRequest) -> (Int, Data)) -> URLSession {
        StubURLProtocol.handler = { request in
            let (status, data) = handler(request)
            let response = HTTPURLResponse(url: request.url ?? URL(string: "http://localhost")!, statusCode: status, httpVersion: nil, headerFields: nil)!
            return (response, data)
        }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: configuration)
    }
}

private final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handler, let client else { return }
        do {
            let (response, data) = try handler(request)
            client.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client.urlProtocol(self, didLoad: data)
            client.urlProtocolDidFinishLoading(self)
        } catch {
            client.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
