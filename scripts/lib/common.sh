#!/usr/bin/env bash
# common.sh - helpers compartilhados por todos os scripts.
# Fonte este arquivo com:  source "$(dirname "$0")/lib/common.sh"

# Raiz do repositório = pai do diretório scripts/
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[1]:-$0}")/.." && pwd)"

# Diretórios do projeto (tudo relativo ao repo; pode sobrescrever por env)
MODELS_DIR="${MODELS_DIR:-$REPO_ROOT/models}"
OUTPUT_DIR="${OUTPUT_DIR:-$REPO_ROOT/outputs}"
INPUTS_DIR="${INPUTS_DIR:-$MODELS_DIR/inputs}"
LOG_DIR="${LOG_DIR:-$REPO_ROOT/logs}"
VENDOR_DIR="$REPO_ROOT/vendor"
SDCPP_DIR="${SDCPP_DIR:-$VENDOR_DIR/stable-diffusion.cpp}"

# Modelo padrão (quantizado q5_0: equilíbrio qualidade/memória em CPU)
MODEL_FILE="${MODEL_FILE:-$MODELS_DIR/CyberRealistic_V8_q5_0.gguf}"

# Parâmetros de geração (defaults ajustáveis por ambiente)
THREADS="${THREADS:-$(nproc)}"
WIDTH="${WIDTH:-512}"
HEIGHT="${HEIGHT:-768}"
STEPS="${STEPS:-24}"
CFG_SCALE="${CFG_SCALE:-7}"
PORT="${PORT:-39100}"

# ---------------------------------------------------------------------------

# Localiza o binário CLI (sd-cli ou sd) dentro de vendor/stable-diffusion.cpp/build
find_sd_bin() {
  find "$SDCPP_DIR/build" -type f \( -name 'sd-cli' -o -name 'sd' \) 2>/dev/null | head -n 1
}

# Localiza o binário do servidor (sd-server), se a build o gerou
find_server_bin() {
  find "$SDCPP_DIR/build" -type f -name 'sd-server' 2>/dev/null | head -n 1
}

# Garante que o binário CLI existe; imprime erro e sai caso contrário
require_sd_bin() {
  local bin
  bin="$(find_sd_bin)"
  if [ -z "$bin" ]; then
    echo "ERRO: binário sd/sd-cli não encontrado em $SDCPP_DIR/build" >&2
    echo "Rode primeiro: $REPO_ROOT/scripts/02_build_sd_cpp.sh" >&2
    exit 1
  fi
  printf '%s' "$bin"
}

# Garante que o modelo GGUF existe
require_model() {
  if [ ! -f "$MODEL_FILE" ]; then
    echo "ERRO: modelo não encontrado: $MODEL_FILE" >&2
    echo "Rode primeiro: $REPO_ROOT/scripts/03_download_cyberrealistic_v8.sh e $REPO_ROOT/scripts/04_convert_v8_to_gguf_q5.sh" >&2
    exit 1
  fi
}

# Selo da revisão vendorizada do stable-diffusion.cpp (usada pelo build)
SDCPP_PIN="${SDCPP_PIN:-d2797b86670622b6538123b4aeb5fbb6be2653c5}"

# Número de jobs de compilação seguro para a RAM disponível.
# Unidades de tradução deste projeto (vocabulários gigantes em headers) podem
# consumir >1.5 GB cada; -j$(nproc) puro estoura a memória em máquinas modestas.
# Sobrescreva com BUILD_JOBS se quiser forçar outro valor.
compute_jobs() {
  local cores ram_kb ram_gb jobs
  cores="$(nproc)"
  if [ -r /proc/meminfo ]; then
    ram_kb="$(awk '/^MemAvailable:/{print $2}' /proc/meminfo)"
    ram_gb=$(( ram_kb / 1024 / 1024 ))
  else
    ram_gb=4 # fallback conservador (macOS/BSD)
  fi
  jobs=$(( ram_gb * 2 / 3 )) # ~1.5 GB por job
  [ "$jobs" -lt 1 ] && jobs=1
  [ "$jobs" -gt "$cores" ] && jobs="$cores"
  echo "$jobs"
}
