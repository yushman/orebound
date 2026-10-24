# Этап 1, неделя 1 — декомпозиция

Неделя 1 из [plan.md](plan.md) (строка «1»): `GravityField`, тела на орбитах, корабль
(поворот, тяга, тормоз, форсаж), предсказание траектории, панель настройки.
Результат недели — **линия предсказания совпадает с полётом**. Техническая основа —
[prototype-tech.md](prototype-tech.md).

Каждый срез — отдельное slimspec-изменение (explore → ground, команда `/slimspec:slimspec`).

> **Отклонено после ручного плейтеста 22.10.2026.** Реализация S1–S5 не
> подтвердилась: масштаб, камера («север вверху»), планета точкой в центре
> экрана, сильная тяга. Модель уточнена в D35 «Сектор у планеты»
> ([../decisions.md](../decisions.md)). Переделка — раздел «Переделка (1′)»
> ниже; исходная декомпозиция S1–S5 оставлена как история.

## Переделка (1′)

Развитие существующего кода, а не переписывание. Результат — **полёт в секторе
читается: масштаб, кривизна, дрейф, синхронизация; короткая линия совпадает с
полётом**.

- **Физика во вращающейся системе матки:** ускорение = гравитация + центробежное
  + Кориолис; тела движутся с относительной угловой скоростью; матка неподвижна
  ([prototype-tech.md](prototype-tech.md)).

| # | Срез | Суть | Проверка (TDD) |
|---|---|---|---|
| R1 | Поле во вращающейся системе | радиус планеты, кромка атмосферы, Ω_f из параметров (дрейф у дна), Φ_eff; Кориолис и центробежное в `ShipFlight.step` | тело в покое у матки остаётся на месте; корабль с дрейфом полосы держит высоту; максимум Φ_eff — у матки; интеграл Якоби сохраняется |
| R2 | Камера и отрисовка | местная вертикаль, масштаб 1×…40× (плавно до ~22×, дальше крупными шагами), дуга планеты и атмосферы, подсветка орбит, старт у матки, тяга 8–10, опорные числа D35 | — |
| R3 | Управление | W — разгон тяги по удержанию и перегрев (D36: греются только главный двигатель и форсаж; выше порога тяга плавно падает до минимума); S — мягкий тормоз (D36: между «против скорости» и «назад от носа»); Shift — синхронизация дрейфа (бывший тормоз) с меткой ориентира | тяга растёт с удержанием W; нагрев растёт при работающем двигателе, падает без тяги, форсаж греет быстрее; выше порога тяга падает плавно, при 100% — минимум; тормоз: нос по ходу — гасит скорость, 90° — сила ≈ 0,71 максимума, нос против скорости — ноль; расход тормоза пропорционален фактической тяге |
| R4 | Короткая линия на новом масштабе | горизонт 10–20 с; короткая линия показывается всегда, стрелка скорости настоящей длины — тоже всегда (решение 24.10.2026); режим полной линии убран (Shift его больше не включает); `ShipPrediction` остаётся чистой функцией; tech-debt #6 — под стоимость короткой линии | — |
| R5 | Панель и пресеты под новые параметры | пресеты p перемасштабированы по D29/D35 (O71) | — |

Промпты R1–R5 — ниже.

### Промпты (1′)

