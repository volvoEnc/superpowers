# Task 5: finishing — кеш evidence по SHA, PR по умолчанию, приём риск-тира

**Risk:** high
**Depends on:** 001 (схема `state.json` определена в `phase-handoff`)
**Review policy:** per-task-plus-risk
**Files:** Modify: `plugins/superpowers-claude/skills/finishing-a-development-branch/SKILL.md`

Кодирует пункты спеки D, F, K (см. `docs/superpowers/specs/2026-06-24-post-spec-autonomy-design.md` строки 43, 49, 69). Схема `state.json` и поля `code_review_verdict`/`security_review_status`/`plan_risk_tier` — единый источник `phase-handoff`; здесь ТОЛЬКО ссылаемся и читаем, НЕ переопределяем. Tier-1 определён единожды в `verification-before-completion` — ссылаемся. Встроенные `/code-review`, `/security-review` — БЕЗ префикса `superpowers:`.

Три поведенческих изменения в одном файле:
- **D** (Step 1 + Step 2): читать `state.json`; для каждого кешированного вердикта сверять `verdict.commit` с текущим HEAD SHA — равно и чисто → пропустить ревью (лог `cached: clean`); иначе перезапустить.
- **F** (Step 5): дефолт — авто-пуш ветки + открыть PR через `gh`; меню только при триггерах неоднозначности.
- **K** (Step 1): принять опциональный вход `plan risk: [Tier-1 | not]`; если передан — использовать, не выводить заново.

---

