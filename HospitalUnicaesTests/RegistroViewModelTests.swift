import Foundation
import Testing
@testable import HospitalUnicaes

@MainActor
struct RegistroViewModelTests {
    let auth = FakeAuthService()
    let me = FakeMeService()

    /// 24 oct 2026, para que la validación de fecha futura sea determinista.
    private static let hoy = Date(timeIntervalSince1970: 1_792_800_000)

    private func makeViewModel() -> (RegistroViewModel, SessionViewModel) {
        let session = SessionViewModel(authService: auth, meService: me, state: .signedOut)
        return (RegistroViewModel(session: session, today: { Self.hoy }), session)
    }

    private func completar(_ viewModel: RegistroViewModel) {
        viewModel.nombres = " Carlos "
        viewModel.apellidos = "Martínez Rivas"
        viewModel.documento = "01234567-8"
        viewModel.fechaNacimiento = Self.fecha(1990, 5, 14)
        viewModel.telefono = "7000-0000"
        viewModel.email = "Carlos.Martinez@Correo.com"
        viewModel.password = "Hospital2026"
        viewModel.contactoNombre = "María Rivas"
        viewModel.contactoTelefono = "7111-1111"
    }

    @Test func enviarVacioMarcaLosObligatoriosSinLlamarALaAPI() async {
        let (viewModel, _) = makeViewModel()
        #expect(viewModel.error(for: .nombres) == nil)

        await viewModel.submit()

        for field in RegistroViewModel.Field.allCases where field != .alergias {
            #expect(viewModel.error(for: field) == "Campo obligatorio", "\(field)")
        }
        #expect(viewModel.error(for: .alergias) == nil)
        #expect(me.registros.isEmpty)
    }

    @Test func registroValidoEnviaElContratoYEntraComoPaciente() async {
        let (viewModel, session) = makeViewModel()
        completar(viewModel)

        await viewModel.submit()

        let request = me.registros.first
        #expect(request?.nombres == "Carlos")
        #expect(request?.email == "carlos.martinez@correo.com")
        #expect(request?.fechaNacimiento == "1990-05-14")
        #expect(request?.documentoIdentidad == "01234567-8")
        #expect(request?.contactoEmergencia == "María Rivas")
        #expect(request?.telefonoEmergencia == "7111-1111")
        #expect(request?.alergias == nil)
        guard case .signedIn(let perfil) = session.state else {
            Issue.record("Se esperaba signedIn")
            return
        }
        #expect(perfil.rol == .paciente)
    }

    @Test func alergiasSeEnvianSiSeEscriben() {
        let (viewModel, _) = makeViewModel()
        completar(viewModel)
        viewModel.alergias = " Penicilina "
        #expect(viewModel.makeRequest().alergias == "Penicilina")
    }

    @Test func correoRepetidoMarcaElCampoCorreo() async {
        let (viewModel, session) = makeViewModel()
        me.registroResult = .failure(APIError(statusCode: 409, code: "EMAIL_EN_USO", message: "Ya existe"))
        completar(viewModel)

        await viewModel.submit()

        #expect(viewModel.error(for: .email) == "Ya existe una cuenta con ese correo")
        #expect(viewModel.errorMessage == nil)
        #expect(session.state == .signedOut)

        viewModel.didEdit(.email)
        #expect(viewModel.error(for: .email) == nil)
    }

    @Test func registroDuplicadoMarcaElDUI() async {
        let (viewModel, _) = makeViewModel()
        me.registroResult = .failure(APIError(statusCode: 409, code: "REGISTRO_DUPLICADO"))
        completar(viewModel)

        await viewModel.submit()

        #expect(viewModel.error(for: .documento) == "Ya hay un paciente registrado con ese documento")
    }

    @Test func erroresDeValidacionDeLaAPIVanASuCampo() async {
        let (viewModel, _) = makeViewModel()
        me.registroResult = .failure(APIError(
            statusCode: 400, code: "VALIDACION", errors: [.init(field: "telefono_emergencia", message: "Muy corto")]
        ))
        completar(viewModel)

        await viewModel.submit()

        #expect(viewModel.error(for: .contactoTelefono) == "Muy corto")
    }

    @Test func confirmacionDeCorreoPendienteEsUnAviso() async {
        let (viewModel, _) = makeViewModel()
        me.registroResult = .failure(MeServiceError.confirmacionDeCorreoPendiente)
        completar(viewModel)

        await viewModel.submit()

        #expect(viewModel.infoMessage != nil)
        #expect(viewModel.errorMessage == nil)
    }

    @Test(arguments: [
        ("1234567-8", false), ("12345678-9", true), ("123456789", false),
    ])
    func formatoDUI(dui: String, valido: Bool) {
        let (viewModel, _) = makeViewModel()
        viewModel.documento = dui
        #expect((viewModel.validationError(for: .documento) == nil) == valido)
    }

    @Test func fechaDeHoyEsValidaYMananaNo() {
        let (viewModel, _) = makeViewModel()
        let calendar = Calendar(identifier: .gregorian)
        let hoy = calendar.startOfDay(for: Self.hoy)
        viewModel.fechaNacimiento = hoy
        #expect(viewModel.validationError(for: .fechaNacimiento) == nil)

        viewModel.fechaNacimiento = calendar.date(byAdding: .day, value: 1, to: hoy)
        #expect(viewModel.validationError(for: .fechaNacimiento) == "La fecha no puede ser futura")
    }

    @Test func fechaAnteriorA1900NoEsValida() {
        let (viewModel, _) = makeViewModel()
        viewModel.fechaNacimiento = Self.fecha(1899, 12, 31)
        #expect(viewModel.validationError(for: .fechaNacimiento) == "La fecha no puede ser anterior a 1900")
    }

    private static func fecha(_ year: Int, _ month: Int, _ day: Int) -> Date {
        DateComponents(calendar: Calendar(identifier: .gregorian), year: year, month: month, day: day).date!
    }

    @Test(arguments: [
        ("corta1A", false), ("sinmayuscula1", false), ("SINMINUSCULA1", false), ("SinNumero", false), ("Hospital2026", true),
    ])
    func politicaDeContrasena(password: String, valida: Bool) {
        let (viewModel, _) = makeViewModel()
        viewModel.password = password
        #expect((viewModel.validationError(for: .password) == nil) == valida)
    }

    @Test func soloSeMarcaElCampoAlSalirDeEl() {
        let (viewModel, _) = makeViewModel()
        viewModel.telefono = "7000"
        #expect(viewModel.error(for: .telefono) == nil)
        viewModel.didLeave(.telefono)
        #expect(viewModel.error(for: .telefono) == "Formato: 0000-0000")
    }
}

struct InputMaskTests {
    @Test func dui() {
        #expect(InputMask.dui("012345678") == "01234567-8")
        #expect(InputMask.dui("0123") == "0123")
        #expect(InputMask.dui("01234567-89") == "01234567-8")
    }

    @Test func telefono() {
        #expect(InputMask.telefono("70001234") == "7000-1234")
        #expect(InputMask.telefono("7000-12345") == "7000-1234")
        #expect(InputMask.telefono("+503") == "503")
    }

    @Test func fecha() {
        #expect(InputMask.fecha("14051990") == "14/05/1990")
        #expect(InputMask.fecha("140") == "14/0")
    }
}
