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
 ▼              ▼                   │
M2 Топливо     M3 Луч и добыча      │
 │              │                   │
 │              └─────────┬─────────┘
 │                        ▼
 │                       M5 Раскол лучом и сбор
 │                        │
 │                        ├──► M6 Глыбы кольца
 │                        │
 │                        └──► M7 Аварийный сброс и контейнер
 ▼
M8 HUD: энергия, трюм, корпус
 ▲
 │   M7 ──► M9 Перелив льда в бак

M10 Корабль на зуме и шеврон скорости (независим)
M11 Звёздный фон (независим)
M12 Поле ограничивает скорость (независим)
```

M1 и M4 независимы и идут параллельно. M5 (раскол лучом и сбор, D40) ждёт M3
(луч) и M4 (свободное тело кусков). M6 (глыбы разбиваются и собираются) и M7
(контейнер подбирается сбором, не лучом) ждут M5. M9 ждёт M7 (компонент долгого
нажатия). M10, M11 и M12 независимы: M12 трогает `AsteroidField` и
`ShipFlight` и не зависит от M4 и M5.

## Общие решения (26.10.2026)

- **Ресурсы — лёд и руда по ярусам** (а не «лёд + 1 руда»): лёд и базовая —
  верхний, средняя — средний, редкая — нижний, уникальная — дно; массы и
  энергия по таблице [../design/economy.md](../design/economy.md). Цены и
  переработка в прототипе не нужны.
- **Трюм — ячейки:** тип, масса, объём; число ячеек — параметр корабля
  (служебная шлюпка 10, масса корпуса 4). Ячейка наполняется добычей
  постепенно, частичная ячейка занимает место целиком.
- **Топливо — энергия ячеек бака** (по умолчанию отдельный бак, 4 ячейки;
  [D38](../decisions.md)). Стартовая комплектация — `Tuning`, шлюпке 2 ячейки
  топлива в баке. **Сырой лёд — груз трюма, сам не горит;** в бак его
  переливают долгим нажатием (M9). Бак пуст — двигатель, тормоз, синхронизация
  и форсаж не работают (буксир — неделя 4).
- **Масса — в `ShipFlight.step`:** ускорение тяги = сила / (корпус + трюм),
  расход — от силы и времени; масса — часть состояния корабля, поэтому линия
  предсказания учитывает её сама. Нынешние счётчики `fuel_*` остаются
  разбивкой расхода по статьям для телеметрии.
- **A/B «единый трюм / отдельный бак»** решён 27.10.2026 в пользу бака
  ([D38](../decisions.md)): режим единого трюма и флаг `separate_tank`
  удалены из кода; топливо — только в баке, лёд — только груз.
- **Добытое меняет мир:** мир по-прежнему формула от t, а изменения вылета
  (выбранная масса астероида, разбитый объект, контейнер) — отдельный слой
  состояния вылета поверх неё, по идентификатору объекта (полоса, чанк,
  индекс).
- **Сброшенный груз — контейнер на орбите:** свободное тело со своей
  траекторией (как мелкий объект), подбирается сбором (ПКМ / LB, D40) обратно в
  трюм, служит ориентиром синхронизации.
- **D40 (27.10.2026):** скорость ограничивает поле (квадратичный урон по
  скорости относительно течения полосы, ореол полей астероидов — M12, M4);
  добыча идёт через раскол: ЛКМ / RB — луч-лазер разбивает объекты, ПКМ / LB —
  сбор в секторе (0,5 × `beam_range`); импульс убран. Луч больше не вытягивает
  ресурс в трюм — переделка M3 в M5 ([D40](../decisions.md)).

## Срезы

| # | Срез | Суть | Проверка (TDD) |
|---|---|---|---|
| M1 | Трюм и масса | таблица ресурсов в `Tuning`; трюм ячеек в `ShipState` (копируется для предсказания); масса корабля = корпус + трюм; ускорение тяги, тормоза, синхронизации и форсажа делится на массу; стартовая комплектация; отдельный бак | масса = корпус + Σ ячеек; при большей массе та же тяга даёт меньше Δv; ячейки не превышают ёмкость; предсказание == полёт с грузом |
| M2 | Топливо из трюма | расход списывает энергию ячеек топлива в баке до пустого; пустая ячейка освобождает место; без энергии двигатели молчат; калибровка расхода под цену подъёма economy.md; лёд в трюме не горит | частичная ячейка бака сгорает первой; ячейка освобождается на нуле; без энергии тяга 0; расход пропорционален фактической тяге (D36); форсаж в 3–4 раза дороже на ту же Δv |
| M3 | Луч и добыча | **D40 переделывает срез: луч больше не вытягивает ресурс в трюм, переделка — в M5.** Состав астероида по ярусу и запас по площади; ЛКМ / RB — луч по прицелу (мышь / правый стик, независимо от носа) до ближайшего астероида в дальности; добыча с темпом в ячейки; астероид уменьшается, выработанный исчезает; слой изменений вылета; трюм полон — луч не добывает | состав по ярусу; добыча в нужный тип с темпом; масса трюма растёт; радиус столкновения и снимок предсказания учитывают выработку; полный трюм — ничего не добавляется; одно зерно → один состав |
| M4 | Мелкие объекты | упрощённый этап 7: появление по зерну и времени с частотой по ярусу, вытянутые орбиты через ярусы, полёт в том же `GravityField`, видны заранее; существуют только рядом с кораблём; мелкий проглатывается с уроном, крупный мягко отталкивает; урон от удара — квадратичный `k·max(0, v_rel − v_safe)²` по скорости относительно течения полосы (D40, общее правило с M12); свободное тело переиспользуют куски M5 | расписание появления — чистая функция (зерно, вылет, ярус, окно времени); частота по ярусу; траектория совпадает с интегрированием поля; удар даёт урон, крупный отталкивает; урон квадратичный по v_rel, ниже v_safe нулевой |
| M5 | Раскол лучом и сбор | ЛКМ / RB — луч копит урон на цели, на пороге тело делится на N кусков следующего меньшего класса размера (простое деление, без линии разреза); самый мелкий класс — собираемый; ресурс сохраняется (площадь × amount_per_area); куски слегка разлетаются и становятся свободными телами M4; ПКМ / LB — сбор: сектор перед прицелом, дальность 0,5 × `beam_range`, угол — параметр; собираемые куски в секторе тянутся к кораблю с ускорением, притяжение сдвигает только позицию и не меняет собственную скорость куска; кусок в круге корабля попадает в трюм (заменяет вытягивание лучом из M3); куски крошатся по времени жизни; зависит от M3 и M4 | урон копится только пока луч на цели и порог ломает тело; куски суммарно по ресурсу равны исходному; класс куска на единицу меньше; самый мелкий класс собирается, остальные нет; сектор: в конусе и в дальности тянет, вне — нет; скорость куска не меняется притяжением; кусок в круге корабля — в трюме, трюм полон — не собирается; кусок крошится за время жизни; сбор ничего не разбивает |
| M6 | Глыбы кольца | редкие глыбы среди частиц кольца: те же ленивые угловые чанки, вращение с Ω полосы кольца; средняя руда, янтарный акцент «Обода»; глыбы разбиваются лучом и собираются сбором (M5), не вытягиваются; мягкое столкновение, ориентир синхронизации (well-generator.md, этап 3) | глыбы лежат в полосе кольца; положение — формула от t; чанк — чистая функция; Shift у глыбы гасит относительную скорость; раскол глыбы и сбор кусков даёт среднюю руду |
| M7 | Аварийный сброс и контейнер | X / B долгим нажатием (время — `Tuning`); короткое нажатие на X / B выбирает ячейку для сброса (детали — решить в explore: перебор, показ, сбрасывает ли долгое нажатие выбранную или самую тяжёлую, метрика отмен); сброс ячейки самого тяжёлого груза, топливо не трогается; удержание дальше — следующая ячейка; сброшенное — контейнер со скоростью корабля + малый отлёт; подбор сбором (ПКМ / LB), не лучом (D40); счётчик отменённых в первую секунду нажатий; компонент долгого нажатия переиспользует буксир (неделя 4) | короткое нажатие не сбрасывает, а выбирает ячейку для сброса; сбрасывается самая тяжёлая ячейка, не топливо; масса падает; контейнер летит в поле и подбирается сбором обратно; отмена в первую секунду считается |
| M8 | HUD: энергия, трюм, корпус | полоса энергии (сумма энергии в баке) с отметкой «нужно на подъём отсюда» — энергетическая оценка запаса возврата (prototype-tech.md) × коэффициент запаса, жёлтый у отметки, красный ниже; полоса ячеек трюма с массой и узорами по типу; сегменты корпуса; контейнеры на корпусе в `ShipView` по реальному трюму вместо `cargo_fill` | отметка растёт с массой и глубиной; ниже матки = 0 у матки; цвет по положению энергии относительно отметки; ячейки и масса по трюму; сегменты по корпусу |
| M9 | Перелив льда в бак | долгое нажатие R / X (компонент M7) переливает лёд из трюма в бак, стабильная орбита не нужна; два режима: без усилителя сырой лёд занимает целую ячейку бака с энергией 1 (топливо 3, на ту же тягу сгорает больше); с усилителем — переработка, 1 ячейка льда → 1/3 ячейки топлива; усилитель — флаг в `Tuning`, заменяет покупное улучшение; бак полон — ничего не льётся; полоса энергии считает только бак | сырой лёд занимает целую ячейку бака с энергией 1; с усилителем 1 лёд → 1/3 ячейки топлива; бак полон — ничего не перелито; полоса энергии считает только бак |
| M10 | Корабль на зуме и шеврон скорости | корабль честного мирового размера — при отдалении уменьшается (больше не масштабируется на s); когда на экране он меньше порога (~12 px), плавно гаснет и проявляется прицел-крестик постоянного экранного размера (порог и ширина перехода — `Tuning.view`, D39); шеврон скорости вместо стрелки `FlightVector`: без древка, на постоянном экранном расстоянии от корабля по вектору скорости, чуть дальше крестика (размеры подобрать), |v| числом рядом, скрыт ниже 1 u/s | экранный размер корабля ∝ 1/s; переход корабль → крестик по экранному размеру, плавный; крестик постоянного экранного размера; позиция шеврона не зависит от |v| и не перекрывает крестик; подпись = округлённое |v|; ниже порога скрыт |
| M11 | Звёздный фон | неподвижное звёздное небо в системе матки (вращающейся, как орбиты и `LIGHT_DIR`): у матки в покое звёзды стоят, собственное движение и дрейф полосы видны относительно них; процедурно (шейдер по мировым клеткам, хеш от клетки), рисуется первым; плотность на экране примерно постоянна на зуме 1–40 (слои по масштабу с плавным переходом); приглушённо, не спорит с ореолами и орбитами | звезда в мировой точке остаётся в ней при движении корабля и камеры; одно зерно — одно небо; плотность на экране в допуске на зумах 1, 10, 40; цвет из `Palette` |
| M12 | Поле ограничивает скорость | урон от удара — квадратичный по скорости относительно течения полосы `k·max(0, v_rel − v_safe)²` вместо линейного урона на ед/с (D40); у полей астероидов ореол: плотность растёт от края к ядру, скорость гасится постепенно при подходе; настройки `Tuning`: v_safe (≈ 10–15 ед/с), k, форма ореола (гипотезы); независим от M4 и M5, трогает `AsteroidField` и `ShipFlight` | ниже v_safe урон 0; выше растёт квадратично; v_rel считается к течению полосы, не к миру; плотность ореола монотонно растёт от края к ядру; один seed → одна плотность; предсказание == полёт |

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

Note: D40 (docs/decisions.md) reworks this slice — the beam no longer extracts resource into the hold; the rework is in M5 (beam split and collector).

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
- Contact only near the ship: small ones are swallowed with damage, large ones push softly with damage (flight.md "Корпус и урон"). Damage follows the D40 quadratic rule k·max(0, v_rel − v_safe)² with v_rel relative to the local band flow (v_safe, k in Tuning, hypotheses; shared with M12 — whichever slice lands first adds the function).
- Decide in explore whether the short prediction line sees small objects (honesty vs a jumpy line) and how prediction == flight holds.
- A generic free-body piece reused by M5 pieces (broken-asteroid pieces) and M7 containers.
- Tunables: frequency per tier, eccentricity range, sizes, damage.
- TDD: same seed → same schedule; frequency per tier; trajectory equals the field integration; swallow vs push by size; damage on hit is quadratic in v_rel and zero below v_safe.

Non-goals: beam breaking and collecting (M5); comets, full stage 7, frequency per planet (slice); warning text and stereo cue (week 4); git commit.

Context: CLAUDE.md and module CLAUDE.md files (gen/CLAUDE.md), docs/production/stage1-week3.md, docs/production/well-generator.md (stage 7, "Прототип"), docs/production/prototype-tech.md ("Мелкие объекты"), docs/design/flight.md, docs/production/open-questions.md (O63). Test command is in .slimspec/config.yaml.
```

