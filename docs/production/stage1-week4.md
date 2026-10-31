# Этап 1, неделя 4 — декомпозиция

Неделя 4 из [plan.md](plan.md): матка и стыковка, потолок +5 000 с тревогой и
буксиром, принудительный буксир шлюпки ниже границы, запас возврата, звук,
телеметрия, HUD: стрелка к матке и предупреждения, сборка для тестеров
(Windows, macOS). Результат недели — **сборка у тестеров**: вылет играется от
расстыковки до стыковки без перезапуска, каждый вылет пишет JSON телеметрии.
Техническая основа — [prototype-tech.md](prototype-tech.md), провалы —
[../design/failure.md](../design/failure.md).

Каждый срез — отдельное slimspec-изменение (explore → ground, команда
`/slimspec:slimspec`).

## Порядок

```
N1 Матка и стыковка
 │
 ├──────────────────────────┐
 ▼                          ▼
N2 Исходы вылета           N5 Стрелка к матке и предупреждения
 │                          ▲
 ├──────────────┐           │
 ▼              ▼           │
N3 Буксир      N7 Телеметрия JSON
 │                          │
 ▼                          │
N4 Потолок и принудительный буксир ──┘
                            │
                            ▼
                           N6 Звук-прибор

N8 Автомасштаб (независим)
N9 Сборка для тестеров (последний, ждёт всех)
```

N1 первым: без стыковки нет конца вылета. N2 (исходы и следующий вылет) ждёт
N1; N3 (буксир по вызову) и N7 (JSON по концу вылета) ждут N2. N4 переиспользует
прибытие буксира из N3. N5 ждёт N1 (матка в кадре) и N4 (типы предупреждений
потолка и границы); шина предупреждений N5 — источник сигналов для N6. N7 пишет
счётчики, которые есть на момент слияния; N3 и N4, если идут после N7,
дописывают свои поля сами. N8 независим. N9 — последним.

## Общие решения (31.10.2026)

- **Исходы прототипа — три** ([failure.md](../design/failure.md), D24):
  вернулся (стыковка, весь груз), буксир (бак слит, плата за подъём грузом —
  см. ниже), гибель (груз потерян; у шлюпки — весь изъят, обломков нет).
  Обломки, почта, счета, кредиты и хаб — не в прототипе.
- **Буксир — спасение от просчёта топлива, а не способ вернуться с грузом**
  (пересмотр N3, 31.10.2026). Плоская конфискация 30% делала выгодным «набрать
  полный трюм у границы и вызвать буксир» (O37). Теперь буксир берёт плату за
  весь подъём: `fee = tow_base + tow_markup × energy_price ×
  Fuel.climb_energy(r, speed, mass)` — растёт с глубиной и с массой трюма. Бак
  сливается целиком, поэтому буксир никогда не дешевле, чем подняться самому;
  топливо выгоднее дотратить на подход к матке — тогда подъём и плата меньше.
  Плата изымается грузом пропорционально: доля `min(1, fee / cargo_value)` от
  каждой ячейки по цене типа (`price` в `Tuning.resources`, из economy.md).
  Промах мимо матки — пара процентов груза; полный трюм у границы — почти весь.
  У всех кораблей плата не больше груза, остаток списан, долга за буксир нет. Цена видна заранее: пока держишь вызов,
  HUD показывает «буксир: −N% груза».
- **Конец вылета — экран итога**, а не мгновенный респаун: исход, груз
  привезён / изъят, топливо по статьям, время; «следующий вылет» —
  `Tuning.regenerate(seed, flight + 1)` и расстыковка. Нынешний мгновенный
  респаун после гибели заменяется этим экраном.
- **Стыковка автоматическая** (controls.md, hub.md): в зоне захвата при малой
  относительной скорости корабль сам входит в док; управление на это время
  отключено. Большой радиус захвата; синхронизация дрейфа помогает войти в
  зону (матка уже ориентир синхронизации).
- **Буксир — служба матки, прибывает не мгновенно:** вызов долгим нажатием
  (T / крестовина вниз, компонент `LongPress` из M7), несколько секунд ожидания,
  гибель в ожидании — гибель. Доступен выше границы буксира (низ среднего
  яруса) и не в атмосфере. Пустой бак — только буксир.
