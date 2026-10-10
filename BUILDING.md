# Native builds

**Current source: Godot 4.7.2.** The provisional combat source and exported resource pack have separate [verification records](verification/provisional-combat/README.md). Latest standalone Windows/Linux exports have not been produced because matching export templates are not installed. Previously delivered checkpoint-5 archives do not contain the current art or combat rules.

The supplied export scripts can produce native executables with embedded game data and license notices once matching official templates are provided. A tested `.pck` is not itself a standalone executable.

## Requirements

- Official Godot **4.7.2 stable** editor (`godot` on PATH, or set `GODOT`)
- Matching official export templates from https://godotengine.org/download/
- Bash and Python 3 for the supplied cross-export script

Do not use template binaries from unknown sources. The official download entry point is:
https://downloads.godotengine.org/?flavor=stable&platform=templates&slug=export_templates.tpz&version=4.7.2

## Build on Linux

```sh
./scripts/build.sh
```

To supply a template directory explicitly and use an output folder outside the checkout:

```sh
GODOT_TEMPLATE_DIR=/path/to/4.7.2.stable ./scripts/build.sh /absolute/output/path
```

The template directory must contain `linux_release.x86_64` and `windows_release_x86_64.exe`.
The script stores writable editor config, cache, and user data under `.runtime/` in the project.
Override this with `BUILD_RUNTIME_DIR` if needed. The original templates are copied into that
writable build area. No user-home settings are modified by the build script.

The script imports the project, runs model/UI/campaign tests, exports both native release builds,
launches the Linux binary headlessly, checks logs for engine/script errors, verifies ZIP CRCs, and
writes SHA-256 checksums. It stops on a failed check.

The Windows build is unsigned. Windows-native runtime testing and SmartScreen reputation are not
established by exporting it from Linux. The headless Linux smoke test is not visual playtesting;
see the current test report for separately performed screen-based checks.

## Source tests without export templates

Run `./scripts/test.sh`. Each suite receives an isolated HOME/data/config/cache profile under `.runtime/tests/`; no played campaign is modified. The script rejects Godot script errors even if the engine exits with status zero. It includes Korean glyph/layout checks, transactional-save corruption and interruption fixtures, and a separate fresh-profile startup test. These automated suites complement, rather than replace, native human-input play.

The Korean display font is bundled with its SIL OFL license. Future native packages include that notice alongside the existing font and engine licenses.

## Resource pack without platform templates

Run `GODOT=/path/to/Godot_v4.7.2 scripts/test-package.sh`. It exports a PCK, then loads the actual packed JSON rules and model, executes Defend and validates checkpoint writing under a fresh profile. Export logs are scanned because the editor can exit successfully after an import error. This does not replace native-platform runtime testing.

## Outputs

- `ASHEN-OATH-windows-x64.zip`
- `ASHEN-OATH-linux-x64.zip`
- `SHA256SUMS.txt`
- Uncompressed executables and accompanying notices in `windows/` and `linux/`
- Import, test, export, and smoke logs in `logs/`

Commit the compressed release ZIPs instead of the raw Windows executable: the uncompressed Godot
runtime is close to GitHub's individual-file size limit before embedding the game data. Do not
commit `.godot/`, `.runtime/`, editor caches, or the export templates.

## Manual editor exports

Open `project.godot` with Godot 4.7.2, install its matching templates, then use
Project → Export → **Windows x64** or **Linux x64**. Both presets are checked in as
`export_presets.cfg` and embed the game data in the executable.
