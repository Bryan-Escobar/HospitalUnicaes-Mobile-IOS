import Foundation

enum DoctorRoute: Hashable {
    case cita(Cita)
    case expediente(pacienteId: UUID, nombre: String)
    case consulta(ConsultaDetalle)
}
