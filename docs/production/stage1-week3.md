# Этап 1, неделя 3 — декомпозиция

Неделя 3 из [plan.md](plan.md): трюм с массой и объёмом, топливо, лёд и руда,
инструмент, мелкие объекты (упрощённый этап 7 генератора: вытянутые орбиты с
частотой по ярусу, без комет) и разбивание, глыбы кольца, аварийный сброс; HUD:
полоса энергии с отметкой, полоса трюма, корпус. Результат недели — **полный
вылет**: спуститься с топливом, набрать груз, при нужде сбросить часть и
подняться к матке (стыковка — неделя 4). Техническая основа —
[prototype-tech.md](prototype-tech.md).

Каждый срез — отдельное slimspec-изменение (explore → ground, команда
`/slimspec:slimspec`).

## Порядок

```
M1 Трюм и масса                    M4 Мелкие объекты
 │                                  │
 ├──────────────┐                   │
 ▼              ▼                   ▼
M2 Топливо     M3 Луч и добыча     M5 Импульс и разбивание
 │              │                   │
 │              ├──► M6 Глыбы кольца│
 │              │                   │
 │              └─────────┬─────────┘
 │                        ▼
 │                       M7 Аварийный сброс и контейнер
 ▼
M8 HUD: энергия, трюм, корпус
```

M1 и M4 независимы и идут параллельно. M7 ждёт M3 (подбор лучом) и M4
(свободный полёт объекта).

## Общие решения (26.10.2026)

- **Ресурсы — лёд и руда по ярусам** (а не «лёд + 1 руда»): лёд и базовая —
  верхний, средняя — средний, редкая — нижний, уникальная — дно; массы и
  энергия по таблице [../design/economy.md](../design/economy.md). Цены и
  переработка в прототипе не нужны.
- **Трюм — ячейки:** тип, масса, объём; число ячеек — параметр корабля
  (служебная шлюпка 10, масса корпуса 4). Ячейка наполняется добычей
  постепенно, частичная ячейка занимает место целиком.
- **Топливо — энергия ячеек трюма.** Сначала сгорают ячейки сжатого топлива:
  вылет всегда начинается с готовым топливом (стартовая комплектация —
  `Tuning`, шлюпке 2 ячейки). **Лёд — средство спасения, а не топливо:**
  горит только когда ячейки топлива кончились. Всё пусто — двигатель, тормоз,
  синхронизация и форсаж не работают (буксир — неделя 4).
- **Масса — в `ShipFlight.step`:** ускорение тяги = сила / (корпус + трюм),
  расход — от силы и времени; масса — часть состояния корабля, поэтому линия
  предсказания учитывает её сама. Нынешние счётчики `fuel_*` остаются
  разбивкой расхода по статьям для телеметрии.
- **A/B «единый трюм / отдельный бак»** — флаг пресета (DoD плана); в режиме
  бака топливо в своём объёме, лёд — только груз.
- **Добытое меняет мир:** мир по-прежнему формула от t, а изменения вылета
  (выбранная масса астероида, разбитый объект, контейнер) — отдельный слой
  состояния вылета поверх неё, по идентификатору объекта (полоса, чанк,
  индекс).
- **Сброшенный груз — контейнер на орбите:** свободное тело со своей
  траекторией (как мелкий объект), подбирается лучом обратно в трюм, служит
  ориентиром синхронизации.

## Срезы

