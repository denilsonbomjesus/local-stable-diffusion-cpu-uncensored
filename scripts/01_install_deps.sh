#!/usr/bin/env bash
# 01_install_deps.sh - instala as dependências de build/sistema (Ubuntu/Debian).
# Seguro para rodar novamente: só executa se faltar algo.
set -euo pipefail

source "$(dirname "$0")/lib/common.sh"

need_install=0

check_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Faltando: $1"
    need_install=1
  fi
}

for c in git make cmake ninja g++ pkg-config curl wget; do
  check_cmd "$c"
done

# libcurl é exigida pelo sd-server no stable-diffusion.cpp
if ! dpkg -s libcurl4-openssl-dev >/dev/null 2>&1; then
  echo "Faltando: libcurl4-openssl-dev"
  need_install=1
fi

if [ "$need_install" -eq 0 ]; then
  echo "OK: todas as dependências já estão instaladas."
  exit 0
fi

echo "Instalando dependências..."
sudo apt update
sudo apt install -y \
  git \
  build-essential \
  cmake \
  ninja-build \
  pkg-config \
  libcurl4-openssl-dev \
  curl \
  wget \
  ca-certificates

echo "OK: dependências instaladas."
