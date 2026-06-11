#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
RUN_DIR="${ROOT_DIR}/.local/run"
LOG_DIR="${ROOT_DIR}/.local/logs"
PID_FILE="${RUN_DIR}/whisper-metal-server.pid"
LOG_FILE="${LOG_DIR}/whisper-metal-server.log"
PORT="${WHISPER_CPP_SERVER_PORT:-8787}"

mkdir -p "${RUN_DIR}" "${LOG_DIR}" "${ROOT_DIR}/.local/share/ai-analysis-work"

is_running() {
  [[ -f "${PID_FILE}" ]] && kill -0 "$(cat "${PID_FILE}")" 2>/dev/null
}

start() {
  "${SCRIPT_DIR}/setup-whisper-metal.sh"

  if is_running; then
    echo "whisper-metal-server already running on port ${PORT} (pid $(cat "${PID_FILE}"))"
    return 0
  fi

  nohup python3 "${SCRIPT_DIR}/whisper-metal-server.py" >"${LOG_FILE}" 2>&1 &
  echo "$!" >"${PID_FILE}"
  echo "whisper-metal-server started on http://127.0.0.1:${PORT} (log: ${LOG_FILE})"
}

stop() {
  if is_running; then
    kill "$(cat "${PID_FILE}")"
    rm -f "${PID_FILE}"
    echo "whisper-metal-server stopped"
  else
    rm -f "${PID_FILE}"
    echo "whisper-metal-server is not running"
  fi
}

status() {
  if is_running; then
    echo "running (pid $(cat "${PID_FILE}"))"
  else
    echo "stopped"
  fi
}

case "${1:-start}" in
  start) start ;;
  stop) stop ;;
  restart) stop; start ;;
  status) status ;;
  *)
    echo "Usage: $0 {start|stop|restart|status}" >&2
    exit 2
    ;;
esac
