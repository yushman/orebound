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
| R4 | Короткая линия на новом масштабе | горизонт 10–20 с; режим полной линии убран (Shift его больше не включает); `ShipPrediction` остаётся чистой функцией; tech-debt #6 — под стоимость короткой линии | — |
| R5 | Панель и пресеты под новые параметры | пресеты p перемасштабированы по D29/D35 (O71) | — |

Промпты для R1–R5 не написаны.

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
