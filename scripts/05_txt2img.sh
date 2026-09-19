#!/usr/bin/env bash
# 05_txt2img.sh - gera imagem a partir de texto.
#
# Uso:
#   scripts/05_txt2img.sh "prompt" ["negative prompt"]
#
# Variáveis: WIDTH HEIGHT STEPS CFG_SCALE THREADS OUTPUT_DIR (ver scripts/lib/common.sh)
set -euo pipefail

source "$(dirname "$0")/lib/common.sh"

PROMPT="${1:-portrait photo of a person, realistic skin, natural light, detailed face}"
NEGATIVE="${2:-blurry, deformed, extra fingers, bad hands, low quality}"

mkdir -p "$OUTPUT_DIR"

BIN="$(require_sd_bin)"
require_model
OUT="$OUTPUT_DIR/txt2img-$(date +%Y%m%d-%H%M%S).png"

"$BIN" \
  -m "$MODEL_FILE" \
  -p "$PROMPT" \
  -n "$NEGATIVE" \
  -W "$WIDTH" \
  -H "$HEIGHT" \
  --steps "$STEPS" \
  --cfg-scale "$CFG_SCALE" \
  --threads "$THREADS" \
  -o "$OUT"

echo "$OUT"
