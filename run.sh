#!/usr/bin/env sh
set -eu
cd "$(dirname "$0")"
if command -v godot >/dev/null 2>&1; then exec godot --path . "$@"; fi
if command -v godot4 >/dev/null 2>&1; then exec godot4 --path . "$@"; fi
printf 'Install Godot 4.6+ from https://godotengine.org/download/ then open project.godot and press F6 or F5.\n'
exit 1
