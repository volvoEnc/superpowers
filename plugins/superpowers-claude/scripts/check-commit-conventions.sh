#!/usr/bin/env bash
# check-commit-conventions.sh — detect-only линтер конвенции git-артефактов форка.
#
# Реализует docs/superpowers/specs/2026-06-26-commit-pr-conventions-design.md.
# Три режима (первый argv — subcommand):
#   commit-msg <file>   — проверяет сообщение коммита из файла (например .git/COMMIT_EDITMSG)
#   pr-title   <string> — проверяет строку-заголовок PR
#   branch     <name>   — проверяет имя ветки
#
# Коды возврата: 0 — валидно; 1 — нарушение конвенции (причина в stderr); 2 — ошибка использования.
#
# Whitelist (load-bearing — текстовый guard в tests/claude-code/test-commit-conventions.sh пиннит эти
# литералы здесь, в SKILL.md и в тесте, чтобы они не разошлись): тип коммита/PR ∈ feat|fix|hotfix;
# префикс ветки ∈ feature|fix|hotfix (обрати внимание на асимметрию feat vs feature).
#
# Безопасность (Tier-1): весь разбор, все регэкспы и чтение файла происходят ВНУТРИ одной программы
# python3. Сообщение / строка / имя / путь передаются в python как argv и НИКОГДА не интерполируются
# в shell-команду — внедрение команд структурно невозможно, ровно как в scripts/liveness-floor.sh.
#
# Zero-dependency: bash + системный python3 (stdlib re, sys) только.
set -euo pipefail

MODE="${1:-}"
case "$MODE" in
  commit-msg|pr-title|branch) ;;
  "")  echo "check-commit-conventions: не указан режим (commit-msg|pr-title|branch)" >&2; exit 2 ;;
  *)   echo "check-commit-conventions: неизвестный режим: $MODE" >&2; exit 2 ;;
esac

if [ "$#" -lt 2 ]; then
  echo "check-commit-conventions: режим $MODE требует аргумент" >&2
  exit 2
fi
ARG="$2"

if [ "$MODE" = "commit-msg" ] && [ ! -f "$ARG" ]; then
  echo "check-commit-conventions: нет такого файла: $ARG" >&2
  exit 2
fi

# Режим и аргумент уходят в python как argv[1]/argv[2]; python заменяет shell (exec), его код возврата
# становится кодом скрипта. Значения пользователя не покидают python и не сплайсятся в shell.
exec python3 - "$MODE" "$ARG" <<'PY'
import sys, re

mode = sys.argv[1]
arg = sys.argv[2]

TYPES = ("feat", "fix", "hotfix")                # whitelist типа коммита/PR
BRANCH_PREFIXES = ("feature", "fix", "hotfix")   # whitelist префикса ветки (feature, не feat)
MAX_SUBJECT = 72

# Структурные регэкспы (синтаксис Python, флаг UNICODE по умолчанию для str — кириллица в subject ок).
# Якорь конца — \Z (строгий конец строки), НЕ $: в Python `$` без re.MULTILINE матчит ещё и перед
# финальным '\n', из-за чего 'feat: x\n' / 'feature/x\n' (хвостовой перевод строки в argv) ложно
# проходили pr-title/branch. \Z запрещает любой хвостовой '\n'.
COMMIT_RE = re.compile(r'^(?P<type>feat|fix|hotfix): (?P<subject>\S(?:.*[^.\s])?)\Z')
PR_TITLE_RE = re.compile(
    r'^(?P<type>feat|fix|hotfix): '
    r'(?P<subject>[^\s\[](?:[^\n\[]*[^.\s\[])?)'
    r'(?: \[(?P<ticket>[A-Z]+-\d+)\])?\Z'
)
BRANCH_RE = re.compile(
    r'^(?P<prefix>feature|fix|hotfix)/'
    r'(?P<slug>[a-z0-9]+(?:-[a-z0-9]+)*)'
    r'(?:-(?P<ticket>[A-Z]+-\d+))?\Z'
)

