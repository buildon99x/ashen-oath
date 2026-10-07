# Verification evidence

The native screenshots are actual game-window captures. `native-full-victory.jpg` records completion of all nine crossings and all three bosses through mouse/keyboard input. Its cycle counter exposed an off-by-one label bug, fixed in the current source and covered by the 49th UI test.

The log files preserve checks at their respective checkpoints. `checkpoint3-build.txt` records the current 78 model checks, 49 UI checks, 7 resume assertions, 50 seeded runs, and both native exports. Windows OS runtime testing is still pending.

`checkpoint2-SHA256.json` is a historical source-manifest snapshot, not a claim that later modified files still match those hashes. Native release archives have their own matching SHA256 manifests.

The report does not claim visual equality or a 98% quality score against The Severed Gods. Official reference screenshots were inspected separately and are not game assets in this repository.
