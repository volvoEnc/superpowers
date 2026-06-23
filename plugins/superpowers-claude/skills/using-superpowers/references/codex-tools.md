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

### Required subagent lifecycle

Every Codex subagent that has returned a terminal result must be closed immediately:

```text
spawn_agent -> wait_agent -> read result -> close_agent
```

This applies to implementers, reviewers, scouts, risk reviewers, and one-off investigation agents. Do not keep completed agents open for later. Their result is the artifact; the live agent thread is just a tab hoarding gremlin.

If a follow-up fix is needed, dispatch a new subagent with the original task, the review finding, and the relevant diff. Do not leave the old subagent open between phases.

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
- If Codex refuses to spawn more agents, first check for completed agents that were not closed.

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

## Branch Detection

Skills that start or finish implementation should detect their branch state with read-only git commands before proceeding:

```bash
BRANCH=$(git branch --show-current)
STATUS=$(git status --short)
```

- `BRANCH` is `main` or `master` -> ask whether to create a new feature branch or work directly on the current branch.
- `BRANCH` is empty -> detached HEAD, ask how to proceed.
- `STATUS` is non-empty -> report dirty files before switching branches or editing.

See `using-git-branches` for setup and `finishing-a-development-branch` for completion.

## Codex App Finishing

When the sandbox blocks branch or push operations, the agent commits any safe local work it can complete and informs the user to use the App's native controls:

- **"Create branch"** - names the branch, then commit/push/PR via App UI
- **"Hand off to local"** - transfers work to the user's local checkout

The agent can still run tests, stage files, and output suggested branch names, commit messages, and PR descriptions for the user to copy.
