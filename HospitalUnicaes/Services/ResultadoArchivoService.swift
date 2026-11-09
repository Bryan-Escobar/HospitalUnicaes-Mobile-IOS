import Foundation

enum ResultadoArchivoError: Error, Equatable {
    /// La URL firmada venció (Storage responde 400/401/403).
    case enlaceVencido
    /// La respuesta no es un PDF.
    case noEsPDF
    case fallo
}

/// Descarga del PDF de un resultado a una carpeta temporal. Nunca a `Documents` ni a la caché.
protocol ResultadoArchivoService: Sendable {
    /// Descarga la URL firmada a `Resultados/<nombreArchivo>` y devuelve la URL local.
    func descargar(_ url: URL, nombreArchivo: String) async throws -> URL
    /// Borra un archivo descargado, o toda la carpeta si es `nil`.
    func borrar(_ local: URL?)
}

struct URLSessionResultadoArchivoService: ResultadoArchivoService {
    /// Carpeta de los PDF descargados; se borra al cerrar sesión.
    static var carpeta: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("Resultados", isDirectory: true)
    }

    /// `.ephemeral`: sin caché en disco. Sin `Authorization`: la URL ya va firmada
    /// y el token de la sesión no debe viajar a Storage por esta vía.
    var session = URLSession(configuration: .ephemeral)
    var carpeta = Self.carpeta

    func descargar(_ url: URL, nombreArchivo: String) async throws -> URL {
        let (temporal, response) = try await session.download(from: url)
        defer { try? FileManager.default.removeItem(at: temporal) }
        guard let http = response as? HTTPURLResponse else { throw ResultadoArchivoError.fallo }
        switch http.statusCode {
        case 200..<300: break
        case 400, 401, 403: throw ResultadoArchivoError.enlaceVencido
        default: throw ResultadoArchivoError.fallo
        }
        guard Self.esPDF(temporal) else { throw ResultadoArchivoError.noEsPDF }

        let manager = FileManager.default
        try manager.createDirectory(at: carpeta, withIntermediateDirectories: true)
        let destino = carpeta.appendingPathComponent(nombreArchivo)
        if manager.fileExists(atPath: destino.path) {
            try manager.removeItem(at: destino)
        }
        try manager.moveItem(at: temporal, to: destino)
        try manager.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: destino.path)
        return destino
    }

    func borrar(_ local: URL?) {
        try? FileManager.default.removeItem(at: local ?? carpeta)
    }

    /// Los PDF empiezan con `%PDF-`.
    private static func esPDF(_ archivo: URL) -> Bool {
        guard let handle = try? FileHandle(forReadingFrom: archivo) else { return false }
        defer { try? handle.close() }
        let cabecera = (try? handle.read(upToCount: 5)) ?? Data()
        return cabecera == Data("%PDF-".utf8)
    }
}
