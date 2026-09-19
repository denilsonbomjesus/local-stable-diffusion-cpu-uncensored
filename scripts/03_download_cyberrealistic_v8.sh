#!/usr/bin/env bash
# 03_download_cyberrealistic_v8.sh - baixa o checkpoint FP16 do CyberRealistic V8.
# Retomável: wget -c continua de onde parou.
set -euo pipefail

source "$(dirname "$0")/lib/common.sh"

mkdir -p "$MODELS_DIR"

URL="https://huggingface.co/cyberdelia/CyberRealistic/resolve/main/CyberRealistic_V8_FP16.safetensors"
OUT="$MODELS_DIR/CyberRealistic_V8_FP16.safetensors"

if [ -f "$OUT" ]; then
  echo "OK: checkpoint já existe, pulando download: $OUT"
  ls -lh "$OUT"
  exit 0
fi

echo "Baixando modelo (~2.1 GB, pode demorar)..."
wget -c --content-disposition -O "$OUT" "$URL"

echo
echo "Download concluído:"
ls -lh "$OUT"
