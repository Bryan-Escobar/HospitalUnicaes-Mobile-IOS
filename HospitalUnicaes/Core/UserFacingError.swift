import Foundation

/// Texto en español para mostrar un error al usuario. Nunca expone detalles técnicos
/// ni datos privados (context.md §10.5).
enum UserFacingError {
    static func message(for error: Error) -> String {
        switch error {
        case let error as AuthServiceError:
            return error.localizedDescription
        case let error as MeServiceError:
            return error.localizedDescription
        case let error as APIError:
            return message(for: error)
        case let error as APIClientError:
            return message(for: error)
        case let error as URLError:
            return message(for: error)
        default:
            return "Algo salió mal. Intenta de nuevo."
        }
    }

    /// Primero el `code` exacto; si la app no lo conoce (o el cuerpo no era JSON), la categoría HTTP.
    private static func message(for error: APIError) -> String {
        if let text = codigos[error.code] { return text }
        switch error.statusCode {
        case 401:
            return "Tu sesión expiró. Vuelve a ingresar."
        case 403:
            return "No tienes permiso para realizar esta acción."
        case 500...:
            return "El servidor del hospital no está disponible en este momento. Intenta más tarde."
        default:
            return "El servidor no pudo completar la solicitud. Intenta de nuevo."
        }
    }

    private static func message(for error: APIClientError) -> String {
        switch error {
        case .notAuthenticated:
            return "Tu sesión expiró. Vuelve a ingresar."
        case .missingBaseURL, .invalidResponse, .decoding:
            return "No se pudo conectar con el servidor del hospital. Intenta más tarde."
        }
    }

    /// Sin internet en el dispositivo vs. servidor que no responde (caído, apagado o lento).
    private static func message(for error: URLError) -> String {
        switch error.code {
        case .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed, .timedOut, .badServerResponse:
            return "No se pudo conectar con el servidor del hospital. Intenta más tarde."
        default:
            return "No hay conexión. Revisa tu internet e intenta de nuevo."
        }
    }

    /// Códigos de la API (`error-codes.ts`) con un texto más específico que el de su status.
    private static let codigos: [String: String] = [
        "PERFIL_INCOMPLETO": "Tu cuenta no tiene un perfil de paciente o de personal. Contacta a recepción.",
        "CUENTA_INACTIVA": "Tu cuenta está desactivada. Contacta a la administración del hospital.",
    ]
}