- **Потолок и граница шлюпки — одно правило** (D24, D35): пересечение —
  тревога, через N секунд (`Tuning`) — буксир в хаб; вернулся раньше —
  отсчёт сброшен. Шлюпке ниже границы ручного буксира нет, принудительный
  буксир изымает весь груз.
- **Запас возврата** — уже готовая энергетическая оценка M8
  (`Fuel.climb_energy` × коэффициент запаса); в неделе 4 она красит стрелку к
  матке и контур матки в кадре, при смене цвета — предупреждение. Полной
  симуляции подъёма нет.
- **Звук — функциональный, без музыки** (audio.md, «Прототип»): сигналы
  приборов, двигатель, атмосфера, запас возврата. Источник звука (процедурный
  синтез или сэмплы) — решить в N6; ничего не скачивать и не ставить без
  согласования.
- **Сборка требует export templates Godot** — это установка, только с
  разрешения (N9).

## Срезы

| # | Срез | Суть | Проверка (TDD) |
|---|---|---|---|
| N1 | Матка и стыковка | матка — видимый объект в `carrier_pos(t)` (`Carrier.tscn` перестаёт быть пустым), силуэт в стиле W7; зона захвата — чистая функция: расстояние < `capture_radius` и относительная скорость < `capture_speed` (`Tuning`); в зоне корабль плавно стягивается в док (позиция и скорость к матке за время стыковки), ввод отключён; состояние «пристыкован»; старт вылета — расстыковка из дока (нынешний спуск от матки); время стыковки — от входа в радиус подхода до дока | в радиусе и ниже скорости — захват, вне радиуса или быстрее — нет; стягивание сходится к матке за заданное время; ввод во время стыковки не влияет; предсказание == полёт до захвата; матка рисуется в `carrier_pos(t)`; таймер стыковки |
| N2 | Исходы вылета | конечный автомат вылета: полёт / стыковка / ожидание буксира / итог; исходы «вернулся», «буксир», «гибель» (шлюпка — весь груз изъят); экран итога (исход, груз, топливо по статьям, время, кнопка / клавиша «следующий вылет»); следующий вылет — `Tuning.regenerate(seed, flight + 1)`, `Telemetry.flight` растёт; сигнал конца вылета для телеметрии; мгновенный респаун после гибели убран | стыковка → «вернулся», груз цел; гибель → «гибель», у шлюпки груз изъят; следующий вылет даёт flight + 1 и тот же seed; сигнал конца вылета ровно один на вылет; в итоге нет управления кораблём |
| N3 | Буксир | вызов T / крестовина вниз долгим нажатием (`LongPress`, время удержания в `Tuning`); доступен выше границы буксира и не в атмосфере, иначе отказ с причиной; ожидание `tow_delay` с отсчётом в HUD, гибель в ожидании — гибель; цена — чистая функция `tow_fee(r, speed, mass)` = `tow_base` + `tow_markup` × `energy_price` × `Fuel.climb_energy`, фиксируется в момент прибытия; по прибытии — исход «буксир», бак слит целиком, изъята доля `min(1, fee / cargo_value)` каждой ячейки груза (`price` в `Tuning.resources`); у всех кораблей плата ≤ груза, остаток списан, долга нет; при удержании вызова HUD показывает «буксир: −N% груза»; пустой бак не мешает вызову; счётчики `tow_calls`, `tow_cancelled` (окно отмены как у сброса, D42), `tow_fee`, `tow_seized_share` | ниже границы и в атмосфере вызов отклонён; выше — прибытие через `tow_delay`; гибель до прибытия — исход «гибель»; цена растёт с глубиной и массой (монотонность); бак пуст после буксира; изъятая доля = fee / стоимость груза, не больше 1; плата шлюпки не превышает груз; буксир у матки дешевле, чем у границы при том же грузе; короткое нажатие не вызывает; отмена считается |
| N4 | Потолок и принудительный буксир | общий таймер нарушения: над потолком (`WellGenerator.tiers().ceiling`) и для шлюпки ниже границы буксира — тревога и отсчёт `violation_time` (`Tuning`), вернулся в зону — сброс; по истечении — прибытие буксира из N3; потолок — обычные последствия буксира, граница шлюпки — весь груз изъят; флаг «шлюпка» — параметр корабля в `Tuning`; счётчики `ceiling_tows`, `forced_tows` | пересечение запускает отсчёт, возврат сбрасывает; истечение → буксир; над потолком — плата по `tow_fee` N3, у шлюпки ниже границы — 100%; не-шлюпке ниже границы отсчёта нет; таймер детерминирован по тикам |
| N5 | Стрелка к матке и предупреждения | стрелка у края экрана к матке, когда она за кадром; в кадре — контур матки; цвет — `reserve_state` из M8 (обычная → жёлтая → красная); шина предупреждений: текст вверху по центру на 2–3 с, очередь без наложения; типы: граница буксира (подход и пересечение), атмосфера, смена цвета запаса, удар, потолок, отсчёт буксира; каждое событие — также сигнал для звука (N6) | стрелка на краю по направлению к матке, скрыта при матке в кадре; цвет стрелки и контура по `reserve_state`; смена цвета даёт одно предупреждение; предупреждение живёт заданное время; повтор того же типа не спамит |
| N6 | Звук-прибор | гул двигателя: `pitch_scale` от массы и тяги, рёв форсажа, грубее при перегреве и щелчок у порога; шипение атмосферы и треск на тике урона; запас возврата: щелчок → двойной сигнал → непрерывный тон по `reserve_state`; сигнал приборов на каждое предупреждение N5; удар; аккорд стыковки; громкость / выключение на панели; источник звука — решить в explore | параметры звука — чистые функции состояния (pitch от массы и тяги, режим сигнала по `reserve_state`); событие шины даёт ровно один сигнал; без звукового устройства (headless) ничего не падает |
| N7 | Телеметрия JSON | по сигналу конца вылета (и при выходе из игры посреди вылета — исход «вышел») JSON в `user://telemetry/` по списку prototype-tech.md: seed, flight, пресет, исход; топливо по статьям; время с тягой, ограниченной перегревом, и максимальный нагрев; время по ярусам и максимальная глубина; гибели, буксиры, причины урона; `jettisons`, `jettison_selects`, `jettison_cancelled`, `tow_calls`, `tow_cancelled`; время стыковки; частота синхронизации и тормоза; отключение автомасштаба (поле, N8); счётчики вылета обнуляются на расстыковке | один вылет — один файл; имена полей стабильны (тест по схеме); значения совпадают со счётчиками; время по ярусам в сумме = время вылета; выход посреди вылета пишет файл |
| N8 | Автомасштаб | отдаление при высокой скорости и у границы яруса, приближение при работе лучом, в кадре ближайший объект (controls.md); колесо / крестовина влево-вправо перебивают автомасштаб (на сколько — решить в explore); плавно, в ступенях зума O85; счётчик отключений для телеметрии | целевой зум — чистая функция (скорость, близость границы, луч); ручной зум перебивает; переход плавный; отключение считается |
| N9 | Сборка для тестеров | `export_presets.cfg` Windows и macOS (export templates — только с разрешения); номер версии и коммит на экране итога и в JSON; панель F1 и пресеты доступны в сборке; инструкция тестеру (управление, где лежит телеметрия, протокол пресетов и анкета гейта 1); архивы; проверка запуска на обеих ОС | headless-экспорт проходит; версия в JSON совпадает с версией сборки; путь телеметрии в инструкции совпадает с `user://` на ОС |

