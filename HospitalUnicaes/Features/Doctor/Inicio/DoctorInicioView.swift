import SwiftUI

/// iOS-D1 Inicio (Figma). La próxima cita abre la pestaña Agenda.
struct DoctorInicioView: View {
    @State private var viewModel: DoctorInicioViewModel
    private let onAbrir: (DoctorTab) -> Void

    init(me: Me, hoy: Date = Date(), onAbrir: @escaping (DoctorTab) -> Void) {
        _viewModel = State(initialValue: DoctorInicioViewModel(me: me, hoy: hoy))
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
                    if let turno = viewModel.resumen.turno {
                        turnoCard(turno)
                    }
                    if let cita = viewModel.resumen.proximaCita {
                        proximaCitaCard(cita)
                    }
                    laboratorioCard
                    ambulanciaCard
                    if let aviso = viewModel.resumen.aviso {
                        DSBanner("\(aviso.titulo): \(aviso.detalle)", kind: .notice)
                    }
                    InformacionHospitalLink()
                }
                .pantallaPrincipal()
            }
            .doctorScreen()
            .navigationTitle(viewModel.saludo)
        }
    }

    private func turnoCard(_ turno: DoctorInicioResumen.Turno) -> some View {
        Button { onAbrir(.turnos) } label: {
            VStack(alignment: .leading, spacing: DSSpacing.tiny) {
                Text("Turno en curso").dsEyebrow().foregroundStyle(DSColor.textSecondary)
                HStack {
                    Text("\(turno.horario) · \(turno.area)")
                        .font(DSFont.subtitle)
                        .foregroundStyle(DSColor.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    DSStatusBadge(.turnoEnCurso)
                }
                Text(turno.especialidad)
                    .font(DSFont.bodySecondary)
                    .foregroundStyle(DSColor.textSecondary)
            }
            .padding(.vertical, 14)
            .padding(.horizontal, DSSpacing.regular)
            .dsCardBackground()
            .overlay {
                RoundedRectangle(cornerRadius: DSRadius.card, style: .continuous)
                    .strokeBorder(DSColor.action, lineWidth: 2)
            }
        }
        .buttonStyle(.plain)
        .accessibilityHint("Abre tus turnos")
    }

    private func proximaCitaCard(_ cita: DoctorInicioResumen.ProximaCita) -> some View {
        Button { onAbrir(.agenda) } label: {
            DSCard(style: .highlighted) {
                Text("Próxima cita").dsEyebrow().opacity(0.9)
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(cita.hora) · \(cita.paciente)").font(DSFont.title)
                        Text(cita.motivo).font(DSFont.bodySecondary).opacity(0.9)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "chevron.right").fontWeight(.semibold).accessibilityHidden(true)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityHint("Abre la agenda")
    }

    private var laboratorioCard: some View {
        DSCard {
            Text("Laboratorio de mis pacientes").font(DSFont.subtitle)
            ForEach(viewModel.conteosLaboratorio, id: \.estado) { conteo in
                HStack(spacing: DSSpacing.medium) {
                    Text("\(conteo.cantidad)")
                        .font(.system(.title2, weight: .bold))
                        .frame(minWidth: 28, alignment: .leading)
                    DSStatusBadge(conteo.estado.status)
                    Spacer()
                }
                .frame(minHeight: DSSize.minTapTarget)
                .accessibilityElement(children: .combine)
            }
        }
    }

    private var ambulanciaCard: some View {
        DSCard {
            HStack(spacing: DSSpacing.medium) {
                Image(systemName: "light.beacon.max")
                    .font(.title3)
                    .foregroundStyle(DSColor.textSecondary)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Ambulancia").font(DSFont.bodySecondaryEmphasis)
                    Text("Solo lectura").font(DSFont.footnote).foregroundStyle(DSColor.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                DSStatusBadge(viewModel.resumen.ambulancia.status)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    DoctorInicioView(me: .previewDoctor) { _ in }
}