### M5
```
/slimspec explore

Change: beam split and collector — slice M5 of docs/production/stage1-week3.md (D40).

Scope:
- Beam on LMB / RB (M3 aiming) accumulates damage on the target while held on it; at the threshold the body breaks into N pieces (plain split into N, no cut line). Asteroids have N size classes; breaking gives pieces of the next smaller class; the smallest class is the collectible one. Resource is conserved (piece amount = area × amount_per_area, as in M3). Pieces fly apart slightly relative to the band and become free bodies (the M4 free-body piece). The beam no longer extracts resource into the hold (replaces the M3 extraction).
- Collector on RMB / LB: a sector (cone) in front of the aim, range 0.5 × beam_range, angle is a Tuning parameter; it cannot break anything. Collectible pieces inside the sector are pulled toward the ship with acceleration; the pull only shifts the piece's position while it is in the sector and does not change the piece's own velocity (leaving the sector, it continues with its own velocity from the new position). A piece entering the ship's circle is collected into the hold; no relative-speed requirement; hold full → not collected. If this turns out complex in implementation, simplify and note it.
- Pieces crumble over time (lifetime in Tuning; which size classes crumble — decide in explore).
- Tunables (hypotheses, open questions O79–O82): number of classes N and pieces per break, beam damage per second and threshold per class, pull acceleration and sector angle, piece lifetime.
- TDD: damage accumulates only while the beam is on the target and the threshold breaks the body; pieces' resource sums to the original; piece class is one smaller; only the smallest class is collectible; in-sector pieces are pulled, out-of-sector are not; the pull does not change piece velocity; a piece inside the ship circle lands in the hold, a full hold collects nothing; pieces crumble after their lifetime; the collector breaks nothing.

Non-goals: pirates; comets; the upgrades shop (collector range / angle and laser upgrades); sound; git commit.

Context: CLAUDE.md and module CLAUDE.md files, docs/production/stage1-week3.md, docs/decisions.md D40, docs/design/flight.md ("Инструмент"), docs/design/controls.md, docs/production/prototype-tech.md ("Инструмент", "Генерация"), docs/production/open-questions.md (O79–O82). Depends on M3 and M4. Test command is in .slimspec/config.yaml.
```