#### R1
```
/slimspec explore

Change: field in the carrier's rotating frame — slice R1 of the rework (1′) in docs/production/stage1-week1.md.

Scope:
- Physics moves into the frame rotating with the carrier's angular speed Ω_f (D35): acceleration = gravity + centrifugal + Coriolis; bodies move with relative angular speed (Ω_body − Ω_f); the carrier is stationary in the frame. Honest central gravity g(r) = k·M / (r^p + ε) is unchanged.
- GravityField: body positions/velocities in the rotating frame (carrier's Ω = Ω_f ⇒ fixed point); new potential_eff(pos) = Φ(pos) − ½·Ω_f²·r² — the single function later reused for tiers, isolines and return margin (D18/D30); the carrier's orbit is its maximum (g_eff = 0 there).
- ShipFlight.step: centrifugal and Coriolis (velocity-dependent) terms; ShipPrediction reuses the same step, so prediction keeps matching flight bit-identically. Strict 60 Hz step unchanged.
- Parameters in Tuning resources (read per call, never cached): planet surface radius, atmosphere edge, Ω_f (from the carrier's orbit, not a constant in code). Calibration target for p = 2: the D35 reference numbers (bottom drift = 80); rescaling the presets themselves is R5.
- Existing controls keep working in the new frame: thrust/boost unchanged; the existing brake still converges to a stable orbit at the current altitude — i.e. to the band-drift velocity of that depth — via relative velocities.
- Existing GravityField/ShipFlight/ShipPrediction tests are updated to the rotating-frame semantics; the week-1 result (prediction == flight) must still hold.
- TDD (acceptance from the slice table): a body at rest at the carrier stays in place; a ship moving with the band drift of its depth holds its altitude; Φ_eff is maximal at the carrier's orbit; the Jacobi integral (½v² + Φ_eff) is conserved along unforced flight.

Non-goals: camera, local vertical, D35 rendering scale and start at the carrier (R2); thrust ramp, overheat, soft brake, drift sync (R3, D36); prediction horizon changes (R4); rescaling presets and the tuning panel (R5, O71); gravity pull ceiling below the atmosphere edge (later, with presets); surface collision and atmosphere drag/damage (week 2); random moons; ceiling and tow (D35); HUD; git commit.

Context: CLAUDE.md and module CLAUDE.md files, docs/production/stage1-week1.md ("Переделка (1′)"), docs/production/prototype-tech.md ("Гравитация: один источник правды", "Интегрирование корабля"), docs/decisions.md D35 (reference numbers table), docs/design/flight.md, docs/design/gravity-well.md, docs/glossary.md. Test command is in .slimspec/config.yaml.
```

#### R2
```
/slimspec explore

Change: local-vertical camera and rendering at the D35 scale — slice R2 of the rework (1′) in docs/production/stage1-week1.md.

Scope:
- Camera2D: local vertical (D35) — screen "down" always toward the planet center under the ship, planet edge at the bottom; the world slowly rotates as the ship drifts along the sector. The camera never rotates with the ship's nose (today it is a child of Ship with ignore_rotation — decouple it). No autoscale in this slice; manual zoom only.
- Zoom 1×…40×: smooth by mouse wheel / d-pad left-right up to ~22× (the whole well in frame), beyond — coarse discrete steps.
- Planet and atmosphere as honest arcs, not a tiny circle in the middle of the screen: planet surface and atmosphere edge drawn from the field parameters (planet radius, atmosphere edge — R1); orbits (circles r = const) shown as arcs and highlighted when zoomed out.
- Start at the carrier: respawn places the ship at the carrier, at rest in the rotating frame (vel = 0 — the carrier is the frame's fixed point), replacing today's spawn on a circular orbit at spawn_radius.
- Default field/ship parameters set to the D35 reference numbers for p = 2: R = 100 000, atmosphere thickness 1 500, carrier r = 121 500, Ω_f ≈ 0.00255, bottom drift = 80, thrust 8–10, boost ×2.5. Rescaling all four presets per curve is R5, not here.
- Check Vector2 float precision at r up to ~126 500 (prototype-tech "Технические ловушки"); if visible jitter shows up, add a row to docs/production/tech-debt.md instead of redesigning now.
- Unit checks where the math is pure (camera angle toward the planet center, zoom discretization above ~22×, respawn at the carrier at rest); visual acceptance is a manual playtest — the slice table has no TDD row.

Non-goals: thrust ramp, overheat, soft brake, drift sync (R3); short-line horizon and full-line removal (R4); rescaling presets and the tuning panel (R5); camera autoscale (later, with playtest); isoline and atmosphere shaders, style frame (week 2); atmosphere drag/damage and surface collision (week 2); random moons; ceiling and tow; HUD; git commit.

Context: CLAUDE.md and module CLAUDE.md files, docs/production/stage1-week1.md, docs/decisions.md D35 (reference numbers table), docs/design/controls.md ("Камера"), docs/design/flight.md, docs/production/prototype-tech.md ("Камера и звук", "Технические ловушки"). Test command is in .slimspec/config.yaml.
```

