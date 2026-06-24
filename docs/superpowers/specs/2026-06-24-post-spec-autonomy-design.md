# Spec: Полная автономность после согласования спеки

**Дата:** 2026-06-24
**Ветка:** `chore/post-spec-autonomy`
**Цель-плагин:** `plugins/superpowers-claude/` (установленный Claude Code вариант)
**Статус:** на ревью

## Goal

Стратегическая цель: **максимальная автономность исполнения после согласования спеки/доков**. Единственный человеческий гейт — approval спеки. После него оркестратор автономно проходит план → ревью плана → исполнение → security → finishing вплоть до **открытого PR**, без дополнительных человеческих гейтов и с **минимальным накоплением контекста оркестратора** (тяжёлая работа — фрешевым субагентам, состояние — на диск, оркестратор лёгкий и resumable).

Основано на верифицированном разборе текущего флоу (35 подтверждённых проблем, 0 спекулятивных) — `wf analyze-autonomy-context`.

## Решения (decision pack)

| Развилка | Решение |
|---|---|
| Гейт approval плана | **Убрать.** После approval спеки — авто-проход к исполнению. Ревью плана выполняется; блокеры оркестратор устраняет автономно (ограниченные циклы), эскалация к человеку — только если не смог |
| Режим исполнения | **subagent-driven по умолчанию** при наличии Task; inline — явный opt-in/fallback. Убрать симметричный вопрос «Which approach?» |
| Tier-1 `/security-review` | **Авто-ран** при детекте Tier-1; **блок только на нерешённых critical**. Убрать гейт approval перед запуском |
| Меню finishing | **По умолчанию — авто-пуш ветки + открыть PR** (не мержить). Меню — только при реальной неоднозначности; флаги для override |
| Inline-fallback | **Coordinator-only.** Тяжёлая inline-работа запрещена даже при недоступности Task |
| Целевой плагин | Только `superpowers-claude/`. Это форк, не upstream — можно смелее публичной eval-gated политики |

## Scope (12 изменений)

### A. Единственный гейт — спека; убрать гейт плана
- `writing-plans` (Human approval, ~стр. 92-94): заменить безусловный approval на **авто-проход когда review-статус `approved` и нет блокеров**. Явный approval только при `issues-found`/`blocked` ИЛИ если человек заранее запросил гейт. Спека остаётся гейтом (в `brainstorming`).
- **Ревью плана (`reviewing-plans`) выполняется всегда** — убирается только человеческий approval, не само ревью.
- Согласовать с моделью: после approval спеки orchestrator идёт до PR без остановок (кроме недетерминированных блокеров и явных эскалаций из лимитов циклов).

### B. Дефолт режима — subagent-driven
- `writing-plans` (Execution Handoff, ~стр. 206-217; note ~стр. 126; Fallback): subagent-driven — заявленный дефолт при наличии Task; inline (executing-plans) — явный opt-in/fallback. Убрать «Which approach?». Согласовать с Core Rule (стр. 10).

### C. Durable execution state (resume после компакта)
- `subagent-driven-development` и `executing-plans`: новая секция «Maintaining Execution State» — писать `state.json` (схема — `phase-handoff`, по ссылке, не переопределять) после каждой задачи: `current_task`, `completed_tasks`, `blocked_tasks`, `last_green_commit`. 
- `subagent-driven-development` (Per-Task Loop, стр. 37): «Capture the result in your notes or task status» → писать receipt в durable per-task файл `docs/superpowers/runs/<run>/task-NNN-result.md` (**новый артефакт, создаётся этими правками**) и после компакта читать файлы, не чат. Шаблон диспатча таск-субагента: «работай только над этой задачей, не заглядывай вперёд».

