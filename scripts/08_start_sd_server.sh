#!/usr/bin/env bash
# 08_start_sd_server.sh - sobe o servidor HTTP local (foreground; Ctrl+C para parar).
#
# Uso: scripts/08_start_sd_server.sh
# Variáveis: PORT THREADS MODEL_FILE LOG_DIR
# Para rodar como serviço systemd --user, use o script 09.
set -euo pipefail

source "$(dirname "$0")/lib/common.sh"

mkdir -p "$LOG_DIR"

SERVER_BIN="$(find_server_bin)"
CLI_BIN="$(find_sd_bin)"

if [ -z "$SERVER_BIN" ] && [ -z "$CLI_BIN" ]; then
  echo "ERRO: nenhum binário compatível encontrado em $SDCPP_DIR/build" >&2
  echo "Rode primeiro: $REPO_ROOT/scripts/02_build_sd_cpp.sh" >&2
  exit 1
fi

if [ -n "$SERVER_BIN" ]; then
  # sd-server novo: --listen-port e --model; threads usam -t (igual à CLI)
  exec "$SERVER_BIN" \
    -m "$MODEL_FILE" \
    -t "$THREADS" \
    --listen-port "$PORT" \
    >>"$LOG_DIR/sd-server.log" 2>&1
fi

# Fallback para builds antigos sem sd-server (sd/sd-cli --server)
exec "$CLI_BIN" \
  -m "$MODEL_FILE" \
  --threads "$THREADS" \
  --server \
  --port "$PORT" \
  >>"$LOG_DIR/sd-server.log" 2>&1
