import SwiftUI

/// iOS-D6 Detalle de consulta, solo lectura. Recibe la consulta que ya cargó el expediente.
struct DetalleConsultaView: View {
    let consulta: ConsultaDetalle

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DSSpacing.medium) {
                Text(subtitulo)
                    .font(DSFont.bodySecondary)
                    .foregroundStyle(DSColor.textSecondary)
                if !consulta.diagnosticos.isEmpty { diagnosticos }
                if let motivo = consulta.motivoConsulta?.nilIfBlank { bloque("Motivo", motivo) }
                if let notas = consulta.notas?.nilIfBlank { bloque("Notas", notas) }
                if let signos = consulta.signosVitales, !signos.filas.isEmpty { signosVitales(signos) }
                if let examen = consulta.examenFisico?.nilIfBlank { bloque("Examen físico", examen) }
                recetasYOrdenes
            }
            .padding(DSSpacing.regular)
        }
        .doctorScreen()
        .navigationTitle("Consulta · \(Formatting.fechaCorta(consulta.fecha))")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var subtitulo: String {
        Formatting.unir([
            consulta.doctor.nombreCompleto,
            consulta.doctor.especialidad,
            consulta.paciente.nombreCompleto,
        ])
    }

    private var diagnosticos: some View {
        DSCard {
            Text(consulta.diagnosticos.count == 1 ? "Diagnóstico" : "Diagnósticos")
                .font(DSFont.fieldLabel)
                .foregroundStyle(DSColor.textLabel)
            ForEach(ordenados) { diagnostico in
                VStack(alignment: .leading, spacing: 2) {
                    Text(diagnostico.descripcion).font(DSFont.bodySecondaryEmphasis)
                    if let codigo = diagnostico.codigoCie10?.nilIfBlank {
                        Text(codigo).font(DSFont.footnote).foregroundStyle(DSColor.textSecondary)
                    }
                }
            }
        }
    }

    private var ordenados: [Diagnostico] {
        consulta.diagnosticos.sorted { izquierda, derecha in
            (izquierda.tipo == .principal ? 0 : 1) < (derecha.tipo == .principal ? 0 : 1)
        }
    }

    private func bloque(_ titulo: String, _ texto: String) -> some View {
        DSCard {
            Text(titulo).font(DSFont.fieldLabel).foregroundStyle(DSColor.textLabel)
            Text(texto).font(DSFont.body)
        }
    }

    private func signosVitales(_ signos: SignosVitales) -> some View {
        DSCard {
            Text("Signos vitales").font(DSFont.fieldLabel).foregroundStyle(DSColor.textLabel)
            ForEach(signos.filas) { fila in
                HStack {
                    Text(fila.etiqueta).font(DSFont.bodySecondary).foregroundStyle(DSColor.textSecondary)
                    Spacer()
                    Text(fila.valor).font(DSFont.bodySecondaryEmphasis)
                }
            }
        }
    }

    @ViewBuilder
    private var recetasYOrdenes: some View {
        if consulta.recetas.isEmpty && consulta.ordenesLaboratorio.isEmpty {
            ContentUnavailableView(
                "Sin recetas ni órdenes",
                systemImage: "doc.text",
                description: Text("Esta consulta solo tiene diagnóstico y notas.")
            )
        } else {
            if !consulta.recetas.isEmpty { recetas }
            if !consulta.ordenesLaboratorio.isEmpty { ordenes }
        }
    }

    private var recetas: some View {
        DSCard {
            Text("Recetas (\(consulta.recetas.count))").font(DSFont.subtitle)
            ForEach(consulta.recetas) { receta in
                ForEach(receta.detalles) { detalle in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(detalle.medicamento).font(DSFont.bodySecondaryEmphasis)
                        Text(Formatting.unir([detalle.dosis, detalle.frecuencia, detalle.duracion]))
                            .font(DSFont.footnote)
                            .foregroundStyle(DSColor.textSecondary)
                    }
                }
                if let indicaciones = receta.indicaciones?.nilIfBlank {
                    Text(indicaciones).font(DSFont.footnote).foregroundStyle(DSColor.textSecondary)
                }
            }
        }
    }

    private var ordenes: some View {
        DSCard {
            Text("Órdenes de laboratorio (\(consulta.ordenesLaboratorio.count))").font(DSFont.subtitle)
            ForEach(consulta.ordenesLaboratorio) { orden in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Orden · creada \(Formatting.fechaCorta(orden.fechaSolicitud))")
                            .font(DSFont.bodySecondaryEmphasis)
                        Text(Formatting.cantidad(orden.totalExamenes, singular: "examen", plural: "exámenes"))
                            .font(DSFont.footnote)
                            .foregroundStyle(DSColor.textSecondary)
                    }
                    Spacer()
                    DSStatusBadge(orden.estado.status)
                }
            }
        }
    }
}
