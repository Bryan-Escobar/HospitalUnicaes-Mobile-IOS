import Foundation
import Testing
@testable import HospitalUnicaes

struct ResultadoArchivoServiceTests {
    private let firmada = URL(string: "https://x.supabase.co/storage/v1/object/sign/a.pdf?token=t") ?? URL(fileURLWithPath: "/")
    private let carpeta = FileManager.default.temporaryDirectory
        .appendingPathComponent("ResultadosTests-\(UUID().uuidString)", isDirectory: true)

    private func servicio(_ handler: @escaping MockURLProtocol.Handler) -> (URLSessionResultadoArchivoService, URLSession) {
        let session = MockURLProtocol.session(handler)
        return (URLSessionResultadoArchivoService(session: session, carpeta: carpeta), session)
    }

    @Test func descargaElPDFSinAuthorization() async throws {
        let (servicio, session) = servicio { _ in (200, Data("%PDF-1.4 contenido".utf8)) }
        defer { servicio.borrar(nil) }

        let local = try await servicio.descargar(firmada, nombreArchivo: "resultado-hemograma.pdf")

        #expect(local == carpeta.appendingPathComponent("resultado-hemograma.pdf"))
        #expect(FileManager.default.fileExists(atPath: local.path))
        let peticion = try #require(MockURLProtocol.requests(of: session).first)
        #expect(peticion.value(forHTTPHeaderField: "Authorization") == nil)
    }

    @Test func respuestaQueNoEsPDF() async {
        let (servicio, _) = servicio { _ in (200, Data("<html>".utf8)) }
        defer { servicio.borrar(nil) }

        await #expect(throws: ResultadoArchivoError.noEsPDF) {
            try await servicio.descargar(firmada, nombreArchivo: "a.pdf")
        }
    }

    @Test(arguments: [400, 403])
    func enlaceVencido(statusCode: Int) async {
        let (servicio, _) = servicio { _ in (statusCode, Data()) }

        await #expect(throws: ResultadoArchivoError.enlaceVencido) {
            try await servicio.descargar(firmada, nombreArchivo: "a.pdf")
        }
    }

    @Test func errorDelServidorEsFallo() async {
        let (servicio, _) = servicio { _ in (500, Data()) }

        await #expect(throws: ResultadoArchivoError.fallo) {
            try await servicio.descargar(firmada, nombreArchivo: "a.pdf")
        }
    }

    @Test func borrarNilEliminaLaCarpeta() async throws {
        let (servicio, _) = servicio { _ in (200, Data("%PDF-1.4".utf8)) }
        _ = try await servicio.descargar(firmada, nombreArchivo: "a.pdf")

        servicio.borrar(nil)

        #expect(!FileManager.default.fileExists(atPath: carpeta.path))
    }
}
