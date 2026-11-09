import Foundation
import Testing
@testable import HospitalUnicaes

struct AlergiaCheckerTests {
    @Test func casosDelContrato() {
        #expect(AlergiaChecker.coincidencias(medicamento: "Amoxicilina", alergias: "penicilina").isEmpty)
        #expect(AlergiaChecker.coincidencias(medicamento: "Penicilina G benzatínica", alergias: "Penicilina, polen") == ["Penicilina"])
        #expect(AlergiaChecker.coincidencias(medicamento: "IBUPROFENO 400 mg", alergias: "ibuprofeno") == ["ibuprofeno"])
        #expect(
            AlergiaChecker.coincidencias(medicamento: "Ácido acetilsalicílico", alergias: "acido acetilsalicilico")
                == ["acido acetilsalicilico"]
        )
        #expect(AlergiaChecker.coincidencias(medicamento: "Loratadina", alergias: nil).isEmpty)
        #expect(AlergiaChecker.coincidencias(medicamento: "Loratadina", alergias: "Ninguna").isEmpty)
    }
}
