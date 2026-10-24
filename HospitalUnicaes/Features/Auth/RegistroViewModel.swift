import Foundation
import Observation

/// iOS-C3 Registro (solo pacientes): valida en línea, llama `POST /api/auth/registro`,
/// inicia sesión y entra al Inicio Paciente.
@MainActor
@Observable
final class RegistroViewModel {
    enum Field: Hashable, CaseIterable {
        case nombres, apellidos, documento, fechaNacimiento, telefono
        case email, password, contactoNombre, contactoTelefono, alergias
    }

    var nombres = ""
    var apellidos = ""
    var documento = ""
    var fechaNacimiento: Date?
    var telefono = ""
    var email = ""
    var password = ""
    var contactoNombre = ""
    var contactoTelefono = ""
    var alergias = ""

    private(set) var isLoading = false
    /// Error general (red, servidor) mostrado sobre el botón.
    private(set) var errorMessage: String?
    /// Aviso no bloqueante (correo de confirmación enviado).
    private(set) var infoMessage: String?
    /// Errores que devolvió la API para un campo (409 o validación). Se borran al editarlo.
    private var serverErrors: [Field: String] = [:]
    /// Campos que el usuario ya dejó: su error se muestra en línea desde ese momento.
    private var touchedFields: Set<Field> = []
    private(set) var hasAttemptedSubmit = false

    private let session: SessionViewModel
    private let today: () -> Date

    init(session: SessionViewModel, today: @escaping () -> Date = Date.init) {
        self.session = session
        self.today = today
    }

    // MARK: Validación

    /// Mensaje a mostrar bajo el campo, o `nil` si está bien (o aún no toca mostrarlo).
    func error(for field: Field) -> String? {
        if let serverError = serverErrors[field] { return serverError }
        guard hasAttemptedSubmit || touchedFields.contains(field) else { return nil }
        return validationError(for: field)
    }

    var isValid: Bool {
        Field.allCases.allSatisfy { validationError(for: $0) == nil }
    }

    func validationError(for field: Field) -> String? {
        let text = value(of: field).trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty && field != .alergias { return "Campo obligatorio" }
        switch field {
        case .nombres, .apellidos, .contactoNombre:
            return text.count > 100 ? "Máximo 100 caracteres" : nil
        case .documento:
            return text.range(of: #"^\d{8}-\d$"#, options: .regularExpression) == nil
                ? "Formato: 00000000-0" : nil
        case .fechaNacimiento:
            guard let date = fechaNacimiento else { return "Campo obligatorio" }
            let calendar = Calendar(identifier: .gregorian)
            if calendar.startOfDay(for: date) > calendar.startOfDay(for: today()) {
                return "La fecha no puede ser futura"
            }
            return calendar.component(.year, from: date) < 1900 ? "La fecha no puede ser anterior a 1900" : nil
        case .telefono, .contactoTelefono:
            return text.range(of: #"^\d{4}-\d{4}$"#, options: .regularExpression) == nil
                ? "Formato: 0000-0000" : nil
        case .email:
            return text.range(of: #"^[^@\s]+@[^@\s]+\.[^@\s]+$"#, options: .regularExpression) == nil
                ? "Escribe un correo válido" : nil
        case .password:
            // Misma política que Supabase Auth y la API (common.validator.ts).
            let isStrong = password.count >= 8
                && password.contains(where: \.isLowercase)
                && password.contains(where: \.isUppercase)
                && password.contains(where: \.isNumber)
            return isStrong ? nil : "Mínimo 8 caracteres, con mayúscula, minúscula y número"
        case .alergias:
            return text.count > 2000 ? "Máximo 2000 caracteres" : nil
        }
    }

    /// El usuario editó un campo: su error del servidor deja de aplicar.
    func didEdit(_ field: Field) {
        serverErrors[field] = nil
        errorMessage = nil
    }

    /// El foco salió del campo: desde ahora se valida en línea (si escribió algo).
    func didLeave(_ field: Field) {
        if !value(of: field).isEmpty { touchedFields.insert(field) }
    }

    // MARK: Envío

    func submit() async {
        hasAttemptedSubmit = true
        errorMessage = nil
        infoMessage = nil
        guard isValid, !isLoading else { return }

        isLoading = true
        defer { isLoading = false }
        do {
            try await session.register(makeRequest())
        } catch let error as APIError {
            handle(error)
        } catch let error as MeServiceError {
            infoMessage = error.localizedDescription
        } catch {
            errorMessage = UserFacingError.message(for: error)
        }
    }

    func makeRequest() -> RegistroPacienteRequest {
        func clean(_ text: String) -> String { text.trimmingCharacters(in: .whitespacesAndNewlines) }
        let alergias = clean(alergias)
        return RegistroPacienteRequest(
            nombres: clean(nombres),
            apellidos: clean(apellidos),
            email: clean(email).lowercased(),
            password: password,
            documentoIdentidad: clean(documento),
            fechaNacimiento: fechaNacimiento.map(Self.isoDate(from:)),
            telefono: clean(telefono),
            contactoEmergencia: clean(contactoNombre),
            telefonoEmergencia: clean(contactoTelefono),
            alergias: alergias.isEmpty ? nil : alergias
        )
    }

    private func handle(_ error: APIError) {
        switch error.code {
        case "EMAIL_EN_USO":
            serverErrors[.email] = "Ya existe una cuenta con ese correo"
        case "REGISTRO_DUPLICADO":
            serverErrors[.documento] = "Ya hay un paciente registrado con ese documento"
        case "VALIDACION":
            let fieldErrors = error.errors ?? []
            for fieldError in fieldErrors {
                if let field = Self.field(forAPIName: fieldError.field) {
                    serverErrors[field] = fieldError.message
                }
            }
            if fieldErrors.isEmpty { errorMessage = UserFacingError.message(for: error) }
        default:
            errorMessage = UserFacingError.message(for: error)
        }
    }

    // MARK: Utilidades

    private func value(of field: Field) -> String {
        switch field {
        case .nombres: nombres
        case .apellidos: apellidos
        case .documento: documento
        case .fechaNacimiento: fechaNacimiento == nil ? "" : "seleccionada"
        case .telefono: telefono
        case .email: email
        case .password: password
        case .contactoNombre: contactoNombre
        case .contactoTelefono: contactoTelefono
        case .alergias: alergias
        }
    }

    private static func field(forAPIName name: String) -> Field? {
        switch name {
        case "nombres": .nombres
        case "apellidos": .apellidos
        case "documento_identidad": .documento
        case "fecha_nacimiento": .fechaNacimiento
        case "telefono": .telefono
        case "email": .email
        case "password": .password
        case "contacto_emergencia": .contactoNombre
        case "telefono_emergencia": .contactoTelefono
        case "alergias": .alergias
        default: nil
        }
    }

    /// Día elegido en el calendario, de 1900 al día de hoy.
    var rangoFechaNacimiento: ClosedRange<Date> {
        let calendar = Calendar(identifier: .gregorian)
        let start = calendar.date(from: DateComponents(year: 1900, month: 1, day: 1)) ?? .distantPast
        let startOfToday = calendar.startOfDay(for: today())
        let end = calendar.date(byAdding: DateComponents(day: 1, second: -1), to: startOfToday) ?? today()
        return start...max(start, end)
    }

    /// Día de calendario local, sin depender de UTC (`1990-05-14`).
    private static func isoDate(from date: Date) -> String {
        let parts = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}
