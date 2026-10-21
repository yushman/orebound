# OREBOUND

Однопользовательская космическая добыча, где главный навык — гравитация.
Спокойная работа в гравитационных колодцах, где ставки поднимает твоя
собственная жадность. Вид сверху, 2D, Godot 4.

> Отстыкуйся от корпоративной матки, спустись в колодец планеты, набери руды и
> поднимись обратно, пока хватает топлива. В конце — Отрыв из гравитации звезды.

## Статус

Пре-продакшн. Решения зафиксированы 21.10.2026, кода нет.
**Следующий шаг:** этап 0 → прототип ([docs/production/plan.md](docs/production/plan.md)).

## Документы

| Документ | О чём |
|---|---|
| [docs/decisions.md](docs/decisions.md) | **Журнал решений:** что выбрано, почему, что отклонено |
| [docs/glossary.md](docs/glossary.md) | Единые термины |
| **Дизайн** | |
| [docs/design/concept.md](docs/design/concept.md) | Пич, столпы, core loop, кривая вылета, аудитория |
| [docs/design/controls.md](docs/design/controls.md) | Схема управления, тормоз, камера, траектория на экране, доступность |
| [docs/design/hud.md](docs/design/hud.md) | HUD вылета: правило «в мире, а не на экране», полоса энергии, трюм, шкала колодца |
| [docs/design/flight.md](docs/design/flight.md) | Физика корабля, гравитация, форсаж, инструмент, угрозы, атмосфера, стыковка |
| [docs/design/gravity-well.md](docs/design/gravity-well.md) | Ярусы, ресурсы, константы планет, процедурная генерация |
| [docs/design/planets.md](docs/design/planets.md) | Три планеты главы 1: «Иней», «Обод», «Горн» |
| [docs/design/hold-and-fuel.md](docs/design/hold-and-fuel.md) | Единый трюм, масса и объём, топливо, переработка, добавка |
| [docs/design/economy.md](docs/design/economy.md) | Ресурсы и кредиты, рынок, апгрейды, корабли, соотношения баланса |
| [docs/design/contracts.md](docs/design/contracts.md) | Контракты, аванс топливом, типы |
| [docs/design/failure.md](docs/design/failure.md) | Буксир, гибель, обломки, ремонт, служебная шлюпка |
| [docs/design/hub.md](docs/design/hub.md) | Матка: экраны, принципы, апгрейды хаба, почта |
| [docs/design/endgame.md](docs/design/endgame.md) | Финал Отрыв, главы |
| [docs/design/onboarding.md](docs/design/onboarding.md) | Первые смены, демо-крючок |
| **Подача** | |
| [docs/presentation/positioning.md](docs/presentation/positioning.md) | Позиционирование, тексты Steam, теги, трейлер, цена |
| [docs/presentation/visual-style.md](docs/presentation/visual-style.md) | Стиль изолиний, палитра, ИИ-иллюстрации |
| [docs/presentation/audio.md](docs/presentation/audio.md) | Звук через корпус, музыка по глубине |
| **Производство** | |
| [docs/production/scope.md](docs/production/scope.md) | Что входит в прототип, срез, EA и после |
| [docs/production/plan.md](docs/production/plan.md) | Этапы с DoD и гейтами |
| [docs/production/well-generator.md](docs/production/well-generator.md) | Генератор колодца: вход, орбиты, этапы, проверка, порядок по этапам |
| [docs/production/econ-sim.md](docs/production/econ-sim.md) | Симулятор экономики: слои, DoD, чувствительность, структура `tools/econ-sim/` |
| [docs/production/prototype-tech.md](docs/production/prototype-tech.md) | Техническая основа прототипа на Godot 4: гравитация, интегрирование, шейдеры, инструменты настройки и телеметрии |
| [docs/production/risks.md](docs/production/risks.md) | Реестр рисков |
| [docs/production/open-questions.md](docs/production/open-questions.md) | Что ещё не решено |
| **Исследования** | |
| [docs/research/market.md](docs/research/market.md) | Конкуренты, цифры, итог спора оптимиста и пессимиста |
| [docs/archive/2026-10-21/](docs/archive/2026-10-21/) | Документы до пересборки решений |
