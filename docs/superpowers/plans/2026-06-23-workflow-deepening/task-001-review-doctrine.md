# Task 1: Создать Review Integration Doctrine (reference-doc)
**Risk:** low
**Depends on:** none
**Review policy:** group
**Files:**
- Create: /Users/danilka/llm-plugins/superpowers/plugins/superpowers-claude/docs/review-integration-doctrine.md

Контекст для исполнителя (не нужно перечитывать спек):
Это первый таск раунда. Он создаёт ЕДИНЫЙ reference-документ, на который ссылаются последующие правки скилов (`requesting-code-review`, `finishing-a-development-branch`, `subagent-driven-development`, `executing-plans`). Документ описывает ментальную модель встроенных механизмов Claude Code и правила их сочетания с ручными субагентами-ревьюерами.

КРИТИЧНО:
- `/code-review`, `/security-review`, `/simplify`, `verify`, `run` — это ВСТРОЕННЫЕ механизмы Claude Code, а НЕ скилы superpowers. Ссылаться на них как `/code-review` и т.п., БЕЗ префикса `superpowers:`. Документ должен содержать явную ноту об этом.
- Это НЕ SKILL.md. Никакого YAML-фронтматтера. Обычный markdown reference-файл. Лоадер скилов его не загружает.
- Каталог `docs/` ещё не существует — его нужно создать (Write создаст его автоматически вместе с файлом).
- Риск-тиры НЕ определять здесь. Они определяются один раз в `verification-before-completion` (Task 002). Здесь только ссылаться на ту секцию по имени: «Security-Review Risk Tiers в `verification-before-completion`». На момент исполнения Task 001 эта секция может ещё не существовать (Task 002 идёт позже) — это нормально, ссылка по имени допустима, grep на резолв тиров делается на финальной валидации раунда, не здесь.

Шаги:

- [ ] **Step 1: Определить acceptance-check.** После правки должны проходить все три проверки:
  1. `test -f /Users/danilka/llm-plugins/superpowers/plugins/superpowers-claude/docs/review-integration-doctrine.md && echo OK` → выводит `OK`.
  2. `grep -c "superpowers:" /Users/danilka/llm-plugins/superpowers/plugins/superpowers-claude/docs/review-integration-doctrine.md` → выводит `0` (в документе НЕТ ни одного упоминания встроенных механизмов с префиксом `superpowers:`).
  3. `grep -E "Decision Tree|Effort Ladder|Conflict Precedence|Built-?in" /Users/danilka/llm-plugins/superpowers/plugins/superpowers-claude/docs/review-integration-doctrine.md` → находит все четыре обязательных раздела (по одной строке-заголовку на каждый).

- [ ] **Step 2: Убедиться, что check сейчас FAILS.** Выполнить:
  `test -f /Users/danilka/llm-plugins/superpowers/plugins/superpowers-claude/docs/review-integration-doctrine.md && echo EXISTS || echo ABSENT`
  Ожидаемый вывод: `ABSENT` (файл и каталог `docs/` ещё не созданы — это подтверждено инспекцией: `ls plugins/superpowers-claude/` показывает только `.claude-plugin assets hooks skills`).

