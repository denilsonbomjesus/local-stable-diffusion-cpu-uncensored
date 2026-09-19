#!/usr/bin/env bash
# 04_convert_v8_to_gguf_q5.sh - converte o checkpoint FP16 para GGUF quantizado (q5_0).
# Pula se o GGUF já existir.
set -euo pipefail

source "$(dirname "$0")/lib/common.sh"

SRC="$MODELS_DIR/CyberRealistic_V8_FP16.safetensors"
DST="$MODEL_FILE"

BIN="$(require_sd_bin)"

if [ ! -f "$SRC" ]; then
  echo "ERRO: arquivo fonte não encontrado: $SRC" >&2
  echo "Rode primeiro: $REPO_ROOT/scripts/03_download_cyberrealistic_v8.sh" >&2
  exit 1
fi

if [ -f "$DST" ]; then
  echo "OK: GGUF já existe, pulando conversão: $DST"
  ls -lh "$DST"
  exit 0
fi

"$BIN" -M convert -m "$SRC" -o "$DST" -v --type q5_0

echo
echo "Conversão concluída:"
ls -lh "$DST"
