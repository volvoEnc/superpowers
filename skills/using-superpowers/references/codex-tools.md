# Codex Tool Mapping

Skills use Claude Code tool names. When you encounter these in a skill, use your platform equivalent:

| Skill references | Codex equivalent |
|-----------------|------------------|
| `Task` tool (dispatch subagent) | `spawn_agent` |
| Multiple `Task` calls (parallel) | Multiple `spawn_agent` calls |
| Task returns result | `wait_agent` |
| Task completes automatically | `close_agent` to free slot |
| `TodoWrite` (task tracking) | `update_plan` |
| `Skill` tool (invoke a skill) | Skills load natively. Follow the selected skill's instructions |
| `Read`, `Write`, `Edit` (files) | Use your native file tools |
| `Bash` (run commands) | Use your native shell tools |

## Subagent support in current Codex

Current Codex releases support subagent workflows without the legacy feature flag. Do not tell users to add this obsolete config:

```toml
[features]
multi_agent = true
```

Use `spawn_agent`, `wait_agent`, and `close_agent` when a Superpowers skill calls for subagent dispatch.

Subagents are best for bounded work with clean handoffs: codebase exploration, plan review, test investigation, triage, and single-task implementation. Be cautious with parallel write-heavy work. Multiple agents editing the same files can create conflicts and coordination overhead.

## Subagent limits

Global Codex subagent settings live under `[agents]` in `~/.codex/config.toml` or project config:

```toml
[agents]
max_threads = 6
max_depth = 1
```

- `max_threads` caps concurrently open agent threads.
- `max_depth = 1` allows direct child agents but prevents recursive fan-out. Keep this default unless you have a strong reason to allow agents to spawn more agents.
- Raising `max_depth` can increase token usage, latency, local resource use, and unpredictability.

## Custom agents

Codex can use project-scoped custom agents from `.codex/agents/*.toml` or personal agents from `~/.codex/agents/*.toml`.

Each custom agent file must define:

```toml
name = "plan_reviewer"
description = "Reviews implementation plans for correctness, coverage, and testability."
developer_instructions = """
Review plans only. Do not implement code.
Return concrete findings with file paths, evidence, severity, and recommended plan edits.
"""
```

Useful Superpowers agent roles:

| Role | Suggested sandbox | Use |
|------|-------------------|-----|
| `context_scout` | read-only | Build a concise codebase map before planning |
| `plan_author` | read-only | Draft plans from an approved spec and context pack |
| `plan_reviewer` | read-only | Review plans before execution |
| `risk_reviewer` | read-only | Check migrations, security, data loss, concurrency, public APIs |

## Environment Detection

Skills that create worktrees or finish branches should detect their
environment with read-only git commands before proceeding:

```bash
GIT_DIR=$(cd "$(git rev-parse --git-dir)" 2>/dev/null && pwd -P)
GIT_COMMON=$(cd "$(git rev-parse --git-common-dir)" 2>/dev/null && pwd -P)
BRANCH=$(git branch --show-current)
```

- `GIT_DIR != GIT_COMMON` -> already in a linked worktree (skip creation)
- `BRANCH` empty -> detached HEAD (cannot branch/push/PR from sandbox)

See `using-git-worktrees` Step 0 and `finishing-a-development-branch`
Step 1 for how each skill uses these signals.

## Codex App Finishing

When the sandbox blocks branch/push operations (detached HEAD in an
externally managed worktree), the agent commits all work and informs
the user to use the App's native controls:

- **"Create branch"** - names the branch, then commit/push/PR via App UI
- **"Hand off to local"** - transfers work to the user's local checkout

The agent can still run tests, stage files, and output suggested branch
names, commit messages, and PR descriptions for the user to copy.