### D. Единый durable evidence-артефакт
- Расширить схему `state.json` полями: `test_results{count,exit_code,timestamp,commit}`, `code_review_verdict`, `security_review_status`, `plan_risk_tier`.
- `verification-before-completion`: писать evidence туда.
- `executing-plans`/`subagent-driven-development`: обновлять после верификаций.
- `finishing` (Step 2): читать `state.json` и для каждого кешированного вердикта **сверять `verdict.commit` с текущим HEAD SHA**: совпало и вердикт чистый → пропустить ревью (лог `cached: clean`); SHA отличается ИЛИ вердикт не чистый ИЛИ записи нет → перезапустить. (Любой новый коммит инвалидирует кеш — кешируется привязанно к SHA.)

### E. Security автономно
- `executing-plans` (Step 2a, ~стр. 37): убрать гейт approval; при Tier-1 — **авто-ран `/security-review`** на накопленном диффе. Critical-находки → **автономный fix (1 цикл, лимит из G) → ре-ран**; если critical остаётся после цикла — **эскалация** (`human-decision-required`). Блок только на нерешённых critical.

### F. Finishing — PR по умолчанию
- `finishing-a-development-branch` (Step 5 menu): дефолт — **авто-пуш ветки + открыть PR** (не мержить). **Меню показывается только при триггерах неоднозначности:** на `main`/`master` (error без `--allow-main`); грязное дерево; неоднозначная base-ветка; флаг `--no-auto`. Иначе (feature-ветка, чистое дерево, ясная base) — авто-PR без вопроса. Флаги `--merge`/`--push`/`--keep`/`--discard` для override.

### G. Ограниченные циклы + эскалация
- `subagent-driven-development` (Handling Status; Per-Task Loop; Red Flag): **макс 2 fix-попытки на задачу**, затем обязательная эскалация. Исходы эскалации: `approved-amended-plan` | `human-decision-required` | `task-removed`. Категоризация находок **Blocking vs Deferred**.
- Граница **implementation-wrong vs plan-wrong**: implementation-wrong → ре-диспатч с fix-scope (в пределах лимита); plan-wrong → эскалация (авто-ретрай не маскирует неверный план).
- `reviewing-plans` (Re-review): **макс 1 раунд edit-and-re-review на receipt**, затем эскалация новых блокеров.
- `executing-plans` (When to Stop): «тест падает повторно» = 1 ре-ран на флаки + 1 ограниченный fix-and-retest цикл через `systematic-debugging`, затем эскалация.

### H. Repo-контекст субагентам в шаблонах диспатча
- `writing-plans` (plan-author inputs), `reviewing-plans` (Subagent Prompt Shape), `subagent-driven-development/*-prompt.md`, `requesting-code-review/code-reviewer.md`: добавить repo root (+ для код-ревьюеров branch + base/head SHA) с пометкой «можешь читать/`git diff`, не коммить/не править». Расширить implementer Context-плейсхолдер в Quick Reference (точные файлы, тест-команда, импорты, символы).

### I. Inline-fallback → coordinator-only
- `brainstorming`/`writing-plans`/`reviewing-plans` (Fallback): inline только по явному запросу человека (не на недоступности Task), и только координация/состояние. Явно запретить inline-инспекцию репо, проверку сниппетов, аудиты файлов, генерацию context-pack — это всё фрешевым read-only субагентам.
- **Если субагент-классовая работа (инспекция / спека / план / ревью) нужна, а Task реально недоступен — эскалация/hard-stop, НЕ выполнять inline.** Координатор не подменяет субагента собой.

### J. Per-task load-and-discard
- `executing-plans`: после Step 1 держать только overview (title/goal/risk) + список задач; читать task-файл с диска на каждый цикл, выкидывать после receipt.
- `subagent-driven-development` (стр. 34): префикс «per this task only:» + напоминание discard-after-capture в самом цикле.

### K. Подключить кросс-скил хендофф риск-тира
- `finishing` (Step 1 Inputs, Step 2): опциональный вход «plan risk: [Tier-1 | not]»; если передан — использовать, не выводить заново. `executing-plans` (Step 3): вызывать finishing с явным риск-контекстом.

