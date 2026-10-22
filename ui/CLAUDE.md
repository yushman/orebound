# ui

Screen-space Control scenes.

- `HUD.tscn` is an empty Control root.
- `TuningPanel.tscn` is a dev-only Control root with `TuningPanel.gd`, instanced under a `CanvasLayer` in `Run.tscn`; hidden by default, `debug_tuning_panel` (F1) toggles it in `_unhandled_input` and marks the event handled.
- Header: an `OptionButton` with the full preset names (same as the `name` in `p1`..`p4.tres`; P4 selected on start), Load and Save. Load applies `Tuning.load_preset(<presets_dir>/pN.tres)` via `Tuning.apply`; Save overwrites the selected preset with `Tuning.save_preset` at `<presets_dir>/pN.tres` (`presets_dir` defaults to `res://presets`, a dev tool run from the editor; there is no `user://` save and no save-as). A failed load or save is a `push_error`.
- Slider rows (Label + `HSlider` + value Label) are built in code from the `ROWS` descriptor list (target `"field"` | `"ship"` | body index, property, min, max, step): field `k`, `eps`, `fade_width` (min 0.01: `_fade` divides by it); per body `p` and `mass` (3 bodies), moon `influence_radius` (bodies 1, 2); ship `thrust_accel`, `boost_accel_mult`, `boost_fuel_mult`, `brake_accel`, `brake_fuel_mult`, `fuel_per_dv`, `predict_every`, `predict_short_steps`, `predict_full_steps`. No orbit sliders. `sliders` maps ids like `field.k`, `body1.mass`, `ship.thrust_accel` to the slider.
- Mass sliders use `exp_edit` with range 1..1e7 (covers the P1 planet, ~6e5); `predict_every` has min 1.
- A slider change writes straight into the current `Tuning.field` / `Tuning.ship` / `Tuning.field.bodies[i]` (looked up on every change, never cached; int properties get `int(v)`), so the next `GravityField.accel` / `ShipFlight.step` / Prediction call sees it. Slider changes do not respawn the ship.
- On `Tuning.preset_applied` (and in `_ready`) `_sync` sets every slider from the current `Tuning` without emitting `value_changed`, so syncing never writes back; values outside a slider's range are kept as is (range limits are lifted only for the sync).
- Every panel control has `focus_mode = FOCUS_NONE` (mouse only), so flight keys never reach it and flight input stays live while the panel is open.
