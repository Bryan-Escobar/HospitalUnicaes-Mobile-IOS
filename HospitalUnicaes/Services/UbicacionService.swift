import CoreLocation
import Foundation

enum EstadoPermisoUbicacion: Equatable, Sendable {
    case noDeterminado, permitido, denegado
}

enum UbicacionError: Error, Equatable {
    case permisoDenegado
    /// Sin lectura en 10 s o `kCLErrorLocationUnknown`.
    case sinSenal
}

/// Una lectura del GPS para enviarla con la solicitud de ambulancia. Solo "cuando se usa
/// la app", sin segundo plano; la ubicación no se guarda ni se registra en logs.
@MainActor
protocol UbicacionService: AnyObject {
    var autorizacion: EstadoPermisoUbicacion { get }
    /// Pide permiso si hace falta, toma una lectura y la convierte en dirección.
    func ubicacionActual() async throws -> Ubicacion
}

@MainActor
final class CoreLocationUbicacionService: NSObject, UbicacionService, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var permiso: CheckedContinuation<EstadoPermisoUbicacion, Never>?
    private var lectura: CheckedContinuation<CLLocation, Error>?
    private let timeout: Duration

    init(timeout: Duration = .seconds(10)) {
        self.timeout = timeout
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
    }

    var autorizacion: EstadoPermisoUbicacion {
        Self.estado(manager.authorizationStatus)
    }

    func ubicacionActual() async throws -> Ubicacion {
        var estado = autorizacion
        if estado == .noDeterminado {
            estado = await withCheckedContinuation { continuation in
                permiso = continuation
                manager.requestWhenInUseAuthorization()
            }
        }
        guard estado == .permitido else { throw UbicacionError.permisoDenegado }

        let location = try await leerConTimeout()
        return Ubicacion(
            latitud: location.coordinate.latitude,
            longitud: location.coordinate.longitude,
            precisionM: max(0, Int(location.horizontalAccuracy.rounded())),
            direccion: await direccion(de: location)
        )
    }

    private func leerConTimeout() async throws -> CLLocation {
        let timeout = timeout
        let espera = Task { [weak self] in
            try await Task.sleep(for: timeout)
            self?.terminarLectura(.failure(UbicacionError.sinSenal))
        }
        defer { espera.cancel() }
        return try await withCheckedThrowingContinuation { continuation in
            lectura = continuation
            manager.requestLocation()
        }
    }

    private func terminarLectura(_ result: Result<CLLocation, Error>) {
        lectura?.resume(with: result)
        lectura = nil
    }

    /// "Col. Escalón, San Salvador". Si el geocoder falla, la lectura sigue siendo válida.
    private func direccion(de location: CLLocation) async -> String? {
        guard let lugar = try? await CLGeocoder().reverseGeocodeLocation(location).first else { return nil }
        let partes = [lugar.subLocality ?? lugar.thoroughfare, lugar.locality].compactMap { $0?.nilIfBlank }
        return partes.isEmpty ? nil : partes.joined(separator: ", ")
    }

    nonisolated private static func estado(_ status: CLAuthorizationStatus) -> EstadoPermisoUbicacion {
        switch status {
        case .notDetermined: .noDeterminado
        case .authorizedAlways, .authorizedWhenInUse: .permitido
        default: .denegado
        }
    }

    // MARK: CLLocationManagerDelegate

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let estado = Self.estado(manager.authorizationStatus)
        Task { @MainActor in
            guard estado != .noDeterminado else { return }
            self.permiso?.resume(returning: estado)
            self.permiso = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in self.terminarLectura(.success(location)) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let denegado = (error as? CLError)?.code == .denied
        Task { @MainActor in
            self.terminarLectura(.failure(denegado ? UbicacionError.permisoDenegado : UbicacionError.sinSenal))
        }
    }
}
