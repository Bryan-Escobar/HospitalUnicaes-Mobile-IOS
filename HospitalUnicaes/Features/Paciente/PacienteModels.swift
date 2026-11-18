import Foundation

// Modelos de la app del paciente. `PacienteMuestra` arma con fechas relativas a hoy los datos
// del Figma para los Previews.

struct CitaPaciente: Hashable, Identifiable {
    var id = UUID()
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

/// Un medicamento de una receta, con dosis, frecuencia, duración e indicaciones en una línea.
struct RecetaPaciente: Hashable, Identifiable {
    /// Id del detalle de la receta.
    let id: UUID
    let medicamento: String
    let indicacion: String
}

/// Una consulta del historial clínico propio (iOS-P5 / P6, HUNI-60).
struct ConsultaPaciente: Hashable, Identifiable {
    let id: UUID
    let fecha: Date
    let diagnostico: String
    /// Nombre completo del doctor, sin título (la API no trae sexo ni título).
    let doctor: String
    let especialidad: String?
    let recetas: [RecetaPaciente]
    /// Exámenes de las órdenes de la consulta; `nil` si no se pudieron cargar.
    let ordenes: [ExamenLaboratorioPaciente]?

    /// "Ana Rivas · Alergología".
    var detalleDoctor: String { Formatting.unir([doctor, especialidad]) }
}

extension ConsultaPaciente {
    /// Consulta del historial de la API. `ordenesLaboratorio` (`GET laboratorio/ordenes`) aporta el
    /// detalle por examen de las órdenes que la consulta solo resume; `nil` si esa carga falló.
    init(_ consulta: ConsultaDetalle, ordenesLaboratorio: [OrdenLaboratorioPaciente]?) {
        let ids = Set(consulta.ordenesLaboratorio.map(\.id))
        self.init(
            id: consulta.id,
            fecha: consulta.fecha,
            diagnostico: consulta.tituloDiagnostico,
            doctor: consulta.doctor.nombreCompleto,
            especialidad: consulta.doctor.especialidad?.nilIfBlank,
            recetas: consulta.recetas.flatMap { receta in
                receta.detalles.map { detalle in
                    RecetaPaciente(
                        id: detalle.id,
                        medicamento: detalle.medicamento,
                        indicacion: Formatting.unir([
                            detalle.dosis, detalle.frecuencia, detalle.duracion, receta.indicaciones,
                        ])
                    )
                }
            },
            ordenes: ordenesLaboratorio?.filter { ids.contains($0.id) }.filasLaboratorio
        )
    }
}

struct HabitacionPaciente: Hashable {
    let codigo: String
    let cama: String
    let tipo: TipoHabitacion
    let planta: String
    let ingreso: Date
    let medicoTratante: String
    /// "HAB-202 · Cama B" si lo trasladaron durante esta hospitalización (cama del último traslado).
    let trasladoDesde: String?
}

extension HabitacionPaciente {
    /// Hospitalización activa de la API en el formato de las pantallas del paciente.
    /// `trasladoDesde` sale de los movimientos del detalle; sin detalle queda en `nil`.
    init(_ hospitalizacion: Hospitalizacion, trasladoDesde: CamaCodigo? = nil) {
        let habitacion = hospitalizacion.cama.habitacion
        self.init(
            codigo: habitacion.codigo,
            cama: "Cama \(hospitalizacion.cama.letra)",
            tipo: habitacion.tipo,
            planta: "\(habitacion.planta).ª planta",
            ingreso: hospitalizacion.fechaIngreso,
            medicoTratante: hospitalizacion.doctorTratante.nombreCompleto,
            trasladoDesde: trasladoDesde?.titulo
        )
    }

    init(_ detalle: HospitalizacionDetalle) {
        self.init(detalle.hospitalizacion, trasladoDesde: detalle.ultimoTrasladoDesde)
    }
}

extension CitaPaciente {
    /// La cita programada o confirmada más cercana que todavía no pasa.
    static func proxima(entre citas: [CitaPaciente], ahora: Date) -> CitaPaciente? {
        citas
            .filter { ($0.estado == .programada || $0.estado == .confirmada) && $0.fecha >= ahora }
            .min { $0.fecha < $1.fecha }
    }
}

enum PacienteRoute: Hashable {
    case cita(CitaPaciente)
    case consulta(ConsultaPaciente)
    case resultado(ExamenLaboratorioPaciente)
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

    static func resultados(hoy: Date) -> [ExamenLaboratorioPaciente] {
        [
            examen(
                "Prueba cutánea de alergias",
                doctor: "Ana Rivas",
                fecha: Formatting.sumarDias(-7, a: hoy),
                estado: .completado,
                resultado: "Positivo a ácaros del polvo y polen de gramíneas. Negativo a epitelio de gato."
            ),
            examen(
                "Hemograma completo",
                doctor: "Carlos Molina",
                fecha: Formatting.sumarDias(-1, a: hoy),
                estado: .completado,
                resultado: "Valores dentro de rangos de referencia."
            ),
            examen("Química sanguínea", doctor: "Carlos Molina", fecha: hoy, estado: .enProceso),
            examen("Examen general de orina", doctor: "Carlos Molina", fecha: hoy, estado: .pendiente),
        ]
    }

    private static func examen(
        _ nombre: String,
        doctor: String,
        fecha: Date,
        estado: EstadoLaboratorio,
        resultado: String? = nil
    ) -> ExamenLaboratorioPaciente {
        let completado = estado == .completado ? Formatting.fecha(fecha, hora: 11, minuto: 25) : nil
        return ExamenLaboratorioPaciente(
            id: UUID(),
            ordenId: UUID(),
            nombre: nombre,
            tipoMuestra: nil,
            doctor: doctor,
            fechaSolicitud: Formatting.fecha(fecha, hora: 10, minuto: 40),
            indicaciones: nil,
            estado: estado,
            fechaInicio: estado == .pendiente ? nil : Formatting.fecha(fecha, hora: 10, minuto: 50),
            fechaCompletado: completado,
            resultado: resultado.map {
                ResultadoExamen(
                    id: UUID(), valor: $0, unidad: nil, rangoReferencia: nil, observaciones: nil,
                    tieneArchivo: false, fechaResultado: completado ?? fecha
                )
            }
        )
    }
}