# Детект ОТСУТСТВИЯ footer/bot-signature: совпадение любой строки = нарушение.
FORBIDDEN_LINE_RES = [
    # Пробел после двоеточия НЕ требуется: git нормализует 'Co-authored-by:Name' в валидный трейлер,
    # поэтому якорим на 'двоеточие в начале строки', без обязательного \s.
    re.compile(r'^\s*Co-Authored-By:', re.IGNORECASE),
    re.compile(r'^\s*Signed-off-by:', re.IGNORECASE),
    re.compile(r'Generated with \[?Claude Code', re.IGNORECASE),
    re.compile('🤖'),                              # робот-эмодзи: любое вхождение — намеренно (over-strict)
    re.compile(r'^\s*Co-?authored-by:', re.IGNORECASE),  # якорная trailer-форма (не ловит прозу)
]

errors = []
def err(msg):
    errors.append(msg)

def check_forbidden(lines):
    for ln in lines:
        for rgx in FORBIDDEN_LINE_RES:
            if rgx.search(ln):
                err("обнаружена запрещённая trailer/bot-signature строка: %s" % ln.strip())
                break

def diagnose_subject(line, allow_ticket):
    """Specific human message for why a 'type: subject' line failed the regex."""
    if re.match(r'^(feat|fix|hotfix)\(', line):
        err("scope/скобки запрещены — формат строго 'type: subject'")
        return
    if not re.match(r'^(feat|fix|hotfix):', line):
        err("неверный или отсутствующий тип (ожидается feat|fix|hotfix)")
        return
    if not re.match(r'^(feat|fix|hotfix): \S', line):
        err("после двоеточия должен быть ровно один пробел и непустой subject")
        return
    body = line.split(": ", 1)[1] if ": " in line else ""
    if allow_ticket and "[" in body:
        err("некорректный или неуместный тикет (допустим только хвостовой ' [ABC-123]')")
        return
    if body.endswith(".") or body != body.rstrip():
        err("subject не должен оканчиваться точкой или пробелом")
        return
    err("строка не соответствует формату 'type: subject'")

def check_core(line, regex, allow_ticket):
    m = regex.match(line)
    if not m:
        diagnose_subject(line, allow_ticket)
        return
    subj = m.group("subject")
    # Пост-проверка: запрет точки/пробела в конце. Регэксп запрещает их только в опциональном хвосте,
    # который для subject длиной 1 пропускается, поэтому 'feat: .' иначе проскочил бы.
    if subj.endswith(".") or subj != subj.strip():
        err("subject не должен оканчиваться точкой и иметь ведущие/хвостовые пробелы")
        return
    if len(subj) > MAX_SUBJECT:
        err("subject длиннее %d символов (%d)" % (MAX_SUBJECT, len(subj)))

if mode == "commit-msg":
    try:
        with open(arg, encoding="utf-8") as fh:
            content = fh.read()
    except OSError as e:
        sys.stderr.write("check-commit-conventions: не удалось прочитать файл: %s\n" % e)
        sys.exit(2)
    except UnicodeDecodeError:
        sys.stderr.write("check-commit-conventions: файл не в кодировке UTF-8: %s\n" % arg)
        sys.exit(2)
    lines = content.split("\n")
    subject = lines[0] if lines else ""
    check_core(subject, COMMIT_RE, allow_ticket=False)
    # Правило «ровно одна пустая строка перед телом» — отдельная не-regex проверка.
    if len(lines) >= 2:
        has_body = any(l.strip() != "" for l in lines[1:])
        if has_body:
            if lines[1] != "":
                err("тело должно отделяться от subject ровно одной пустой строкой")
            elif len(lines) >= 3 and lines[2] == "":
                err("между subject и телом более одной пустой строки")
    check_forbidden(lines)

elif mode == "pr-title":
    check_core(arg, PR_TITLE_RE, allow_ticket=True)
    # Запрет подписей бота распространяется и на заголовок (интент: без bot-атрибуции в git-артефактах).
    check_forbidden([arg])

elif mode == "branch":
    if not BRANCH_RE.match(arg):
        prefix = arg.split("/", 1)[0] if "/" in arg else arg
        if prefix not in BRANCH_PREFIXES:
            err("неверный префикс ветки (ожидается feature|fix|hotfix): %s" % prefix)
        else:
            err("недопустимый slug — ожидается kebab-case [a-z0-9-] и опц. хвост -ABC-123")

else:
    sys.stderr.write("check-commit-conventions: неизвестный режим: %s\n" % mode)
    sys.exit(2)

for e in errors:
    sys.stderr.write("check-commit-conventions: %s\n" % e)
sys.exit(1 if errors else 0)
PY