#### R3
```
/slimspec explore

Change: controls — thrust ramp with overheat, soft brake, drift sync (D36) — slice R3 of the rework (1′) in docs/production/stage1-week1.md.

Scope:
- Thrust ramp (W / RT, held): thrust grows with hold time from a weak short-tap impulse to full (8–10, D35); time to full thrust is a prototype tunable. The hold counter lives in ShipState and advances in ShipFlight.step on the same fixed step — the short prediction line then shows the ramp automatically.
- Overheat (D36): heat grows while the main engine runs, falls without thrust; boost heats faster (D10). Above the threshold thrust falls off smoothly, at 100% heat it reaches the minimum. Nothing breaks. Only the main engine and boost heat — the soft brake and drift sync never heat, slowing down is always possible. Heat is ship state in step, same as the ramp. No separate HUD heat bar (D33); nozzle glow and sound are week 2.
- Soft brake (S / LT, held; replaces the old brake-to-circular-orbit): acceleration = ½ brake force against velocity + ½ backward from the nose. Nose along motion — full braking; nose 90° to motion — ≈ 0.71 of max; nose against velocity — no effect; near-zero speed — weak push against the nose. Max ≈ ⅓ of main thrust (hypothesis). Fuel proportional to the actually applied thrust.
- Drift sync (Shift / left-stick click, held; the former "brake"): kills velocity relative to the sync reference — the nearest interactive object (only bodies and the carrier exist now; asteroids, ring boulders and debris come later — keep the selection rule extensible, see controls.md "Открытое"); nothing near — settles to a stable orbit at the current altitude (band drift of that depth), reusing the old brake's converge-to-circular math in the rotating frame. Weaker than main thrust, more fuel per unit of work. Reference marked on screen (ReferenceMarker).
- Input actions: ship_brake (S / LT) becomes the soft brake; a drift-sync action on Shift / left-stick click replaces ship_full_trajectory (the full line itself is removed in R4). ShipInput carries the held actions into step unchanged in spirit.
- ShipParams grow: ramp time; heat growth (engine, boost), threshold, cooldown rate, min thrust at 100%; soft-brake force; drift-sync force and fuel multiplier. Fuel counters per article: engine / soft brake / drift sync / boost.
- TDD (acceptance from the slice table): thrust grows with W hold; heat grows with the engine on, falls without thrust, boost heats faster; above the threshold thrust falls smoothly, at 100% — minimum; soft brake: nose along motion kills speed, 90° — ≈ 0.71 of max, nose against velocity — zero, fuel ∝ actual thrust; drift sync with the carrier reference zeroes relative velocity, with no reference converges to band drift; brakes never heat.

Non-goals: camera and rendering (R2); short-line horizon and full-line removal (R4); presets and tuning panel (R5); nozzle glow and overheat sound (week 2); atmosphere ("sync doesn't help in atmosphere" — week 2); carrier capture zone and docking; tool aim (week 3); key remapping UI and accessibility options; telemetry beyond the existing counters; HUD; git commit.

Context: CLAUDE.md and module CLAUDE.md files, docs/production/stage1-week1.md, docs/decisions.md D36, docs/design/controls.md ("Схема", "Тяга и перегрев", "Мягкий тормоз", "Синхронизация дрейфа"), docs/design/flight.md, docs/design/hold-and-fuel.md, docs/production/prototype-tech.md ("Интегрирование корабля"). Test command is in .slimspec/config.yaml.
```

