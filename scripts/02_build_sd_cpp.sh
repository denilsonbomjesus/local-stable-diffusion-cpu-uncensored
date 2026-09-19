#!/usr/bin/env bash
# 02_build_sd_cpp.sh - compila o stable-diffusion.cpp (vendor/stable-diffusion.cpp) em CPU.
#
# - Já existe build válida e SD_SKIP_BUILD=1? Sai imediatamente (modo rápido).
# - Sem SD_SKIP_BUILD: se já houver binário, valida contra o commit fixado
#   (SDCPP_PIN, ver scripts/lib/common.sh). Confirma? Sai. Divergente? Recompila.
set -euo pipefail

source "$(dirname "$0")/lib/common.sh"

BUILD_DIR="$SDCPP_DIR/build"
BUILD_STAMP="$BUILD_DIR/.build-stamp"

find_bin() {
  find "$BUILD_DIR" -type f \( -name 'sd-cli' -o -name 'sd' \) 2>/dev/null | head -n 1
}

existing_bin="$(find_bin || true)"

# ---------------------------------------------------------------- fast path
if [ -n "$existing_bin" ] && [ "${SD_SKIP_BUILD:-0}" = "1" ]; then
  echo "OK: build existente em $BUILD_DIR (SD_SKIP_BUILD=1, validação pulada)."
  exit 0
fi

# ------------------------------------------------- validação do build atual
if [ -n "$existing_bin" ]; then
  if [ -f "$BUILD_STAMP" ]; then
    pinned_rev="$(cat "$BUILD_STAMP")"
  else
    pinned_rev="(stamp ausente)"
  fi

  if [ "$pinned_rev" = "$SDCPP_PIN" ]; then
    echo "OK: binário existente corresponde ao commit fixado ($SDCPP_PIN). Nada a fazer."
    exit 0
  fi

  echo "AVISO: já existe um build em $BUILD_DIR (revisão: $pinned_rev)."
  echo "        Esperado: $SDCPP_PIN"
  echo "        Recompilar leva alguns minutos. Interrompa (Ctrl+C) para manter o build atual."
  read -r -p "Recompilar de qualquer forma? [y/N] " answer || answer="n"
  if [ "${answer:-n}" != "y" ]; then
    echo "Mantendo o build existente."
    exit 0
  fi
fi

# ------------------------------------------------------------- build limpo
if [ ! -e "$SDCPP_DIR/.git" ]; then
  echo "ERRO: $SDCPP_DIR não é um repositório git (submódulo ausente?)." >&2
  echo "      Baixe-o com: git submodule update --init --recursive" >&2
  exit 1
fi

echo "Compilando stable-diffusion.cpp (Release, CPU)..."
cmake -S "$SDCPP_DIR" -B "$BUILD_DIR" -G Ninja -DCMAKE_BUILD_TYPE=Release

cmake --build "$BUILD_DIR" -j"${BUILD_JOBS:-$(compute_jobs)}"

new_bin="$(find_bin)"
if [ -z "$new_bin" ]; then
  echo "ERRO: build concluída, mas nenhum binário sd/sd-cli foi encontrado." >&2
  exit 1
fi

printf '%s' "$SDCPP_PIN" > "$BUILD_STAMP"
echo "OK: build concluída e registrada em $BUILD_STAMP"
echo
echo "Binários:"
find "$BUILD_DIR" -maxdepth 4 -type f \( -name 'sd' -o -name 'sd-cli' -o -name 'sd-server' \) | sort
