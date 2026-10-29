import SwiftUI

/// iOS-D11 Mis turnos.
struct TurnosView: View {
    @State private var viewModel: TurnosViewModel

    init(hoy: Date = Date()) {
        _viewModel = State(initialValue: TurnosViewModel(hoy: hoy))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DSSpacing.medium) {
                    Picker("Semana", selection: $viewModel.semana) {
                        ForEach(TurnosSemana.allCases) { semana in
                            Text(semana.titulo).tag(semana)
                        }
                    }
                    .pickerStyle(.segmented)
                    if let hoy = viewModel.turnoDeHoy {
                        turnoDeHoy(hoy)
                    }
                    ListaTarjeta(items: viewModel.restantes) { turno in
                        ResumenRow(
                            titulo: titulo(turno),
                            detalle: detalle(turno),
                            status: turno.estado == .programado ? especialidad(turno) : nil
                        )
                        .opacity(turno.estado == .terminado ? 0.6 : 1)
                    }
                }
                .pantallaPrincipal()
            }
            .doctorScreen()
            .navigationTitle("Turnos")
        }
    }

    private func turnoDeHoy(_ turno: TurnoDia) -> some View {
        VStack(alignment: .leading, spacing: DSSpacing.tiny) {
            HStack {
                Text(titulo(turno))
                    .font(DSFont.subtitle)
                    .frame(maxWidth: .infinity, alignment: .leading)
                DSStatusBadge(.turnoEnCurso)
            }
            Text(Formatting.unir([turno.area, turno.especialidad]))
                .font(DSFont.bodySecondary)
                .foregroundStyle(DSColor.textSecondary)
        }
        .foregroundStyle(DSColor.textPrimary)
        .padding(.vertical, 14)
        .padding(.horizontal, DSSpacing.regular)
        .dsCardBackground()
        .overlay {
            RoundedRectangle(cornerRadius: DSRadius.card, style: .continuous)
                .strokeBorder(DSColor.action, lineWidth: 2)
        }
        .accessibilityElement(children: .combine)
    }

    private func titulo(_ turno: TurnoDia) -> String {
        let dia = "\(Formatting.diaCorto(turno.dia)) \(Formatting.diaNumero(turno.dia))"
        guard let horario = turno.horario else { return dia }
        return "\(dia) · \(horario)"
    }

    private func detalle(_ turno: TurnoDia) -> String {
        guard let area = turno.area else { return "Sin turno" }
        return turno.estado == .terminado ? "\(area) · Terminado" : area
    }

    private func especialidad(_ turno: TurnoDia) -> DSStatus? {
        turno.especialidad.map { DSStatus(domain: "Especialidad", title: $0, systemImage: nil, tone: .neutral) }
    }
}

#Preview {
    TurnosView()
}
