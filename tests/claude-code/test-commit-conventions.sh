#!/usr/bin/env bash
# Tests for scripts/check-commit-conventions.sh — the commit/PR/branch convention linter.
#
# Covers the acceptance criteria of docs/superpowers/specs/2026-06-26-commit-pr-conventions-design.md:
#   - three modes (commit-msg / pr-title / branch), valid AND invalid cases
#   - subject length boundary (72 ok / 73 reject)
#   - forbidden trailer / bot-signature detection
#   - usage errors (exit != 0)
#   - whitelist textual guard (feat/fix/hotfix and feature/fix/hotfix pinned in skill + linter + test)
#   - the skill is cross-referenced from the three pipeline skills
#
# test-helpers.sh has no exit-code asserts, so this file defines its own (assert_exit_zero/_nonzero),
# exactly as the spec anticipates.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/test-helpers.sh"

REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LINTER="$REPO_ROOT/plugins/superpowers-claude/scripts/check-commit-conventions.sh"
SKILL="$REPO_ROOT/plugins/superpowers-claude/skills/commit-pr-conventions/SKILL.md"

FAILS=0
pass() { echo "  [PASS] $1"; }
fail() { echo "  [FAIL] $1"; FAILS=$((FAILS + 1)); }

# --- local exit-code asserts (not provided by test-helpers.sh) ---
assert_exit_zero() {
  local desc="$1"; shift
  if "$@" >/dev/null 2>&1; then pass "$desc"; else fail "$desc (ожидался exit 0, получен $?)"; fi
}
assert_exit_nonzero() {
  local desc="$1"; shift
  if "$@" >/dev/null 2>&1; then fail "$desc (ожидался ненулевой exit, получен 0)"; else pass "$desc"; fi
}
assert_grep() {
  local file="$1" pat="$2" desc="$3"
  if [ -f "$file" ] && grep -qE -- "$pat" "$file"; then pass "$desc"; else fail "$desc (не найдено: $pat в $file)"; fi
}
assert_exit_code() {
  local want="$1" desc="$2"; shift 2
  "$@" >/dev/null 2>&1; local got=$?
  if [ "$got" -eq "$want" ]; then pass "$desc"; else fail "$desc (ожидался exit $want, получен $got)"; fi
}

# temp-файлы трекаются и удаляются на выходе
TMPFILES=()
cleanup() { [ "${#TMPFILES[@]}" -gt 0 ] && rm -f "${TMPFILES[@]}"; }
trap cleanup EXIT

# write stdin to a temp commit-message file, echo its path
commit_file() { local f; f="$(mktemp)"; TMPFILES+=("$f"); cat > "$f"; echo "$f"; }

echo "=== check-commit-conventions: commit-msg ==="
# valid
f="$(printf 'feat: добавил линтер коммитов\n' | commit_file)"
assert_exit_zero "commit valid: feat" "$LINTER" commit-msg "$f"
f="$(printf 'fix: исправил падение при пустом inflight\n' | commit_file)"
assert_exit_zero "commit valid: fix" "$LINTER" commit-msg "$f"
f="$(printf 'hotfix: вернул базовую ветку main\n' | commit_file)"
assert_exit_zero "commit valid: hotfix" "$LINTER" commit-msg "$f"
f="$(printf 'feat: добавил X\n\nподробное тело через одну пустую строку\nвторая строка тела\n' | commit_file)"
assert_exit_zero "commit valid: тело через одну пустую строку" "$LINTER" commit-msg "$f"
s72="$(printf 'д%.0s' $(seq 1 72))"
f="$(printf 'feat: %s\n' "$s72" | commit_file)"
assert_exit_zero "commit valid: subject ровно 72 символа" "$LINTER" commit-msg "$f"

# invalid
f="$(printf 'feature: добавил линтер коммитов\n' | commit_file)"
assert_exit_nonzero "commit invalid: тип feature" "$LINTER" commit-msg "$f"
f="$(printf 'feat(x): добавил линтер коммитов\n' | commit_file)"
assert_exit_nonzero "commit invalid: scope в скобках" "$LINTER" commit-msg "$f"
f="$(printf 'feat: Добавил линтер коммитов.\n' | commit_file)"
assert_exit_nonzero "commit invalid: точка в конце" "$LINTER" commit-msg "$f"
f="$(printf 'feat:  добавил линтер коммитов\n' | commit_file)"
assert_exit_nonzero "commit invalid: два пробела после двоеточия" "$LINTER" commit-msg "$f"
s73="$(printf 'д%.0s' $(seq 1 73))"
f="$(printf 'feat: %s\n' "$s73" | commit_file)"
assert_exit_nonzero "commit invalid: subject 73 символа (граница длины)" "$LINTER" commit-msg "$f"
f="$(printf 'feat: добавил X\n\nтело\n\nCo-Authored-By: Claude <noreply@anthropic.com>\n' | commit_file)"
assert_exit_nonzero "commit invalid: запрещённый Co-Authored-By" "$LINTER" commit-msg "$f"
f="$(printf 'feat: добавил X\n\nтело\n\nSigned-off-by: someone <a@b.c>\n' | commit_file)"
assert_exit_nonzero "commit invalid: запрещённый Signed-off-by" "$LINTER" commit-msg "$f"
f="$(printf 'feat: добавил X\n\n🤖 Generated with Claude Code\n' | commit_file)"
assert_exit_nonzero "commit invalid: запрещённая bot-signature" "$LINTER" commit-msg "$f"
f="$(printf 'feat: добавил X\n\n\nтело с двойной пустой строкой\n' | commit_file)"
assert_exit_nonzero "commit invalid: более одной пустой строки перед телом" "$LINTER" commit-msg "$f"

