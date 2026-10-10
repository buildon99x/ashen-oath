#!/usr/bin/env sh
set -eu
cd "$(dirname "$0")"
if [ -n "${GODOT:-}" ]; then exec "$GODOT" --path . "$@"; fi
if command -v godot >/dev/null 2>&1; then exec godot --path . "$@"; fi
if command -v godot4 >/dev/null 2>&1; then exec godot4 --path . "$@"; fi
printf 'Install the tested Godot 4.7.2 stable from https://godotengine.org/download/ then open project.godot and press F5.\n'
exit 1
