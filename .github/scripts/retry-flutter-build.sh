#!/usr/bin/env bash
# Retry dependency downloads that can fail transiently during a Flutter build:
# Swift package resolution and Android SDK installation of CMake.
set -euo pipefail

MAX_ATTEMPTS="${MAX_ATTEMPTS:-3}"
if ! [[ "$MAX_ATTEMPTS" =~ ^[1-9][0-9]*$ ]]; then
  echo "MAX_ATTEMPTS must be a positive integer." >&2
  exit 2
fi
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
mkdir -p "$repo_root/scratch"
LOG="$(mktemp "$repo_root/scratch/flutter-build.XXXXXX")"
trap 'rm -f "$LOG"' EXIT
status=1

for attempt in $(seq 1 "$MAX_ATTEMPTS"); do
  if "$@" 2>&1 | tee "$LOG"; then
    exit 0
  else
    pipeline_status=("${PIPESTATUS[@]}")
    status=${pipeline_status[0]}
  fi
  if [ "${pipeline_status[1]}" -ne 0 ]; then
    exit "${pipeline_status[1]}"
  fi
  if grep -q "Could not resolve package dependencies" "$LOG"; then
    reason="Swift package resolution"
  elif grep -q "Failed to install the following SDK components" "$LOG" &&
       grep -Eq 'cmake;[0-9]' "$LOG"; then
    reason="CMake installation"
  else
    exit "$status"
  fi
  if [ "$attempt" -eq "$MAX_ATTEMPTS" ]; then
    break
  fi
  echo "$reason failed (attempt $attempt/$MAX_ATTEMPTS); retrying in 15s..." >&2
  sleep 15
done

echo "$reason still failing after $MAX_ATTEMPTS attempts." >&2
exit "$status"
