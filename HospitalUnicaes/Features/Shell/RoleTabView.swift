import SwiftUI

/// Pestaña del armazón: título y vista vacía hasta que HUNI-42 la llene.
struct PlaceholderTabView: View {
    let title: String
    let systemImage: String

    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                title,
                systemImage: systemImage,
                description: Text("Esta sección estará disponible pronto.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(DSColor.backgroundGrouped)
            .navigationTitle(title)
        }
    }
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
    @Environment(\.doctorDependencies) private var dependencies
    @Environment(\.healthService) private var health

    var body: some View {
        TabView {
            PlaceholderTabView(title: "Inicio", systemImage: "house")
                .tabItem { TabLabel(title: "Inicio", systemImage: "house") }
            AgendaView(dependencies: dependencies)
                .tabItem { TabLabel(title: "Agenda", systemImage: "calendar") }
            PacientesView(dependencies: dependencies)
                .tabItem { TabLabel(title: "Pacientes", systemImage: "person.2") }
            PlaceholderTabView(title: "Turnos", systemImage: "clock")
                .tabItem { TabLabel(title: "Turnos", systemImage: "clock") }
            PerfilView(viewModel: PerfilViewModel(me: me, health: health))
                .tabItem { TabLabel(title: "Perfil", systemImage: "person.crop.circle") }
        }
        .tint(DSColor.tint)
    }
}

/// TabView Paciente: Inicio · Citas · Mi salud · Ambulancia · Perfil.
struct PacienteTabView: View {
    let me: Me
    @Environment(\.healthService) private var health

    var body: some View {
        TabView {
            PlaceholderTabView(title: "Inicio", systemImage: "house")
                .tabItem { TabLabel(title: "Inicio", systemImage: "house") }
            PlaceholderTabView(title: "Citas", systemImage: "calendar")
                .tabItem { TabLabel(title: "Citas", systemImage: "calendar") }
            PlaceholderTabView(title: "Mi salud", systemImage: "heart.text.square")
                .tabItem { TabLabel(title: "Mi salud", systemImage: "heart.text.square") }
            PlaceholderTabView(title: "Ambulancia", systemImage: "light.beacon.max")
                .tabItem { TabLabel(title: "Ambulancia", systemImage: "light.beacon.max") }
            PerfilView(viewModel: PerfilViewModel(me: me, health: health))
                .tabItem { TabLabel(title: "Perfil", systemImage: "person.crop.circle") }
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
