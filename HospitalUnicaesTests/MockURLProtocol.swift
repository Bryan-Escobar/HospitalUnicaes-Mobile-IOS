import Foundation

/// Respuestas simuladas para `URLSession` sin tocar la red. Cada sesión creada con
/// `MockURLProtocol.session(_:)` tiene su propio handler y su registro de peticiones,
/// así las pruebas pueden correr en paralelo.
///
/// Las verificaciones van en la prueba (con `requests(of:)`), no dentro del handler:
/// el handler corre en un hilo de `URLSession`, fuera de la tarea de la prueba.
final class MockURLProtocol: URLProtocol, @unchecked Sendable {
    typealias Handler = @Sendable (URLRequest) throws -> (statusCode: Int, body: Data)

    private static let header = "X-Mock-Session"
    private static let lock = NSLock()
    nonisolated(unsafe) private static var handlers: [String: Handler] = [:]
    nonisolated(unsafe) private static var recorded: [String: [URLRequest]] = [:]

    static func session(_ handler: @escaping Handler) -> URLSession {
        let id = UUID().uuidString
        lock.withLock { handlers[id] = handler }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        configuration.httpAdditionalHeaders = [header: id]
        return URLSession(configuration: configuration)
    }

    /// Peticiones que llegaron a `session`, con el body ya leído en `httpBody`.
    static func requests(of session: URLSession) -> [URLRequest] {
        let id = session.configuration.httpAdditionalHeaders?[header] as? String ?? ""
        return lock.withLock { recorded[id] ?? [] }
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let client else { return }
        let id = request.value(forHTTPHeaderField: Self.header) ?? ""
        guard let handler = Self.lock.withLock({ Self.handlers[id] }), let url = request.url else {
            client.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }
        var request = request
        request.httpBody = request.bodyData
        Self.lock.withLock { Self.recorded[id, default: []].append(request) }
        do {
            let (statusCode, body) = try handler(request)
            let response = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: "HTTP/1.1", headerFields: nil)
            if let response {
                client.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            }
            client.urlProtocol(self, didLoad: body)
            client.urlProtocolDidFinishLoading(self)
        } catch {
            client.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

private extension URLRequest {
    /// `URLSession` mueve el body a `httpBodyStream` antes de llegar al `URLProtocol`.
    var bodyData: Data? {
        if let httpBody { return httpBody }
        guard let stream = httpBodyStream else { return nil }
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 1024)
        while stream.hasBytesAvailable {
            let read = stream.read(&buffer, maxLength: buffer.count)
            guard read > 0 else { break }
            data.append(buffer, count: read)
        }
        return data
    }
}
