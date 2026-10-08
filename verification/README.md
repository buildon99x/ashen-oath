# Verification evidence

The native screenshots are actual game-window captures. `native-full-victory.jpg` records completion of all nine crossings and all three bosses through mouse/keyboard input. Its cycle counter exposed an off-by-one label bug, fixed in the current source and covered by the 49th UI test.

The log files preserve checks at their respective checkpoints. `checkpoint3-build.txt` records the current 78 model checks, 49 UI checks, 7 resume assertions, 50 seeded runs, and both native exports. Windows OS runtime testing is still pending.

`checkpoint2-SHA256.json` is a historical source-manifest snapshot, not a claim that later modified files still match those hashes. Native release archives have their own matching SHA256 manifests.

The report does not claim visual equality or a 98% quality score against The Severed Gods. Official reference screenshots were inspected separately and are not game assets in this repository.

## Checkpoint 7
`native-cp7-*.jpg` are unmodified actual native Godot project-window captures, 1178×814. The generated actor master is separate from these screenshots. `cp7/` logs cover the final source checks. 78 model, 82 UI, 7 resume, 1131 legacy animation/runtime, 177 generated-art checks and 50 campaign seeds pass. The generated art test exercises master dimensions/alpha, all 12 pose regions, all 60 facing/state rig combinations, source bounds and monster sever-state wiring. It does not prove commercial-quality animation or Windows runtime behavior.

The first visual launch encountered the desktop’s absent audio device; the final launch explicitly uses the Dummy audio driver. V-Sync support warning is environmental. No new export was performed, because official templates are missing.

## Checkpoints 8 and 9
`cp8/` and `cp9/` contain unaltered native Godot project-window JPEG captures, actual-play findings, reproducible policy comparisons and regression logs. Checkpoint8 completed a zero-legacy, seven-fight run with no enemy hits, exposing repeated sever suppression. Checkpoint9 completed a different preparation-heavy, four-fight route and visibly verified independent source forecasts, marked-hero wards, the Pale Sun recovery phase and dual-attack save/resume. These different routes are not a controlled difficulty comparison. Incoming damage forecasts precede separate Hollow Bell healing.

One transient XServer BadValue startup failure during checkpoint9 was recovered through clean app restart. Invalid desktop-through-window captures were rejected; only rendered game captures were saved here. The final startup has a V-Sync capability warning but no script/runtime error. Audio listening, native FPS, Windows execution and latest exports remain unverified. Checkpoint 9 was published as 610b92d on 2026-10-08 after renewed approval; its remote tree was verified identical to the tested source.

## Checkpoint 10
`cp10/` contains unchanged native-window screenshots from a targeted three-fight finisher/input/reward retest, not another full campaign. Cinder and Bellkeeper show the final-hit arena hold; consecutive Bellkeeper frames show the remaining silhouette dissolving without regrowing severed parts. The Judge’s final hit followed immediately by Escape reaches unchosen rewards without a menu. Bellkeeper reward restart retains 78 gold; one subsequent reward advances once. A mouse skill plus held Space leaves the two-actions-left confirmation intact.

`finisher_selftest.gd` adds 371 isolated scene/model/input/save checks, including all sever targets, HP kills, stale callbacks, held inputs across timeout, exact RNG/economy/reward state, resume, final settlement and shader reset. Its test fixture must use a writable isolated XDG data directory; it refuses the live native playtest save. The final full regression logs are under `cp10/final-tests/`. Tests do not establish visual quality, FPS or audible sound.
