#!/usr/bin/env bash
# 00_setup_dirs.sh - cria a árvore de diretórios de trabalho do projeto.
set -euo pipefail

source "$(dirname "$0")/lib/common.sh"

mkdir -p \
  "$MODELS_DIR/inputs" \
  "$OUTPUT_DIR" \
  "$LOG_DIR"

echo "OK: árvore de diretórios pronta em $REPO_ROOT"
