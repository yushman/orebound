# tests

GUT suite, run headless (command in root `CLAUDE.md`).

- Smoke: instancing `res://scenes/Run.tscn` yields a child `Ship` and 3 `Body.tscn` children with `index` 0, 1, 2; `application/run/main_scene` is `res://scenes/Run.tscn`.
- Autoloads and stub scenes/UI/shaders are checked to exist and load.
- `test_gravity_field.gd`: `body_pos` orbit formula, tick clock, default field, −∇Φ ≈ accel by finite difference (p = 2, 1, 1.5, fade zone), moon fade bounds and continuity, determinism, mixed p. Tests set a custom `Tuning.field` and restore it.
- `test_body.gd`: `Body` places itself at `GravityField.body_pos(index, time())` on physics process.
