# autoload

Global singletons registered in `project.godot`.

- `GravityField` is the pure field math: `accel(pos, t)`, `potential(pos, t)`, `body_pos(i, t)` depend only on their arguments and `Tuning.field` (read on each call, no cache, no node state), so any `t` can be queried. Time is `tick` (int, +1 per `_physics_process`), `time() = tick / 60.0`.
- Per body g(r) = k·M / (r^p + ε), p per body; ε is only in g; Φ is the antiderivative at ε = 0, so −∇Φ ≈ accel only away from body cores (p = 2: −kM/r; |p−1| < 1e-4: kM·ln r; else −kM·r^(1−p)/(p−1)). Moon pull (`influence_radius` R > 0) fades by smoothstep to 0 over [R, R·(1+`fade_width`)]; Φ in the fade zone is a fixed-sample numeric integral.
- `body_pos(i, t)`: circular orbit `parent pos + orbit_radius·(cos, sin)(phase + angular_speed·t)`; `parent = -1` is the origin.
- `Tuning.field` is a `FieldParams` Resource (`k`, `eps`, `fade_width`, `bodies: Array[BodyParams]`); `BodyParams` has `mass`, `p`, `influence_radius` (0 = unlimited), `parent`, `orbit_radius`, `angular_speed`, `phase`. Default is built in code: planet (p = 1, origin) and 2 moons (p = 2).
- `Telemetry` is still an `extends Node` stub without logic.
