# Verification evidence

The native screenshots are actual game-window captures. `native-full-victory.jpg` records completion of all nine crossings and all three bosses through mouse/keyboard input. Its cycle counter exposed an off-by-one label bug, fixed in the current source and covered by the 49th UI test.

The log files preserve checks at their respective checkpoints. `checkpoint3-build.txt` records the current 78 model checks, 49 UI checks, 7 resume assertions, 50 seeded runs, and both native exports. Windows OS runtime testing is still pending.

`checkpoint2-SHA256.json` is a historical source-manifest snapshot, not a claim that later modified files still match those hashes. Native release archives have their own matching SHA256 manifests.

The report does not claim visual equality or a 98% quality score against The Severed Gods. Official reference screenshots were inspected separately and are not game assets in this repository.

## Checkpoint 7
`native-cp7-*.jpg` are unmodified actual native Godot project-window captures, 1178×814. The generated actor master is separate from these screenshots. `cp7/` logs cover the final source checks. 78 model, 82 UI, 7 resume, 1131 legacy animation/runtime, 177 generated-art checks and 50 campaign seeds pass. The generated art test exercises master dimensions/alpha, all 12 pose regions, all 60 facing/state rig combinations, source bounds and monster sever-state wiring. It does not prove commercial-quality animation or Windows runtime behavior.

The first visual launch encountered the desktop’s absent audio device; the final launch explicitly uses the Dummy audio driver. V-Sync support warning is environmental. No new export was performed, because official templates are missing.
