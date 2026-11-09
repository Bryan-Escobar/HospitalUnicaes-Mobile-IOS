import SwiftUI

struct DoctorDestination: View {
    let route: DoctorRoute
    let dependencies: DoctorDependencies
    var onConsultaGuardada: () -> Void = {}

    var body: some View {
        switch route {
        case .cita(let cita):
            DetalleCitaView(cita: cita, dependencies: dependencies, onConsultaGuardada: onConsultaGuardada)
        case .expediente(let pacienteId, let nombre):
            ExpedienteView(
                pacienteId: pacienteId,
                nombre: nombre,
                pacientes: dependencies.pacientes,
                hospitalizaciones: dependencies.hospitalizaciones
            )
        case .consulta(let consulta):
            DetalleConsultaView(consulta: consulta)
        }
    }
}
