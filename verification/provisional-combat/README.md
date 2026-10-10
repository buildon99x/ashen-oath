# Reconstructed combat verification (2026-10-10)

Baseline remote: `65404c21fbb54e355bfce07b2a829d3fb43f11cb`.
Engine: official Godot4.7.2 stable, `ed1daf0bf`; official Linux archive SHA256 `cadd3204e728a35d3f13adb7fd0d7902636b79f6b95c40c265eb73b6c35329e4`.

All runs use isolated HOME and XDG data/config/cache; none use an existing user's profile. Engines run serially. A script exit0 alone is insufficient; logs are scanned for parse/runtime/test errors.

Fresh aggregate run: all 19 source regression invocations passed with exit0 and no error-log matches. See `full-suite.log` and per-suite logs under `full-suite/`. Initial `import.log` and `ui-smoke.log` record failed attempts before fixes, not passing evidence. The import revealed a duplicate local declaration; UI smoke was downstream of the initially failed JSON-number historical Defend pin. `historical.log` now contains the corrected 48/48 passing run. Preserve them as diagnostics, and use named final suite logs below for the verified state.

`provisional-ui.log`: fresh 160 checks,0 failures, headless only. Reusing a test profile correctly triggered transactional save-conflict refusal; the repeat with a fresh profile passed.

No native visual/play-session verification is claimed yet. The full porting plan is not completed by this checkpoint.

`provisional-model.log`:15,386 checks,0 failures;20 seeds replayed twice exactly,38 wins/2 defeats,596 explicit Severs,4,934 campaign commands. Seed97 loses deterministically under this test strategy; this is recorded balance evidence, not hidden or called a softlock.
