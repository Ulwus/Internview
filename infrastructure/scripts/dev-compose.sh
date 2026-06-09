#!/usr/bin/env sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)
ENV_FILE="$ROOT_DIR/.env"
COMPOSE_FILE="$ROOT_DIR/infrastructure/docker-compose.yml"

detect_host_ip() {
  if [ -n "${MEDIASOUP_ANNOUNCED_IP_OVERRIDE:-}" ]; then
    printf '%s\n' "$MEDIASOUP_ANNOUNCED_IP_OVERRIDE"
    return 0
  fi

  if command -v route >/dev/null 2>&1 && command -v ipconfig >/dev/null 2>&1; then
    iface=$(route get default 2>/dev/null | awk '/interface:/{print $2; exit}')
    if [ -n "${iface:-}" ]; then
      ipconfig getifaddr "$iface" 2>/dev/null && return 0
    fi
  fi

  if command -v ip >/dev/null 2>&1; then
    ip route get 1.1.1.1 2>/dev/null | awk '{
      for (i = 1; i <= NF; i++) {
        if ($i == "src") {
          print $(i + 1);
          exit;
        }
      }
    }' | sed -n '1p'
    return 0
  fi

  if command -v hostname >/dev/null 2>&1; then
    hostname -I 2>/dev/null | awk '{print $1; exit}'
    return 0
  fi

  return 1
}

ensure_env_file() {
  if [ ! -f "$ENV_FILE" ]; then
    cp "$ROOT_DIR/.env.example" "$ENV_FILE"
  fi
}

set_env_value() {
  key=$1
  value=$2
  tmp="${ENV_FILE}.tmp"

  awk -v key="$key" -v value="$value" '
    BEGIN { done = 0 }
    $0 ~ "^" key "=" {
      print key "=" value
      done = 1
      next
    }
    { print }
    END {
      if (!done) {
        print key "=" value
      }
    }
  ' "$ENV_FILE" > "$tmp"
  mv "$tmp" "$ENV_FILE"
}

ensure_env_file
HOST_IP=$(detect_host_ip | sed -n '1p')

case "$HOST_IP" in
  ""|127.*|0.0.0.0)
    echo "Aktif LAN IP tespit edilemedi. Manuel override kullan: MEDIASOUP_ANNOUNCED_IP_OVERRIDE=192.168.1.10 $0 up -d" >&2
    exit 1
    ;;
esac

set_env_value "MEDIASOUP_ANNOUNCED_IP" "$HOST_IP"
echo "MEDIASOUP_ANNOUNCED_IP=$HOST_IP"

if [ "$#" -eq 0 ]; then
  set -- up -d
fi

exec docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" "$@"
