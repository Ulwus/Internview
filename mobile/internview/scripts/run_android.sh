#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

DEVICE_ID="${1:-__ALL_ANDROID__}"

if [[ "$DEVICE_ID" == "__ALL_ANDROID__" || "$DEVICE_ID" == "all" ]]; then
  ANDROID_DEVICE_IDS="$(
    flutter devices --machine | python3 -c '
import json, sys
devices = json.load(sys.stdin)
ids = []
for d in devices:
    # "targetPlatform" örnek: "android-arm64", "darwin-arm64", "web-javascript"
    tp = (d.get("targetPlatform") or "").lower()
    if tp.startswith("android"):
        ids.append(d.get("id"))
print("\n".join([i for i in ids if i]))
'
  )"

  if [[ -z "$ANDROID_DEVICE_IDS" ]]; then
    echo "Android cihaz bulunamadı. (emülatör açık mı?)" >&2
    exit 1
  fi

  # Her android cihaz için ayrı flutter run başlat.
  # Not: Aynı anda 2 emülatör için 2 ayrı terminal süreci gerekir.
  while IFS= read -r id; do
    echo "Starting on $id"
    flutter run -d "$id" --dart-define-from-file=env/android.json &
  done <<< "$ANDROID_DEVICE_IDS"

  wait
else
  flutter run -d "$DEVICE_ID" --dart-define-from-file=env/android.json
fi

