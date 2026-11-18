import SwiftUI

/// Turnos del personal para el paciente (HUNI-76): quién está de turno por día, tipo de personal y área.
struct TurnosDelPersonalView: View {
    @State private var viewModel: TurnosDelPersonalViewModel
    @Environment(\.scenePhase) private var scenePhase

    init(service: any TurnosDelPersonalService, hoy: @escaping () -> Date = Date.init) {
        _viewModel = State(initialValue: TurnosDelPersonalViewModel(service: service, hoy: hoy))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: DSSpacing.medium) {
                WeekStripView(
                    semana: viewModel.semana,
                    seleccionado: viewModel.diaSeleccionado,
                    onSelect: viewModel.seleccionar,
                    onPrevious: viewModel.semanaAnterior,
                    onNext: viewModel.semanaSiguiente
                )
                Text(viewModel.titulo)
                    .font(DSFont.bodySecondary)
                    .foregroundStyle(DSColor.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                filtros
                contenido
            }
            .pantallaPrincipal()
        }
        .refreshable { await viewModel.cargar() }
        .background(DSColor.backgroundGrouped)
        .navigationTitle("Turnos del personal")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Hoy", action: viewModel.irAHoy)
            }
        }
        .task(id: viewModel.diaSeleccionado) { await viewModel.cargar() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await viewModel.cargar() } }
        }
    }

    private var filtros: some View {
        HStack(spacing: DSSpacing.small) {
            FiltroMenu(
                titulo: "Tipo de personal",
                todos: "Todo el personal",
                opciones: viewModel.tiposDisponibles,
                seleccion: $viewModel.tipoSeleccionado
            )
            FiltroMenu(
                titulo: "Área",
                todos: "Todas las áreas",
                opciones: viewModel.areasDisponibles,
                seleccion: $viewModel.areaSeleccionada
            )
        }
        .disabled(!viewModel.cargado)
    }

    @ViewBuilder
    private var contenido: some View {
        if viewModel.isLoading && !viewModel.cargado {
            ProgressView("Cargando turnos…")
                .frame(maxWidth: .infinity, minHeight: 200)
        } else if let message = viewModel.errorSinDatos {
            VStack(spacing: DSSpacing.medium) {
                DSBanner(message)
                DSButton("Reintentar", systemImage: "arrow.clockwise") { Task { await viewModel.cargar() } }
            }
        } else if viewModel.cargado {
            if let message = viewModel.errorRecarga {
                DSBanner(message)
            }
            if viewModel.estaVacio {
                ContentUnavailableView {
                    Label("Sin turnos", systemImage: "clock")
                } description: {
                    Text(viewModel.mensajeVacio)
                } actions: {
                    if viewModel.hayFiltros {
                        Button("Quitar filtros", action: viewModel.quitarFiltros)
                    }
                }
            } else {
                ForEach(viewModel.grupos) { grupo in
                    SeccionTitulo(grupo.area)
                    ListaTarjeta(items: grupo.filas) { fila in
                        ResumenRow(
                            titulo: fila.nombre,
                            detalle: "\(fila.horario) · \(fila.puesto)",
                            status: fila.estado == .enCurso ? .turnoEnCurso : nil
                        )
                        .opacity(fila.estado == .terminado ? 0.6 : 1)
                    }
                }
            }
        }
    }
}

/// Menú de filtro con la opción "todos" (`nil`) y los valores del día.
private struct FiltroMenu: View {
    let titulo: String
    let todos: String
    let opciones: [String]
    @Binding var seleccion: String?

    var body: some View {
        Menu {
            Picker(titulo, selection: $seleccion) {
                Text(todos).tag(String?.none)
                ForEach(opciones, id: \.self) { opcion in
                    Text(opcion).tag(String?.some(opcion))
                }
            }
        } label: {
            HStack(spacing: DSSpacing.tiny) {
                Text(seleccion ?? todos)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.up.chevron.down")
                    .font(DSFont.footnote)
                    .accessibilityHidden(true)
            }
            .font(DSFont.bodySecondaryEmphasis)
            .foregroundStyle(seleccion == nil ? DSColor.textPrimary : DSColor.tint)
            .padding(.horizontal, DSSpacing.medium)
            .frame(maxWidth: .infinity, minHeight: DSSize.minTapTarget)
            .dsCardBackground()
        }
        .accessibilityLabel(titulo)
        .accessibilityValue(seleccion ?? todos)
    }
}

/// Fila de Inicio que abre los turnos del personal.
struct TurnosDelPersonalLink: View {
    let service: any TurnosDelPersonalService

    var body: some View {
        NavigationLink {
            TurnosDelPersonalView(service: service)
        } label: {
            HStack(spacing: DSSpacing.medium) {
                Image(systemName: "person.badge.clock")
                    .font(.title3)
                    .foregroundStyle(DSColor.tint)
                    .accessibilityHidden(true)
                ResumenRow(
                    titulo: "Turnos del personal",
                    detalle: "Quién está de turno por día, tipo y área",
                    muestraChevron: true
                )
            }
            .padding(.horizontal, DSSpacing.regular)
            .dsCardBackground()
        }
        .buttonStyle(.plain)
    }
}

#if DEBUG
#Preview {
    NavigationStack { TurnosDelPersonalView(service: PreviewTurnosDelPersonalService()) }
}
#endif
