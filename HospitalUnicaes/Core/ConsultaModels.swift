import Foundation

struct SignosVitales: Decodable, Hashable {
    let presionArterial: String?
    let frecuenciaCardiaca: Int?
    let frecuenciaRespiratoria: Int?
    let temperatura: Double?
    let saturacionOxigeno: Int?
    let pesoKg: Double?
    let tallaCm: Double?

    var filas: [SignoFila] {
        var rows: [SignoFila] = []
        if let presion = presionArterial?.nilIfBlank {
            rows.append(SignoFila(etiqueta: "Presión arterial", valor: presion))
        }
        if let frecuenciaCardiaca {
            rows.append(SignoFila(etiqueta: "Frecuencia cardíaca", valor: "\(frecuenciaCardiaca) lpm"))
        }
        if let frecuenciaRespiratoria {
            rows.append(SignoFila(etiqueta: "Frecuencia respiratoria", valor: "\(frecuenciaRespiratoria) rpm"))
        }
        if let temperatura {
            rows.append(SignoFila(etiqueta: "Temperatura", valor: "\(temperatura.formatted()) °C"))
        }
        if let saturacionOxigeno {
            rows.append(SignoFila(etiqueta: "Saturación de oxígeno", valor: "\(saturacionOxigeno)%"))
        }
        if let pesoKg {
            rows.append(SignoFila(etiqueta: "Peso", valor: "\(pesoKg.formatted()) kg"))
        }
        if let tallaCm {
            rows.append(SignoFila(etiqueta: "Talla", valor: "\(tallaCm.formatted()) cm"))
        }
        return rows
    }
}

struct SignoFila: Hashable, Identifiable {
    var id: String { etiqueta }
    let etiqueta: String
    let valor: String
}

struct Diagnostico: Decodable, Hashable, Identifiable {
    let id: UUID
    let codigoCie10: String?
    let descripcion: String
    let tipo: TipoDiagnostico
}

struct RecetaDetalleItem: Decodable, Hashable, Identifiable {
    let id: UUID
    let medicamento: String
    let dosis: String?
    let frecuencia: String?
    let duracion: String?
}

struct RecetaEmitida: Decodable, Hashable, Identifiable {
    let id: UUID
    let fechaEmision: Date
    let indicaciones: String?
    let detalles: [RecetaDetalleItem]
}

struct OrdenLaboratorioResumen: Decodable, Hashable, Identifiable {
    let id: UUID
    let fechaSolicitud: Date
    let prioridad: PrioridadLaboratorio
    let estado: EstadoLaboratorio
    let totalExamenes: Int
}

struct ConsultaDetalle: Decodable, Hashable, Identifiable {
    let id: UUID
    let expedienteId: UUID
    let paciente: PersonaResumen
    let doctor: DoctorResumen
    let citaId: UUID?
    let fecha: Date
    let motivoConsulta: String?
    let signosVitales: SignosVitales?
    let examenFisico: String?
    let notas: String?
    let cerradaEn: Date?
    let diagnosticos: [Diagnostico]
    let recetas: [RecetaEmitida]
    let ordenesLaboratorio: [OrdenLaboratorioResumen]

    var diagnosticoPrincipal: Diagnostico? {
        diagnosticos.first { $0.tipo == .principal } ?? diagnosticos.first
    }

    var tituloDiagnostico: String {
        diagnosticoPrincipal?.descripcion.nilIfBlank
            ?? motivoConsulta?.nilIfBlank
            ?? "Consulta"
    }

    var estaAbierta: Bool { cerradaEn == nil }
}

struct HabitacionResumen: Decodable, Hashable, Identifiable {
    let id: UUID
    let codigo: String
    let planta: Int
    let tipo: TipoHabitacion
}

struct CamaResumen: Decodable, Hashable, Identifiable {
    let id: UUID
    let codigo: String
    let habitacion: HabitacionResumen

    /// `HAB-204-A` → `A`.
    var letra: String {
        codigo.split(separator: "-").last.map(String.init) ?? codigo
    }
}

struct Hospitalizacion: Decodable, Hashable, Identifiable {
    let id: UUID
    let paciente: PersonaResumen
    let cama: CamaResumen
    let doctorTratante: DoctorResumen
    let fechaIngreso: Date
    let fechaAlta: Date?
    let motivoIngreso: String?
    let estado: EstadoHospitalizacion

    var tituloCama: String {
        "\(cama.habitacion.codigo) · Cama \(cama.letra)"
    }

    var detalleIngreso: String {
        let planta = "\(cama.habitacion.planta).ª"
        let desde = Formatting.fechaCorta(fechaIngreso)
        return "\(cama.habitacion.tipo.nombre) · \(planta) planta · desde \(desde)"
    }
}