## Промпты

### N1
```
/slimspec explore

Change: carrier and docking — slice N1 of docs/production/stage1-week4.md.

Scope:
- The carrier becomes a visible object at ShipFlight.carrier_pos(t) (Carrier.tscn is an empty Node2D today); a silhouette in the W7 style from Palette, constant screen size or world size — decide in explore. It stays a pure formula of t, not a gravity source.
- Capture as a pure function: distance to the carrier < capture_radius and speed relative to carrier_vel(t) < capture_speed (Tuning, hypotheses; large radius per hub.md). Inside, docking is automatic: the ship is eased into the dock (position and velocity toward the carrier over a docking time), input is ignored, the ship ends in a docked state.
- Flight start is the undocking from the carrier (today's spawn: descending from carrier_pos).
- Docking time metric: from entering an approach radius to docked (gate 1: < 15–20 s); define the approach radius in explore.
- Drift sync already treats the carrier as a reference — keep it.
- TDD: capture inside radius and below speed, none outside or faster; the ease converges to the carrier in the docking time; input has no effect while docking; prediction == flight up to capture; the carrier is drawn at carrier_pos(t); docking timer.

Non-goals: end-of-flight screen and next flight (N2); tow (N3); arrow to the carrier and its colour (N5); docking sound (N6); hub screens; git commit.

Context: CLAUDE.md and module CLAUDE.md files (scenes/), docs/production/stage1-week4.md, docs/design/hub.md, docs/design/controls.md ("Стыковка", "Синхронизация дрейфа"), docs/production/prototype-tech.md ("Матка"), docs/presentation/visual-style.md, docs/decisions.md D35/D36. Test command is in .slimspec/config.yaml.
```

