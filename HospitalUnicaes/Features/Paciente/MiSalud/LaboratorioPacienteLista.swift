import SwiftUI

/// iOS-P7 Laboratorio (segmento de Mi salud): una fila por examen con su badge de estado.
struct LaboratorioPacienteLista: View {
    let laboratorio: LaboratorioPacienteViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            switch laboratorio.estado {
            case .cargando:
                cargando
            case .error(let mensaje):
                error(mensaje)
            case .listo where laboratorio.examenes.isEmpty:
                ContentUnavailableView(
                    "No tienes órdenes de laboratorio",
                    systemImage: "testtube.2",
                    description: Text("Cuando tu médico pida un examen, lo verás aquí.")
                )
            case .listo:
                lista
            }
        }
        .animation(reduceMotion ? nil : .default, value: laboratorio.examenes)
        .animation(reduceMotion ? nil : .default, value: laboratorio.aviso)
        .onChange(of: laboratorio.textoAviso) { _, texto in
            if let texto { AccessibilityNotification.Announcement(texto).post() }
        }
    }

    @ViewBuilder
    private var lista: some View {
        if let aviso = laboratorio.aviso, let texto = laboratorio.textoAviso {
            NavigationLink(value: PacienteRoute.resultado(aviso)) {
                DSBanner(texto, kind: .info)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Abre el resultado")
        }
        ListaTarjeta(items: laboratorio.examenes) { examen in
            NavigationLink(value: PacienteRoute.resultado(examen)) {
                ResumenRow(
                    titulo: examen.nombre,
                    detalle: "\(examen.doctor) · \(Formatting.fechaCorta(examen.fechaSolicitud))",
                    status: examen.estado.status,
                    muestraChevron: true
                )
                .accessibilityLabel(
                    "\(examen.nombre), \(examen.estado.status.title), ordenado por \(examen.doctor) "
                        + "el \(Formatting.diaYMes(examen.fechaSolicitud))"
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var cargando: some View {
        ListaTarjeta(items: Array(0..<4).map(FilaCargando.init)) { _ in
            ResumenRow(
                titulo: "Examen de laboratorio",
                detalle: "Nombre del médico · 14 oct",
                status: .labPendiente,
                muestraChevron: true
            )
        }
        .redacted(reason: .placeholder)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Cargando…")
    }

    private func error(_ mensaje: String) -> some View {
        VStack(spacing: DSSpacing.medium) {
            DSBanner("\(mensaje) Revisa tu conexión e inténtalo de nuevo.", kind: .error)
            DSButton("Reintentar", systemImage: "arrow.clockwise", kind: .secondary, size: .compact) {
                Task { await laboratorio.recargar() }
            }
        }
    }
}

private struct FilaCargando: Identifiable {
    let id: Int
}
