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
        case is APIClientError:
            return "No se pudo conectar con el servidor del hospital. Intenta más tarde."
        case is URLError:
            return "No hay conexión. Revisa tu internet e intenta de nuevo."
        default:
            return "Algo salió mal. Intenta de nuevo."
        }
    }

    private static func message(for error: APIError) -> String {
        codigos[error.code] ?? "El servidor no pudo completar la solicitud. Intenta de nuevo."
    }

    private static let codigos: [String: String] = [
        "PERFIL_INCOMPLETO": "Tu cuenta no tiene un perfil de paciente o de personal. Contacta a recepción.",
        "NO_AUTENTICADO": "Tu sesión expiró. Vuelve a ingresar.",
        "ACCESO_DENEGADO": "No tienes permiso para ver esta información.",
        "NO_ENCONTRADO": "La información solicitada ya no existe.",
    ]
}