| # | Срез | Суть | Проверка (TDD) |
|---|---|---|---|
| M1 | Трюм и масса | таблица ресурсов в `Tuning`; трюм ячеек в `ShipState` (копируется для предсказания); масса корабля = корпус + трюм; ускорение тяги, тормоза, синхронизации и форсажа делится на массу; стартовая комплектация; флаг отдельного бака | масса = корпус + Σ ячеек; при большей массе та же тяга даёт меньше Δv; ячейки не превышают ёмкость; предсказание == полёт с грузом |
| M2 | Топливо из трюма | расход списывает энергию: ячейки топлива → лёд → пусто; пустая ячейка освобождает место; без энергии двигатели молчат; калибровка расхода под цену подъёма economy.md; режим бака | порядок сгорания; ячейка освобождается на нуле; без энергии тяга 0; расход пропорционален фактической тяге (D36); форсаж в 3–4 раза дороже на ту же Δv |
| M3 | Луч и добыча | состав астероида по ярусу и запас по площади; ЛКМ / RB — луч по прицелу (мышь / правый стик, независимо от носа) до ближайшего астероида в дальности; добыча с темпом в ячейки; астероид уменьшается, выработанный исчезает; слой изменений вылета; трюм полон — луч не добывает | состав по ярусу; добыча в нужный тип с темпом; масса трюма растёт; радиус столкновения и снимок предсказания учитывают выработку; полный трюм — ничего не добавляется; одно зерно → один состав |
| M4 | Мелкие объекты | упрощённый этап 7: появление по зерну и времени с частотой по ярусу, вытянутые орбиты через ярусы, полёт в том же `GravityField`, видны заранее; существуют только рядом с кораблём; мелкий проглатывается с уроном, крупный мягко отталкивает | расписание появления — чистая функция (зерно, вылет, ярус, окно времени); частота по ярусу; траектория совпадает с интегрированием поля; удар даёт урон, крупный отталкивает |
| M5 | Импульс и разбивание | ПКМ / LB — импульс в радиусе по прицелу с перезарядкой: разбивает мелкий объект (`Geometry2D.clip_polygons`) на слабые быстро сгорающие осколки или отталкивает (O3 — флаг `Tuning`); отдача толкает корабль (в `step`); из разбитого — очень мало ресурса | осколки суммарно не больше исходного; осколки сгорают за время; отдача = −импульс / масса корабля; перезарядка; флаг «отталкивать» не разбивает |
| M6 | Глыбы кольца | редкие глыбы среди частиц кольца: те же ленивые угловые чанки, вращение с Ω полосы кольца; средняя руда, янтарный акцент «Обода»; добыча лучом, мягкое столкновение, ориентир синхронизации (well-generator.md, этап 3) | глыбы лежат в полосе кольца; положение — формула от t; чанк — чистая функция; Shift у глыбы гасит относительную скорость; добыча даёт среднюю руду |
| M7 | Аварийный сброс и контейнер | X / B долгим нажатием (время — `Tuning`): сброс ячейки самого тяжёлого груза, топливо не трогается; удержание дальше — следующая ячейка; сброшенное — контейнер со скоростью корабля + малый отлёт; подбор лучом; счётчик отменённых в первую секунду нажатий; компонент долгого нажатия переиспользует буксир (неделя 4) | короткое нажатие не сбрасывает; сбрасывается самая тяжёлая ячейка, не топливо; масса падает; контейнер летит в поле и подбирается обратно; отмена в первую секунду считается |
| M8 | HUD: энергия, трюм, корпус | полоса энергии (сумма энергии в трюме) с отметкой «нужно на подъём отсюда» — энергетическая оценка запаса возврата (prototype-tech.md) × коэффициент запаса, жёлтый у отметки, красный ниже; полоса ячеек трюма с массой и узорами по типу; сегменты корпуса; контейнеры на корпусе в `ShipView` по реальному трюму вместо `cargo_fill` | отметка растёт с массой и глубиной; ниже матки = 0 у матки; цвет по положению энергии относительно отметки; ячейки и масса по трюму; сегменты по корпусу |

## Промпты

