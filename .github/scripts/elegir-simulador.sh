#!/usr/bin/env bash
# Elige un simulador de iPhone para `xcodebuild test` y escribe su id en stdout.
#
# En los runners macos-26, `xcodebuild -showdestinations` a veces no lista ningún simulador
# justo después de `xcode-select` (CoreSimulator todavía arrancando). Por eso:
#   1. Se despierta CoreSimulator con `simctl` y se reintenta `-showdestinations`.
#   2. Si sigue vacío, se toma un iPhone disponible del runtime de iOS más nuevo.
#   3. Si no hay ninguno, se crea uno con el modelo de iPhone más nuevo de ese runtime.
#
# Uso: elegir-simulador.sh <proyecto.xcodeproj> <esquema> [directorio SPM]
set -uo pipefail

proyecto="$1"
esquema="$2"
spm_dir="${3:-}"
intentos="${INTENTOS:-3}"
espera="${ESPERA:-20}"

log() { echo "$*" >&2; }

desde_showdestinations() {
  local args=(-project "$proyecto" -scheme "$esquema" -showdestinations)
  [ -n "$spm_dir" ] && args+=(-clonedSourcePackagesDirPath "$spm_dir")
  xcodebuild "${args[@]}" 2>/dev/null \
    | grep 'platform:iOS Simulator' | grep 'name:iPhone' | grep -v 'placeholder' | head -1 \
    | sed -E 's/.*id:([^,]+),.*/\1/'
}

# Último runtime de iOS instalado y disponible, p. ej. com.apple.CoreSimulator.SimRuntime.iOS-26-5.
runtime_ios() {
  xcrun simctl list runtimes available 2>/dev/null \
    | grep -E '^iOS ' | tail -1 | sed -E 's/.* - (com\.apple\.CoreSimulator\.SimRuntime\.[^ ]+).*/\1/'
}

desde_simctl() {
  local runtime="$1"
  # Sección "-- iOS 26.5 --" del runtime elegido; primer iPhone disponible.
  local version
  version=$(xcrun simctl list runtimes available | grep -F "$runtime" | sed -E 's/^iOS ([0-9.]+).*/\1/')
  xcrun simctl list devices available 2>/dev/null \
    | awk -v sec="-- iOS $version --" '$0 == sec {dentro=1; next} /^-- / {dentro=0} dentro' \
    | grep -E '^\s+iPhone' | head -1 | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/'
}

crear_simulador() {
  local runtime="$1" tipo
  # Solo modelos que ese runtime soporta; se prefiere uno actual y, si no, el último iPhone de la lista.
  tipo=$(xcrun simctl list runtimes -j 2>/dev/null | /usr/bin/python3 -c '
import json, sys
runtime = sys.argv[1]
datos = json.load(sys.stdin)["runtimes"]
tipos = next((r.get("supportedDeviceTypes", []) for r in datos if r["identifier"] == runtime), [])
iphones = [t for t in tipos if t.get("productFamily") == "iPhone"]
preferidos = ["iPhone 17 Pro", "iPhone 17", "iPhone 16 Pro", "iPhone 16"]
elegido = next((t for p in preferidos for t in iphones if t["name"] == p), iphones[-1] if iphones else None)
print(elegido["identifier"] if elegido else "")
' "$runtime")
  [ -z "$tipo" ] && return 1
  log "Creando simulador $tipo con $runtime"
  xcrun simctl create "CI iPhone" "$tipo" "$runtime"
}

# CoreSimulator arranca al primer uso de simctl; también deja diagnóstico en el log.
xcrun simctl list runtimes >&2 || true

for i in $(seq 1 "$intentos"); do
  id=$(desde_showdestinations)
  if [ -n "$id" ]; then
    log "Simulador (showdestinations, intento $i): $id"
    echo "$id"
    exit 0
  fi
  log "showdestinations no listó ningún iPhone (intento $i/$intentos)"
  [ "$i" -lt "$intentos" ] && sleep "$espera"
done

runtime=$(runtime_ios)
if [ -z "$runtime" ]; then
  log "No hay ningún runtime de iOS disponible"
  exit 1
fi

id=$(desde_simctl "$runtime")
if [ -z "$id" ]; then
  id=$(crear_simulador "$runtime") || true
fi

if [ -z "$id" ]; then
  log "No se pudo obtener ni crear un simulador de iPhone"
  xcrun simctl list devices >&2 || true
  exit 1
fi

log "Simulador (simctl, $runtime): $id"
echo "$id"
