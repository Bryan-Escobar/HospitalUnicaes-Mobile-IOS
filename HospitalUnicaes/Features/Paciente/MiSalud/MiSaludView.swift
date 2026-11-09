import SwiftUI

/// iOS-P5 / P7 / P9 Mi salud. El laboratorio se escucha en vivo mientras la pestaña
/// está visible y la app activa; el canal sigue abierto al entrar a iOS-P8.
struct MiSaludView: View {
    @Bindable var viewModel: MiSaludViewModel
    let laboratorio: LaboratorioPacienteViewModel
    /// La pestaña Mi salud está seleccionada.
    var activo = true
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DSSpacing.medium) {
                    Picker("Sección", selection: $viewModel.segmento) {
                        ForEach(MiSaludSegmento.allCases) { segmento in
                            Text(segmento.titulo).tag(segmento)
                        }
                    }
                    .pickerStyle(.segmented)
                    switch viewModel.segmento {
                    case .historial: historial
                    case .laboratorio: LaboratorioPacienteLista(laboratorio: laboratorio)
                    case .habitacion: habitacion
                    }
                }
                .pantallaPrincipal()
            }
            .refreshable {
                if viewModel.segmento == .laboratorio { await laboratorio.recargar() }
            }
            .background(DSColor.backgroundGrouped)
            .navigationTitle("Mi salud")
            .toolbar {
                if viewModel.segmento == .laboratorio {
                    if #available(iOS 26, *) {
                        // Sin la cápsula de vidrio de la barra: el chip ya trae su propio fondo.
                        ToolbarItem(placement: .topBarTrailing) {
                            DSLiveIndicator(laboratorio.conexion)
                        }
                        .sharedBackgroundVisibility(.hidden)
                    } else {
                        ToolbarItem(placement: .topBarTrailing) {
                            DSLiveIndicator(laboratorio.conexion)
                        }
                    }
                }
            }
            .navigationDestination(for: PacienteRoute.self) { PacienteDestination(route: $0) }
        }
        .task(id: escuchando) {
            if escuchando { await laboratorio.escuchar() }
        }
        .onChange(of: activo) { _, visible in
            if !visible { laboratorio.descartarAviso() }
        }
        .environment(laboratorio)
    }

    private var escuchando: Bool {
        activo && scenePhase == .active
    }

    @ViewBuilder
    private var historial: some View {
        if let alergias = viewModel.alergias {
            AlergiaBanner(texto: "Alergias: \(alergias)")
        }
        if viewModel.consultas.isEmpty {
            ContentUnavailableView("Sin consultas registradas", systemImage: "text.page")
        } else {
            ListaTarjeta(items: viewModel.consultas) { consulta in
                NavigationLink(value: PacienteRoute.consulta(consulta)) {
                    ResumenRow(
                        titulo: "\(Formatting.fechaCorta(consulta.fecha)) · \(consulta.diagnostico)",
                        detalle: "\(consulta.doctor) · \(consulta.especialidad)",
                        muestraChevron: true
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var habitacion: some View {
        if let habitacion = viewModel.habitacion {
            HabitacionCard(habitacion: habitacion)
            if let anterior = habitacion.trasladoDesde {
                DSBanner("Traslado registrado. Antes: \(anterior).", kind: .info)
            }
            Label("Información privada: solo la ven tú, tu médico y la administración.", systemImage: "lock")
                .font(DSFont.footnote)
                .foregroundStyle(DSColor.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            ContentUnavailableView(
                "No estás hospitalizado",
                systemImage: "bed.double",
                description: Text("Si te ingresan, aquí verás tu habitación y cama.")
            )
        }
    }
}

private struct HabitacionCard: View {
    let habitacion: HabitacionPaciente

    var body: some View {
        DSCard(spacing: DSSpacing.medium) {
            HStack(spacing: 14) {
                Image(systemName: "bed.double")
                    .font(.title)
                    .foregroundStyle(DSColor.avatarForeground)
                    .frame(width: 56, height: 56)
                    .background(DSColor.avatarBackground, in: RoundedRectangle(cornerRadius: 16))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 0) {
                    Text(habitacion.codigo).font(.system(.largeTitle, weight: .bold))
                    Text(habitacion.cama).font(DSFont.subtitle)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                DSStatusBadge(DSStatus(domain: "Habitación", title: habitacion.tipo.nombre, systemImage: nil, tone: .neutral))
            }
            ForEach(
                [
                    ("Planta", habitacion.planta),
                    ("Ingreso", Formatting.fechaYHora(habitacion.ingreso)),
                    ("Médico tratante", habitacion.medicoTratante),
                ],
                id: \.0
            ) { titulo, valor in
                HStack {
                    Text(titulo).font(DSFont.bodySecondary).foregroundStyle(DSColor.textSecondary)
                    Spacer()
                    Text(valor).font(DSFont.bodySecondaryEmphasis)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }
}

/// iOS-P6 Detalle de consulta (vista del paciente).
struct DetalleConsultaPacienteView: View {
    let consulta: ConsultaPaciente

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DSSpacing.medium) {
                Text("\(consulta.doctor) · \(consulta.especialidad)")
                    .font(DSFont.bodySecondary)
                    .foregroundStyle(DSColor.textSecondary)
                DSCard {
                    Text("Diagnóstico").font(DSFont.footnote).foregroundStyle(DSColor.textSecondary)
                    Text(consulta.diagnostico).font(DSFont.bodySecondaryEmphasis)
                }
                DSCard {
                    Text("Recetas").font(DSFont.subtitle)
                    if consulta.recetas.isEmpty {
                        Text("Sin recetas").font(DSFont.bodySecondary).foregroundStyle(DSColor.textSecondary)
                    }
                    ForEach(consulta.recetas) { receta in
                        ResumenRow(titulo: receta.medicamento, detalle: receta.indicacion)
                    }
                }
                DSCard {
                    Text("Órdenes de laboratorio").font(DSFont.subtitle)
                    if consulta.ordenes.isEmpty {
                        Text("Sin órdenes").font(DSFont.bodySecondary).foregroundStyle(DSColor.textSecondary)
                    }
                    ForEach(consulta.ordenes) { orden in
                        NavigationLink(value: PacienteRoute.resultado(orden)) {
                            ResumenRow(titulo: orden.nombre, status: orden.estado.status, muestraChevron: true)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .pantallaPrincipal()
        }
        .background(DSColor.backgroundGrouped)
        .navigationTitle("Consulta · \(Formatting.fechaCorta(consulta.fecha))")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Destinos de las pilas del paciente.
struct PacienteDestination: View {
    let route: PacienteRoute

    var body: some View {
        switch route {
        case .cita(let cita): DetalleCitaPacienteView(cita: cita)
        case .consulta(let consulta): DetalleConsultaPacienteView(consulta: consulta)
        case .resultado(let examen): ResultadoLaboratorioView(examen: examen)
        }
    }
}

#Preview {
    let dependencies = PacienteDependencies.preview
    MiSaludView(
        viewModel: MiSaludViewModel(),
        laboratorio: LaboratorioPacienteViewModel(
            service: dependencies.laboratorio,
            realtime: dependencies.laboratorioRealtime
        )
    )
    .environment(\.pacienteDependencies, dependencies)
}