### N2
```
/slimspec explore

Change: flight outcomes and the next flight — slice N2 of docs/production/stage1-week4.md.

Scope:
- A flight state machine: flying / docking / waiting for tow / summary. Outcomes: returned (docked, cargo kept), towed (set by N3/N4), crashed (cargo lost; for the service boat all cargo is seized, no wreck — failure.md).
- Summary screen: outcome, cargo delivered or seized (by type and mass), fuel by category, flight time; a key / button for the next flight. No flight input on the summary.
- Next flight: Tuning.regenerate(seed, flight + 1), Telemetry.flight increments, the ship undocks from the carrier.
- The instant respawn after a crash (Ship._physics_process → respawn) is replaced by the crashed outcome and the summary.
- One end-of-flight signal per flight for telemetry (N7).
- TDD: docking → returned with cargo intact; crash → crashed, service boat cargo seized; next flight gives flight + 1 with the same seed; exactly one end-of-flight signal per flight; no ship control on the summary.

Non-goals: tow call (N3); ceiling and forced tow (N4); telemetry JSON (N7); credits, mail, bills, wrecks, hub; git commit.

Context: CLAUDE.md and module CLAUDE.md files (scenes/, ui/), docs/production/stage1-week4.md, docs/design/failure.md ("Шкала исходов", "Служебная шлюпка"), docs/design/hub.md, docs/production/plan.md (stage 1 DoD), docs/decisions.md D24. Depends on N1. Test command is in .slimspec/config.yaml.
```

### N3
```
/slimspec explore

Change: tow — slice N3 of docs/production/stage1-week4.md.

Scope:
- Call on T / D-pad down with a long press (reuse LongPress from M7; hold time in Tuning). Short press does nothing.
- Allowed above the tow boundary (WellGenerator.tiers().tow, bottom of the middle tier) and outside the atmosphere; otherwise refused with a reason (shown as a warning once N5 lands, a plain HUD line until then). An empty tank does not block the call.
- The tow arrives after tow_delay seconds (Tuning) with a countdown in the HUD; the ship keeps flying meanwhile; a crash before arrival is a crash. Decide in explore whether the call can be cancelled.
- Intent: the tow rescues a fuel miscalculation; it must never be a cheaper way home with cargo. The price pays for the whole climb, so it grows with depth and hold mass; a small miss near the carrier is cheap, a full hold at the boundary costs almost all of it.
- Price as a pure function: tow_fee(r, speed, mass) = tow_base + tow_markup × energy_price × Fuel.climb_energy(r, speed, mass) (tow_base, tow_markup, energy_price in Tuning; energy_price from the fuel cell price in economy.md). Taken at arrival.
- On arrival: outcome towed (N2); the tank is drained completely (fuel is better spent closing in on the carrier, which lowers the climb and the fee); every cargo cell loses the share min(1, fee / cargo_value) of its fill, cargo_value from a new price column in Tuning.resources (ice 5, base 8, mid 25, rare 70 — economy.md). Service boat: the fee never exceeds the cargo, the rest is written off, no debt.
- While the call is held, the HUD shows the current price as "tow: −N% cargo" (plain HUD line; N5 may restyle it).
- Counters tow_calls, tow_cancelled (release window like jettison, D42), tow_fee, tow_seized_share in Telemetry.
- TDD: refused below the boundary and in the atmosphere; arrival after tow_delay; crash before arrival → crashed; fee is monotonic in depth and mass; near the carrier is cheaper than at the boundary with the same cargo; tank empty after the tow; seized share = fee / cargo_value capped at 1; boat fee never exceeds cargo; short press calls nothing; cancel is counted.

Non-goals: ceiling and service-boat forced tow (N4); one-time deep tow consumable; tow icon (slice); accessibility double press; git commit.

Context: CLAUDE.md and module CLAUDE.md files (scenes/, ui/), docs/production/stage1-week4.md, docs/design/failure.md ("Буксир и граница буксира"), docs/design/controls.md, docs/design/flight.md, docs/decisions.md D24/D35/D42. Depends on N2. Test command is in .slimspec/config.yaml.
```