#### R4
```
/slimspec explore

Change: short prediction line at the new scale — slice R4 of the rework (1′) in docs/production/stage1-week1.md.

Scope:
- Short-line horizon 10–20 s (600–1200 steps at 60 Hz): predict_short_steps set from the horizon, stays a Tuning param; recompute every predict_every ticks, unchanged.
- Full-line mode removed from the flight scene: the ship_full_trajectory branch in Prediction.gd and the predict_full_steps param go away (Shift is drift sync since R3). The full trajectory remains only in the future Отрыв scene — nothing to keep for it here.
- ShipPrediction stays a pure static function over the same ShipFlight.step; prediction == flight keeps holding (the existing test stays green).
- Tech-debt #6 (docs/production/tech-debt.md): measure the short line's cost on the dev machine (Time.get_ticks_usec around ShipPrediction.run at 600–1200 steps, every predict_every ticks); clearly above ~4 ms — raise predict_every or thin the points; update or remove the row once measured.

Non-goals: return-margin arrow and color (week 4); Отрыв scene and its full trajectory (outside the prototype); predicting future input changes (the line replays the current input); isolines; HUD; git commit.

Context: CLAUDE.md and module CLAUDE.md files, docs/production/stage1-week1.md, docs/production/tech-debt.md (#6), docs/production/prototype-tech.md ("Предсказание траектории"), docs/design/controls.md ("Траектория на экране"), docs/design/flight.md. Test command is in .slimspec/config.yaml.
```

#### R5
```
/slimspec explore

Change: tuning panel and presets for the new parameters — slice R5 of the rework (1′) in docs/production/stage1-week1.md.

Scope:
- Presets p1–p4 rescaled per D29/D35: the full Φ_eff swing from the carrier to the atmosphere edge is equal across presets — per-p μ keeps the same ΔΦ_eff (fair comparison, not equal radii; tiers are shares of the swing). For p = 2 the D35 reference numbers fix μ (bottom drift = 80).
- Moons in presets fit the D35 sizes (large 1 000–2 000 on high orbits just below the carrier; small 300–700 low) — fixed moons in presets; random per-flight generation is week 2. Moon pull limits unchanged (O74 open).
- The preset set itself is not revised here (O71: keep / shrink / replace stays open) — rescale the existing four.
- TuningPanel: sliders for the parameters that exist after R1–R4 — gravity curve p (per body), k/eps/mass with ranges updated to the new magnitudes, thrust and its ramp time, soft-brake force, drift-sync force and fuel cost, boost multiplier and cost, heat (engine/boost growth, threshold, cooldown, min thrust at 100%), predict_every / predict_short_steps; drop removed rows (predict_full_steps). Planet radius, atmosphere edge and Ω_f stay preset-level constants, not sliders. Preset save/load .tres roundtrip unchanged; values apply live to field, ship and prediction via Tuning.preset_applied.
- TDD: preset save → load roundtrip preserves field and ship params; equal ΔΦ_eff across the rescaled presets (within tolerance) through GravityField.potential_eff; the panel writes straight into Tuning; tests restore Tuning.field / Tuning.ship.

Non-goals: deciding the final preset set (O71); moon pull calibration (O74); parameters of later weeks (ice compression, atmosphere density, return-margin factor); seed selection (week 2); telemetry beyond the existing counters; HUD; git commit.

Context: CLAUDE.md and module CLAUDE.md files, docs/production/stage1-week1.md, docs/production/prototype-tech.md ("Пресеты гравитации", "Честное сравнение", "Панель настройки в игре"), docs/decisions.md D29/D35, docs/production/open-questions.md (O71, O74). Test command is in .slimspec/config.yaml.
```

## Исходная декомпозиция (отклонена)