### M6
```
/slimspec explore

Change: ring boulders — slice M6 of docs/production/stage1-week3.md.

Scope:
- Ring particles stay MultiMesh background without physics; among them rare boulders are real objects like asteroids (well-generator.md stage 3, "Глыбы кольца").
- Boulders lie in the ring band and rotate with its Ω, generated by the same lazy angular chunks; composition — middle ore (the ring is the main additive source on «Обод», planets.md); colour — «Обод» amber accent, not ice.
- Interaction: boulders are broken by the beam and their pieces collected by the collector (M5), not extracted; soft collision, drift-sync reference.
- Decide in explore: boulder density, size relative to asteroids, whether particles hinder flight (default: no).
- TDD: boulders inside the ring band; position is a formula of t; chunk is a pure function; Shift near a boulder zeroes relative velocity; breaking a boulder and collecting its pieces yields middle ore; prediction == flight.

Non-goals: ring gaps; particle physics; git commit.

Context: CLAUDE.md and module CLAUDE.md files (gen/CLAUDE.md, scenes/CLAUDE.md), docs/production/stage1-week3.md, docs/production/well-generator.md (stage 3), docs/design/planets.md, docs/design/controls.md ("Синхронизация дрейфа"). Test command is in .slimspec/config.yaml.
```

### M7
```
/slimspec explore

Change: emergency jettison and cargo container — slice M7 of docs/production/stage1-week3.md.

Scope:
- X / B long press (hold time in Tuning): drops one cell of the heaviest cargo; fuel cells are never dropped; holding on drops the next cell at an interval.
- X / B short press selects the hold cell to jettison. Open, decide in explore: how selection cycles, how it is shown (HUD), whether the long press drops the selected cell or the heaviest one, and how the "cancelled in the first second" metric treats a short press now that it is a valid action.
- A dropped cell becomes a container: a free body (M4 piece) starting with the ship velocity plus a small separation push, flying in the field; it is a drift-sync reference and can be picked back into the hold by the collector (RMB / LB, M5), not the beam (D40).
- A reusable long-press component (the tow in week 4 uses it); presses released within the first second are counted (accidental-press metric for telemetry).
- Accessibility double-press mode — not here.
- TDD: a short press drops nothing; the heaviest non-fuel cell goes first; mass drops; container trajectory follows the field; collector pickup returns the cell; cancel within the first second is counted.

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

### M9
```
/slimspec explore

