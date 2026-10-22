# orebound

Godot 4.7 2D game; stage 0 skeleton with placeholder ship and stub modules.

## Project
- Main scene is `res://scenes/Run.tscn`. Renderer `gl_compatibility` (2D, canvas_item shaders; targets Windows, macOS, Steam Deck).
- Base viewport 1280x800 (Steam Deck 16:10), stretch mode `canvas_items`, aspect `expand`. Physics 60 ticks/s.
- Autoloads: `GravityField`, `Tuning`, `Telemetry` (see `autoload/`).
- Known deferred issues (review nits, small bugs left for later) go to `docs/production/tech-debt.md`; remove a row once fixed.
- Layout: `autoload/`, `scenes/`, `ui/` (`HUD`: empty Control root; `TuningPanel`: Control with script, debug sliders and preset load / save, toggled by F1), `shaders/` (`isolines`, `atmosphere`: `shader_type canvas_item;` only), `presets/` (`p1.tres`..`p4.tres` `TuningPreset`s, `.gitkeep`), `tests/`, `addons/`.

## Tests
- GUT 9.x is vendored in `addons/gut` and enabled as a plugin; tests live in `res://tests` as `test_*.gd` (`.gutconfig.json`, subdirs included).
- Command: `godot --headless --import && godot --headless -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json -gexit`. The import step is required: on a clean checkout `.godot/` (class_name cache) is missing and headless GUT fails.
- `godot` must be on PATH.
