import Foundation
import Observation

/// iOS-C5 Información pública: solo agregados, sin datos de pacientes (`context.md` §3.4).
/// Datos de ejemplo hasta que HUNI-76 conecte los endpoints públicos.
@MainActor
@Observable
final class InformacionPublicaViewModel {
    let ocupacion: [OcupacionPlanta]
    let medicosDeTurno: [MedicoDeTurno]
    let avisos: [Aviso]

    init(
        ocupacion: [OcupacionPlanta] = [
            OcupacionPlanta(titulo: "VIP · 3.ª planta", ocupadas: 3, total: 5, unidad: "ocupadas"),
            OcupacionPlanta(titulo: "Semiprivadas · 2.ª planta", ocupadas: 9, total: 12, unidad: "camas"),
        ],
        medicosDeTurno: [MedicoDeTurno] = [
            MedicoDeTurno(nombre: "Dr. Carlos Molina", especialidad: "General", horario: "07:00–15:00"),
            MedicoDeTurno(nombre: "Dra. Ana Rivas", especialidad: "Alergista", horario: "08:00–14:00"),
            MedicoDeTurno(nombre: "Dr. Jorge Peña", especialidad: "Emergencia", horario: "06:00–18:00"),
        ],
        avisos: [Aviso] = [
            Aviso(titulo: "Horario de visitas", detalle: "2:00–6:00 p. m. desde el lunes."),
        ]
    ) {
        self.ocupacion = ocupacion
        self.medicosDeTurno = medicosDeTurno
        self.avisos = avisos
    }
}
