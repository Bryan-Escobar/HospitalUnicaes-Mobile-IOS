import Foundation

enum ResultadoArchivoError: Error, Equatable {
    /// La URL firmada venció (Storage responde 400/401/403).
    case enlaceVencido
    /// La respuesta no es un PDF ni una imagen (JPG, PNG o WebP) válida.
    case noEsPDF
    case fallo
}

/// Fuente de URL firmada para el archivo adjunto de un resultado (compartido entre paciente y doctor).
protocol ResultadoArchivoURLService: Sendable {
    /// `GET laboratorio/ordenes/{ordenId}/examenes/{examenId}/resultado/archivo`.
    func urlArchivo(ordenId: UUID, examenId: UUID) async throws -> ArchivoFirmado
}

/// Descarga del archivo de un resultado (PDF o imagen) a una carpeta temporal. Nunca a `Documents` ni a la caché.
protocol ResultadoArchivoService: Sendable {
    /// Descarga la URL firmada a `Resultados/<nombreArchivo>` (ajustando la extensión real) y devuelve la URL local.
    func descargar(_ url: URL, nombreArchivo: String) async throws -> URL
    /// Borra un archivo descargado, o toda la carpeta si es `nil`.
    func borrar(_ local: URL?)
}

struct URLSessionResultadoArchivoService: ResultadoArchivoService {
    /// Carpeta de los archivos descargados; se borra al cerrar sesión.
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
        guard let extensionReal = Self.extensionPermitida(temporal) else {
            throw ResultadoArchivoError.noEsPDF
        }

        let manager = FileManager.default
        try manager.createDirectory(at: carpeta, withIntermediateDirectories: true)
        let destino = Self.rutaDestino(en: carpeta, nombreBase: nombreArchivo, extensionReal: extensionReal)
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

    private static func rutaDestino(en carpeta: URL, nombreBase: String, extensionReal: String) -> URL {
        let inicial = carpeta.appendingPathComponent(nombreBase)
        if inicial.pathExtension.lowercased() == extensionReal {
            return inicial
        }
        return inicial.deletingPathExtension().appendingPathExtension(extensionReal)
    }

    /// Valida los magic bytes del archivo (PDF, JPG, PNG o WebP), alineado con HUNI-63 en la API.
    private static func extensionPermitida(_ archivo: URL) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: archivo) else { return nil }
        defer { try? handle.close() }
        let cabecera = (try? handle.read(upToCount: 12)) ?? Data()
        if cabecera.prefix(5) == Data("%PDF-".utf8) { return "pdf" }
        if cabecera.count >= 3, cabecera[0] == 0xFF, cabecera[1] == 0xD8, cabecera[2] == 0xFF { return "jpg" }
        if cabecera.prefix(8) == Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]) { return "png" }
        if cabecera.count >= 12,
           cabecera.subdata(in: 0..<4) == Data("RIFF".utf8),
           cabecera.subdata(in: 8..<12) == Data("WEBP".utf8) {
            return "webp"
        }
        return nil
    }
}
