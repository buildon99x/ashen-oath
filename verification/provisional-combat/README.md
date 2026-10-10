# Reconstructed combat verification (2026-10-10)

Baseline remote: `65404c21fbb54e355bfce07b2a829d3fb43f11cb`.
Engine: official Godot4.7.2 stable, `ed1daf0bf`; official Linux archive SHA256 `cadd3204e728a35d3f13adb7fd0d7902636b79f6b95c40c265eb73b6c35329e4`.

All runs use isolated HOME and XDG data/config/cache; none use an existing user's profile. Engines run serially. A script exit0 alone is insufficient; logs are scanned for parse/runtime/test errors.

Fresh aggregate run: all 19 source regression invocations passed with exit0 and no error-log matches. See `full-suite.log` and per-suite logs under `full-suite/`. Initial `import.log` and `ui-smoke.log` record failed attempts before fixes, not passing evidence. The import revealed a duplicate local declaration; UI smoke was downstream of the initially failed JSON-number historical Defend pin. `historical.log` now contains the corrected 48/48 passing run. Preserve them as diagnostics, and use named final suite logs below for the verified state.

`provisional-ui.log`: fresh 160 checks,0 failures, headless only. Reusing a test profile correctly triggered transactional save-conflict refusal; the repeat with a fresh profile passed.

The initial checkpoint was published as `59a7d4f1b3b7d110411275c33f2d7b7c7bb29ab5` (tree `faabc975847606c983707c8b6b40018c46ed45fc`). Its tree equals the preserved original local commit `45a500e6fced6e145a69253998792c7410c23878`; commit IDs differ because the existing authenticated GitHub connector created the published commit.

Native verification was subsequently completed, found UI defects and drove the fixes described in [NATIVE_QA.md](NATIVE_QA.md). The full porting plan is not completed by this checkpoint.

`provisional-model.log`:15,386 checks,0 failures;20 seeds replayed twice exactly,38 wins/2 defeats,596 explicit Severs,4,934 campaign commands. Seed97 loses deterministically under this test strategy; this is recorded balance evidence, not hidden or called a softlock.

## Post-native final regression

The final 19 source invocations passed again on the post-play fixes: `post-native-suite.log` and `post-native/`. Provisional combat: 15,392 checks; UI: 172; historical effects: 48; save recovery: 188; default-path recovery: 14; localized UI: 36,027 checks across 92 contexts; localization: 159,472 checks. All had zero failures and no error-log matches. The repeated 20-seed campaign outcomes remain 38 wins / 2 defeats, 596 manual Severs and 4,934 commands, with exact replay equality. These counts describe assertions, not distinct gameplay scenarios.

`post-native-package.log`, `post-native-export-pack.log` and `post-native-packaged-combat.log` pass the final exported-resource-pack test. It loads shipped JSON manifests, the compiled model, executes actual Defend from 0 MP to 15 MP with Guard, and saves a valid checkpoint. `scripts/test-package.sh` creates a fresh HOME/XDG profile each time; the native build script now also isolates each release-smoke profile to avoid stale fixture revision conflicts.

An initial post-native pack attempt correctly failed its error scan because screenshots supplied as JPEG bytes had a `.png` extension. The unchanged screenshot bytes were renamed `.jpg`, and the final export/import and pack tests passed. The failed attempt is preserved in `post-native-package-before-image-extension-fix.log`, not counted as passing evidence. The exporter still reported success during that failed import, demonstrating why exit status alone is insufficient.

No platform export templates were downloaded for this check. A PCK tested with Godot is not a standalone Windows/Linux release binary. Native source play, pack validation and headless suites are separate verified scopes. Full growth, exploration and content parity remain outstanding.

Native screenshots are deliberately excluded from this public repository. The numbered evidence referenced by NATIVE_QA.md is retained in a separate private QA attachment. The repository contains the reproducible tests and written observations, not broken image links.
