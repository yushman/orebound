# Этап 1, неделя 2 — декомпозиция

Неделя 2 из [plan.md](plan.md): колодец с ярусами по Φ_eff, атмосфера, шейдер
изолиний, кадр стиля, генерация (этапы 1–5 с простыми кольцами, угловые
чанки, плотность по высоте, случайные луны + геометрическая проверка —
[well-generator.md](well-generator.md)); HUD: шкала колодца. Результат недели —
**колодец читается, кадр стиля собран**. Техническая основа —
[prototype-tech.md](prototype-tech.md).

Каждый срез — отдельное slimspec-изменение (explore → ground, команда
`/slimspec:slimspec`).

## Порядок

```
W1 Ярусы и константы планеты
 │
 ├──────────────┬──────────────┐
 ▼              ▼              ▼
W2 Атмосфера   W3 Изолинии    W4 Генератор: луны, прибытие, проверка
                               │
                               ▼
                              W5 Кольцо и поля, угловые чанки
 │              │              │
 └──────┬───────┴──────────────┘
        ▼
W6 Шкала колодца
        ▼
W7 Кадр стиля
```

## Общие решения (24.10.2026)

- **Планета прототипа — «Обод»:** доли перепада Φ_eff 25 / 40 / 25 / 10,
  2–3 луны, большое кольцо, средняя атмосфера
  ([../design/planets.md](../design/planets.md)). Константы — отдельный
  `Resource` планеты в `Tuning`, рядом с полем и кораблём; другие планеты —
  тот же ресурс с другими числами, позже.
- **Луны — из генератора**, а не из пресетов: пресеты p1–p4 держат только
  планету и кривую гравитации (O71 остаётся открытым).
- **Атмосфера вращается с маткой:** торможение — против скорости во
  вращающейся системе. У дна оно гасит дрейф полосы → орбита снижается →
  спираль ([../design/flight.md](../design/flight.md)). Торможение и урон — в
  `ShipFlight.step`, поэтому линия предсказания показывает спираль сама.
- **Крушение в неделе 2** (касание поверхности или корпус = 0) — респаун у
  матки с полным корпусом и счётчик крушений; гибель, буксир и обломки —
  неделя 4.
- **Астероиды в неделе 2** — уже объекты: ориентир синхронизации дрейфа (Shift
  уравнивает скорость с ближайшим) и мягкое столкновение рядом с кораблём.
  Добыча, разбивание и состав по массе — неделя 3.
- Всё положение мира — формула от t (тела, луны, кольцо, поля), состояние не
  хранится; генератор — чистая функция (константы планеты, зерно, номер
  вылета).

## Срезы

| # | Срез | Суть | Проверка (TDD) |
|---|---|---|---|
| W1 | Ярусы и константы планеты | `PlanetParams` «Обода»; радиусы границ ярусов из долей перепада Φ_eff (этап 1 генератора); граница буксира = низ среднего яруса; потолок = матка + 5 000; особые окружности в `WellView` | ΔΦ_eff между соседними границами = доле × полный перепад; границы упорядочены от кромки к матке; потолок и буксир на своих местах; для всех p пресетов |
| W2 | Атмосфера | плотность от кромки к поверхности; торможение против скорости во вращающейся системе и тикающий урон в `step`; корпус в `ShipState`; касание поверхности и корпус 0 → респаун | над кромкой эффекта нет; ниже — торможение растёт к поверхности; спираль: без тяги орбита у дна в атмосфере снижается; урон тикает только в атмосфере; предсказание == полёт с атмосферой |
| W3 | Изолинии и атмосфера в шейдерах | `canvas_item`-шейдер Φ_eff по uniform-массиву тел (до 16), `fwidth`, плотность линий от масштаба, приглушённо и ярче у корабля; радиальный градиент атмосферы | Φ_eff в шейдере совпадает с `GravityField.potential_eff` (сверка формулы на CPU-копии); шаг уровней от масштаба; остальное — плейтест |
| W4 | Генератор: луны, прибытие, проверка | чистая функция → картина вылета: луны «Обода» по D35 (крупные 1 000–2 000 чуть ниже матки, малые 300–700 низко), фазы; геометрическая проверка; повтор с новым зерном, затем запасное; зерно на панели | одно зерно → одна картина; луны в диапазонах; проверка отбраковывает луну у матки и наложения; после N провалов — запасное зерно |
| W5 | Кольцо и поля, угловые чанки | кольцо в своём ярусе (`MultiMesh`, без щелей); поля астероидов: число по плотности высоты, Poisson disk, состав по ярусу (цветом); жёсткое вращение полосы; ленивые угловые чанки вокруг корабля; астероид — ориентир синхронизации и столкновение | положение объекта — формула от t и полосы; чанк — чистая функция (зерно, полоса, номер чанка); плотность падает к матке и выше неё; Shift у астероида гасит относительную скорость; кольцо не пересекает орбиты лун |
| W6 | Шкала колодца | вертикальная шкала сбоку: сегменты по долям перепада, матка сверху, кромка атмосферы снизу (красная), граница буксира, маркер корабля по Φ_eff | положение маркера = доля перепада Φ_eff от кромки; выше матки — над шкалой до потолка |
| W7 | Кадр стиля | палитра, диски тел с терминатором, силуэт корабля с пламенем и свечением сопла от нагрева (D36), груз на корпусе (заглушка), стиль кольца и полей | — (ручной плейтест: кадр собран) |

