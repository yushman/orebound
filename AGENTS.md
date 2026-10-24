# AGENTS.md — orebound

Godot 4.7 2D space-mining game, docs-first repo: the design spec lives in `docs/`
(Russian), the code is a stage-0 skeleton + rejected week-1 prototype being
reworked. Read this before touching code or docs.

## Layout

- `autoload/` — singletons `GravityField` (pure field math), `Tuning` (params),
  `Telemetry` (stub). `scenes/` — `Run` main scene, ship/flight, prediction.
  `ui/` — `HUD`, dev `TuningPanel`. `presets/` — gravity `TuningPreset`s
  `p1..p4.tres`. `tests/` — GUT suite. `addons/gut` — vendored, do not edit.
- Every module dir has a `CLAUDE.md` with deep detail (step order, formulas,
  test inventory). Read the module file before changing that module.

## Commands

- Tests (GUT 9.x, headless): `godot --headless --import && godot --headless -s
  addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json -gexit`. `godot` must
  be on PATH. The `--import` step is required: without `.godot/` (class_name
  cache, not committed) headless GUT fails.
- No build/lint; GDScript checked via the editor and tests. Run tests after any
  code change.

## Architecture invariants

- Flight physics is the pure static `ShipFlight.step(state, input, t, dt)` —
  no node state, never mutates arguments. `ShipPrediction` reuses the same
  step; prediction must stay bit-identical to real flight. Any new flight
  feature (ramp, overheat, brake changes) goes into the state + `step`, not
  into the `Ship` node.
- Strictly fixed 60 Hz step (`GravityField.DT = 1/60`, integer `tick`); never
  a variable or enlarged dt (time acceleration = more steps per frame).
- `CharacterBody2D.move_and_collide` only for collisions; velocity/rotation are
  own code. No `RigidBody2D`, no `Area2D` gravity.
- All tunables live in `Tuning` resources (`FieldParams`, `BodyParams`,
  `ShipParams`), read on each call, never cached (presets replace the objects).
  A/B comparisons are `.tres` presets, not code edits; sliders write straight
  into `Tuning`.
- Tests restore `Tuning.field` / `Tuning.ship` they changed.

## Docs are the spec (Russian)

- Design decisions: `docs/decisions.md` (D1…D36, each with
  Решение/Почему/Отклонено/Подробно). Terms: `docs/glossary.md` — use exactly
  these terms everywhere; retired names go to its «Отклонённые термины» table.
  Stage lists have a single source: `docs/production/scope.md`.
- A design change updates `decisions.md` **and** propagates to the design docs,
  glossary and production docs in one commit; wrap prose at ~76 chars.
- **Rework (1′) complete:** slices R1–R5 have all landed — rotating carrier
  frame (Ω_f, Φ_eff, band drift), local-vertical camera with 1×…40× zoom
  and honest arcs at D35 defaults, D36 controls (thrust ramp + overheat,
  soft brake, drift sync; playtest hypotheses in `ShipParams`), short
  prediction line (15 s horizon, full line removed), presets rescaled per
  D29/D35 (equal ΔΦ_eff, per-p μ) and the panel with sliders for every
  live parameter. Deferred follow-ups live in
  `docs/production/tech-debt.md` (#6 prediction cost, #7 Coriolis scheme,
  #11 float32 precision at the carrier radius). Next stages are
  week 2 per `docs/production/scope.md`; the slice prompts (R1–R5) remain
  in `docs/production/stage1-week1.md`, «Промпты (1′)».
- Small deferred issues go to `docs/production/tech-debt.md` (remove the row
  once fixed), not to TODO comments.

## Communication

- Chat with the user is in Russian; `docs/` is in Russian. Code, comments,
  module `CLAUDE.md` specs, test names and commits are in English.

## Commits

Lowercase short English, e.g. `add d36 thrust overheat and soft brake to docs`.
