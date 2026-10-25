#!/usr/bin/env bash
# Select the Pub workspace resolution for the requested Flutter toolchain.
# The root lockfile is the 3.44.9 native baseline; the Web resolution is kept as
# a snapshot because Pub only recognizes pubspec.lock at the workspace root.
set -euo pipefail

usage() {
  echo "Usage: $0 <native|web>" >&2
  exit 64
}

platform="${1:-}"
case "$platform" in
  native|web) ;;
  *) usage ;;
esac

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
root_lockfile="$repo_root/pubspec.lock"
web_lockfile="$repo_root/tool/lockfiles/flutter_3.47.7.lock"

if [ ! -f "$web_lockfile" ]; then
  echo "Missing Web lockfile snapshot: $web_lockfile" >&2
  exit 1
fi

if [ "$platform" = "web" ]; then
  if ! cmp -s "$root_lockfile" "$web_lockfile"; then
    if ! git -C "$repo_root" diff --quiet -- pubspec.lock; then
      echo "pubspec.lock has unstaged changes; update both lockfiles before switching SDKs." >&2
      exit 1
    fi
    cp "$web_lockfile" "$root_lockfile"
  fi
else
  if cmp -s "$root_lockfile" "$web_lockfile"; then
    git -C "$repo_root" show :pubspec.lock > "$root_lockfile"
  elif ! git -C "$repo_root" diff --quiet -- pubspec.lock; then
    echo "pubspec.lock has unstaged changes; update both lockfiles before switching SDKs." >&2
    exit 1
  fi
fi

rm -rf "$repo_root/.dart_tool"
echo "Selected $platform Flutter lockfile and cleared .dart_tool."