## Промпты

### W1
```
/slimspec explore

Change: well tiers by Φ_eff and planet constants — slice W1 of docs/production/stage1-week2.md.

Scope:
- PlanetParams Resource held by Tuning (read per call, never cached), values for «Обод»: tier shares of the full Φ_eff swing 25/40/25/10 (top/middle/lower/bottom, from the carrier down to the atmosphere edge), atmosphere edge and surface radius, ceiling offset +5 000 over the carrier, moon count/size ranges and ring parameters as data for W4/W5 (unused here).
- Generator stage 1 as a pure function: tier boundary radii from the shares via GravityField.potential_eff (root-find r for a target Φ_eff on the planet's radial profile); tow boundary = bottom of the middle tier; ceiling = carrier orbit + 5 000.
- WellView draws the special boundaries as their own circles (tow boundary, atmosphere edge, ceiling), distinct from regular orbit arcs; tiers tinted as colour placeholders (scope.md: 4 tiers with colour stubs). Constant screen stroke sizes as today.
- Works for every preset p (radii differ, shares hold).
- TDD: Φ_eff difference between adjacent boundaries = share × full swing (tolerance); boundaries ordered from the atmosphere edge up to the carrier; tow boundary and ceiling where specified; for each preset p1–p4.

Non-goals: atmosphere physics (W2); isoline shader (W3); generator stages 2–5 (W4, W5); well scale HUD (W6); ceiling alarm and tow (week 4); other planets; git commit.

Context: CLAUDE.md and module CLAUDE.md files, docs/production/stage1-week2.md, docs/production/well-generator.md ("Этапы генерации"), docs/design/gravity-well.md ("Ярусы"), docs/design/planets.md, docs/decisions.md D30/D35, docs/production/prototype-tech.md. Test command is in .slimspec/config.yaml.
```

### W2
```
/slimspec explore

Change: atmosphere drag, ticking damage and crash — slice W2 of docs/production/stage1-week2.md.

Scope:
- Atmosphere between the surface and the atmosphere edge (PlanetParams from W1): density profile rising toward the surface (shape is a tunable hypothesis); «Обод» = medium atmosphere.
- Drag in ShipFlight.step against the ship's velocity in the rotating frame (the atmosphere co-rotates with the carrier frame — decision 24.10.2026): near the bottom it kills the band drift, so the orbit decays — the trap spiral from flight.md; only boost gets you out. Being in step, the short prediction line shows the spiral automatically.
- Hull: hull points in ShipState, ticking damage per second while inside the atmosphere scaled by density; no HUD bar (hull segments come later), a debug readout on the tuning panel is enough.
- Crash: touching the surface or hull reaching 0 → respawn at the carrier with full hull and fresh state; a crash counter (telemetry-ready). Death, tow and debris are week 4.
- Tunables in Tuning: drag coefficient, damage rate, hull max, density shape; sliders on the panel.
- TDD: no drag and no damage above the edge; drag grows toward the surface; unforced flight at the bottom inside the atmosphere loses altitude (spiral); damage ticks only inside; surface contact and hull 0 trigger respawn; prediction == flight still holds with the atmosphere.

Non-goals: atmosphere visuals (W3); drift sync "doesn't help in atmosphere" nuance beyond what drag gives; debris burning (week 4); death/tow/debris; hull HUD; sound; git commit.

Context: CLAUDE.md and module CLAUDE.md files, docs/production/stage1-week2.md, docs/design/flight.md ("Атмосфера", "Корпус и урон"), docs/design/failure.md, docs/production/prototype-tech.md ("Атмосфера", "Интегрирование корабля"), docs/decisions.md D35. Test command is in .slimspec/config.yaml.
```

