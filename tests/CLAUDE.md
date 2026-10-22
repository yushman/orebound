# tests

GUT suite, run headless (command in root `CLAUDE.md`).

- Smoke: instancing `res://scenes/Run.tscn` yields a child `Ship` (scripted, with a `Camera2D` child) and 3 `Body.tscn` children with `index` 0, 1, 2; `application/run/main_scene` is `res://scenes/Run.tscn`.
- Autoloads and stub scenes/UI/shaders are checked to exist and load.
- `test_gravity_field.gd`: `body_pos` orbit formula, tick clock, default field, −∇Φ ≈ accel by finite difference (p = 2, 1, 1.5, fade zone), moon fade bounds and continuity, determinism, mixed p. Tests set a custom `Tuning.field` and restore it.
- `test_body.gd`: `Body` places itself at `GravityField.body_pos(index, time())` on physics process.
- `test_ship_flight.gd`: `ShipFlight.step` with a planet-only `Tuning.field` (restored after): circular orbit keeps its radius (~1% over several orbits), thrust along the nose, determinism and non-mutation of inputs, spin damping and heading convergence, boost accel and fuel ratios, zero fuel without thrust.
- `test_ship.gd`: spawn on a circular orbit, `t` passed to `step` is `GravityField.time()` (pinned by setting `tick` and calling `_physics_process` directly), `step` gets the fixed `GravityField.DT` whatever the physics callback argument, `ship.input` is the input passed to `step`, camera `ignore_rotation`.
- `test_ship_prediction.gd`: `ShipPrediction.run` from tick T equals real flight (`ship._physics_process` with `GravityField.tick += 1` per step) point for point with `assert_eq`, with and without `ship_thrust` held, inputs not mutated; the `Prediction` Line2D shows `predict_short_steps` points from `ship.input` and, with `ship_full_trajectory` pressed, `predict_full_steps` points from a neutral input, recomputing only every `predict_every` ticks.
- `test_ship_params.gd`, `test_ship_types.gd`, `test_input_actions.gd`: `Tuning.ship` defaults (incl. `predict_*` 180 / 1800 / 4), `ShipState`/`ShipInput` `copy()`, presence of the input actions in `project.godot` (`ship_full_trajectory` is Shift + joypad button 7).