### N4
```
/slimspec explore

Change: ceiling and forced tow — slice N4 of docs/production/stage1-week4.md.

Scope:
- One violation timer for two rules (D24, D35): above the ceiling (WellGenerator.tiers().ceiling, carrier orbit + ceiling_offset) and, for the service boat, below the tow boundary. Crossing raises an alarm and starts violation_time (Tuning); coming back resets it; on expiry the tow from N3 arrives.
- Consequences: ceiling — a normal tow (tow_fee from N3); service boat below the boundary — all cargo seized. A non-boat ship below the boundary gets no timer.
- "Service boat" is a ship parameter in Tuning (the prototype ship is the boat by default).
- Counters ceiling_tows, forced_tows in Telemetry.
- The timer counts physics ticks, so it is deterministic.
- TDD: crossing starts the countdown, return resets it; expiry → tow; above the ceiling 30% seized, boat below the boundary 100%; no timer for a non-boat below the boundary; deterministic by ticks.

Non-goals: warning texts and sound (N5, N6 — expose the alarm state for them); one-time deep tow; git commit.

Context: CLAUDE.md and module CLAUDE.md files (gen/, scenes/), docs/production/stage1-week4.md, docs/design/failure.md, docs/design/hub.md ("Потолок"), docs/design/onboarding.md (service boat), docs/decisions.md D24/D35. Depends on N3. Test command is in .slimspec/config.yaml.
```

### N5
```
/slimspec explore

Change: arrow to the carrier and warnings — slice N5 of docs/production/stage1-week4.md.

Scope:
- Arrow to the carrier at the screen edge when the carrier is off-screen; with the carrier in frame the arrow is replaced by the carrier's highlighted contour (hud.md, D36). Colour by the M8 reserve_state (energy vs Fuel.climb_energy × margin): calm → yellow → red; no return-margin line in the world (D35).
- A warning bus: short text top-centre for 2–3 s, a queue without overlap, the same type not repeated while shown. Types: tow boundary (approach and crossing), atmosphere, reserve colour change, impact, ceiling, tow countdown / refusal (N3, N4). Every event is also a signal for sound (N6).
- Base viewport 1280×800; text size for Steam Deck in mind (O70).
- TDD: the arrow sits on the edge toward the carrier and hides with the carrier in frame; arrow and contour colour follow reserve_state; a colour change gives one warning; a warning lives its time; repeats of a type do not spam.

Non-goals: tow and stable-orbit icons, contract line, wreck arrows (slice); sounds (N6); no-HUD mode; git commit.

Context: CLAUDE.md and module CLAUDE.md files (ui/, scenes/), docs/production/stage1-week4.md, docs/design/hud.md, docs/design/controls.md ("Траектория на экране"), docs/production/prototype-tech.md ("Запас возврата в прототипе"), docs/production/open-questions.md (O70, O78), docs/decisions.md D35/D36. Depends on N1 and N4. Test command is in .slimspec/config.yaml.
```

### N6
```
/slimspec explore

Change: instrument sound — slice N6 of docs/production/stage1-week4.md.

Scope:
- Engine hum: pitch_scale from ship mass and actual thrust (heavier → lower and strained), a distinct boost roar, rougher with heat and a click at the threshold (audio.md "Звук как прибор").
- Atmosphere: hiss by density and a crack on each damage tick.
- Return margin by reserve_state: calm click → double beep → continuous tone.
- An instrument signal for every N5 warning-bus event; impact; docking chord.
- Volume / mute on the tuning panel.
- Decide in explore: procedural (AudioStreamGenerator) or samples; nothing is downloaded or installed without asking the user.
- Gate 1 question: does the player react to sound before the picture — keep sound states loggable.
- TDD: sound parameters are pure functions of state (pitch from mass and thrust, signal mode by reserve_state); one bus event gives exactly one signal; headless (no audio device) does not fail.

Non-goals: generative music, hub sounds, mail (slice); stereo cue for small objects unless trivial; git commit.

Context: CLAUDE.md and module CLAUDE.md files, docs/production/stage1-week4.md, docs/presentation/audio.md, docs/design/hud.md ("Доступность"), docs/production/prototype-tech.md ("Камера и звук"). Depends on N5. Test command is in .slimspec/config.yaml.
```

