#!/usr/bin/env bash
# Source regression tests; no export templates or player's save directory required.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT:-godot}"
LOGS="${1:-$ROOT/verification/local-tests}"
RUNTIME="${TEST_RUNTIME_DIR:-$ROOT/.runtime/tests}"
mkdir -p "$LOGS" "$RUNTIME"
LOGS="$(cd "$LOGS" && pwd)"
RUNTIME="$(cd "$RUNTIME" && pwd)"
run_test() {
  local name="$1" script="$2" profile
  shift 2
  profile="$(mktemp -d "$RUNTIME/${name}.XXXXXX")"
  if ! XDG_DATA_HOME="$profile/data" XDG_CONFIG_HOME="$profile/config" XDG_CACHE_HOME="$profile/cache" \
    "$GODOT" --headless --path "$ROOT" --script "res://$script.gd" "$@" >"$LOGS/$name.log" 2>&1; then
    cat "$LOGS/$name.log"; return 1
  fi
  cat "$LOGS/$name.log"
  if grep -Ein 'SCRIPT ERROR|Parse Error|Assertion failed|FAIL:|ERROR:' "$LOGS/$name.log"; then
    printf 'Regression log contains an error: %s\n' "$name" >&2; return 1
  fi
}
for test in selftest ui_selftest resume_selftest campaign_stress animation_selftest generated_art_selftest tactical_selftest encounter_selftest encounter_ui_selftest finisher_selftest arena_selftest localization_selftest localized_ui_selftest save_recovery_selftest; do
  run_test "$test" "$test"
done
run_test save_default_path save_recovery_selftest -- --default-path-only
printf '\nAll source regression suites passed. Logs: %s\n' "$LOGS"
