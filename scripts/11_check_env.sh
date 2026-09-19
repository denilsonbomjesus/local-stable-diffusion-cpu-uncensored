#!/usr/bin/env bash
# 11_check_env.sh - valida o ambiente: dependências, build e modelo.
# Não executa o modelo; apenas diagnostica.
set -euo pipefail

source "$(dirname "$0")/lib/common.sh"

status=0

ok()   { echo "  [OK]    $1"; }
fail() { echo "  [FALHA] $1"; status=1; }

echo "== Dependências =="
for c in git make cmake ninja g++ pkg-config curl wget; do
  if command -v "$c" >/dev/null 2>&1; then ok "$c"; else fail "$c (rode scripts/01_install_deps.sh)"; fi
done

echo
echo "== Vendor stable-diffusion.cpp =="
if [ -e "$SDCPP_DIR/.git" ]; then
  ok "$SDCPP_DIR"
  rev="$(git -C "$SDCPP_DIR" rev-parse HEAD 2>/dev/null || echo '?')"
  if [ "$rev" = "$SDCPP_PIN" ]; then
    ok "revisão $rev (confere com o pin)"
  else
    fail "revisão $rev difere do pin $SDCPP_PIN (veja docs/VENDORING.md)"
  fi
else
  fail "vendor ausente: $SDCPP_DIR"
fi

echo
echo "== Build =="
bin="$(find_sd_bin)"
if [ -n "$bin" ]; then
  ok "binário: $bin"
else
  fail "binário sd/sd-cli não encontrado (rode scripts/02_build_sd_cpp.sh)"
fi
server_bin="$(find_server_bin)"
if [ -n "$server_bin" ]; then
  ok "servidor: $server_bin"
else
  echo "  [AVISO] sd-server não encontrado (fallback sd --server será usado)"
fi

echo
echo "== Modelo =="
if [ -f "$MODEL_FILE" ]; then
  ok "$MODEL_FILE ($(du -h "$MODEL_FILE" | cut -f1))"
else
  fail "$MODEL_FILE ausente (rode scripts/03 e 04)"
fi
if [ -f "$MODELS_DIR/CyberRealistic_V8_FP16.safetensors" ]; then
  ok "checkpoint FP16 presente (para reconversões)"
else
  echo "  [AVISO] checkpoint FP16 ausente (necessário apenas para reconverter GGUF)"
fi

echo
if [ "$status" -eq 0 ]; then
  echo "Resultado: ambiente pronto."
else
  echo "Resultado: há pendências acima."
fi
exit "$status"
