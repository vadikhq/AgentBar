---
name: agentbar
description: "AgentBar read. Provider usage, limits, credits, config health. JSON. No writes."
---

# AgentBar

Read AgentBar. Never mutate config/auth.

## Run

```bash
skill="${CODEX_HOME:-$HOME/.codex}/skills/agentbar"
"$skill/scripts/agentbar" doctor
"$skill/scripts/agentbar" providers
"$skill/scripts/agentbar" usage
"$skill/scripts/agentbar" usage --provider codex
"$skill/scripts/agentbar" usage --all
```

All stdout: JSON. Upstream AgentBar shape kept. Less drift, fewer tokens.

## Rules

- Start `doctor` when install/config unknown.
- `usage` reads enabled providers. Prefer this.
- `usage --provider ID` reads one provider.
- `usage --all` expensive; use only when needed.
- Identities hidden by default. `--include-identities` only when user explicitly needs them.
- Secrets always hidden.
- Helper read-only: fixed allowlist only. No config writes, auth repair, enable/disable, key storage.
- Timeout means upstream stuck. Narrow provider or raise `AGENTBAR_TIMEOUT` (default 120 seconds).

## Binary

Auto-find: `AGENTBAR_BIN`, PATH, app bundle, Homebrew cask. If missing: open AgentBar, Preferences > Advanced > Install CLI; or set `AGENTBAR_BIN`.

Each stdout/stderr stream capped at 1 MiB while fully drained. Timeout kills process group.
