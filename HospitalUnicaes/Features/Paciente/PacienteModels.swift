import Foundation

// Modelos de la app del paciente. Mientras no existan los endpoints del paciente,
// `PacienteMuestra` arma los datos del Figma con fechas relativas a hoy.

struct CitaPaciente: Hashable, Identifiable {
    let id = UUID()
    let fecha: Date
    let doctor: String
    let especialidad: String
    let motivo: String
    let estado: EstadoCita
}

/// Solicitud de cita que recepción todavía no convierte en cita.
struct SolicitudCita: Hashable, Identifiable {
    let id = UUID()
    let motivo: String
    let especialidad: String
    let preferencia: String
}

struct RecetaPaciente: Hashable, Identifiable {
    let id = UUID()
    let medicamento: String
    let indicacion: String
}

struct ResultadoLaboratorio: Hashable, Identifiable {
    let id = UUID()
    let examen: String
    let doctor: String
    let fecha: Date
    let estado: EstadoLaboratorio
    /// Texto del resultado; solo cuando la orden está Completada.
    let resultado: String?
    let archivo: String?
}

struct ConsultaPaciente: Hashable, Identifiable {
    let id = UUID()
    let fecha: Date
    let diagnostico: String
    let doctor: String
    let especialidad: String
    let recetas: [RecetaPaciente]
    let ordenes: [ResultadoLaboratorio]
}

struct HabitacionPaciente: Hashable {
    let codigo: String
    let cama: String
    let tipo: TipoHabitacion
    let planta: String
    let ingreso: Date
    let medicoTratante: String
    /// "HAB-202 · Cama B" si hubo un traslado reciente.
    let trasladoDesde: String?
}

enum PacienteRoute: Hashable {
    case cita(CitaPaciente)
    case consulta(ConsultaPaciente)
    case resultado(ResultadoLaboratorio)
}

enum PacienteMuestra {
    static func citas(hoy: Date) -> [CitaPaciente] {
        [
            CitaPaciente(
                fecha: Formatting.fecha(Formatting.sumarDias(1, a: hoy), hora: 10, minuto: 30),
                doctor: "Dra. Ana Rivas",
                especialidad: "Alergista",
                motivo: "Control de alergia",
                estado: .programada
            ),
            CitaPaciente(
                fecha: Formatting.fecha(Formatting.sumarDias(13, a: hoy), hora: 9),
                doctor: "Dr. Carlos Molina",
                especialidad: "General",
                motivo: "Control general",
                estado: .programada
            ),
            CitaPaciente(
                fecha: Formatting.fecha(Formatting.sumarDias(-7, a: hoy), hora: 10),
                doctor: "Dra. Ana Rivas",
                especialidad: "Alergista",
                motivo: "Rinitis alérgica",
                estado: .atendida
            ),
            CitaPaciente(
                fecha: Formatting.fecha(Formatting.sumarDias(-49, a: hoy), hora: 15, minuto: 30),
                doctor: "Dr. Carlos Molina",
                especialidad: "General",
                motivo: "Dermatitis",
                estado: .cancelada
            ),
        ]
    }

    static let solicitud = SolicitudCita(
        motivo: "Revisión general",
        especialidad: "Medicina general",
        preferencia: "lunes por la mañana"
    )

    static func resultados(hoy: Date) -> [ResultadoLaboratorio] {
        [
            ResultadoLaboratorio(
                examen: "Prueba cutánea de alergias",
                doctor: "Dra. Ana Rivas",
                fecha: Formatting.sumarDias(-7, a: hoy),
                estado: .completado,
                resultado: "Positivo a ácaros del polvo y polen de gramíneas. Negativo a epitelio de gato.",
                archivo: "resultado-prueba-cutanea.pdf"
            ),
            ResultadoLaboratorio(
                examen: "Hemograma completo",
                doctor: "Dr. Carlos Molina",
                fecha: Formatting.sumarDias(-1, a: hoy),
                estado: .completado,
                resultado: "Valores dentro de rangos de referencia.",
                archivo: "hemograma.pdf"
            ),
            ResultadoLaboratorio(
                examen: "Química sanguínea",
                doctor: "Dr. Carlos Molina",
                fecha: hoy,
                estado: .enProceso,
                resultado: nil,
                archivo: nil
            ),
            ResultadoLaboratorio(
                examen: "Examen general de orina",
                doctor: "Dr. Carlos Molina",
                fecha: hoy,
                estado: .pendiente,
                resultado: nil,
                archivo: nil
            ),
        ]
    }

    static func consultas(hoy: Date) -> [ConsultaPaciente] {
        let prueba = resultados(hoy: hoy)[0]
        return [
            ConsultaPaciente(
                fecha: Formatting.sumarDias(-7, a: hoy),
                diagnostico: "Rinitis alérgica estacional",
                doctor: "Dra. Ana Rivas",
                especialidad: "Alergista",
                recetas: [
                    RecetaPaciente(medicamento: "Loratadina 10 mg", indicacion: "1 tableta cada 24 h · 14 días"),
                    RecetaPaciente(medicamento: "Fluticasona nasal", indicacion: "2 aplicaciones cada 12 h"),
                ],
                ordenes: [prueba]
            ),
            ConsultaPaciente(
                fecha: Formatting.sumarDias(-49, a: hoy),
                diagnostico: "Dermatitis de contacto",
                doctor: "Dr. Carlos Molina",
                especialidad: "General",
                recetas: [RecetaPaciente(medicamento: "Hidrocortisona crema 1 %", indicacion: "Cada 12 h · 7 días")],
                ordenes: []
            ),
            ConsultaPaciente(
                fecha: Formatting.sumarDias(-110, a: hoy),
                diagnostico: "Control general",
                doctor: "Dr. Carlos Molina",
                especialidad: "General",
                recetas: [],
                ordenes: []
            ),
        ]
    }

    static func habitacion(hoy: Date) -> HabitacionPaciente {
        HabitacionPaciente(
            codigo: "HAB-204",
            cama: "Cama A",
            tipo: .semiprivada,
            planta: "2.ª planta",
            ingreso: Formatting.fecha(Formatting.sumarDias(-2, a: hoy), hora: 16, minuto: 40),
            medicoTratante: "Dr. Carlos Molina",
            trasladoDesde: "HAB-202 · Cama B"
        )
    }

    static let alergias = "penicilina, polen"
}