- [ ] **Step 1: Acceptance check (три grep'а + два behavioral pressure-test).**
  Запустить из корня репо `/Users/danilka/llm-plugins/superpowers`:
  ```bash
  TARGET=plugins/superpowers-claude/skills/finishing-a-development-branch/SKILL.md
  grep -n "cached: clean" "$TARGET"
  grep -n "plan risk:" "$TARGET"
  grep -nE "auto.?push|gh pr create" "$TARGET"
  grep -nE "no-auto|--allow-main|--merge|--push|--keep|--discard" "$TARGET"
  ```
  Ожидаемо ПОСЛЕ правок: первый grep находит строку про SHA-сверку и лог `cached: clean`; второй находит опциональный вход риск-тира в Step 1; третий находит описание дефолтного авто-PR; четвёртый находит все триггеры неоднозначности и флаги override.

  **Behavioral pressure-test F (дефолт PR, не мерж):**
  - Сценарий: implementation завершён на feature-ветке `chore/x`, дерево чистое, base = `main` ясна, флага `--no-auto` нет.
  - BEFORE (текущий файл): Step 5 безусловно печатает меню с 4 опциями и спрашивает «Which option?» — агент останавливается и ждёт человека.
  - AFTER (после правок): агент НЕ показывает меню; авто-выполняет `git push -u origin chore/x` + `gh pr create`; меню появилось бы только на main/master, грязном дереве, неоднозначной base или при `--no-auto`.

  **Behavioral pressure-test D (кеш по SHA):**
  - Сценарий: `state.json` содержит `code_review_verdict.verdict = "clean"` c `commit` == текущий HEAD SHA, дерево чистое.
  - BEFORE: Step 2 безусловно запускает `/code-review` заново — лишняя работа и контекст.
  - AFTER: Step 2 сверяет `code_review_verdict.commit` с HEAD, видит совпадение + чистый вердикт, логирует `cached: clean`, пропускает `/code-review`. Если бы HEAD сдвинулся (новый коммит) или вердикт был `issues-found` — перезапустил бы.

- [ ] **Step 2: Verify it currently FAILS (отсутствует).**
  ```bash
  TARGET=plugins/superpowers-claude/skills/finishing-a-development-branch/SKILL.md
  grep -c "cached: clean" "$TARGET"   # ожидаем 0
  grep -c "plan risk:" "$TARGET"      # ожидаем 0
  grep -c "no-auto" "$TARGET"         # ожидаем 0
  ```
  Все три должны вернуть `0` до правок (текущий файл: Step 1 — только «Verify Tests»; Step 2 — безусловный gate; Step 5 — безусловное меню).

- [ ] **Step 3: Применить правки (три анкера).**

  **3a — Step 1 (K + ссылка на state): принять риск-тир и прочитать state.json.**
  Анкер — заголовок `## Step 1: Verify Tests`. После строки `If tests fail, report failures and stop.` (последняя строка секции, перед `## Step 2: Code Review Gate`) ВСТАВИТЬ:

  ```markdown
  ### Inputs (optional)

  - **plan risk: `[Tier-1 | not]`** — if the caller (e.g. `executing-plans` Step 3) passes the plan's risk tier, use it as-is. Do **not** re-derive the tier. If not passed, fall back to detecting Tier-1 from the branch diff per `verification-before-completion` (`## Security-Review Risk Tiers`).

  Read durable evidence before running any review. If `docs/superpowers/runs/<run>/state.json` exists, load it — its schema (incl. `code_review_verdict`, `security_review_status`, `plan_risk_tier`) is defined once in `superpowers:phase-handoff`; do not redefine it here. The cached verdicts drive Step 2's skip/re-run decision.
  ```

  **3b — Step 2 (D): SHA-сверка кеша перед запуском ревью.**
  Анкер — заголовок `## Step 2: Code Review Gate`. Сразу ПОСЛЕ строки `Tests passing is necessary, not sufficient. Before presenting completion options, run automated review on the branch diff.` ВСТАВИТЬ новый абзац (перед `Run \`/code-review\` at **medium** effort...`):

  ```markdown
  **Cache check (per SHA).** First compute the current HEAD SHA (`git rev-parse HEAD`). For each cached verdict in `state.json` (`code_review_verdict`, `security_review_status`):

  - `verdict.commit` == HEAD **and** the verdict is clean (`code_review_verdict.verdict == "clean"` / `security_review_status.verdict` is `clean` or `n/a`) → **skip** that review, log `cached: clean`.
  - SHA differs **or** the verdict is not clean **or** no record exists → **re-run** that review below.

  Any new commit invalidates the cache (verdicts are bound to a SHA). Skipping a clean cached review avoids redoing fresh-subagent work the orchestrator already paid for.
  ```

  И в строке про Tier-1 security (`If the branch touched **Tier-1** areas, additionally run \`/security-review\` before presenting options.`) дополнить началом ссылкой на переданный риск-тир и кеш — заменить её на:

  ```markdown
  If the branch is **Tier-1** (use the passed `plan risk` from Step 1 if provided, else detect from the diff), additionally run `/security-review` before presenting options — unless its cached `security_review_status` is clean for the current HEAD (`cached: clean`). Tier-1 is defined once in `verification-before-completion` (see its `## Security-Review Risk Tiers` section) — do not redefine it here. If not Tier-1, skip `/security-review` (adaptive by risk).
  ```

  **3c — Step 5 (F): дефолт авто-PR, меню только при неоднозначности.**
  Анкер — заголовок `## Step 5: Present Options`. Заменить ВЕСЬ блок от `Open the menu with a one-line review verdict` до конца секены Step 5 (т.е. всё до `## Step 6: Execute Choice`) на:

  ```markdown
  **Default: auto-push branch + open PR (no menu).** When ALL of these hold — on a feature branch (not `main`/`master`), clean working tree, an unambiguous base branch (from Step 4), and no `--no-auto` flag — do NOT ask. Auto-execute the "push and create PR" path in Step 6: push the branch and open a PR with `gh` (never auto-merge). Log a one-line verdict first, e.g. `Tests pass. Code review: cached clean. Security: not required (not Tier-1). Opening PR.`

  **Show the menu ONLY on an ambiguity trigger:**

  - On `main`/`master` → **error** and stop unless `--allow-main` was passed (refuse to push/PR from the trunk silently).
  - Dirty working tree (Step 3 `STATUS` non-empty).
  - Ambiguous base branch (Step 4 could not resolve a single base).
  - Explicit `--no-auto` flag.

  When a trigger fires, open the menu with the one-line verdict, e.g. `Tests pass. Code review: 0 critical, 1 minor. Security review: not required (not Tier-1). How to finish?`:

  ```text
  Implementation complete on branch <branch>. What would you like to do?

  1. Push and create a Pull Request (default)
  2. Merge back to <base-branch> locally
  3. Keep the branch as-is
  4. Discard this branch

  Which option?
  ```

  **Override flags** (any one bypasses both the default and the menu, executing the named Step 6 path directly): `--merge` (merge locally), `--push` (push branch without PR), `--keep` (keep as-is), `--discard` (discard, still requires typed confirmation). `--allow-main` permits acting from `main`/`master`; `--no-auto` forces the menu.
  ```

- [ ] **Step 4: Verify it PASSES + validate + ссылки целы.**
  ```bash
  cd /Users/danilka/llm-plugins/superpowers
  TARGET=plugins/superpowers-claude/skills/finishing-a-development-branch/SKILL.md
  grep -n "cached: clean" "$TARGET"          # >=2 совпадения (Step 2 кеш + Tier-1 строка)
  grep -n "plan risk:" "$TARGET"             # >=1 (Step 1 Inputs)
  grep -nE "no-auto|--allow-main|--merge|--push|--keep|--discard" "$TARGET"  # все флаги
  grep -n "gh pr create" "$TARGET"           # дефолт PR + Step 6 путь
  claude plugin validate /Users/danilka/llm-plugins/superpowers/plugins/superpowers-claude
  grep -n "superpowers:" "$TARGET"           # ссылка superpowers:phase-handoff цела
  grep -nE "superpowers:(code-review|security-review|simplify|verify|run)" "$TARGET"  # ПУСТО
  ```
  Ожидаемо: первые четыре grep'а находят вставленный текст; `claude plugin validate` зелёный; пятый grep показывает `superpowers:phase-handoff` (и любые существующие); шестой grep ПУСТ (встроенные без префикса). Фронтматтер (строки 1-4) не тронут. Red Flags секция по-прежнему присутствует.

  Также проверить, что Red Flags в конце файла согласованы с новым дефолтом — прочитать секцию `## Red Flags` и убедиться, что строка про критические `/code-review` находки и `main`-защита не противоречат авто-PR (они остаются: дефолт PR не отменяет блок на critical и защиту main). Если есть прямое противоречие (напр. «Always: ask before destructive actions» — destructive = только merge/discard, авто-PR не destructive), оставить как есть; PR-открытие не разрушительно.

- [ ] **Step 5: Commit.**
  ```bash
  cd /Users/danilka/llm-plugins/superpowers
  git add plugins/superpowers-claude/skills/finishing-a-development-branch/SKILL.md
  git commit -m "feat(finishing): кеш ревью по SHA, PR по умолчанию, приём риск-тира"
  ```