### W3
```
/slimspec explore

Change: isoline and atmosphere shaders — slice W3 of docs/production/stage1-week2.md.

Scope:
- Isolines: canvas_item shader over the visible world (shaders/isolines.gdshader, today a stub) computing Φ_eff from a uniform array of bodies (up to ~16: positions, k·M, p, influence, fade) plus the frame term −½Ω_f²r²; the same formula as GravityField.potential_eff — one source of truth, uniforms refreshed from Tuning/GravityField every frame.
- Lines via fwidth — even thickness at any zoom; level spacing depends on camera zoom (anti-moire when zoomed out); dimmed by default, brighter near the ship. Planet levels are arcs r = const.
- Special boundaries (tow, atmosphere edge, ceiling) stay separate circles from W1 — not isolines.
- Atmosphere: radial gradient glow (shaders/atmosphere.gdshader) from the surface to the edge; heat shimmer optional if trivial.
- Float32: world coordinates ~1e5 in the shader — check banding/jitter, compute relative to the camera/planet if needed; note tech-debt #11.
- TDD where pure: a CPU mirror of the shader's Φ_eff equals GravityField.potential_eff at sample points; zoom → level spacing function. Visual acceptance — rendered frames (godot --write-movie) and manual playtest.

Non-goals: scanner pulse brightening (slice); ore heat map overlay (debug, later); style frame palette pass (W7); performance tuning beyond a sanity check; git commit.

Context: CLAUDE.md and module CLAUDE.md files, docs/production/stage1-week2.md, docs/production/prototype-tech.md ("Изолинии", "Атмосфера"), docs/presentation/visual-style.md, docs/decisions.md D35, docs/production/tech-debt.md. Test command is in .slimspec/config.yaml.
```

### W4
```
/slimspec explore

Change: well generator core — random moons, arrival, geometric check — slice W4 of docs/production/stage1-week2.md.

Scope:
- Pure function (planet constants, seed, flight number) → flight picture, deterministic; seed in telemetry-ready state. Stage 1 (tiers) comes from W1.
- Stage 2 moons per D35 within «Обод» ranges (2–3): large radius 1 000–2 000 only on high orbits just below the carrier, small 300–700 on low orbits; random phases; circular orbits with the curve's speed; they feed GravityField bodies (replacing preset moons — presets keep planet + curve only). Moon pull per O74 stays a tunable (influence radius, limiter). Moons drawn as discs of their radius.
- Stage 5 arrival: the carrier stays the fixed point of the rotating frame; the arrival rule (not inside a moon's influence, min distance to bodies, stable start) constrains moon phases.
- Geometric check: moon not near the arrival point, no overlaps, (ring vs moon orbits checked in W5). Fail → new seed, at most N tries, then a pre-validated fallback seed.
- Tuning panel: seed field, "next seed" button, regenerate applies live (same path as preset_applied).
- Moon surface: small debris is swallowed, large bodies push back softly with damage (D35) — keep minimal: ship contact with a moon disc = soft push-out + damage via the W2 hull.
- TDD: same seed → identical picture; moons in ranges and on the right orbit bands; check rejects a moon at the arrival point and overlapping moons; fallback seed after N failures; GravityField sees the generated moons.

Non-goals: rings and asteroid fields (W5); lazy chunks (W5); small objects and comets (week 3 / slice); other planets; resource and trajectory checks (slice); git commit.

Context: CLAUDE.md and module CLAUDE.md files, docs/production/stage1-week2.md, docs/production/well-generator.md, docs/design/gravity-well.md, docs/design/planets.md, docs/decisions.md D35 (moons), docs/production/open-questions.md (O71, O74, O75). Test command is in .slimspec/config.yaml.
```

