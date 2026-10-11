#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
exec "$ROOT/launch/run-linux-monado-cv1-reference.sh"
