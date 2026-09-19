#!/usr/bin/env bash
# 10_install_wrappers.sh - cria symlinks de conveniência em ~/.local/bin
# (run-txt2img, run-inpainting, run-img2img, start-sd-server).
# Idempotente: pode rodar quantas vezes quiser.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

mkdir -p "$HOME/.local/bin"

link() {
  local name="$1" target="$2"
  ln -sfn "$target" "$HOME/.local/bin/$name"
}

link run-txt2img     "$REPO_ROOT/scripts/05_txt2img.sh"
link run-inpainting  "$REPO_ROOT/scripts/06_inpainting.sh"
link run-img2img     "$REPO_ROOT/scripts/07_img2img.sh"
link start-sd-server "$REPO_ROOT/scripts/08_start_sd_server.sh"

echo "Wrappers instalados em: $HOME/.local/bin"

case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *)
    echo
    echo "AVISO: $HOME/.local/bin não está no PATH."
    echo "Adicione ao seu ~/.bashrc e reabra o terminal:"
    echo '  export PATH="$HOME/.local/bin:$PATH"'
    ;;
esac