Change: ice transfer to the tank — slice M9 of docs/production/stage1-week3.md.

Scope:
- Long press R / X (reuse the M7 long-press component, hold time in Tuning) moves ice from the hold into the tank (D38); no stable orbit required, works in any flight.
- Two modes: without the amplifier raw ice poured into the tank takes a whole tank cell and has energy 1 (fuel 3); with the amplifier the transfer is refining: 1 ice cell becomes 1/3 fuel cell in the tank.
- The amplifier is a Tuning flag standing in for the bought refiner upgrade.
- Tank full: nothing is poured. The energy bar counts the tank only.
- The tank UI shows raw ice as a whole ice cell and refined fuel as a partial fuel cell.
- TDD: raw ice takes a whole tank cell with energy 1; with the amplifier 1 ice becomes 1/3 fuel cell; tank full pours nothing; the energy bar counts the tank only.

Non-goals: the upgrade shop and its price; hold-bar redesign beyond the tank cells; git commit.

Context: CLAUDE.md and module CLAUDE.md files, docs/production/stage1-week3.md, docs/design/hold-and-fuel.md, docs/design/economy.md, docs/decisions.md D38. Test command is in .slimspec/config.yaml.
```

### M10
```
/slimspec explore

Change: ship on zoom and speed chevron — slice M10 of docs/production/stage1-week3.md.

