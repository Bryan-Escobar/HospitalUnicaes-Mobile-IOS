import Foundation
import Observation
import PDFKit
import UIKit

/// PDF del resultado en iOS-P8: pide la URL firmada a la API, lo descarga a un temporal
/// y prepara la miniatura y el tamaño. Se borra al salir de la pantalla.
@MainActor
@Observable
final class ResultadoArchivoViewModel {
    enum Estado: Equatable {
        case sinArchivo
        case descargando
        case listo(local: URL, tamano: String, miniatura: UIImage?)
        case error(String)
    }

    static let mensajeVencido = "El enlace caducó, vuelve a abrirlo"
    static let mensajeFallo = "No se pudo abrir el PDF."

    private(set) var estado: Estado = .sinArchivo

    private var examen: ExamenLaboratorioPaciente
    private let service: any LaboratorioPacienteService
    private let archivos: any ResultadoArchivoService
    private var descargando = false

    init(
        examen: ExamenLaboratorioPaciente,
        service: any LaboratorioPacienteService,
        archivos: any ResultadoArchivoService
    ) {
        self.examen = examen
        self.service = service
        self.archivos = archivos
    }

    var archivoLocal: URL? {
        if case .listo(let local, _, _) = estado { return local }
        return nil
    }

    /// Descarga el PDF si el examen está Completado con archivo y aún no está listo.
    /// La vista lo vuelve a llamar cuando el examen cambia de estado en vivo.
    func preparar(para examen: ExamenLaboratorioPaciente) async {
        self.examen = examen
        guard examen.tieneArchivo else {
            estado = .sinArchivo
            return
        }
        if case .listo = estado { return }
        await descargar()
    }

    func reintentar() async {
        await descargar()
    }

    /// Borra el archivo local (al salir de iOS-P8). Si la pantalla vuelve a aparecer, `preparar` lo descarga de nuevo.
    func limpiar() {
        if let local = archivoLocal {
            archivos.borrar(local)
        }
        estado = .sinArchivo
    }

    // MARK: Privado

    private func descargar() async {
        guard !descargando, examen.tieneArchivo else { return }
        descargando = true
        defer { descargando = false }
        estado = .descargando
        do {
            let local = try await descargarConReintento()
            estado = await Self.listo(local)
        } catch let error as APIError where error.code == "NO_ENCONTRADO" {
            estado = .sinArchivo
        } catch ResultadoArchivoError.enlaceVencido {
            estado = .error(Self.mensajeVencido)
        } catch let error as APIError where error.statusCode == 403 {
            estado = .error(UserFacingError.message(for: error))
        } catch {
            estado = .error(Self.mensajeFallo)
        }
    }

    /// Si la URL firmada ya venció, pide una nueva y lo intenta una vez más.
    private func descargarConReintento() async throws -> URL {
        do {
            return try await descargarUnaVez()
        } catch ResultadoArchivoError.enlaceVencido {
            return try await descargarUnaVez()
        }
    }

    private func descargarUnaVez() async throws -> URL {
        let firmado = try await service.urlArchivo(ordenId: examen.ordenId, examenId: examen.id)
        return try await archivos.descargar(firmado.url, nombreArchivo: examen.nombreArchivo)
    }

    /// Miniatura de la primera página y "PDF · 240 KB", fuera del hilo principal.
    private nonisolated static func listo(_ local: URL) async -> Estado {
        await Task.detached(priority: .userInitiated) {
            let bytes = (try? local.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            let tamano = ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
            let miniatura = PDFDocument(url: local)?
                .page(at: 0)?
                .thumbnail(of: CGSize(width: 600, height: 440), for: .mediaBox)
            return Estado.listo(local: local, tamano: tamano, miniatura: miniatura)
        }.value
    }
}
