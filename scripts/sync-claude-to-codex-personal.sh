#!/usr/bin/env bash
#
# sync-claude-to-codex-personal.sh
#
# Conservative sync from the Claude fork package into the Codex personal package.
# This is a port, not a blind mirror: it copies only the portable additions and
# rewrites Claude-package paths to Codex-package paths.
#
# Usage:
#   ./scripts/sync-claude-to-codex-personal.sh          # apply sync
#   ./scripts/sync-claude-to-codex-personal.sh --check  # fail if drift exists
#   ./scripts/sync-claude-to-codex-personal.sh -n       # preview diff only

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SRC="$REPO_ROOT/plugins/superpowers-claude"
DEST="$REPO_ROOT/plugins/superpowers-personal"

CHECK=0
DRY_RUN=0

usage() {
  sed -n '/^# Usage:/,/^$/s/^# \{0,1\}//p' "$0"
  exit "${1:-0}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --check) CHECK=1; shift ;;
    -n|--dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage 0 ;;
    *) echo "unknown arg: $1" >&2; usage 2 ;;
  esac
done

die() {
  echo "ERROR: $*" >&2
  exit 1
}

command -v python3 >/dev/null || die "python3 not found"
command -v diff >/dev/null || die "diff not found"

[[ -d "$SRC" ]] || die "Claude package missing: $SRC"
[[ -d "$DEST" ]] || die "Codex personal package missing: $DEST"
[[ -f "$SRC/.claude-plugin/plugin.json" ]] || die "Claude manifest missing"
[[ -f "$DEST/.codex-plugin/plugin.json" ]] || die "Codex manifest missing"

SYNC_SKILLS=(
  "commit-pr-conventions"
  "frontend-design"
  "web-interface-guidelines"
  "webapp-testing"
)

