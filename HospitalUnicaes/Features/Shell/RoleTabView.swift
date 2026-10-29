import SwiftUI

/// Pestañas del doctor; Inicio las abre desde sus tarjetas.
enum DoctorTab: Hashable {
    case inicio, agenda, pacientes, turnos, perfil
}

/// Pestañas del paciente.
enum PacienteTab: Hashable {
    case inicio, citas, miSalud, ambulancia, perfil
}

/// Ícono de contorno como en el Figma (iOS rellena los íconos de la TabBar por defecto).
private struct TabLabel: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .environment(\.symbolVariants, .none)
    }
}

/// TabView Doctor: Inicio · Agenda · Pacientes · Turnos · Perfil (Figma 44:1115).
struct DoctorTabView: View {
    let me: Me
    @State private var tab: DoctorTab = .inicio
    @Environment(\.doctorDependencies) private var dependencies
    @Environment(\.healthService) private var health

    var body: some View {
        TabView(selection: $tab) {
            DoctorInicioView(me: me) { tab = $0 }
                .tabItem { TabLabel(title: "Inicio", systemImage: "house") }
                .tag(DoctorTab.inicio)
            AgendaView(dependencies: dependencies)
                .tabItem { TabLabel(title: "Agenda", systemImage: "calendar") }
                .tag(DoctorTab.agenda)
            PacientesView(dependencies: dependencies)
                .tabItem { TabLabel(title: "Pacientes", systemImage: "person.2") }
                .tag(DoctorTab.pacientes)
            TurnosView()
                .tabItem { TabLabel(title: "Turnos", systemImage: "clock") }
                .tag(DoctorTab.turnos)
            PerfilView(viewModel: PerfilViewModel(me: me, health: health))
                .tabItem { TabLabel(title: "Perfil", systemImage: "person.crop.circle") }
                .tag(DoctorTab.perfil)
        }
        .tint(DSColor.tint)
    }
}

/// TabView Paciente: Inicio · Citas · Mi salud · Ambulancia · Perfil.
struct PacienteTabView: View {
    let me: Me
    @State private var tab: PacienteTab = .inicio
    @State private var miSalud = MiSaludViewModel()
    @Environment(\.healthService) private var health

    var body: some View {
        TabView(selection: $tab) {
            PacienteInicioView(me: me) { destino, segmento in
                if let segmento { miSalud.segmento = segmento }
                tab = destino
            }
            .tabItem { TabLabel(title: "Inicio", systemImage: "house") }
            .tag(PacienteTab.inicio)
            CitasPacienteView()
                .tabItem { TabLabel(title: "Citas", systemImage: "calendar") }
                .tag(PacienteTab.citas)
            MiSaludView(viewModel: miSalud)
                .tabItem { TabLabel(title: "Mi salud", systemImage: "heart.text.square") }
                .tag(PacienteTab.miSalud)
            AmbulanciaPacienteView()
                .tabItem { TabLabel(title: "Ambulancia", systemImage: "light.beacon.max") }
                .tag(PacienteTab.ambulancia)
            PerfilView(viewModel: PerfilViewModel(me: me, health: health))
                .tabItem { TabLabel(title: "Perfil", systemImage: "person.crop.circle") }
                .tag(PacienteTab.perfil)
        }
        .tint(DSColor.tint)
    }
}

#Preview("Doctor") {
    DoctorTabView(me: .previewDoctor)
        .environment(SessionViewModel.preview())
        .environment(\.doctorDependencies, .preview)
}

#Preview("Paciente") {
    PacienteTabView(me: .previewPaciente)
        .environment(SessionViewModel.preview())
}
