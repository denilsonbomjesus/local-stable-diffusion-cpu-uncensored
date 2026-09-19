#!/usr/bin/env bash
# 07_img2img.sh - transforma uma imagem inteira (força baixa => refina; alta => reinventa).
#
# Diferença para o 06_inpainting.sh: aqui NÃO há máscara; a edição vale para a
# imagem toda, controlada por DENOISE (0.20-0.45 refino, 0.75+ muda bastante).
#
# Uso:
#   scripts/07_img2img.sh <input.png> ["prompt"] ["negative"]
#
# Variáveis: DENOISE WIDTH HEIGHT STEPS CFG_SCALE THREADS OUTPUT_DIR
set -euo pipefail

source "$(dirname "$0")/lib/common.sh"

DENOISE="${DENOISE:-0.45}"

INPUT_IMAGE="${1:?Uso: $0 <input.png> [prompt] [negative]}"
PROMPT="${2:-improve realism, natural skin texture, detailed lighting}"
NEGATIVE="${3:-blurry, deformed, extra fingers, bad hands, low quality}"

mkdir -p "$OUTPUT_DIR"

BIN="$(require_sd_bin)"
require_model
OUT="$OUTPUT_DIR/img2img-$(date +%Y%m%d-%H%M%S).png"

if [ ! -f "$INPUT_IMAGE" ]; then
  echo "ERRO: imagem de entrada não encontrada: $INPUT_IMAGE" >&2
  exit 1
fi

# Nomes de flags variam entre builds; detecta pelo --help
pick_init_img_flag() {
  local help_text="$1"
  if grep -q -- '--init-img' <<<"$help_text"; then
    echo '--init-img'
  elif grep -q -- '--image' <<<"$help_text"; then
    echo '--image'
  elif grep -q -- '-i,' <<<"$help_text"; then
    echo '-i'
  else
    echo '--init-img'
  fi
}

pick_strength_flag() {
  local help_text="$1"
  if grep -q -- '--strength' <<<"$help_text"; then
    echo '--strength'
  elif grep -q -- '--img2img-strength' <<<"$help_text"; then
    echo '--img2img-strength'
  elif grep -q -- '--denoise' <<<"$help_text"; then
    echo '--denoise'
  else
    echo '--strength'
  fi
}

HELP_TEXT="$("$BIN" --help 2>&1 || true)"
INIT_FLAG="$(pick_init_img_flag "$HELP_TEXT")"
STRENGTH_FLAG="$(pick_strength_flag "$HELP_TEXT")"

"$BIN" \
  -m "$MODEL_FILE" \
  "$INIT_FLAG" "$INPUT_IMAGE" \
  "$STRENGTH_FLAG" "$DENOISE" \
  -p "$PROMPT" \
  -n "$NEGATIVE" \
  -W "$WIDTH" \
  -H "$HEIGHT" \
  --steps "$STEPS" \
  --cfg-scale "$CFG_SCALE" \
  --threads "$THREADS" \
  -o "$OUT"

echo "$OUT"