sync_tree() {
  local target="$1"
  local skill

  for skill in "${SYNC_SKILLS[@]}"; do
    [[ -d "$SRC/skills/$skill" ]] || die "source skill missing: $skill"
    rm -rf "$target/skills/$skill"
    mkdir -p "$target/skills"
    cp -R "$SRC/skills/$skill" "$target/skills/$skill"
  done

  mkdir -p "$target/scripts"
  cp "$SRC/scripts/check-commit-conventions.sh" "$target/scripts/check-commit-conventions.sh"
  chmod +x "$target/scripts/check-commit-conventions.sh"

  python3 - "$SRC" "$target" <<'PY'
from pathlib import Path
import json
import sys

src = Path(sys.argv[1])
target = Path(sys.argv[2])


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def write_text(path: Path, text: str) -> None:
    path.write_text(text, encoding="utf-8")


def replace_section(text: str, start_marker: str, end_marker: str, replacement: str) -> str:
    start = text.find(start_marker)
    if start == -1:
        return text
    start += len(start_marker)
    end = text.find(end_marker, start)
    if end == -1:
        return text
    return text[:start] + replacement + text[end:]


def rewrite_common_paths(path: Path) -> None:
    text = read_text(path)
    text = text.replace("plugins/superpowers-claude", "plugins/superpowers-personal")
    text = text.replace(".claude-plugin", ".codex-plugin")
    if text != read_text(path):
        write_text(path, text)


for path in target.rglob("*"):
    if not path.is_file():
        continue
    if path.suffix.lower() not in {".md", ".txt", ".json", ".sh", ".py", ".js", ".mjs", ".ts", ".dot"}:
        continue
    rewrite_common_paths(path)

commit_skill = target / "skills" / "commit-pr-conventions" / "SKILL.md"
if commit_skill.exists():
    text = read_text(commit_skill)
    text = replace_section(
        text,
        "## Линтер\n\n",
        "Три режима",
        (
            "Линтер поставляется вместе с Codex personal plugin.\n\n"
            "Разреши `linterPath` так:\n\n"
            "- если читаешь этот файл как skill: `../../scripts/check-commit-conventions.sh` "
            "относительно каталога `commit-pr-conventions/SKILL.md`;\n"
            "- если работаешь из корня этого репозитория: "
            "`plugins/superpowers-personal/scripts/check-commit-conventions.sh`.\n\n"
            "Не используй путь из Claude-пакета для Codex-адаптации.\n\n"
        ),
    )
    text = text.replace("Если строка `linterPath=…` выше **не напечаталась** (shell-инъекция отключена политикой, напр. `disableSkillShellExecution`), не угадывай путь — линтер лежит в каталоге плагина: `plugins/superpowers-personal/scripts/check-commit-conventions.sh`.\n\n", "")
    write_text(commit_skill, text)

guidelines_skill = target / "skills" / "web-interface-guidelines" / "SKILL.md"
if guidelines_skill.exists():
    text = read_text(guidelines_skill)
    text = replace_section(
        text,
        "## Как прогнать аудит\n\n",
        "Правила бери",
        (
            "Свод правил лежит рядом со скиллом: `references/guidelines.md`.\n\n"
            "Разрешай путь относительно каталога этого `SKILL.md`. Если работаешь из корня "
            "этого репозитория, fallback-путь такой: "
            "`plugins/superpowers-personal/skills/web-interface-guidelines/references/guidelines.md`.\n\n"
            "1. **Прочитай свод правил** по этому локальному пути — это единственный источник правил для аудита.\n"
            "2. **Открой проверяемые файлы UI** (разметка, компоненты, стили) и пройди их по каждому пункту свода.\n"
            "3. **Зафиксируй каждое нарушение** в формате репорта (ниже).\n\n"
        ),
    )
    text = text.replace("напечатанному выше `guidelinesPath`", "локальному `references/guidelines.md`")
    text = text.replace("напечатанный `guidelinesPath` (он же `references/guidelines.md` в каталоге скилла)", "`references/guidelines.md` в каталоге скилла")
    text = text.replace("`guidelinesPath`", "`references/guidelines.md`")
    text = text.replace("напечатанному `references/guidelines.md`", "локальному `references/guidelines.md`")
    write_text(guidelines_skill, text)

src_manifest = json.loads(read_text(src / ".claude-plugin" / "plugin.json"))
dest_manifest_path = target / ".codex-plugin" / "plugin.json"
dest_manifest = json.loads(read_text(dest_manifest_path))
dest_manifest["version"] = src_manifest["version"]

keywords = dest_manifest.setdefault("keywords", [])
for keyword in [
    "commit-pr-conventions",
    "frontend-design",
    "web-interface-guidelines",
    "webapp-testing",
]:
    if keyword not in keywords:
        keywords.append(keyword)

interface = dest_manifest.setdefault("interface", {})
interface["longDescription"] = (
    "Use Superpowers Personal to guide Codex through text-only brainstorming, artifact-first planning, "
    "plan review, test-driven development, branch-based execution, immediate subagent cleanup, code review, "
    "finish-the-branch workflows, commit/PR conventions, distinctive frontend design, web interface audits, "
    "and local webapp testing."
)

write_text(dest_manifest_path, json.dumps(dest_manifest, ensure_ascii=False, indent=2) + "\n")
PY
}

make_expected() {
  local work target
  work="$(mktemp -d)"
  target="$work/superpowers-personal"
  mkdir -p "$target"
  cp -R "$DEST/." "$target/"
  sync_tree "$target"
  printf '%s' "$target"
}

if [[ "$CHECK" -eq 1 || "$DRY_RUN" -eq 1 ]]; then
  EXPECTED="$(make_expected)"
  if diff -qr "$EXPECTED" "$DEST"; then
    echo "Codex personal plugin is in sync with the Claude allowlist."
    exit 0
  fi
  if [[ "$CHECK" -eq 1 ]]; then
    echo "Codex personal plugin is out of sync. Run: $0" >&2
    exit 1
  fi
  exit 0
fi

sync_tree "$DEST"
echo "Synced Claude allowlist into Codex personal plugin."
