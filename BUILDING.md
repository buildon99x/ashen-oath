# Native builds

**Checkpoint 10 status:** source regressions and three native finisher/input/reward flows verified, following checkpoint 9’s full native journey. Current Windows/Linux exports are blocked by missing official 4.6.3 templates. Previously delivered native archives are checkpoint 5 and do not contain the new background/actor art.

The repository includes original Godot source plus packaged Windows x64 and Linux x64 releases.
The packages run without a separately installed Godot editor. Each ZIP contains a native executable
with embedded game data, launch instructions, and Godot license notices.

## Requirements

- Official Godot **4.6.3 stable** editor (`godot` on PATH, or set `GODOT`)
- Matching official export templates from https://godotengine.org/download/
- Bash and Python 3 for the supplied cross-export script

Do not use template binaries from unknown sources. The official download entry point is:
https://downloads.godotengine.org/?flavor=stable&platform=templates&slug=export_templates.tpz&version=4.6.3

## Build on Linux

```sh
./scripts/build.sh
```

To supply a template directory explicitly and use an output folder outside the checkout:

```sh
GODOT_TEMPLATE_DIR=/path/to/4.6.3.stable ./scripts/build.sh /absolute/output/path
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

Open `project.godot` with Godot 4.6.3, install its matching templates, then use
Project → Export → **Windows x64** or **Linux x64**. Both presets are checked in as
`export_presets.cfg` and embed the game data in the executable.
