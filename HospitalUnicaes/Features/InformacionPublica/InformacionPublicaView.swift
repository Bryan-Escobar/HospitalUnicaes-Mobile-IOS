import SwiftUI

/// iOS-C5 Información pública (sin sesión). El contenido es de HUNI-76.
struct InformacionPublicaView: View {
    var body: some View {
        ContentUnavailableView(
            "Próximamente",
            systemImage: "building.2",
            description: Text("Aquí verás la ocupación general, los médicos de turno y los avisos del hospital.")
        )
        .foregroundStyle(DSColor.textSecondary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DSColor.background)
        .navigationTitle("Información del hospital")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }
}

#Preview {
    NavigationStack { InformacionPublicaView() }
}
