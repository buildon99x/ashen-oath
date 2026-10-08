#!/usr/bin/env bash
# Reproducible native release export. Official Godot 4.6.3 templates are required.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="${1:-$ROOT/builds}"
GODOT="${GODOT:-godot}"
VERSION="4.6.3.stable"
TEMPLATE_SOURCE="${GODOT_TEMPLATE_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/godot/export_templates/$VERSION}"
RUNTIME="${BUILD_RUNTIME_DIR:-$ROOT/.runtime}"
mkdir -p "$OUT" "$RUNTIME"
OUT="$(cd "$OUT" && pwd)"
RUNTIME="$(cd "$RUNTIME" && pwd)"
mkdir -p "$RUNTIME/data/godot/export_templates/$VERSION" "$RUNTIME/config" "$RUNTIME/cache" "$OUT/windows" "$OUT/linux" "$OUT/logs"
export XDG_DATA_HOME="$RUNTIME/data" XDG_CONFIG_HOME="$RUNTIME/config" XDG_CACHE_HOME="$RUNTIME/cache"
TARGET="$XDG_DATA_HOME/godot/export_templates/$VERSION"
for template in linux_release.x86_64 windows_release_x86_64.exe; do
  if [[ "$TEMPLATE_SOURCE" != "$TARGET" && -f "$TEMPLATE_SOURCE/$template" ]]; then
    cp "$TEMPLATE_SOURCE/$template" "$TARGET/$template"
  fi
  if [[ ! -f "$TARGET/$template" ]]; then
    printf 'Missing official %s template: %s\nInstall export templates from https://godotengine.org/download/ or set GODOT_TEMPLATE_DIR.\n' "$VERSION" "$template" >&2
    exit 1
  fi
done
ACTUAL_VERSION="$("$GODOT" --headless --version)"
if [[ "$ACTUAL_VERSION" != "$VERSION"* ]]; then
  printf 'Expected Godot %s, found %s\n' "$VERSION" "$ACTUAL_VERSION" >&2
  exit 1
fi
"$GODOT" --headless --path "$ROOT" --editor --quit >"$OUT/logs/import.log" 2>&1
for test in selftest ui_selftest resume_selftest campaign_stress animation_selftest generated_art_selftest tactical_selftest encounter_selftest encounter_ui_selftest; do
  "$GODOT" --headless --path "$ROOT" --script "res://$test.gd" >"$OUT/logs/$test.log" 2>&1
  cat "$OUT/logs/$test.log"
done
"$GODOT" --headless --path "$ROOT" --export-release 'Windows x64' "$OUT/windows/ashen-oath.exe" >"$OUT/logs/export-windows.log" 2>&1
"$GODOT" --headless --path "$ROOT" --export-release 'Linux x64' "$OUT/linux/ashen-oath.x86_64" >"$OUT/logs/export-linux.log" 2>&1
chmod +x "$OUT/linux/ashen-oath.x86_64"
"$OUT/linux/ashen-oath.x86_64" --headless --quit-after 5 >"$OUT/logs/linux-smoke.log" 2>&1
if grep -Ein 'SCRIPT ERROR|Parse Error|ERROR:' "$OUT/logs/"*.log; then
  printf 'An import, test, export, or smoke log contains errors.\n' >&2
  exit 1
fi
for platform in windows linux; do
  cp "$ROOT/GODOT_LICENSE.txt" "$ROOT/GODOT_THIRD_PARTY_NOTICES.txt" "$OUT/$platform/"
  cp "$ROOT/scripts/PLAY.txt" "$OUT/$platform/PLAY.txt"
  if [[ -f "$ROOT/assets/fonts/OFL.txt" ]]; then cp "$ROOT/assets/fonts/OFL.txt" "$OUT/$platform/PIXELIFY_OFL.txt"; fi
done
python3 "$ROOT/scripts/package_builds.py" "$OUT"
printf '\nBuilds ready: %s\n' "$OUT"
