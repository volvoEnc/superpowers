#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SYNC_SCRIPT="$REPO_ROOT/scripts/sync-claude-to-codex-personal.sh"
DEST="$REPO_ROOT/plugins/superpowers-personal"
SRC="$REPO_ROOT/plugins/superpowers-claude"

FAILURES=0

pass() {
  echo "  [PASS] $1"
}

fail() {
  echo "  [FAIL] $1"
  FAILURES=$((FAILURES + 1))
}

assert_file() {
  local path="$1" desc="$2"
  if [[ -f "$path" ]]; then pass "$desc"; else fail "$desc (missing: $path)"; fi
}

assert_dir() {
  local path="$1" desc="$2"
  if [[ -d "$path" ]]; then pass "$desc"; else fail "$desc (missing: $path)"; fi
}

assert_absent() {
  local path="$1" desc="$2"
  if [[ ! -e "$path" ]]; then pass "$desc"; else fail "$desc (unexpected: $path)"; fi
}

assert_no_grep() {
  local pattern="$1" path="$2" desc="$3"
  if grep -R -n -E "$pattern" "$path" >/tmp/sync-claude-to-codex-grep.$$ 2>/dev/null; then
    fail "$desc"
    sed 's/^/    /' /tmp/sync-claude-to-codex-grep.$$
  else
    pass "$desc"
  fi
  rm -f /tmp/sync-claude-to-codex-grep.$$
}

json_field() {
  python3 - "$1" "$2" <<'PY'
import json, sys
path, field = sys.argv[1], sys.argv[2]
value = json.load(open(path))
for part in field.split("."):
    value = value[int(part)] if part.isdigit() else value[part]
print(value)
PY
}

echo "=== Test: sync Claude additions into Codex personal plugin ==="

assert_file "$SYNC_SCRIPT" "sync script exists"
if [[ -f "$SYNC_SCRIPT" ]]; then
  if bash "$SYNC_SCRIPT" --check >/tmp/sync-claude-to-codex-check.$$ 2>&1; then
    pass "sync check reports destination up to date"
  else
    fail "sync check reports drift"
    sed 's/^/    /' /tmp/sync-claude-to-codex-check.$$
  fi
  rm -f /tmp/sync-claude-to-codex-check.$$
fi

for skill in commit-pr-conventions frontend-design web-interface-guidelines webapp-testing; do
  assert_dir "$DEST/skills/$skill" "Codex personal has $skill"
  assert_file "$DEST/skills/$skill/SKILL.md" "$skill has SKILL.md"
done

assert_file "$DEST/scripts/check-commit-conventions.sh" "Codex personal has commit convention linter"
if [[ -f "$DEST/scripts/check-commit-conventions.sh" && -x "$DEST/scripts/check-commit-conventions.sh" ]]; then
  pass "commit convention linter is executable"
else
  fail "commit convention linter is executable"
fi

assert_file "$DEST/skills/web-interface-guidelines/references/guidelines.md" "web interface guidelines snapshot copied"
assert_file "$DEST/skills/web-interface-guidelines/LICENSE.txt" "web interface guidelines license copied"
assert_file "$DEST/skills/webapp-testing/scripts/with_server.py" "webapp-testing helper script copied"

assert_absent "$DEST/skills/reviewing-plans/review-plan.workflow.js" "Claude Workflow script is not copied into Codex personal"
assert_absent "$DEST/hooks" "Claude hooks are not copied into Codex personal"

for skill in commit-pr-conventions web-interface-guidelines webapp-testing frontend-design; do
  assert_no_grep 'CLAUDE_SKILL_DIR|plugins/superpowers-claude' "$DEST/skills/$skill" "$skill has no Claude-only repo/path markers"
done

if [[ -f "$DEST/skills/commit-pr-conventions/SKILL.md" ]]; then
  if grep -q 'plugins/superpowers-personal/scripts/check-commit-conventions.sh' "$DEST/skills/commit-pr-conventions/SKILL.md"; then
    pass "commit-pr-conventions points at Codex personal linter path"
  else
    fail "commit-pr-conventions points at Codex personal linter path"
  fi
fi

if [[ -f "$DEST/skills/web-interface-guidelines/SKILL.md" ]]; then
  if grep -q 'plugins/superpowers-personal/skills/web-interface-guidelines/references/guidelines.md' "$DEST/skills/web-interface-guidelines/SKILL.md"; then
    pass "web-interface-guidelines points at Codex personal snapshot path"
  else
    fail "web-interface-guidelines points at Codex personal snapshot path"
  fi
fi

src_version="$(json_field "$SRC/.claude-plugin/plugin.json" version)"
dest_version="$(json_field "$DEST/.codex-plugin/plugin.json" version)"
if [[ "$dest_version" == "$src_version" ]]; then
  pass "Codex personal manifest version matches Claude plugin version ($dest_version)"
else
  fail "Codex personal manifest version matches Claude plugin version"
  echo "    expected: $src_version"
  echo "    actual:   $dest_version"
fi

echo
if [[ "$FAILURES" -eq 0 ]]; then
  echo "PASS"
  exit 0
else
  echo "FAIL ($FAILURES failures)"
  exit 1
fi
