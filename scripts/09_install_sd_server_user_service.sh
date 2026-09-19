#!/usr/bin/env bash
# 09_install_sd_server_user_service.sh - instala o servidor como serviço systemd --user.
# Opcional: só use se quiser o servidor rodando como serviço persistente.
#
# Gera a unidade em tempo de instalação com o caminho absoluto deste clone
# ($REPO_ROOT), então funciona em qualquer diretório onde o repo foi clonado.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
USER_SYSTEMD_DIR="$HOME/.config/systemd/user"
PORT="${PORT:-39100}"

if ! command -v systemctl >/dev/null 2>&1; then
  echo "ERRO: systemctl não encontrado (systemd indisponível?)." >&2
  echo "Use o modo foreground: $REPO_ROOT/scripts/08_start_sd_server.sh" >&2
  exit 1
fi

mkdir -p "$USER_SYSTEMD_DIR"

cat > "$USER_SYSTEMD_DIR/sd-server.service" <<EOF
# Gerado por scripts/09_install_sd_server_user_service.sh em $(date '+%Y-%m-%d %H:%M:%S')
# Clone: $REPO_ROOT
[Unit]
Description=stable-diffusion.cpp local server (CyberRealistic V8, CPU)
After=default.target

[Service]
Type=simple
WorkingDirectory=$REPO_ROOT
Environment=PORT=$PORT
ExecStart=$REPO_ROOT/scripts/08_start_sd_server.sh
Restart=on-failure
RestartSec=3

[Install]
WantedBy=default.target
EOF

systemctl --user daemon-reload
systemctl --user enable sd-server.service

echo "Unidade gerada e instalada em: $USER_SYSTEMD_DIR/sd-server.service"
echo "  Clone: $REPO_ROOT | Porta: $PORT"
echo "Para iniciar:"
echo "  systemctl --user start sd-server.service"
echo "Para verificar:"
echo "  systemctl --user status sd-server.service"
