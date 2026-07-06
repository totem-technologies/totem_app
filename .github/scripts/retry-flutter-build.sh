#!/usr/bin/env bash
# Runs a flutter build command, retrying only when it fails during Swift
# Package Manager dependency resolution (transient network errors, e.g. the
# grpc binary download from dl.google.com dropping mid-transfer). Any other
# failure exits immediately so real build errors are not retried.
set -uo pipefail

MAX_ATTEMPTS="${MAX_ATTEMPTS:-3}"
LOG="$(mktemp)"
status=1

for attempt in $(seq 1 "$MAX_ATTEMPTS"); do
  if "$@" 2>&1 | tee "$LOG"; then
    exit 0
  fi
  status=${PIPESTATUS[0]}
  if ! grep -q "Could not resolve package dependencies" "$LOG"; then
    exit "$status"
  fi
  echo "Swift package resolution failed (attempt $attempt/$MAX_ATTEMPTS); retrying in 15s..." >&2
  sleep 15
done

echo "Swift package resolution still failing after $MAX_ATTEMPTS attempts." >&2
exit "$status"
