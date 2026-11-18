import Foundation
@testable import HospitalUnicaes

final class FakeHistorialPacienteService: HistorialPacienteService, @unchecked Sendable {
    var historialResult: Result<HistorialClinico, Error> = .success(HistorialFixtures.historial())
    private(set) var pacienteIds: [UUID] = []

    func historial(pacienteId: UUID) async throws -> HistorialClinico {
        pacienteIds.append(pacienteId)
        return try historialResult.get()
    }
}

enum HistorialFixtures {
    static let pacienteId = UUID(uuidString: "aaaaaaaa-aaaa-4aaa-8aaa-000000000099") ?? UUID()

    static func historial(alergias: String? = "Penicilina", consultas: [ConsultaDetalle] = []) -> HistorialClinico {
        let base = DoctorFixtures.historial(paciente: DoctorFixtures.paciente(id: pacienteId), consultas: consultas)
        return HistorialClinico(
            paciente: base.paciente,
            expediente: Expediente(
                id: base.expediente.id, pacienteId: pacienteId, numeroExpediente: base.expediente.numeroExpediente,
                tipoSangre: "O+", alergias: alergias, antecedentes: nil, enfermedadesCronicas: nil,
                createdAt: base.expediente.createdAt, updatedAt: base.expediente.updatedAt
            ),
            consultas: consultas
        )
    }

    static func consulta(
        id: UUID = UUID(),
        fecha: Date,
        diagnostico: String? = "Rinitis alérgica",
        motivo: String? = "Control",
        recetas: [RecetaEmitida] = [],
        ordenes: [UUID] = []
    ) -> ConsultaDetalle {
        ConsultaDetalle(
            id: id, expedienteId: UUID(),
            paciente: PersonaResumen(id: pacienteId, nombres: "Luis", apellidos: "Martínez"),
            doctor: DoctorResumen(id: UUID(), nombres: "Ana", apellidos: "Rivas", especialidad: "Alergología"),
            citaId: nil, fecha: fecha, motivoConsulta: motivo, signosVitales: nil, examenFisico: nil,
            notas: nil, cerradaEn: fecha,
            diagnosticos: diagnostico.map {
                [Diagnostico(id: UUID(), codigoCie10: nil, descripcion: $0, tipo: .principal)]
            } ?? [],
            recetas: recetas,
            ordenesLaboratorio: ordenes.map { DoctorFixtures.orden(fecha: fecha, id: $0) }
        )
    }

    static func receta(indicaciones: String? = nil, _ detalles: [RecetaDetalleItem]) -> RecetaEmitida {
        RecetaEmitida(id: UUID(), fechaEmision: Date(), indicaciones: indicaciones, detalles: detalles)
    }

    static func medicamento(
        _ nombre: String, dosis: String? = nil, frecuencia: String? = nil, duracion: String? = nil
    ) -> RecetaDetalleItem {
        RecetaDetalleItem(id: UUID(), medicamento: nombre, dosis: dosis, frecuencia: frecuencia, duracion: duracion)
    }
}
