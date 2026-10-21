# HospitalUnicaes-Mobile-IOS

App iOS del sistema de gestión del Hospital Universitario Central (HospitalUnicaes), para **Doctores** y **Pacientes**: citas y turnos, consultas, órdenes y resultados de laboratorio, historial clínico y solicitud de ambulancia.

Stack: Swift 5 + SwiftUI, iOS 17+, arquitectura **MVVM** con `async/await` y `@Observable`. La autenticación usa Supabase Auth (`supabase-swift` por SPM); los datos de negocio se piden al backend unificado ([HospitalUnicaes-Api](https://github.com/Bryan-Escobar/HospitalUnicaes-Api)).

- Reglas de negocio y privacidad: [`context.md`](./context.md)
- Ramas, commits y Pull Requests: [`CONTRIBUTING.md`](./CONTRIBUTING.md)

## Requisitos

- macOS con Xcode 16 o superior (el proyecto usa carpetas sincronizadas, formato de Xcode 16)
- Opcional: [SwiftLint](https://github.com/realm/SwiftLint) (`brew install swiftlint`). Si no está instalado, el build muestra un aviso y continúa.

## Ejecutar

1. `git clone https://github.com/Bryan-Escobar/HospitalUnicaes-Mobile-IOS.git && git checkout development`
2. Copia `Config/Secrets.example.xcconfig` como `Config/Secrets.xcconfig` y completa la URL y la anon key de Supabase. Este archivo está en `.gitignore`.
3. Abre `HospitalUnicaes.xcodeproj`. Xcode descarga `supabase-swift` automáticamente.
4. Elige el esquema `HospitalUnicaes` y un simulador de iPhone, y ejecuta (⌘R).

Sin `Secrets.xcconfig` la app abre igual, pero el login muestra que Supabase no está configurado.

## Ambientes (xcconfig)

| Configuración | Archivo | Uso |
|---|---|---|
| Debug | `Config/Dev.xcconfig` | Desarrollo en simulador; `API_BASE_URL` apunta a `localhost:3000` |
| Release | `Config/Prod.xcconfig` | Archivo/TestFlight; completar URLs de producción |

Ambos incluyen `Config/Shared.xcconfig` (bundle id, versión mínima) y, si existe, `Config/Secrets.xcconfig`. Los valores llegan a la app por `Config/Info.plist` y se leen en `Core/Config/AppConfig.swift`.

En un `.xcconfig`, `//` inicia un comentario: escribe las URLs como `https:/$()/host`.

## Estructura (MVVM)

```
HospitalUnicaes/
├── App/                    # Punto de entrada, RootView y estado global de sesión
│   ├── HospitalUnicaesApp.swift
│   ├── RootView.swift
│   └── SessionViewModel.swift
├── Core/                   # Código compartido sin UI: configuración, modelos, utilidades
│   ├── Config/AppConfig.swift
│   └── Models.swift
├── Features/               # Una carpeta por funcionalidad: View + ViewModel
│   ├── Auth/               # LoginView, LoginViewModel
│   └── Home/               # HomeView
├── Services/               # Acceso a red y SDKs (Supabase Auth, cliente de la API)
│   └── AuthService.swift
└── Resources/              # Assets.xcassets
```

Reglas:
- **View** (SwiftUI) solo dibuja y reenvía acciones al ViewModel. Sin llamadas de red ni lógica de negocio.
- **ViewModel** (`@MainActor @Observable`) expone estado (`isLoading`, `errorMessage`, datos) y métodos `async`.
- **Service** encapsula la red o el SDK detrás de un protocolo, para poder sustituirlo en previews y tests.
- Una funcionalidad nueva va en `Features/<Nombre>/` con su `<Nombre>View.swift` y `<Nombre>ViewModel.swift`.

La carpeta `HospitalUnicaes/` está sincronizada con Xcode: cualquier archivo que agregues dentro entra al target sin editar el proyecto.

## Ramas

| Rama | Uso |
|---|---|
| `prod` | Producción |
| `staging` | Pruebas e integración |
| `development` | Integración diaria; todo PR de tarea apunta aquí |

Ramas de tarea: `HUNI-<n>-<titulo-en-kebab>` (ej. `HUNI-19-scaffold-ios-swiftui-mvvm`). Detalle en `CONTRIBUTING.md`.