- [ ] **Step 3: Применить правку.** Так как файл новый, создать его целиком (Write по абсолютному пути выше; каталог `docs/` создаётся автоматически). Вставить РОВНО следующее содержимое:

  ```markdown
  # Review Integration Doctrine

  Единая модель того, как сочетать **встроенные механизмы ревью Claude Code** с **ручными субагентами-ревьюерами** в воркфлоу superpowers. Скилы ссылаются на этот документ, а не дублируют его содержимое.

  > **Это встроенные механизмы Claude Code, а не скилы superpowers.** Ссылаемся на них как `/code-review`, `/security-review`, `/simplify`, `verify`, `run` — **без** префикса `superpowers:`. Префикс `superpowers:` зарезервирован только для скилов этого плагина.

  ## Mental Model

  Два класса ревью покрывают разные вопросы и не заменяют друг друга:

  - **Автоматическая гигиена** — `/code-review` + `/simplify`. Ловят то, что машина видит надёжнее человека: баги, мёртвый код, дублирование, неэффективность, стилевые расхождения. `/code-review` ищет баги; `/simplify` — только качество (reuse/simplification/efficiency), он НЕ охотится за багами.
  - **Суждение** — ручные субагенты-ревьюеры. Отвечают на вопросы, требующие контекста и намерения: правильная ли это архитектура, решает ли изменение настоящую задачу, согласуется ли с доменными инвариантами, той ли формы абстракции.
  - **Риск-тированный гейт** — `/security-review`. Запускается не всегда, а по риск-тиру изменения (см. ниже).
  - **Поведенческое подтверждение** — `verify` / `run`. Доказывают, что изменение реально работает в запущенном приложении, а не только проходит тесты. Применимо к user-visible изменениям; не нужно для доков/чистой внутренней логики.

  Правило большого пальца: **автоматика — для механики, субагенты — для суждения.** Не гонять субагента на то, что надёжнее найдёт `/code-review`; не доверять `/code-review` архитектурное решение.

  ## Decision Tree

  Что именно нужно проверить → какой механизм:

  - **Корректность / баги / мёртвый код / стиль** → `/code-review` (effort `low` для рутины, см. лестницу).
  - **Качество без поиска багов (упрощение, переиспользование, эффективность)** → `/simplify`.
  - **Архитектура / намерение / доменные инварианты / форма абстракции** → ручной субагент-ревьюер (суждение, машина не покрывает).
  - **Высокий риск (задеты Tier-1 области)** → `/security-review`. Какие области относятся к Tier-1 — см. секцию **Security-Review Risk Tiers** в скиле `verification-before-completion` (единый источник тиров; здесь не дублируется).
  - **User-visible поведение** → `verify` / `run` после прочих проверок.

  ## Effort Ladder

  `/code-review` (и связанные) масштабируются по уровню усилий под риск задачи:

  - **low** — рутинные, изолированные изменения; меньше находок, только высокоуверенные.
  - **medium** — рискованные/нетривиальные изменения; шире охват.
  - **high → max** — пред-мердж проход; широкий охват, могут быть неуверенные находки.
  - **ultra** — глубокое мультиагентное облачное ревью для самого критичного.

  Поднимать уровень с риском, не наоборот: дефолт — самый дешёвый достаточный уровень.

  ## Conflict Precedence

  Когда автоматическая находка противоречит ручному суждению:

  - **Ручное суждение > автоматическая находка.** Субагент/человек видит намерение и контекст, которых нет у автоматического прохода; ложноположительные срабатывания автоматики возможны.
  - **При НАСТОЯЩЕМ противоречии** (не очевидный ложноположительный результат, а реальный конфликт оценок) — **спросить human partner.** Не разрешать молча в пользу той или иной стороны.
  ```

- [ ] **Step 4: Убедиться, что check теперь PASSES.** Выполнить все три проверки из Step 1:
  - `test -f /Users/danilka/llm-plugins/superpowers/plugins/superpowers-claude/docs/review-integration-doctrine.md && echo OK` → `OK`.
  - `grep -c "superpowers:" /Users/danilka/llm-plugins/superpowers/plugins/superpowers-claude/docs/review-integration-doctrine.md` → `0`.
  - `grep -E "Decision Tree|Effort Ladder|Conflict Precedence|Built-?in" /Users/danilka/llm-plugins/superpowers/plugins/superpowers-claude/docs/review-integration-doctrine.md` → находит строки `## Decision Tree`, `## Effort Ladder`, `## Conflict Precedence` и ноту про встроенные механизмы.
  Затем валидация плагина: `claude plugin validate /Users/danilka/llm-plugins/superpowers/plugins/superpowers-claude` → зелёный (новый файл в `docs/` не является скилом и не должен влиять на счёт скилов/валидность). Кросс-линки этого таска не трогают — он только создаёт файл; убедиться, что в созданном документе ссылка на риск-тиры указывает на секцию `Security-Review Risk Tiers` в `verification-before-completion` (по имени, как в тексте выше).

- [ ] **Step 5: Commit.**
  `git add /Users/danilka/llm-plugins/superpowers/plugins/superpowers-claude/docs/review-integration-doctrine.md`
  `git commit -m "docs(superpowers-claude): добавить Review Integration Doctrine (единая модель ревью)"`
