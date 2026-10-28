import Foundation

/// Error de la API (`{ statusCode, success: false, code, message, errors? }`).
/// Los clientes deciden con `code`, nunca comparando `message`.
struct APIError: Error, Equatable, Decodable {
    struct FieldError: Equatable, Decodable {
        let field: String
        let message: String
    }

    let statusCode: Int
    let code: String
    let message: String
    let errors: [FieldError]?

    init(statusCode: Int, code: String, message: String = "", errors: [FieldError]? = nil) {
        self.statusCode = statusCode
        self.code = code
        self.message = message
        self.errors = errors
    }

    var isUnauthorized: Bool { statusCode == 401 }
    var isForbidden: Bool { statusCode == 403 }
    var isServerError: Bool { statusCode >= 500 }
}

/// Fallas del lado del cliente: nunca llegó una respuesta de la API que se pueda interpretar.
enum APIClientError: LocalizedError {
    case missingBaseURL
    case notAuthenticated
    case invalidResponse
    /// La API respondió 2xx pero el cuerpo no coincide con el DTO esperado.
    case decoding(DecodingError)

    var errorDescription: String? {
        switch self {
        case .missingBaseURL: "La URL de la API no está configurada (API_BASE_URL)."
        case .notAuthenticated: "No hay una sesión activa."
        case .invalidResponse: "La respuesta del servidor no es válida."
        case .decoding: "La respuesta del servidor no tiene el formato esperado."
        }
    }
}

/// Cliente HTTP del backend unificado. Inyecta `Authorization: Bearer` con el token
/// de la sesión de Supabase y desenvuelve la respuesta estándar `{ data }`.
///
/// `path` se agrega a `API_BASE_URL` (`auth/me` → `…/api/auth/me`); si empieza con `/`
/// es relativo a la raíz del servidor (`/health` → `…/health`, fuera de `/api`).
struct APIClient {
    enum Method: String {
        case get = "GET"
        case post = "POST"
        case patch = "PATCH"
    }

    private let baseURL: URL?
    private let session: URLSession
    /// Devuelve el access token vigente; `nil` en endpoints públicos.
    private let accessToken: @Sendable () async throws -> String?

    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return encoder
    }()

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()

    init(
        baseURL: URL? = AppConfig.apiBaseURL,
        session: URLSession = .shared,
        accessToken: @escaping @Sendable () async throws -> String?
    ) {
        self.baseURL = baseURL
        self.session = session
        self.accessToken = accessToken
    }

    func send<Response: Decodable>(
        _ method: Method,
        _ path: String,
        body: (some Encodable)? = String?.none,
        authenticated: Bool = true
    ) async throws -> Response {
        guard let baseURL else { throw APIClientError.missingBaseURL }

        var request = URLRequest(url: try url(baseURL: baseURL, path: path))
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if authenticated {
            guard let token = try await accessToken() else { throw APIClientError.notAuthenticated }
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try Self.encoder.encode(body)
        }

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIClientError.invalidResponse }

        guard (200..<300).contains(http.statusCode) else {
            // Un proxy (502/504) o un error no controlado puede responder sin el JSON estándar.
            throw (try? Self.decoder.decode(APIError.self, from: data))
                ?? APIError(statusCode: http.statusCode, code: "HTTP_\(http.statusCode)")
        }
        do {
            return try Self.decoder.decode(Envelope<Response>.self, from: data).data
        } catch let error as DecodingError {
            throw APIClientError.decoding(error)
        }
    }

    private struct Envelope<T: Decodable>: Decodable {
        let data: T
    }

    private func url(baseURL: URL, path: String) throws -> URL {
        guard path.hasPrefix("/") else { return baseURL.appendingPathComponent(path) }
        guard let url = URL(string: path, relativeTo: baseURL)?.absoluteURL else {
            throw APIClientError.missingBaseURL
        }
        return url
    }
}