### Порядок

```
S1 GravityField + тела на орбитах
 │
 ▼
S2 Корабль: интегратор 60 Гц, поворот, тяга, форсаж, ввод, камера
 │
 ├──────────────┐
 ▼              ▼
S3 Предсказание  S4 Тормоз → круговая орбита
 │              │
 └──────┬───────┘
        ▼
S5 Панель настройки + пресеты .tres
```

### Общие решения

- **Параметры** поля и корабля с S1 живут в `Resource`, который держит `Tuning`.
  S5 добавляет только UI и сохранение/загрузку `.tres`.
- **Топливо в неделе 1** — только счётчики расхода по статьям (двигатель / тормоз /
  форсаж, форсаж ×3–4), бак без лимита. Масса, трюм и лимит топлива — неделя 3.
- Один `GravityField`, один шаг, один dt для полёта и предсказания.

### Срезы

| # | Срез | Суть | Проверка (TDD) |
|---|---|---|---|
| S1 | GravityField + Body | `accel/potential(pos, t)`, g = kM / (r^p + ε), p у каждого тела (для П4), радиус влияния лун; положение тела — формула орбиты от t | −∇Φ ≈ accel; положение тела при t; влияние луны за радиусом → 0 |
| S2 | Корабль | чистая `step(state, input, t, dt)`: полунеявный Эйлер, гашение вращения; WASD + геймпад (абсолютный курс); `move_and_collide` только для столкновений; счётчики расхода; камера следит, север вверху | на круговой орбите без тяги радиус держится; тяга по носу; шаг детерминирован |
| S3 | Предсказание | тот же `step` на N шагов, `Line2D`, пересчёт раз в несколько кадров; короткая линия, полная по Shift / левому стику | предсказанное состояние через N шагов == реальному полёту при том же вводе |
| S4 | Тормоз | ориентир (пока только тела), сход к круговой орбите на текущей высоте с ограничением силы, метка ориентира, расход тормоза | скорость сходится к круговой для текущего p; тормоз слабее тяги |
| S5 | Панель + пресеты | TuningPanel, сохранение/загрузка `.tres`, П1–П4 и ползунок p | пресет сохранён → загружен → параметры поля и корабля совпадают |

### Промпты

#### S1
```
/slimspec explore

Change: GravityField + bodies on orbits — slice S1 of docs/production/stage1-week1.md.

Scope:
- autoload/GravityField.gd: pure math per docs/production/prototype-tech.md ("Гравитация", "Пресеты гравитации"): accel(pos, t), potential(pos, t); g(r) = k·M / (r^p + ε), potential per p (p = 2, p = 1, general); p per body (P4 mixes planet p = 1, moons p = 2); moon influence fades smoothly beyond its radius of influence; deterministic, no physics-engine state.
- scenes/Body.tscn: planet/moon on a fixed orbit, position = formula of t; bodies register with GravityField; a planet and a couple of moons placed in scenes/Run.tscn.
- Field/body parameters live in a Resource held by autoload Tuning (panel and .tres presets come in S5).

Non-goals: ship, trajectory prediction, brake, tuning panel UI, tiers by potential, atmosphere and its pull ceiling, isolines, HUD, git commit.

Context: CLAUDE.md, autoload/CLAUDE.md, scenes/CLAUDE.md, tests/CLAUDE.md, docs/production/stage1-week1.md, docs/production/prototype-tech.md, docs/design/flight.md ("Модель гравитации"), docs/design/gravity-well.md, docs/decisions.md. Test command is in .slimspec/config.yaml.
```