### N7
```
/slimspec explore

Change: per-flight telemetry JSON — slice N7 of docs/production/stage1-week4.md.

Scope:
- On the N2 end-of-flight signal (and on quitting mid-flight, outcome "quit") write one JSON file to user://telemetry/ (name by seed, flight, timestamp).
- Fields per prototype-tech.md "Телеметрия": build version, seed, flight, preset name, outcome; fuel by category (engine / soft brake / drift sync / boost) and the boost share; heat-limited thrust time and max heat; time per tier and max depth; crashes, tows (manual, ceiling, forced), damage causes (atmosphere, impacts, moons); jettisons, jettison_selects, jettison_cancelled, tow_calls, tow_cancelled; docking time; drift-sync and soft-brake frequency; autoscale overrides (field kept even before N8).
- Per-flight counters reset on undocking; the FLOG line log stays for debugging.
- Counters that are not there yet (tows if N3/N4 are not merged) are written as 0 and filled by those slices.
- TDD: one flight → one file; field names stable (schema test); values equal the counters; time per tier sums to flight time; quitting mid-flight writes a file.

Non-goals: sending telemetry over the network; dashboards; econ-sim import; git commit.

Context: CLAUDE.md and module CLAUDE.md files (autoload/), autoload/Telemetry.gd, docs/production/stage1-week4.md, docs/production/prototype-tech.md ("Телеметрия"), docs/production/plan.md (stage 1 DoD metrics), docs/design/controls.md ("Метрики"), docs/design/failure.md ("Метрики плейтеста"). Depends on N2. Test command is in .slimspec/config.yaml.
```

### N8
```
/slimspec explore

Change: autoscale — slice N8 of docs/production/stage1-week4.md.

Scope:
- FlightCamera autoscale (controls.md "Камера"): zoom out at high speed and near a tier boundary, zoom in while the beam works, keep the nearest object in frame.
- Wheel / D-pad left-right overrides autoscale; decide in explore for how long (until release, a timeout, or until a toggle) and how it returns.
- Smooth, respecting the O85 zoom stops (continuous 1..8, steps beyond).
- Overrides counted for telemetry (gate 1: do players turn autoscale off).
- TDD: target zoom is a pure function (speed, boundary proximity, beam); a manual zoom overrides; the transition is smooth; an override is counted.

Non-goals: camera rotation changes; zoom stops retune; git commit.

Context: CLAUDE.md and module CLAUDE.md files (scenes/), scenes/FlightCamera.gd, docs/production/stage1-week4.md, docs/design/controls.md ("Камера", "Метрики"), docs/design/flight.md, docs/production/open-questions.md (O85). Test command is in .slimspec/config.yaml.
```

### N9
```
/slimspec explore

Change: tester build — slice N9 of docs/production/stage1-week4.md.

Scope:
- export_presets.cfg for Windows and macOS. Export templates are an install: ask the user before installing anything.
- Build version and commit shown on the summary screen and written to the telemetry JSON.
- The F1 tuning panel and presets stay available in the build (A/B by presets).
- A tester note: controls (keyboard and gamepad), where telemetry lives on each OS (user:// path), the preset protocol and the gate 1 questionnaire (prototype-tech.md, plan.md).
- Archives per OS; macOS unsigned — launch instructions in the note.
- TDD: headless export succeeds; version in JSON equals the build version; the telemetry path in the note matches user:// on the OS.

Non-goals: Steam, signing and notarisation, Steam Deck build, auto-update, itch.io page; git commit.

Context: CLAUDE.md and module CLAUDE.md files, docs/production/stage1-week4.md, docs/production/prototype-tech.md ("Контроль версий и сборки", "Телеметрия"), docs/production/plan.md (stage 1 DoD and gate 1), docs/decisions.md D34. Depends on all other slices. Test command is in .slimspec/config.yaml.
```
