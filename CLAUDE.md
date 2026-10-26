# orebound

Godot 4.7 2D game; stage 0 skeleton with placeholder ship and stub modules.

## Project
- Main scene is `res://scenes/Run.tscn`. Renderer `gl_compatibility` (2D, canvas_item shaders; targets Windows, macOS; Steam Deck secondary, see D34 in docs/decisions.md).
- Base viewport 1280x800 (Steam Deck 16:10), stretch mode `canvas_items`, aspect `expand`. Physics 60 ticks/s.
- Autoloads: `GravityField`, `Tuning` (incl. `Tuning.picture`, the generated moons and ring), `Telemetry` (see `autoload/`).
- Known deferred issues (review nits, small bugs left for later) go to `docs/production/tech-debt.md`; remove a row once fixed.
- Layout: `autoload/`, `scenes/`, `ui/` (`HUD`: empty Control root; `TuningPanel`: Control with script, debug sliders, preset load / save and seed controls, toggled by F1), `gen/` (`WellGenerator`: pure static well, seeded moon and ring generator; `AsteroidField`: pure static lazy asteroid chunks, see `gen/CLAUDE.md`), `shaders/` (`atmosphere`, `gravity_halo`: canvas_item shaders drawn by `AtmosphereView` / `GravityHaloView`; `RingView` / `AsteroidView` draw the ring and asteroids, see `scenes/CLAUDE.md`), `presets/` (`p1.tres`..`p4.tres` planet-only `TuningPreset`s, moons are generated at runtime, `.gitkeep`), `tests/`, `addons/`.

## Tests
- GUT 9.x is vendored in `addons/gut` and enabled as a plugin; tests live in `res://tests` as `test_*.gd` (`.gutconfig.json`, subdirs included).
- Command: `godot --headless --import && godot --headless -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json -gexit`. The import step is required: on a clean checkout `.godot/` (class_name cache) is missing and headless GUT fails.
- `godot` must be on PATH.