#### S2
```
/slimspec explore

Change: ship flight core — slice S2 of docs/production/stage1-week1.md.

Scope:
- Pure step(state, input, t, dt) for the ship: semi-implicit Euler (or Verlet) on a strict fixed 60 Hz step in _physics_process, acceleration from GravityField; rotation with always-on spin damping; thrust along the nose; boost = stronger thrust (Space / gamepad A).
- scenes/Ship.tscn gets a script: CharacterBody2D, move_and_collide only for collisions, velocity from own code.
- Input per docs/design/controls.md: A/D rotate, W thrust, Space boost; gamepad left stick = absolute heading, RT thrust, A boost. Input map in project.godot.
- Fuel consumption counters per item (engine / boost, boost ×3–4), no tank limit.
- Camera2D follows the ship, north always up, no autoscale yet.
- Ship parameters in the Tuning Resource from S1.

Non-goals: brake (S4), trajectory prediction (S3), tuning panel (S5), mass/hold/fuel limit (week 3), autoscale camera, HUD, git commit.

Context: CLAUDE.md and module CLAUDE.md files, docs/production/stage1-week1.md, docs/production/prototype-tech.md ("Интегрирование корабля"), docs/design/flight.md, docs/design/controls.md. Test command is in .slimspec/config.yaml.
```

#### S3
```
/slimspec explore

Change: trajectory prediction — slice S3 of docs/production/stage1-week1.md; closes the week-1 result "prediction line matches flight".

Scope:
- Prediction runs the same ship step() with the same dt and the same GravityField N steps ahead, body positions from their orbit formulas at future t.
- Line2D output, recomputed every few frames; short line always (next seconds), full trajectory while Shift / left stick click is held (input map).
- Test: predicted state after N steps equals the real flight after N physics steps with the same input.

Non-goals: return-margin line and its color (week 4), brake (S4), tuning panel (S5), HUD, git commit.

Context: CLAUDE.md and module CLAUDE.md files, docs/production/stage1-week1.md, docs/production/prototype-tech.md ("Предсказание траектории"), docs/design/flight.md, docs/design/controls.md. Test command is in .slimspec/config.yaml.
```

#### S4
```
/slimspec explore

Change: brake relative to a reference — slice S4 of docs/production/stage1-week1.md.

Scope:
- Brake (S / gamepad LT, held) per docs/design/controls.md "Тормоз": with no nearby object, steer velocity toward a circular orbit at the current altitude around the dominant body, circular speed from the current curve p; limited force, weaker than main thrust; higher fuel cost (brake counter).
- Reference selection: only bodies exist now (asteroids, debris, carrier come later) — keep the selection rule extensible; reference marked on screen.
- Brake goes through the same step() so prediction (S3) stays exact.

Non-goals: matching velocity with small objects / carrier (weeks 3–4), atmosphere ("brake doesn't help in atmosphere", week 2), tuning panel (S5), git commit.

Context: CLAUDE.md and module CLAUDE.md files, docs/production/stage1-week1.md, docs/design/controls.md, docs/design/flight.md ("Тормоз"), docs/production/prototype-tech.md, docs/production/open-questions.md (brake reference rule). Test command is in .slimspec/config.yaml.
```

#### S5
```
/slimspec explore

Change: tuning panel and presets — slice S5 of docs/production/stage1-week1.md.

Scope:
- ui/TuningPanel.tscn: sliders for parameters that exist after S1–S4 (gravity curve p, thrust, brake force and consumption, boost consumption); toggled by a debug key.
- Presets as .tres in presets/ (the Tuning Resource): save / load; P1 "Ньютон", P2 "Плоский 2D", P3 "Компромисс" (panel only), P4 "Смешанный" per docs/production/prototype-tech.md.
- Changing parameters applies live to GravityField, ship and prediction.

Non-goals: parameters of later weeks (ice compression, atmosphere density, return-margin factor), seed selection (generator, week 2), unified hold / separate tank toggle (week 3), telemetry, git commit.

Context: CLAUDE.md and module CLAUDE.md files, docs/production/stage1-week1.md, docs/production/prototype-tech.md ("Пресеты гравитации", "Панель настройки в игре"). Test command is in .slimspec/config.yaml.
```
