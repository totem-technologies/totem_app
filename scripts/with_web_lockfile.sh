#!/usr/bin/env bash
# Run a command against the Web Pub resolution, then restore the native one.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
root_lockfile="$repo_root/pubspec.lock"
web_lockfile="$repo_root/pubspec.web.lock"

if [ ! -f "$web_lockfile" ]; then
  echo "Missing Web lockfile snapshot: $web_lockfile" >&2
  exit 1
fi

if command -v fvm >/dev/null 2>&1; then
  web_flutter=(fvm spawn 3.50.0-0.2.pre)
  native_flutter=(fvm flutter)
else
  web_flutter=(flutter)
  native_flutter=(flutter)
fi

native_lockfile="$(mktemp)"
cp "$root_lockfile" "$native_lockfile"

restore_native_workspace() {
  local status=$?
  trap - EXIT
  cp "$native_lockfile" "$root_lockfile"
  rm -rf "$repo_root/.dart_tool"
  if ! (
    cd "$repo_root"
    "${native_flutter[@]}" pub get --enforce-lockfile
  ); then
    status=1
  fi
  rm -f "$native_lockfile"
  exit "$status"
}
trap restore_native_workspace EXIT

cp "$web_lockfile" "$root_lockfile"
rm -rf "$repo_root/.dart_tool"
cd "$repo_root"

if [ "${1:-}" = "--update-lockfile" ]; then
  shift
  if [ "$#" -ne 0 ]; then
    echo "Usage: $0 --update-lockfile" >&2
    exit 64
  fi
  "${web_flutter[@]}" pub get
  cp pubspec.lock "$web_lockfile"
  "${web_flutter[@]}" pub get --enforce-lockfile
else
  if [ "$#" -eq 0 ]; then
    echo "Usage: $0 [--update-lockfile|command ...]" >&2
    exit 64
  fi
  "${web_flutter[@]}" pub get --enforce-lockfile
  "$@"
fi