### M1
```
/slimspec explore

Change: hold cells and ship mass — slice M1 of docs/production/stage1-week3.md.

Scope:
- Resource table in Tuning (data, not hardcoded): ice, base, middle, rare, unique ore and compressed fuel cell with mass per cell, volume per cell and energy (ice 1/1, fuel 3/3, ore masses 1/2/3/3) per docs/design/economy.md.
- Hold as cells in ShipState (copied for prediction): each cell has a type and fill (0..1, a partial cell takes a whole slot); capacity and hull mass are ship parameters (service boat: 10 cells, hull mass 4).
- Ship mass = hull + Σ cells; thrust, soft brake, drift sync and boost accelerations in ShipFlight.step are force / mass, calibrated so today's tuned accelerations hold at a reference mass (decide which in explore). Keep D35 thrust/gravity ratio in mind.
- Starting loadout in Tuning (boat: 2 fuel cells); applied on spawn and respawn.
- A/B flag "single hold / separate tank" in the preset (separate tank: fuel lives in its own volume outside the cells); only the data model and flag here, burning is M2.
- Sliders for capacity, hull mass and loadout on the tuning panel.
- TDD: mass = hull + cells; heavier ship gets less Δv for the same input; cells never exceed capacity; prediction == flight with cargo; copy() is deep.

Non-goals: burning fuel from the hold (M2); mining (M3); jettison (M7); HUD bars (M8); refining; prices; git commit.

Context: CLAUDE.md and module CLAUDE.md files, docs/production/stage1-week3.md, docs/design/hold-and-fuel.md, docs/design/economy.md ("Ресурсы", "Корабли в числах"), docs/design/flight.md, docs/production/prototype-tech.md ("Трюм", "Интегрирование корабля"), docs/decisions.md D35/D36. Test command is in .slimspec/config.yaml.
```

### M2
```
/slimspec explore

Change: fuel burned from the hold — slice M2 of docs/production/stage1-week3.md.

Scope:
- All propulsion (main engine, soft brake, drift sync, boost) draws energy from the hold in step: fuel cells first, raw ice only after the fuel cells are empty (ice is a rescue, not fuel — decision 26.10.2026); an emptied cell frees its slot and its mass.
- No energy left → engine, brake, sync and boost give zero acceleration (tow is week 4).
- Consumption stays proportional to actual thrust (ramp and overheat, D36); boost 3–4× the main engine for the same Δv; sync dearer than the main engine; soft brake like the main engine for the same Δv. Existing fuel_* counters stay as the per-category breakdown for telemetry, now in energy units.
- Calibrate the energy unit so a clean climb from the middle of the middle tier costs ≈ economy.md's coefficient × mass (≈ 0.2 × mass, whole flight ≈ 1.3 × climb); expose the factor in Tuning.
- Separate tank mode (M1 flag): burns from the tank only; ice is cargo.
- TDD: burn order fuel → ice → empty; slot freed at zero; zero thrust with no energy; consumption ∝ actual thrust; boost ratio; prediction == flight while cells drain and when they run out mid-line.

Non-goals: return margin estimate and energy bar (M8); refining (slice); tow on empty (week 4); git commit.

Context: CLAUDE.md and module CLAUDE.md files, docs/production/stage1-week3.md, docs/design/hold-and-fuel.md ("Расход топлива", "Единый трюм"), docs/design/economy.md ("Подъём", "Опорная цена топлива"), docs/design/flight.md, docs/decisions.md D35/D36. Test command is in .slimspec/config.yaml.
```

