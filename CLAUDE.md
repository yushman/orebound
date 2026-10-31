# orebound

Godot 4.7 2D game; stage 0 skeleton with placeholder ship and stub modules.

## Project
- Main scene is `res://scenes/Run.tscn`. Renderer `gl_compatibility` (2D, canvas_item shaders; targets Windows, macOS; Steam Deck secondary, see D34 in docs/decisions.md).
- Base viewport 1280x800 (Steam Deck 16:10), stretch mode `canvas_items`, aspect `expand`. Physics 60 ticks/s (60 × `time_warp_mult` while the time warp is held, see `scenes/CLAUDE.md` Time warp).
- Autoloads: `GravityField`, `Tuning` (incl. `Tuning.picture`, the generated moons and ring; `Tuning.view`; `Tuning.resources`, the `CellType` table of mass / volume / energy / price per cell type, not saved in presets), `Telemetry` (see `autoload/`).
- Known deferred issues (review nits, small bugs left for later) go to `docs/production/tech-debt.md`; remove a row once fixed.
- Visual style (W7): one palette in `scenes/Palette.gd` (`Palette`, colours bound to meaning; clear colour `Palette.BACKGROUND`), bodies are flat discs with a terminator, the ship look is `Ship/Visual` + `ShipView`; see `scenes/CLAUDE.md`.
- Layout: `autoload/`, `scenes/`, `ui/` (`HUD`: scripted well scale on a Control root; `TuningPanel`: Control with script, debug sliders, preset load / save and seed controls, toggled by F1; `Summary`: end-of-flight screen, `flight_next` starts the next flight; `Warnings`: top-centre warning bus; `HUD` also draws the carrier arrow), `SoundView` / `SoundBank` / `SoundModel` (procedural instrument sound, no audio assets), `gen/` (`WellGenerator`: pure static well, seeded moon and ring generator; `AsteroidField`: pure static lazy asteroid chunks, see `gen/CLAUDE.md`), `shaders/` (`atmosphere`, `gravity_halo`, `starfield`: canvas_item shaders drawn by `AtmosphereView` / `GravityHaloView` / `StarfieldView`; `RingView` / `AsteroidView` / `BeamView` / `CollectorView` draw the ring, asteroids, the beam and the collector sector, see `scenes/CLAUDE.md`), `presets/` (`p1.tres`..`p4.tres` planet-only `TuningPreset`s, moons are generated at runtime, `.gitkeep`), `tests/`, `addons/`, `tools/` (`build_macos.sh`: one-command tester build, `tools/tester/README-macOS.md` the tester note; see Build).

## Build
- `tools/build_macos.sh` (needs `godot` on PATH and the matching export templates) writes gitignored `build_info.json` (`{"commit": "<short sha>[-dirty]"}`), imports, exports the committed `macOS` preset (universal, ad-hoc signed, unsigned for Gatekeeper) to `build/Orebound.app` and zips it with the tester note into `build/orebound-macos-<version>-<commit>.zip`. `export_presets.cfg` is committed; `tests/`, `addons/gut/`, `docs/`, `.slimspec/`, `tools/` are excluded from the export. Version is `application/config/version` in `project.godot`, bumped by hand. Windows has no preset yet.

## Tests
- GUT 9.x is vendored in `addons/gut` and enabled as a plugin; tests live in `res://tests` as `test_*.gd` (`.gutconfig.json`, subdirs included).
- Command: `godot --headless --import && godot --headless -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json -gexit`. The import step is required: on a clean checkout `.godot/` (class_name cache) is missing and headless GUT fails.
- `godot` must be on PATH.
