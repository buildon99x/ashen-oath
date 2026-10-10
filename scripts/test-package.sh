#!/usr/bin/env bash
# Validate the shipped resource pack without downloading platform templates.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT:-godot}"
OUT="${1:-$ROOT/builds/provisional-smoke}"
mkdir -p "$ROOT/.runtime" "$OUT"
OUT="$(cd "$OUT" && pwd)"
PROFILE="$(mktemp -d "$ROOT/.runtime/package-test.XXXXXX")"
mkdir -p "$PROFILE/home"
export HOME="$PROFILE/home" XDG_DATA_HOME="$PROFILE/data" XDG_CONFIG_HOME="$PROFILE/config" XDG_CACHE_HOME="$PROFILE/cache"
if [[ "$("$GODOT" --headless --version)" != 4.7.2.stable* ]]; then
  printf 'Package test requires the same official Godot4.7.2 engine as runtime.\n' >&2; exit 1
fi
timeout -k 5 120 "$GODOT" --headless --path "$ROOT" --export-pack 'Linux x64' "$OUT/ashen-oath.pck" >"$OUT/export-pack.log" 2>&1
timeout -k 5 60 "$GODOT" --headless --main-pack "$OUT/ashen-oath.pck" --script "$ROOT/scripts/package_smoke.gd" >"$OUT/packaged-combat.log" 2>&1
if grep -Ein 'SCRIPT ERROR|Parse Error|ERROR:|FAIL' "$OUT/"*.log; then exit 1; fi
cat "$OUT/packaged-combat.log"
printf 'Resource-pack verification passed (not a Windows/Linux executable export).\n'
