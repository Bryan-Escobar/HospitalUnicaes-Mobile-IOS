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
            switch error.code {
            case "PERFIL_INCOMPLETO":
                return "Tu cuenta no tiene un perfil de paciente o de personal. Contacta a recepción."
            case "NO_AUTENTICADO":
                return "Tu sesión expiró. Vuelve a ingresar."
            default:
                return "El servidor no pudo completar la solicitud. Intenta de nuevo."
            }
        case is APIClientError:
            return "No se pudo conectar con el servidor del hospital. Intenta más tarde."
        case is URLError:
            return "No hay conexión. Revisa tu internet e intenta de nuevo."
        default:
            return "Algo salió mal. Intenta de nuevo."
        }
    }
}
