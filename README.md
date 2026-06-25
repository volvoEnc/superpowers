# Superpowers (форк volvoEnc)

Superpowers — это методология разработки для кодинг-агентов: набор композируемых
скиллов плюс bootstrap, который заставляет агента их применять. Когда ты говоришь
«давай сделаем X», агент **не бросается писать код** — он идёт по дисциплинированному
конвейеру **spec → plan → review → build → PR**.

Это **форк** оригинального [obra/superpowers](https://github.com/obra/superpowers)
(автор — [Jesse Vincent](https://blog.fsck.com) и команда Prime Radiant) с правками
под Claude-вариант (`plugins/superpowers-claude`).

---

## 1. Зачем это нужно

Главная идея — **чистый контекст и ранняя ловля ошибок**:

- **Чистый контекст.** Каждый шаг делает *свежий* субагент и возвращает только
  компактный результат-receipt. Оркестратор не тонет в сыром выводе, а состояние
  живёт на диске (`state.json`), поэтому работа переживает компакцию.
- **Ранняя ловля ошибок.** План ревьюится **до** кода; каждая задача проходит
  spec/quality-ревью; зависший или неверный шаг ловится прежде, чем на нём построят
  следующий.

Скилы триггерятся автоматически (bootstrap `using-superpowers`) — отдельных действий
от пользователя не требуется. Фиксируешь спеку (единственный человеческий гейт), а
дальше агент может работать автономно вплоть до открытия PR.

## 2. Как это работает — этапы конвейера

| # | Скилл / инструмент | Когда вызывается | Зачем нужен | Вход → выход |
|---|--------------------|------------------|-------------|--------------|
| 0 | **using-superpowers** (bootstrap) | старт сессии, всегда | учит агента, как и когда триггерить скилы | — → правила |
| 1 | **brainstorming** | любое продуктовое/кодовое изменение («давай сделаем X») | превратить размытый запрос в **утверждённую спеку** (единственный человеческий гейт); скаутит контекст субагентами, сначала защищает ветку | запрос → `docs/superpowers/specs/<date>-…-design.md` |
| 2 | **using-git-branches** | старт brainstorming / планирования / реализации | увести работу с `main`/`master`/`dev` на feature-ветку. Режимы: `design-start` (только ветка), `implementation-start` (+ baseline-тесты) | текущий checkout → защищённая ветка |
| 3 | **writing-plans** | есть утверждённая спека | спека → исполнимый план (`overview.md` + per-task файлы + `status.json`). Дефолт — Workflow-скрипт `write-plan.workflow.js` (**Scout → Author → Review**), затем coordinator patch loop | спека → `docs/superpowers/plans/<feature>/` |
| 4 | **reviewing-plans** | перед исполнением плана | adversarial-валидация. Workflow `review-plan.workflow.js`: параллельные ревьюеры по измерениям (spec-coverage / plan-correctness / snippet / risk / security) → верификация каждой находки → вердикт | план → `review-findings.md` + verdict |
| 5 | **phase-handoff** | сквозной (владелец схемы) | единственный источник схемы `state.json` (что переживает компакцию); все остальные скилы **ссылаются**, не переопределяют формы полей | — → схема состояния |
| 6 | **subagent-driven-development** | «go» после одобрения плана (дефолтный путь исполнения) | исполнять план свежим субагентом на задачу: implement → spec-review → quality-review → built-in mechanical review → commit; состояние в `state.json` + per-task receipts | план → коммиты + receipts |
| 6′ | **executing-plans** | явный opt-in вместо 6 | то же исполнение, но **inline** в текущей сессии с чекпойнтами | план → коммиты |
| 7 | **finishing-a-development-branch** | реализация готова, тесты зелёные | verify tests → `/code-review` gate → (`/security-review`, если Tier-1) → push + PR (или merge / keep / discard) | ветка → PR |

### Поддерживающие скилы (по ситуации)

| Скилл | Когда | Зачем |
|-------|-------|-------|
| **verification-before-completion** | перед любым заявлением «готово / работает» | риск-тиры (Tier-1/2/3) + правило «доказательства до утверждений» |
| **test-driven-development** | внутри задачи-реализации | RED → GREEN → refactor |
| **systematic-debugging** | любой баг / неожиданное поведение | root cause до фикса (4 фазы), без угадывания |
| **dispatching-parallel-agents** | 2+ независимых задач | веер субагентов / Workflow, без общего состояния |
| **requesting- / receiving-code-review** | запрос и приём ревью | дисциплина: верифицировать перед внедрением, без формального поддакивания |
| **writing-skills** | создание / правка скилла | разработка + eval-доказательства (поведение скилла = код) |

### Движок Workflow (инструмент)

`*.workflow.js` (например `write-plan` / `review-plan`) запускаются Workflow-инструментом,
который **детерминированно** разворачивает субагентов (`agent()` / `parallel()` /
`pipeline()`), хранит их результаты структурно и переживает паузы через replay. Он
используется внутри `writing-plans` / `reviewing-plans`. Ручной `Task`-dispatch —
альтернатива, когда нужен пошаговый контроль или когда Workflow упирается в баг
с `args` (см. раздел «Текущие проблемы»).

### Схема потока

```
brainstorming ──► (using-git-branches) ──► writing-plans ──► reviewing-plans
   спека (гейт)        feature-ветка        план-директория      verdict
        │                                                            │
        └──────────────────────── одобрено ──────────────────────────┘
                                       │
                       subagent-driven-development  (или executing-plans)
                         implement → spec → quality → mechanical → commit
                                       │
                          finishing-a-development-branch ──► PR
        (сквозь весь поток: phase-handoff = state.json, verification-before-completion = tiers)
```

Сопутствующие доктрины форка:
[`review-integration-doctrine.md`](plugins/superpowers-claude/docs/review-integration-doctrine.md)
(автоматическое vs ручное ревью) и
[`liveness-doctrine.md`](plugins/superpowers-claude/docs/liveness-doctrine.md)
(обнаружение зависших фоновых субагентов).

## 3. Текущие проблемы

| Проблема | Симптом | Обход / статус |
|----------|---------|----------------|
| **Workflow теряет `args` за границей replay** | фоновый Workflow-скрипт после первого `await` видит `args.* === undefined`; ломает последовательные await-стадии (Author в `write-plan`; verify/persist в `review-plan`) | обход: зашить пути литералами **или** ручной `Task`-dispatch. Нужен фикс: строить все промпты до первого `await` либо re-supply `args` на replay |
| **Раннер тестов не работает на macOS** | `tests/claude-code/run-skill-tests.sh` оборачивает тесты в `timeout`, которого на macOS нет по умолчанию → любой тест = FAIL через раннер | запускать тест напрямую (`bash …/test-*.sh`) или поставить `coreutils` (`gtimeout`) |
| **Кэш плагина vs правки в репо** | живая сессия грузит скилы из `~/.claude/plugins/cache/…`, поэтому правка файла в репо **не меняет** живое поведение до переустановки/синка | live-eval требует reinstall; пока — text-fed A/B (скормить субагенту старый/новый текст скилла) |
| **Артефакты gitignored** | `docs/superpowers/{specs,plans,runs}` в `.gitignore` → `git add` молча игнорит; отслеживаемый тест не должен зависеть от фикстур оттуда | тестовые фикстуры класть в `tests/claude-code/fixtures/` (tracked); процессные артефакты — on-disk, без коммита |
| **Ревью может противоречить себе** | adversarial-ревью способно выдать одновременно «добавь X» и «X вне scope» | развилки, задевающие утверждённую спеку, эскалировать человеку, а не решать молча |
| **Тяжёлая eval-планка** | поведенческие правки скиллов требуют multi-session live A/B (золотой стандарт), дорогой/неудобный из-за кэша | сейчас — контролируемый text-fed A/B + рекомендация live-прогона перед опорой на правку |

## 4. Roadmap

- **[высокий] Resume-safe Workflow** — починить потерю `args` (строить все промпты до
  первого `await`, либо рантайм re-supply `args` на replay), чтобы `write-plan` /
  `review-plan` работали без обходов.
- **[высокий] Портируемый раннер тестов** — fallback на `gtimeout` / детект отсутствия
  `timeout`, чтобы skill-тесты шли на macOS из коробки.
- **[средний] Live-eval тулинг** — шаг reinstall/sync или eval-харнесс, грузящий
  правленый текст скилла, чтобы поведенческие правки проходили натуральный
  multi-session A/B, а не text-fed.
- **[средний] Конфликт-резолюшн в review→patch loop** — явное правило: при
  противоречивых находках, задевающих спеку, — стоп + эскалация.
- **[низкий] Доки по артефактам** — зафиксировать соглашение tracked-фикстуры vs
  on-disk-эвиденс, чтобы новые планы не наступали на `.gitignore`.

## Установка

Это личный форк, поэтому ставится через локальный marketplace `superpowers-personal`
(Claude-вариант `plugins/superpowers-claude`), а не через официальный marketplace
upstream. Общий механизм установки Superpowers для разных харнессов (Claude Code,
Codex, Gemini CLI, Cursor, Copilot CLI и др.) описан в
[оригинальном проекте](https://github.com/obra/superpowers).

## Лицензия и благодарности

MIT — см. файл [`LICENSE`](LICENSE).

Оригинальный Superpowers создан [Jesse Vincent](https://blog.fsck.com) и командой
[Prime Radiant](https://primeradiant.com) — см. апстрим
[obra/superpowers](https://github.com/obra/superpowers). Этот репозиторий — форк с
правками под собственный воркфлоу; апстрим-специфичные изменения сюда не отправляются.
