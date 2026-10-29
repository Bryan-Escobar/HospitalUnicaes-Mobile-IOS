import SwiftUI

/// iOS-P1 Inicio del paciente. Cada tarjeta abre la pestaña que resume.
struct PacienteInicioView: View {
    @State private var viewModel: PacienteInicioViewModel
    private let onAbrir: (PacienteTab, MiSaludSegmento?) -> Void

    init(me: Me, hoy: Date = Date(), onAbrir: @escaping (PacienteTab, MiSaludSegmento?) -> Void) {
        _viewModel = State(initialValue: PacienteInicioViewModel(me: me, hoy: hoy))
        self.onAbrir = onAbrir
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DSSpacing.medium) {
                    Text(viewModel.fecha)
                        .font(DSFont.bodySecondary)
                        .foregroundStyle(DSColor.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    proximaCita
                    if let habitacion = viewModel.habitacion {
                        habitacionCard(habitacion)
                    }
                    resultados
                    ambulancia
                    if let aviso = viewModel.aviso {
                        DSBanner("\(aviso.titulo): \(aviso.detalle)", kind: .notice)
                    }
                    InformacionHospitalLink()
                }
                .pantallaPrincipal()
            }
            .background(DSColor.backgroundGrouped)
            .navigationTitle(viewModel.saludo)
        }
    }

    @ViewBuilder
    private var proximaCita: some View {
        Button { onAbrir(.citas, nil) } label: {
            if let cita = viewModel.proximaCita {
                DSCard(style: .highlighted) {
                    Text("Próxima cita").dsEyebrow().opacity(0.9)
                    Text(Formatting.fechaYHora(cita.fecha)).font(DSFont.title)
                    HStack {
                        Text("\(cita.doctor) · \(cita.especialidad)")
                            .font(DSFont.bodySecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        DSStatusBadge(cita.estado.status, appearance: .onAccent)
                    }
                }
            } else {
                DSCard {
                    Text("Próxima cita").dsEyebrow().foregroundStyle(DSColor.textSecondary)
                    Text("No tienes citas programadas").font(DSFont.subtitle)
                    Text("Solicita una desde la pestaña Citas.")
                        .font(DSFont.bodySecondary)
                        .foregroundStyle(DSColor.textSecondary)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityHint("Abre tus citas")
    }

    private func habitacionCard(_ habitacion: HabitacionPaciente) -> some View {
        Button { onAbrir(.miSalud, .habitacion) } label: {
            HStack(spacing: DSSpacing.medium) {
                Image(systemName: "bed.double")
                    .font(.title2)
                    .foregroundStyle(DSColor.avatarForeground)
                    .frame(width: 48, height: 48)
                    .background(DSColor.avatarBackground, in: RoundedRectangle(cornerRadius: DSRadius.iconContainer))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Mi habitación").font(DSFont.footnoteEmphasis).foregroundStyle(DSColor.textSecondary)
                    Text("\(habitacion.codigo) · \(habitacion.cama)").font(DSFont.subtitle)
                    Text("\(habitacion.tipo.nombre) · \(habitacion.planta) · desde \(Formatting.fechaCorta(habitacion.ingreso))")
                        .font(DSFont.footnote)
                        .foregroundStyle(DSColor.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .font(DSFont.footnote)
                    .foregroundStyle(DSColor.textTertiary)
                    .accessibilityHidden(true)
            }
            .foregroundStyle(DSColor.textPrimary)
            .padding(.vertical, 14)
            .padding(.horizontal, DSSpacing.regular)
            .dsCardBackground()
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Abre Mi salud, habitación")
    }

    private var resultados: some View {
        DSCard {
            HStack {
                Text("Últimos resultados").font(DSFont.subtitle)
                Spacer()
                Button("Ver todos") { onAbrir(.miSalud, .laboratorio) }
                    .font(DSFont.bodySecondaryEmphasis)
                    .foregroundStyle(DSColor.tint)
            }
            ForEach(viewModel.ultimosResultados) { resultado in
                ResumenRow(
                    titulo: resultado.examen,
                    detalle: "\(resultado.doctor) · \(Formatting.fechaCorta(resultado.fecha))",
                    status: resultado.estado.status
                )
            }
        }
    }

    private var ambulancia: some View {
        DSCard {
            HStack(spacing: DSSpacing.medium) {
                Image(systemName: "light.beacon.max")
                    .font(.title3)
                    .foregroundStyle(DSColor.textSecondary)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: DSSpacing.tiny) {
                    Text("Ambulancia").font(DSFont.bodySecondaryEmphasis)
                    DSStatusBadge(viewModel.ambulancia.status)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                DSButton(
                    "Solicitar",
                    systemImage: "light.beacon.max",
                    kind: .destructive,
                    size: .compact,
                    isFullWidth: false
                ) {
                    onAbrir(.ambulancia, nil)
                }
                .disabled(!viewModel.puedeSolicitarAmbulancia)
            }
        }
    }
}

#Preview {
    PacienteInicioView(me: .previewPaciente) { _, _ in }
}