### M3
```
/slimspec explore

Change: mining beam and asteroid composition — slice M3 of docs/production/stage1-week3.md.

Scope:
- Asteroid composition by tier (top: ice + base, middle: middle ore, lower: rare, bottom: unique — gravity-well.md) and amount by polygon area; part of the pure chunk function (same seed → same composition). Colour placeholders become the composition colours from Palette.
- Beam on LMB / RB, aimed by mouse world point / right stick independently of the nose (controls.md): hits the nearest asteroid along the ray within beam range; extracts at a rate into hold cells of the asteroid's type (fills a partial cell, then opens a new one); hold full → nothing is added.
- Per-flight change layer over the formula world, keyed by (band, chunk, index): remaining amount; the asteroid shrinks with it (collision radius and polygon) and disappears when empty. The prediction snapshot and drift sync see the shrunk asteroid.
- Beam visual: a line to the hit point; zoom-in while drilling is camera autoscale (later, not here).
- Tunables: beam range, rate, amount per area.
- TDD: composition by tier; extraction rate and type; hold mass grows; full hold adds nothing; mined asteroid shrinks and vanishes; same seed → same composition; prediction == flight around a mined asteroid.

Non-goals: impulse (M5); ring boulders (M6); picking up containers (M7); scanner; ore heat map; autoscale on drilling; git commit.

Context: CLAUDE.md and module CLAUDE.md files (gen/CLAUDE.md), docs/production/stage1-week3.md, docs/design/flight.md ("Инструмент"), docs/design/controls.md, docs/design/gravity-well.md ("Ярусы", "Ресурсы"), docs/production/prototype-tech.md ("Инструмент", "Генерация"), docs/production/tech-debt.md (#29). Test command is in .slimspec/config.yaml.
```

### M4
```
/slimspec explore

Change: small objects on elongated orbits — slice M4 of docs/production/stage1-week3.md (simplified generator stage 7).

Scope:
- Spawn schedule as a pure function (planet constants, seed, flight, tier, time window) with frequency per tier; objects start on elongated orbits that cross tiers; no comets.
- Free flight in the same GravityField (own function, same fixed step); they exist only near the ship (spawn and despawn radius); visible ahead of time (no invisible instant death — flight.md).
- Random convex polygons, sizes small to medium.
- Contact only near the ship: small ones are swallowed with damage, large ones push softly with damage (flight.md "Корпус и урон").
- Decide in explore whether the short prediction line sees small objects (honesty vs a jumpy line) and how prediction == flight holds.
- A generic free-body piece reused by M5 fragments and M7 containers.
- Tunables: frequency per tier, eccentricity range, sizes, damage.
- TDD: same seed → same schedule; frequency per tier; trajectory equals the field integration; swallow vs push by size; damage on hit.

Non-goals: impulse and breaking (M5); comets, full stage 7, frequency per planet (slice); warning text and stereo cue (week 4); git commit.

Context: CLAUDE.md and module CLAUDE.md files (gen/CLAUDE.md), docs/production/stage1-week3.md, docs/production/well-generator.md (stage 7, "Прототип"), docs/production/prototype-tech.md ("Мелкие объекты"), docs/design/flight.md, docs/production/open-questions.md (O63). Test command is in .slimspec/config.yaml.
```

### M5
```
/slimspec explore

Change: impulse and breaking — slice M5 of docs/production/stage1-week3.md.

Scope:
- Impulse on RMB / LB, aimed like the beam; area in front of the aim with a cooldown.
- Small objects in the area break (Geometry2D.clip_polygons / intersect_polygons) into weak fragments that burn out fast, or are pushed away — O3 as a Tuning flag for the playtest.
- Recoil pushes the ship (third law) inside step, scaled by ship mass — a possible manoeuvre trick.
- Broken objects drop very little resource (flight.md: shooting debris must not beat mining).
- Asteroids are not broken by the impulse.
- TDD: fragments' total area ≤ the original; fragments vanish after their lifetime; recoil = −impulse / ship mass; cooldown blocks a second shot; push mode does not break.

Non-goals: tool upgrades; pirates; sound; git commit.

Context: CLAUDE.md and module CLAUDE.md files, docs/production/stage1-week3.md, docs/design/flight.md ("Инструмент"), docs/design/controls.md, docs/production/prototype-tech.md ("Инструмент", "Генерация"), docs/production/open-questions.md (O3). Test command is in .slimspec/config.yaml.
```