echo "=== check-commit-conventions: pr-title ==="
assert_exit_zero "pr-title valid: с тикетом" "$LINTER" pr-title 'feat: исправил верстку ЛК [MBSD-4312]'
assert_exit_zero "pr-title valid: без тикета" "$LINTER" pr-title 'fix: убрал дубль проверки'
assert_exit_nonzero "pr-title invalid: строчный тикет" "$LINTER" pr-title 'feat: исправил верстку ЛК [mbsd-4312]'
assert_exit_nonzero "pr-title invalid: тикет не в конце" "$LINTER" pr-title 'feat: [MBSD-4312] исправил верстку ЛК'
assert_exit_nonzero "pr-title invalid: точка в конце" "$LINTER" pr-title 'feat: исправил верстку.'
assert_exit_nonzero "pr-title invalid: тип feature" "$LINTER" pr-title 'feature: исправил верстку ЛК'
assert_exit_zero "pr-title valid: subject ровно 72" "$LINTER" pr-title "feat: $s72"
assert_exit_nonzero "pr-title invalid: subject 73 (граница длины)" "$LINTER" pr-title "feat: $s73"
pr_nl=$'feat: добавил фичу\n'
assert_exit_nonzero "pr-title invalid: хвостовой перевод строки" "$LINTER" pr-title "$pr_nl"
assert_exit_nonzero "pr-title invalid: 🤖 в заголовке" "$LINTER" pr-title 'feat: добавил 🤖 фичу'

echo "=== check-commit-conventions: branch ==="
assert_exit_zero "branch valid: с тикетом" "$LINTER" branch 'fix/lk-design-ui-MBSD-3123'
assert_exit_zero "branch valid: без тикета" "$LINTER" branch 'feature/commit-linter'
assert_exit_zero "branch valid: hotfix" "$LINTER" branch 'hotfix/restore-main-base'
assert_exit_nonzero "branch invalid: префикс feat" "$LINTER" branch 'feat/commit-linter'
assert_exit_nonzero "branch invalid: slug не kebab" "$LINTER" branch 'feature/Commit_Linter'
br_nl=$'feature/commit-linter\n'
assert_exit_nonzero "branch invalid: хвостовой перевод строки" "$LINTER" branch "$br_nl"

echo "=== check-commit-conventions: usage ==="
assert_exit_nonzero "usage: без subcommand" "$LINTER"
assert_exit_nonzero "usage: неизвестный режим" "$LINTER" bogus x
assert_exit_nonzero "usage: commit-msg без файла" "$LINTER" commit-msg
assert_exit_nonzero "usage: commit-msg несуществующий файл" "$LINTER" commit-msg /no/such/file/xyz

echo "=== регресс после code-review ==="
# одиночная точка (длина 1) не должна обходить запрет точки в конце subject
f="$(printf 'feat: .\n' | commit_file)"
assert_exit_nonzero "commit invalid: одиночная точка в subject" "$LINTER" commit-msg "$f"
assert_exit_nonzero "pr-title invalid: одиночная точка в subject" "$LINTER" pr-title 'feat: .'
# трейлер без пробела после двоеточия должен ловиться (git нормализует его в валидный)
f="$(printf 'feat: добавил X\n\nCo-authored-by:Jane Doe <j@e.co>\n' | commit_file)"
assert_exit_nonzero "commit invalid: трейлер без пробела после двоеточия" "$LINTER" commit-msg "$f"
# не-UTF-8 файл -> usage-ошибка (exit 2), не traceback/exit 1
f="$(mktemp)"; TMPFILES+=("$f")
python3 -c "import sys; open(sys.argv[1],'wb').write('feat: добавил X\n'.encode('cp1251'))" "$f"
assert_exit_code 2 "commit-msg: не-UTF-8 файл -> exit 2" "$LINTER" commit-msg "$f"
# контракт кодов возврата: usage=2, нарушение конвенции=1
assert_exit_code 2 "контракт: usage без subcommand -> 2" "$LINTER"
assert_exit_code 2 "контракт: несуществующий файл -> 2" "$LINTER" commit-msg /no/such/file/xyz
f="$(printf 'feature: добавил X\n' | commit_file)"
assert_exit_code 1 "контракт: нарушение конвенции -> 1" "$LINTER" commit-msg "$f"

echo "=== whitelist guard (drift): константы пиннятся в линтере, скилле и тесте ==="
assert_grep "$LINTER" 'feat\|fix\|hotfix' "линтер пиннит whitelist типов feat|fix|hotfix"
assert_grep "$LINTER" 'feature\|fix\|hotfix' "линтер пиннит whitelist префиксов веток feature|fix|hotfix"
assert_grep "$SKILL" 'feat' "SKILL.md упоминает feat"
assert_grep "$SKILL" 'feature' "SKILL.md упоминает feature"
assert_grep "$SKILL" 'hotfix' "SKILL.md упоминает hotfix"

echo "=== перекрёстные ссылки: skill упомянут в 3 пайплайн-скиллах ==="
for s in finishing-a-development-branch using-git-branches requesting-code-review; do
  assert_grep "$REPO_ROOT/plugins/superpowers-claude/skills/$s/SKILL.md" 'commit-pr-conventions' "skill $s ссылается на commit-pr-conventions"
done

echo
if [ "$FAILS" -eq 0 ]; then
  echo "ВСЕ ТЕСТЫ ПРОЙДЕНЫ"
  exit 0
else
  echo "ПРОВАЛЕНО ТЕСТОВ: $FAILS"
  exit 1
fi
