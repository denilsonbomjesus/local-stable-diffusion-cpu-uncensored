#!/usr/bin/env bash
# 06_inpainting.sh - inpainting localizado: edita apenas a região demarcada pela máscara.
#
# A máscara é uma imagem do mesmo tamanho da entrada; área BRANCA = região editada,
# área PRETA = preservada. (O script 07_img2img.sh altera a imagem inteira.)
#
# Uso:
#   scripts/06_inpainting.sh <input.png> <mask.png> ["prompt"] ["negative"]
#
# Variáveis: DENOISE WIDTH HEIGHT STEPS CFG_SCALE THREADS OUTPUT_DIR
set -euo pipefail

source "$(dirname "$0")/lib/common.sh"

THREADS="${THREADS:-$(nproc)}"
WIDTH="${WIDTH:-512}"
HEIGHT="${HEIGHT:-768}"
STEPS="${STEPS:-24}"
CFG_SCALE="${CFG_SCALE:-7}"
DENOISE="${DENOISE:-0.85}" # Denoise alto é necessário no inpainting para mudar a forma da roupa

INPUT_IMAGE="${1:?Uso: $0 <input.png> <mask.png> [prompt] [negative]}"
MASK_IMAGE="${2:?Uso: $0 <input.png> <mask.png> [prompt] [negative]}"
PROMPT="${3:-person wearing casual shorts, bare calves, detailed realistic skin}"
NEGATIVE="${4:-long pants, jeans, trousers, bad proportions}"

mkdir -p "$OUTPUT_DIR"

BIN="$(require_sd_bin)"
require_model
OUT="$OUTPUT_DIR/inpainting-$(date +%Y%m%d-%H%M%S).png"

if [ ! -f "$MASK_IMAGE" ]; then
  echo "ERRO: máscara não encontrada: $MASK_IMAGE" >&2
  exit 1
fi

"$BIN" \
  -m "$MODEL_FILE" \
  -i "$INPUT_IMAGE" \
  --mask "$MASK_IMAGE" \
  --strength "$DENOISE" \
  -p "$PROMPT" \
  -n "$NEGATIVE" \
  -W "$WIDTH" \
  -H "$HEIGHT" \
  --steps "$STEPS" \
  --cfg-scale "$CFG_SCALE" \
  --threads "$THREADS" \
  -o "$OUT"

echo "$OUT"