### W5
```
/slimspec explore

Change: ring, asteroid fields and lazy angular chunks — slice W5 of docs/production/stage1-week2.md.

Scope:
- Stage 3 ring: a band in its tier (from PlanetParams), MultiMesh, random rotation, no resonance gaps; particles on circular orbits of their band.
- Stage 4 asteroid fields: count by resource density and the height density function (constant amount per height level → sparser higher up; sharp geometric drop toward the carrier, almost nothing above it, D35); random angle in the tier band; Poisson disk inside a field with angular noise; composition by tier as colour placeholders (well-generator table). Asteroids — random convex polygons (Polygon2D + CollisionPolygon2D).
- Everything rotates rigidly with its band's Ω: content = pure function (planet constants, seed, flight number, band, angle − Ω_band·t). Generated lazily by angular chunks around the ship; far chunks do not exist. Decide chunk size and generation radius (O75) in explore.
- Interaction (decision 24.10.2026): an asteroid is a drift-sync reference (Shift matches its velocity — extend ShipFlight.sync_reference) and a soft collision near the ship (collisions only near the ship). Mining, breaking and mass are week 3.
- Geometric check gains: ring does not cross moon orbits; fields do not overlap moons.
- TDD: object position is a formula of t and band; a chunk is a pure function of (seed, band, chunk index); density falls toward the carrier and above it; Shift near an asteroid zeroes relative velocity; ring vs moon orbit check; prediction == flight unaffected.

Non-goals: mining, tool, breaking (week 3); small objects on elongated orbits (week 3); resource check (slice); ore heat map; style pass (W7); git commit.

Context: CLAUDE.md and module CLAUDE.md files, docs/production/stage1-week2.md, docs/production/well-generator.md, docs/design/gravity-well.md, docs/design/controls.md ("Синхронизация дрейфа"), docs/production/prototype-tech.md ("Генерация"), docs/production/open-questions.md (O47, O75). Test command is in .slimspec/config.yaml.
```

### W6
```
/slimspec explore

Change: well scale HUD — slice W6 of docs/production/stage1-week2.md.

Scope:
- Vertical well scale at the screen side (hud.md "Вертикальная шкала колодца"): tier segments proportional to the Φ_eff shares (D30) — it shows the price of climbing, not distance; carrier at the top, atmosphere edge at the bottom (red), tow boundary line, ship marker by its Φ_eff share; above the carrier the marker goes over the scale up to the ceiling.
- Lives in ui/HUD (today an empty Control root); colour is not the only carrier of meaning (hud.md accessibility) — tier labels or patterns.
- TDD: marker position = Φ_eff share from the atmosphere edge; segment sizes = shares; ceiling/above-carrier mapping.

Non-goals: energy bar, hold bar, hull segments, arrow to the carrier, warnings (weeks 3–4); contract depth mark and debris icons (slice); git commit.

Context: CLAUDE.md and module CLAUDE.md files, docs/production/stage1-week2.md, docs/design/hud.md, docs/design/gravity-well.md, docs/decisions.md D30/D35. Test command is in .slimspec/config.yaml.
```

### W7
```
/slimspec explore

Change: style frame — slice W7 of docs/production/stage1-week2.md.

Scope:
- One style frame in the engine (visual-style.md "Первый шаг"): well with isolines, planet with atmosphere, ring, ship with cargo, climb trajectory.
- Palette of 5–7 colours bound to meaning (ice cold blue, ore amber→bright, atmosphere/danger red-orange, isolines/UI muted green or white, carrier/safety warm yellow), «Обод» accent.
- Bodies as flat discs with a terminator (light from the star on one side); ship silhouette of a few polygons with engine flame; nozzle glow from heat (D36 — the overheat readout without a HUD bar); cargo containers on the hull as a placeholder (real hold is week 3); ring and fields in the palette.
- Visual acceptance: rendered frames (godot --write-movie) + manual playtest; screenshot saved for the mood board.

Non-goals: hub illustrations; sound (week 4); scanner; final art; smooth prediction-line transition (later polish, controls.md); git commit.

Context: CLAUDE.md and module CLAUDE.md files, docs/production/stage1-week2.md, docs/presentation/visual-style.md, docs/design/hud.md, docs/design/controls.md, docs/decisions.md D36. Test command is in .slimspec/config.yaml.
```
