#!/usr/bin/env bash
# Reconstruct a read-only Git baseline, then compare two fixed Ashen policies.
# No Git writes, downloads, publishing, or player-profile writes.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BASELINE_COMMIT=597788546b80f6deecfed0e0488f4bd37b26caff
GODOT="${GODOT:-godot}"
OUT="${1:-$ROOT/.runtime/provisional-choice-review}"
FIRST_SEED="${FIRST_SEED:-81}"
LAST_SEED="${LAST_SEED:-100}"
PREPARE_ONLY="${PREPARE_ONLY:-0}"
mkdir -p "$ROOT/.runtime/choice-baseline" "$OUT"
OUT="$(cd "$OUT" && pwd)"
python3 - "$ROOT" "$BASELINE_COMMIT" "$OUT" <<'PY'
import hashlib, json, pathlib, subprocess, sys
root = pathlib.Path(sys.argv[1])
commit = sys.argv[2]
out = pathlib.Path(sys.argv[3])
target = root / '.runtime' / 'choice-baseline'
original_model = subprocess.check_output(['git', '-C', str(root), 'show', f'{commit}:model.gd'])
original_combat = subprocess.check_output(['git', '-C', str(root), 'show', f'{commit}:core/provisional_combat.gd'])
model = original_model.decode('utf-8')
class_line = 'class_name OathModel\n'
old_preload = 'preload("res://core/provisional_combat.gd")'
if model.count(class_line) != 1 or model.count(old_preload) != 1:
    raise SystemExit('Unexpected baseline model; refusing an ambiguous source rewrite.')
model = model.replace(class_line, '', 1).replace(old_preload, 'preload("res://.runtime/choice-baseline/provisional_combat.gd")', 1)
(target / 'model.gd').write_text(model, encoding='utf-8')
(target / 'provisional_combat.gd').write_bytes(original_combat)
sha = lambda data: hashlib.sha256(data).hexdigest()
metadata = {
    'baseline_commit': commit,
    'baseline_original_sha256': {'model.gd': sha(original_model), 'core/provisional_combat.gd': sha(original_combat)},
    'baseline_rewrite': 'Remove duplicate class_name OathModel; replace only combat preload path. Combat bytes unchanged.',
    'baseline_dependencies': 'Historical effect resolver and legacy content are shared with candidate and hashed below.',
    'candidate_head': subprocess.check_output(['git', '-C', str(root), 'rev-parse', 'HEAD'], text=True).strip(),
    'candidate_working_tree_status': subprocess.check_output(['git', '-C', str(root), 'status', '--short'], text=True),
    'candidate_sha256': {p: sha((root / p).read_bytes()) for p in [
        'model.gd', 'core/provisional_combat.gd', 'core/historical_effect_resolver.gd',
        'legacy/legacy_content.gd', 'rulesets/severed_historical_effects_v1/manifest.json',
        'provisional_choice_review.gd', 'scripts/review-provisional-choices.sh']},
}
(out / 'source-metadata.json').write_text(json.dumps(metadata, indent=2) + '\n', encoding='utf-8')
print(f'Baseline reconstructed in {target}; metadata: {out / "source-metadata.json"}')
PY
if [[ "$PREPARE_ONLY" == 1 ]]; then
  printf 'Preparation only; no engine was invoked.\n'
  exit 0
fi
PROFILE="$(mktemp -d "$ROOT/.runtime/choice-profile.XXXXXX")"
mkdir -p "$PROFILE/home" "$PROFILE/config" "$PROFILE/data" "$PROFILE/cache"
export HOME="$PROFILE/home" XDG_CONFIG_HOME="$PROFILE/config" XDG_DATA_HOME="$PROFILE/data" XDG_CACHE_HOME="$PROFILE/cache"
if [[ "$("$GODOT" --headless --version)" != 4.7.2.stable* ]]; then
  printf 'Choice review requires Godot 4.7.2.stable.\n' >&2
  exit 1
fi
printf 'ISOLATED_PROFILE=%s\n' "$PROFILE" > "$OUT/review.log"
set +e
timeout -k 5 240 "$GODOT" --headless --path "$ROOT" --script res://provisional_choice_review.gd -- \
  "--output=$OUT" "--first-seed=$FIRST_SEED" "--last-seed=$LAST_SEED" >> "$OUT/review.log" 2>&1
STATUS=$?
set -e
cat "$OUT/review.log"
if [[ "$STATUS" -ne 0 ]]; then exit "$STATUS"; fi
if grep -Ein 'SCRIPT ERROR|Parse Error|ERROR:|CHOICE REVIEW FAIL' "$OUT/review.log"; then exit 1; fi
if [[ ! -s "$OUT/choice-review.json" || ! -s "$OUT/campaigns.csv" || ! -s "$OUT/battles.csv" || ! -s "$OUT/summary.txt" ]]; then
  printf 'Choice review did not produce all expected result files.\n' >&2
  exit 1
fi
cat "$OUT/summary.txt"
printf 'Comparison artifacts: %s\n' "$OUT"