Scope:
- Ship at honest world size: FlightCamera no longer scales Ship/Visual by s, so the ship shrinks when zooming out (D39; reverses the constant-screen-size ship of playtest #2).
- Below a screen-size threshold (~12 px) the ship fades out and a crosshair marker (four ticks with a gap in the centre, no nose direction) of constant screen size fades in; smooth cross-fade by on-screen size; threshold and fade width in Tuning.view. Flame and glow follow the ship visual.
- Replace the FlightVector arrow with a speed chevron: no shaft; at a constant screen distance from the ship along the velocity, slightly beyond the crosshair so they never overlap (pick sizes in explore); |v| as a number next to the chevron; hidden below 1 u/s.
- TDD: ship on-screen size ∝ 1/s; ship/crosshair alpha by on-screen size (cross-fade, both ends); crosshair constant screen size; chevron position independent of |v| and outside the crosshair; label equals rounded |v|; hidden below the threshold.

Non-goals: acceleration term, other arrows, other zoom-stable icons (carrier, reference marker stay as they are); git commit.

Context: CLAUDE.md and module CLAUDE.md files (scenes/), scenes/FlightCamera.gd, scenes/ShipView.gd, scenes/FlightVector.gd, docs/design/hud.md, docs/decisions.md D38/D39. Test command is in .slimspec/config.yaml.
```

### M11
```
/slimspec explore

Change: starfield background — slice M11 of docs/production/stage1-week3.md.

Scope:
- A static starfield fixed in the carrier's rotating frame (world coordinates, like orbits and Palette.LIGHT_DIR): at rest at the carrier the stars stand still; own motion and band drift read against them.
- Procedural: a canvas_item shader over world cells (hash per cell), drawn first (before AtmosphereView), a camera-centred square like AtmosphereView / GravityHaloView; no big textures.
- Roughly constant on-screen star density across zoom 1–40 (scale layers with a smooth cross-fade, no popping); muted so it does not compete with halos, orbits and the prediction line; colour from Palette (add a constant if needed).
- Decide in explore: star size in screen px, layer count, brightness variation, twinkle (default: no).
- TDD: a star at a world point stays there as the ship and camera move; same seed → same sky; on-screen density within tolerance at zoom 1, 10, 40 (CPU mirror of the shader hash, like GravityHaloView statics).

Non-goals: inertial sky rotation; nebulae; parallax layers; per-planet skies; git commit.

Context: CLAUDE.md and module CLAUDE.md files (scenes/, shaders/), docs/presentation/visual-style.md, scenes/AtmosphereView.gd and scenes/GravityHaloView.gd (camera-centred shader pattern), scenes/FlightCamera.gd (zoom, rotation). Test command is in .slimspec/config.yaml.
```

### M12
```
/slimspec explore

Change: the field limits speed — slice M12 of docs/production/stage1-week3.md (D40).

Scope:
- Impact damage becomes quadratic in speed relative to the local band flow: k·max(0, v_rel − v_safe)², replacing the linear per-u/s damage. v_safe ≈ 10–15 u/s, k and the numbers are hypotheses in Tuning (open question O83).
- Asteroid fields get a halo: density rises from the edge to the core, so the player slows down gradually on approach (AsteroidField, pure function of seed and position). Halo shape is a tunable (O84).
- In empty space speed stays free: no hard cap, no global drag, no dust wear.
- Independent of M4 and M5; touches AsteroidField and ShipFlight. If M4 lands first it already uses the damage rule — share the function.
- TDD: damage is 0 below v_safe and grows quadratically above; v_rel is measured against the band flow, not the world; halo density rises monotonically from edge to core; same seed → same density; prediction == flight.

Non-goals: small objects spawn (M4); beam breaking and collecting (M5); HUD speed warnings; git commit.

Context: CLAUDE.md and module CLAUDE.md files (gen/CLAUDE.md, scenes/CLAUDE.md), docs/production/stage1-week3.md, docs/decisions.md D40, docs/design/flight.md ("Корпус и урон"), docs/production/open-questions.md (O83, O84). Test command is in .slimspec/config.yaml.
```
