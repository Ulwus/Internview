#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

flutter run --dart-define-from-file=env/ios.json