### M6
```
/slimspec explore

Change: ring boulders — slice M6 of docs/production/stage1-week3.md.

Scope:
- Ring particles stay MultiMesh background without physics; among them rare boulders are real objects like asteroids (well-generator.md stage 3, "Глыбы кольца").
- Boulders lie in the ring band and rotate with its Ω, generated by the same lazy angular chunks; composition — middle ore (the ring is the main additive source on «Обод», planets.md); colour — «Обод» amber accent, not ice.
- Interaction: mining by the M3 beam, soft collision, drift-sync reference.
- Decide in explore: boulder density, size relative to asteroids, whether particles hinder flight (default: no).
- TDD: boulders inside the ring band; position is a formula of t; chunk is a pure function; Shift near a boulder zeroes relative velocity; mining yields middle ore; prediction == flight.

Non-goals: ring gaps; particle physics; git commit.

Context: CLAUDE.md and module CLAUDE.md files (gen/CLAUDE.md, scenes/CLAUDE.md), docs/production/stage1-week3.md, docs/production/well-generator.md (stage 3), docs/design/planets.md, docs/design/controls.md ("Синхронизация дрейфа"). Test command is in .slimspec/config.yaml.
```

### M7
```
/slimspec explore

Change: emergency jettison and cargo container — slice M7 of docs/production/stage1-week3.md.

Scope:
- X / B long press (hold time in Tuning): drops one cell of the heaviest cargo; fuel cells are never dropped; holding on drops the next cell at an interval.
- A dropped cell becomes a container: a free body (M4 piece) starting with the ship velocity plus a small separation push, flying in the field; it is a drift-sync reference and can be picked back into the hold by the beam (M3).
- A reusable long-press component (the tow in week 4 uses it); presses released within the first second are counted (accidental-press metric for telemetry).
- Accessibility double-press mode — not here.
- TDD: a short press drops nothing; the heaviest non-fuel cell goes first; mass drops; container trajectory follows the field; beam pickup returns the cell; cancel within the first second is counted.

Non-goals: tow (week 4); debris of lost ships (slice); toggle/double-press accessibility; git commit.

Context: CLAUDE.md and module CLAUDE.md files, docs/production/stage1-week3.md, docs/design/hold-and-fuel.md ("Единый трюм"), docs/design/controls.md, docs/design/hud.md, docs/production/prototype-tech.md ("Телеметрия"). Test command is in .slimspec/config.yaml.
```

### M8
```
/slimspec explore

Change: energy bar, hold bar and hull segments — slice M8 of docs/production/stage1-week3.md.

Scope:
- Energy bar (hud.md "Полоса энергии"): total energy in the hold (or tank) with the mark "needed to climb from here" — the energy estimate of the return margin from prototype-tech.md (Φ_eff difference to the carrier orbit, from below or above, + kinetic term relative to the carrier) × ship mass → energy via the M2 calibration × a tunable margin factor. Normal right of the mark, yellow near it, red below. A pure function reused by the week-4 arrow to the carrier.
- Hold bar under it: one slot per cell, type by colour and pattern (fuel striped, ice dotted — colour is not the only carrier), partial fill, total mass.
- Hull segments next to the hold.
- ShipView cargo containers from the real hold; drop the Tuning.view.cargo_fill placeholder.
- Layout per hud.md (bottom centre); base viewport 1280×800.
- TDD: the mark grows with mass and depth and is ~0 at the carrier; colour thresholds; cells and mass mirror the hold; segments mirror hull.

Non-goals: arrow to the carrier and its colour, warnings, sound (week 4); stable-orbit and tow icons (slice); numbers on the bar (open question); git commit.

Context: CLAUDE.md and module CLAUDE.md files (ui/), docs/production/stage1-week3.md, docs/design/hud.md, docs/design/hold-and-fuel.md, docs/production/prototype-tech.md ("Запас возврата в прототипе"), docs/presentation/visual-style.md, docs/decisions.md D30/D35. Test command is in .slimspec/config.yaml.
```