### L. Мелочи
- `writing-plans` (Branch Context, стр. 204): убрать фантомный выбор «ask whether to create a feature branch» — `using-git-branches` авто-создаёт ветку на main/master.
- Контекст-гигиена: кросс-ссылка на правило follow-up-диспатча из шагов цикла; «save each reviewer receipt to disk immediately»; определить «compact» (≤2-3 страниц); добавить промежуточные receipts в `phase-handoff` Do-Not-Reload + mid-task resume check.

## Инварианты
- Спека — единственный человеческий гейт; после неё автономность до PR.
- Чистота контекста оркестратора: делегирование — жёсткий дефолт; durable state на диске; только компактные артефакты в контексте.
- Единые источники: риск-тиры (`verification-before-completion`), схема state (`phase-handoff`), доктрина ревью.
- Адаптивность сохраняется (NOT-APPLICABLE / opt-in по риску).
- Все правки — только в `superpowers-claude/`; `superpowers:*` ссылки целы.

## Acceptance criteria
1. `writing-plans`: нет безусловного гейта approval плана; авто-проход при чистом ревью задокументирован; спека остаётся гейтом.
2. `writing-plans`: subagent-driven — явный дефолт; «Which approach?» убран; согласовано с Core Rule.
3. `subagent-driven-development` и `executing-plans` пишут `state.json` (current/completed/blocked/last_green_commit) после каждой задачи; receipts — на диск.
4. `state.json` расширен evidence-полями; `verification-before-completion` пишет; `finishing` Step 2 читает и пропускает повторные ревью при чистом результате для текущего HEAD; инвалидация по новому коммиту описана.
5. `executing-plans`: Tier-1 → авто-ран `/security-review`, блок только на critical; гейт approval убран.
6. `finishing`: дефолт авто-пуш + PR; меню только при неоднозначности; флаги override; защита `main`.
7. Циклы ограничены: лимиты ретраев, исходы эскалации, Blocking/Deferred, impl-wrong vs plan-wrong — во всех затронутых скилах.
8. Шаблоны диспатча субагентов содержат repo root/branch/SHA + read-only пометку; implementer Quick Reference.
9. Inline-fallback — coordinator-only во всех трёх скилах; тяжёлая inline-работа явно запрещена.
10. Per-task load-and-discard явно прописан в обоих циклах.
11. `finishing` принимает переданный риск-тир; `executing-plans` его передаёт.
12. Мелочи L применены; `claude plugin validate` зелёный; `superpowers:*` ссылки целы; фронтматтер цел.

## Testing / eval approach
- Изменения — поведение-формирующий код (CLAUDE.md). Вести через `superpowers:writing-skills`.
- Адверсариальный pressure-test ключевых поведенческих правок: (a) после approval спеки агент НЕ останавливается на approval плана; (b) BLOCKED-задача эскалирует после 2 попыток, не зацикливается; (c) Tier-1 авто-запускает security и блокирует на critical; (d) finishing по умолчанию открывает PR, не мержит; (e) resume после компакта восстанавливается из `state.json`.
- Структурно: `claude plugin validate`, grep `superpowers:` целостности, отсутствие префикса у встроенных, фронтматтер.

## Rollout
1. План через `superpowers:writing-plans`, ревью через `superpowers:reviewing-plans`.
2. **После approval ЭТОЙ спеки — автономный прогон** (демонстрация новой модели): план → исполнение (subagent-driven) → security → finishing = PR.
3. Human review результирующего PR.
4. После мерджа — переустановка плагина, новая сессия.

## Open questions (дефолты даны — поправь при ревью)
- Лимиты ретраев: 2 fix-попытки/задача, 1 раунд ре-ревью/receipt, тесты 1 флаки-ран + 1 fix-цикл. ОК?
- Инвалидация evidence строго по commit SHA (любой новый коммит обнуляет кеш) — ОК, или мягче (по затронутым файлам)?
- `finishing` дефолт PR: пушить в `origin` и `gh pr create` автоматически — подтверждаешь авто-открытие PR без вопроса?
