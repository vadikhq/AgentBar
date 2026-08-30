---
summary: "AgentBar CLI for fetching usage from the command line."
read_when:
  - "You want to call AgentBar data from scripts or a terminal."
  - "Adding or modifying Commander-based CLI commands."
  - "Aligning menubar and CLI output/behavior."
---

# AgentBar CLI

A lightweight Commander-based CLI that mirrors the menu bar app’s provider fetchers and config file.
Use it when you need usage numbers in scripts, CI, or dashboards without UI.

## Install
- In the app: **Preferences → Advanced → Install CLI**. This symlinks `AgentBarCLI` to `/usr/local/bin/agentbar` and `/opt/homebrew/bin/agentbar`.
- From the repo, after installing `AgentBar.app` in `/Applications`: `./bin/install-agentbar-cli.sh` (same symlink targets; requires macOS administrator approval).
- Manual: `ln -sf "/Applications/AgentBar.app/Contents/Helpers/AgentBarCLI" /usr/local/bin/agentbar`.

The repo installer requires an executable `/Applications/AgentBar.app/Contents/Helpers/AgentBarCLI`; a missing
helper is an error. It starts the system POSIX shell with `-p` to ignore inherited functions and startup hooks
before helper validation or failure handling. This shell mode does not elevate privileges; macOS administrator
approval is still required. The installer uses absolute system tools, clears the inherited environment before
requesting approval, and stops on installation failure. The in-app installer is separate and uses Foundation symlinks.

### Release tarball install (macOS/Linux)
- Homebrew formula (Linux today): `brew install steipete/tap/codexbar`.
- Download release tarballs from GitHub Releases:
  - macOS: `AgentBarCLI-v<tag>-macos-arm64.tar.gz`, `AgentBarCLI-v<tag>-macos-x86_64.tar.gz`
  - Linux (glibc): `AgentBarCLI-v<tag>-linux-aarch64.tar.gz`, `AgentBarCLI-v<tag>-linux-x86_64.tar.gz`
  - Linux (static musl): `AgentBarCLI-v<tag>-linux-musl-aarch64.tar.gz`, `AgentBarCLI-v<tag>-linux-musl-x86_64.tar.gz`
- Extract and run `./agentbar` (symlink) or `./AgentBarCLI`.

```
tar -xzf AgentBarCLI-v0.17.0-macos-x86_64.tar.gz
./agentbar --version
./agentbar usage --format json --pretty
```

## Build
- `./Scripts/package_app.sh` (or `./Scripts/compile_and_run.sh`) bundles `AgentBarCLI` into `AgentBar.app/Contents/Helpers/AgentBarCLI`.
- Standalone: `swift build -c release --product AgentBarCLI` (binary at `./.build/release/AgentBarCLI`).
- Dependencies: Swift 6.2+, Commander package (`https://github.com/steipete/Commander`).

## Configuration
AgentBar reads the resolved config file for provider settings, secrets, and ordering. New installs use
`~/.config/agentbar/config.json`; absolute `XDG_CONFIG_HOME` paths and `AGENTBAR_CONFIG` are supported, and existing
`~/.agentbar/config.json` installs keep using the legacy file when no XDG config exists.
See `docs/configuration.md` for the schema.

## Command
- `agentbar` defaults to the `usage` command.
  - `--format text|json|toon` (default: text).
  - JSON uses the generic `usage.details` array for provider-specific information. Each section contains an optional
    `title`, `rows` (`label`, `value`, and optional `secondaryValue`), and an optional `bars` or `line` chart. The same
    shape is returned by `GET /usage` from `agentbar serve`.
  - Legacy provider-specific keys such as `openRouterUsage`, `clawRouterUsage`, and `sub2APIUsage` are not compatibility
    aliases; clients must read `usage.details`. Unknown legacy keys in cached or iCloud-synced snapshots are ignored
    when decoding.
  - `--format toon` emits the same payload as `--format json` (and implies `--json`'s credits/no-color behavior),
    rendered as [TOON](https://github.com/toon-format/spec) instead: uniform arrays of scalar-only objects (for
    example `usage.details[].rows`) collapse into a compact `rows[N]{label,value}:` table, everything else falls
    back to an indented list form. This is a presentation-only mapping of the existing JSON schema — no new fields,
    no denormalization — intended for agents that want a token-cheaper alternative to parsing JSON. `usage --format
    toon` is the only command that supports it; every other command still advertises and accepts only
    `--format text|json`, and treats `toon` like any other unrecognized value.
- `agentbar cost` prints token cost usage for Claude, Codex, Cursor, and Antigravity.
  - Claude and Codex are scanned from local session logs without web/CLI access.
  - Antigravity reads supported local token history without web, provider CLI, or credential access. It does not estimate dollar costs; unsupported timestamps and incomplete histories remain unavailable (see `docs/antigravity.md`). The same provider selection applies to `serve /cost` and dashboard cost collection.
    Text output labels this as token history and distinguishes unavailable or incomplete history from a complete period with no recorded usage.
  - Cursor is fetched from the cookie-authenticated cursor.com dashboard API (macOS only; see `docs/cursor.md`) and honors the configured cookie source: a non-empty Manual header is required and forwarded, while Off fails explicitly instead of silently omitting Cursor.
  - `--format text|json` (default: text). `--json` includes the same cost concepts as Settings → Usage & Spend (token mix, `provenance`, coverage), but it is not the dashboard Export JSON schema. CLI places mix fields under each provider's `totals` and emits `provenance`/`coverage` on that provider object; Export JSON nests `tokenMix`, `provenance`, and `coverage` under `groups[]`.
  - OpenCodex appears as a separate `opencodex` payload only when **Include OpenCodex usage logs** is on in Settings. That payload does not invent `projects` (OpenCodex logs have no workspace path).
  - `--refresh` ignores cached scans.
  - `--provider-native-only` is experimental and excludes pi and OMP session mirrors from Claude and Codex history.
- `agentbar cards` prints a one-shot usage snapshot as a responsive terminal card grid.
  - Reuses the same provider, source, account, credits, and status flags as `agentbar usage`.
  - Account lines and plan badges are included in the card grid by default.
  - `--brief` renders a compact table (Provider / Usage / Reset) instead of the card grid.
  - Stdout is always rendered text; `--json-output` only affects stderr logs (no JSON card payload).
  - Failed providers are summarized in a footer (not rendered as error cards).
  - When the opt-in Claude claude-swap integration returns two or more accounts—or one account with
    `claudeSwapShowSingleAccount` enabled—cards renders every account in active-first/slot order instead of the
    ambient or token-account Claude cards. This applies on macOS and Linux, including an explicit
    `--provider claude`; `--source auto` remains eligible.
  - `--account`, `--account-index`, `--all-accounts`, and explicit non-auto source flags preserve their requested
    ambient behavior and do not invoke claude-swap. Zero-account lists always retain ambient Claude output;
    one-account lists do so unless `claudeSwapShowSingleAccount` is enabled.
  - claude-swap sentinel accounts remain successful cards with their problem text and no fabricated usage metrics.
    A list adapter, parser, or timeout failure retains useful ambient Claude output, adds a distinct
    `Claude (claude-swap)` failure footer entry, and makes the command exit non-zero.
  - This precedence is cards-only: `agentbar usage` and `agentbar serve` keep their existing output cardinality.
  - Honors `$COLUMNS` for layout; falls back to 80 columns. Use `--no-color` for plain output.
  - Kitty, Ghostty, WezTerm, and other truecolor terminals auto-enable enhanced gradients/outlines.
  - Force enhanced mode elsewhere with `AGENTBAR_CARDS_ENHANCED=1`.
  - Exit code is non-zero when any provider fetch fails.
- `agentbar dashboard` prints one dashboard-v1 JSON snapshot and exits.
  - Honors enabled providers in stable order, carries configured display sort keys, and defaults to full account identity; `--identity redacted` hides email local parts.
  - Provider failures remain row-level errors alongside healthy rows; a valid partial snapshot exits `0`.
  - Stdout contains only the snapshot document. Diagnostics and optional `--json-output` logs go to stderr.
  - `--pretty` formats the document. `--timeout <seconds>` accepts `0...86400`, defaults to `30`, and uses `0` to disable the command deadline.
  - `--output <path>` atomically writes the snapshot to a file (`0644`) instead of stdout — staged in the destination directory, fsync'd, then renamed over the target so readers never observe a partial document. The parent directory must already exist (it is not created), and stdout stays silent on success.
  - Starts no HTTP server and requires no dashboard bearer token. See `docs/dashboard-api.md` for the shared payload contract.
- `agentbar serve` starts a foreground HTTP server for usage and cost JSON, a token-gated dashboard snapshot, and a built-in web UI at `/`.
  - Dashboard snapshot identity follows the app's "Hide personal information" setting when `--identity` is absent: the toggle on redacts email local parts, off keeps full emails. The setting is read per request, so a change applies without a serve restart. Pass `--identity redacted` or `--identity full` to pin the mode and ignore the app setting, especially when responses cross a network.
  - `--host <host>` accepts `localhost` or an IPv4 address and defaults to `127.0.0.1`; `localhost` is normalized to `127.0.0.1`. Binding a non-loopback host requires a dashboard token **and** `--allow-plain-http` (see `docs/dashboard-api.md` for the threat model).
  - `--port <port>` defaults to `8080`.
  - `--refresh-interval <seconds>` defaults to `60` and controls the in-memory response cache TTL.
  - `--request-timeout <seconds>` defaults to `30` and bounds each request before returning `504 Gateway Timeout`; use `0` to keep waiting indefinitely. Slow builds continue past the deadline, commit their finished result to the cache, and feed any same-config request already waiting so a 504 self-heals on retry.
  - `--dashboard-token <token>` sets the static bearer token for `GET /dashboard/v1/snapshot`. Prefer the `AGENTBAR_DASHBOARD_TOKEN` environment variable (it wins over the flag; a flag value leaks via `ps`). Empty or whitespace-only tokens are startup errors. Without a token the snapshot route fails closed with `401`.
  - On a **non-loopback** host the token gates **all data routes** — `/usage`, `/cost`, and `/dashboard/v1/snapshot` all require `Authorization: Bearer YOUR_TOKEN`, so account data is never exposed to the network unauthenticated. The static web UI at `/` and `/health` are always open. On the default loopback bind, `/usage` and `/cost` stay unauthenticated.
  - `--allow-plain-http` is the explicit acknowledgment that the bearer token crosses the network **in cleartext on every request** when serving on a non-loopback host. `serve` refuses to start on a non-loopback host without it.
  - Provider config is reloaded for each usage/cost request; cache entries are keyed by the loaded config so provider toggles and source changes do not require restarting `serve`.
  - Transient refresh failures fall back to the last good response for up to ten refresh intervals (minimum five minutes) so polling clients do not flicker between data and errors; disabled when `--refresh-interval 0`.
  - After a cached response expires, `serve` returns the last-good response immediately while rebuilding it in the background; `--refresh-interval 0` keeps every request blocking.
  - The default loopback bind rejects non-loopback `Host` headers; a configured non-loopback `--host` additionally accepts its own name. No CORS, TLS, or daemon mode.
  - Endpoints: `GET /` (web UI), `GET /health`, `GET /usage`, `GET /usage?provider=<id|both|all>`, `GET /cost`, `GET /cost?provider=<id|both|all>`, `GET /dashboard/v1/snapshot` (plus `provider=<id>` and `detail=<full|shell>`).
  - `GET /dashboard/v1/snapshot` requires `Authorization: Bearer YOUR_TOKEN`; responses (and all `401`s) carry `Cache-Control: no-store`. The token is never accepted via query string. See `docs/dashboard-api.md` for the payload contract.
  - `GET /health` returns `{"status":"ok"}` plus a `version` field with the running build (e.g. `"0.37.2"`) when resolvable; clients can compare it against `agentbar --version` to detect a `serve` process still running an older binary after an update.
  - Codex usage responses include every visible Codex account, matching the menu bar switcher.
- `agentbar cache clear` clears local AgentBar caches.
  - `--cookies` removes cached browser-cookie headers from the AgentBar Keychain cache.
  - `--cookies --provider <id>` removes browser-cookie cache entries for that provider, including managed Codex account scopes.
  - `--cost` removes local cost-usage scan caches.
  - `--all` clears both cookies and cost caches. `--provider` is cookie-only and cannot be combined with `--cost` or `--all`.
- `agentbar cookie refresh` ignores the provider's current cookie caches while importing a replacement through its web strategy. A failed or interrupted import leaves existing cookies intact.
  - Choose exactly one of `--provider <id>` or `--all`; provider support comes from shared browser-cookie metadata rather than a fixed CLI list.
  - Prompt-capable Chromium imports require `--allow-keychain-prompt`. Without it, the command fails before cache mutation with an interactive-retry hint.
  - A six-hour Keychain-denial cooldown is bypassed only by that explicit acknowledgment flag. Output never includes cookie values.
  - Providers configured for Manual or Off cookie sources are skipped.
- `agentbar guard --provider <id>` gates automation on one provider's remaining quota.
  - `--min-remaining <percent>` sets the inclusive threshold (default: `10`; valid range: `0...100`).
  - `--window session|weekly` selects the primary/session window or secondary/weekly window (default: `session`).
  - `--timeout <seconds>` bounds the complete fetch (range: `0...86400`; default: `60`; `0` disables this guard-level deadline while provider-specific timeouts still apply).
  - `--json` emits the provider, window, remaining quota, threshold, decision, unavailable reason, and exit code; add `--pretty` for formatted JSON.
  - Stable guard exit codes: `0` means safe, `1` means below threshold, `64` (`EX_USAGE`) means invalid arguments, and `69` (`EX_UNAVAILABLE`) means the quota could not be checked or the selected window is unavailable. `--fail-open` changes only unavailable results from `69` to `0`; JSON still reports `decision: "unknown"` and the reason.
  - Guard fetches are read-only and use background interaction policy, matching `agentbar usage`; they never request interactive Keychain access.
- `--provider <id|both|all>` (default: enabled providers in config; falls back to defaults when missing).
  - Provider IDs live in the config file (see `docs/configuration.md`).
  - With three or more providers enabled, the default stays scoped to enabled providers; use `--provider all` to query
    every registered provider.
  - `--account <label>` / `--account-index <n>` / `--all-accounts` (token accounts from config, or all visible Codex accounts for Codex; requires a single provider).
  - `--no-credits` (hide Codex credits in text output).
  - `--pretty` (pretty-print JSON).
  - `--status` (fetch provider status pages and include them in output).
  - `--antigravity-plan-debug` (debug: print Antigravity planInfo fields to stderr).
- `--source <auto|web|cli|oauth|api>` (default: `auto`).
    - `auto`: provider-specific fallback order from `docs/providers.md`.
    - `web`: web-only where that provider exposes an explicit web source; no CLI/API fallback. Browser import is macOS-only, while supported providers can use configured manual cookies on Linux.
    - `cli`: CLI/local-helper source where the provider exposes one (for example Codex RPC/PTy, Claude PTY, Kilo CLI fallback, Kiro CLI, local probes).
    - `oauth`: OAuth-backed source where supported (Codex, Claude, Vertex AI).
    - `api`: API-key/token flow when the provider supports it (OpenAI, Claude Admin API, z.ai, Gemini, Alibaba, Copilot, OpenCode Go, Kilo, Kimi, MiniMax, Ollama, Warp, OpenRouter, ElevenLabs, Deepgram, Synthetic, DeepSeek, DeepInfra, Moonshot, Doubao, Codebuff, Crof, Venice, AWS Bedrock).
    - Output `source` reflects the strategy actually used (`openai-web`, `web`, `oauth`, `api`, `local`, `cli`, or provider CLI label).
    - Codex web: OpenAI web dashboard (usage limits, credits remaining, code review remaining, usage breakdown).
        - `--web-timeout <seconds>` (default: 60)
        - `--web-debug-dump-html` (writes HTML snapshots to `/tmp` when data is missing)
    - Claude web: claude.ai API (session + weekly usage, account metadata, and prepaid Usage credits balance when
      available).
      CLI Auto falls back to the installed Claude executable when web credentials are unavailable. This foreground
      command delegates authentication to Claude Code; the app keeps its stricter prompt-free background availability
      gate for scheduled refreshes.
    - Command Code web: commandcode.ai browser session cookies on macOS, or a configured manual cookie on Linux, for monthly credit usage.
    - OpenCode Go auto: local SQLite cost history on macOS and Linux with API usage-window enrichment when
      `OPENCODE_API_KEY` is configured, plus legacy manual-cookie web fallback.
    - Kilo auto: app.kilo.ai API first, then CLI auth fallback (`~/.local/share/kilo/auth.json`) on missing/unauthorized API credentials.
    - Linux: browser-backed `auto`/`web` modes are not supported; local sources and configured manual-cookie paths remain available where documented.
- Global flags: `-h/--help`, `-V/--version`, `-v/--verbose`, `--no-color`, `--log-level <trace|verbose|debug|info|warning|error|critical>`, `--json-output`, `--json-only`.
  - `--json-output`: JSONL logs on stderr (machine-readable).
  - `--json-only`: suppress non-JSON output; errors become JSON payloads.
- `agentbar config validate` checks the resolved config file for invalid fields.
  - `--format text|json`, `--pretty`, and `--json-only` are supported.
  - Warnings keep exit code 0; errors exit non-zero.
- `agentbar config dump` prints the normalized config JSON.
- `agentbar hooks list` shows the local hook configuration; `--format json` and `--pretty` are supported.
- `agentbar hooks enable|disable` changes the explicit top-level opt-in switch in the local config file.
- `agentbar hooks test <event> --provider <id>` invokes matching enabled rules with a representative event. Hook
  commands run directly without a shell and receive `AGENTBAR_*` variables plus JSON on stdin. `--format json` and
  `--json-only` return structured per-rule results. See
  `docs/configuration.md#external-event-hooks` for the event, payload, timeout, and security contract.
- `agentbar hooks watch` polls enabled providers and fires matching hooks on real quota and status transitions.
  Without it, hook rules only ever fire from the macOS app, so a headless install can configure hooks that never run.
  - `--interval <seconds>`: poll period. Default `300`, minimum `60`; a smaller value is rejected rather than
    clamped, because each tick fetches every selected provider.
  - `--provider <id>`: restrict to one provider; repeatable. Defaults to every enabled provider.
  - `--format json`/`--json`/`--pretty`: emit each fired event as JSON.
  - Events are edge-triggered against the previous poll, so a condition that merely persists (a saturated window,
    an ongoing outage) does not re-fire every tick. State is in-memory only: a restart re-establishes baselines and
    the first poll of any lane fires nothing.
  - Run `watch` as one continuous process. Repeated one-shot invocations cannot preserve transition baselines or event
    rate limits between polls.
  - Runs read-only, like `agentbar guard`: it never prompts for credentials. A failed refresh reports
    `refresh_failed` with a coarse category (`timeout`, `offline`, `auth_required`, `network_error`) and never
    forwards the raw provider error.
  - Stops cleanly on `SIGINT`/`SIGTERM`/`SIGHUP`.

### Token accounts
The CLI reads multi-account tokens from the same resolved config file as the app.
- Select a specific account: `--account <label>` (matches the label/email in the file).
- Select by index (1-based): `--account-index <n>`.
- Fetch all accounts for the provider: `--all-accounts`.
Account selection flags require a single provider (`--provider claude`, etc.).
For Claude, token accounts accept either `sessionKey` cookies or OAuth access tokens (`sk-ant-oat...`).
OAuth usage requires the `user:profile` scope; inference-only tokens will return an error.

### Codex accounts
For Codex, `--all-accounts` and `agentbar serve` enumerate the same visible accounts as the app switcher:
managed Codex accounts from `managed-codex-accounts.json` plus the live system account when present.
Each fetch is scoped to that account's Codex home before the normal Codex web/OAuth/CLI strategy runs, and JSON
payloads include the visible account label in `account`.

### Cost JSON payload
`agentbar cost --format json` emits an array of payloads (one per provider).
- `provider`, `source` (`local` for Claude/Codex log scans, `web` for Cursor dashboard data), `updatedAt`
- `sessionTokens`, `sessionCostUSD`
- `last30DaysTokens`, `last30DaysCostUSD`
- `historyCoverageIsEstablished`: `true` when the displayed Codex history covers the requested window, including an established same-scope snapshot retained while a newer bounded scan catches up; `false` when only incomplete history is available.
- Cursor only: `meteredCostUSD` — what Cursor's plan actually deducts over the window, alongside the API-rate estimate in `last30DaysCostUSD`.
- `daily[]`: `date`, `inputTokens`, `outputTokens`, `cacheReadTokens`, `cacheCreationTokens`, `totalTokens`, `totalCost`, `modelsUsed`, `modelBreakdowns[]` (`modelName`, `cost`)
- Codex only: `projects[]`: `name`, `path`, `totalTokens`, `totalCost`, `daily[]`, `modelBreakdowns[]`, `sources[]`
- `totals`: `inputTokens`, `outputTokens`, `cacheReadTokens`, `cacheCreationTokens`, `totalTokens`, `totalCost`
- `error`: structured provider error when a fetch fails (for example Cursor requested while its cookie source is Off).

## Example usage
```
agentbar                          # text, respects app toggles
agentbar --provider claude        # force Claude
agentbar --provider all           # query all registered providers
agentbar --format json --pretty   # machine output
agentbar --format json --provider both
agentbar cost                     # cost usage (default 30-day window + today)
agentbar cost --days 90           # choose a 1...365 day cost window
agentbar cost --provider codex --group-by project
agentbar cost --provider codex --group-by session
agentbar cost --provider claude --format json --pretty
agentbar guard --provider codex --min-remaining 20 --window weekly --json
agentbar cost --provider cursor   # Cursor dashboard cost (API-rate + Cursor-metered)
agentbar dashboard | jq '.providers[] | {id, windows, error}'
agentbar serve --port 8080        # localhost HTTP JSON server
agentbar serve --request-timeout 0 # disable serve request deadlines
AGENTBAR_DASHBOARD_TOKEN=YOUR_TOKEN agentbar serve # token-gated dashboard snapshot
AGENTBAR_DASHBOARD_TOKEN=... agentbar serve --host 0.0.0.0 --allow-plain-http # LAN, cleartext accepted
COPILOT_API_TOKEN=... agentbar --provider copilot --format json --pretty
agentbar --status                 # include status page indicator/description
agentbar --provider codex --source oauth --format json --pretty
agentbar --provider codex --source web --format json --pretty
agentbar --provider codex --all-accounts --format json --pretty
agentbar --provider claude --account steipete@gmail.com
agentbar --provider claude --all-accounts --format json --pretty
agentbar --json-only --format json --pretty
agentbar --provider gemini --source api --format json --pretty
KILO_API_KEY=... agentbar --provider kilo --source api --format json --pretty
MOONSHOT_API_KEY=... agentbar --provider moonshot --source api --format json --pretty
agentbar config validate --format json --pretty
agentbar config dump --pretty
printf '%s' "$OPENAI_ADMIN_KEY" | agentbar config set-api-key --provider openai --stdin
agentbar config enable --provider grok
agentbar cache clear --cookies
agentbar cache clear --cookies --provider claude
agentbar cache clear --all --format json --pretty
agentbar cookie refresh --provider opencodego --allow-keychain-prompt
```

### Sample output (text)
```
== Codex 0.6.0 (codex-cli) ==
Session: 72% left [========----]
Pace: 12% in deficit | Expected 16% used | Projected empty in 2h 30m
Resets today at 2:15 PM
Weekly: 41% left [====--------]
Pace: 6% in reserve | Expected 47% used | Lasts until reset
Resets Fri at 9:00 AM
Credits: 112.4 left

== Claude Code 2.0.58 (web) ==
Session: 88% left [==========--]
Pace: On pace | Expected 13% used | Lasts until reset
Resets tomorrow at 1:00 AM
Weekly: 63% left [=======-----]
Pace: On pace | Expected 37% used | Runs out in 4d
Resets Sat at 6:00 AM
Sonnet: 95% left [===========-]
Account: user@example.com
Plan: Pro

== Kilo (cli) ==
Credits: 60% left [=======-----]
40/100 credits
Plan: Kilo Pass Pro
Activity: Auto top-up: visa
Note: Using CLI fallback
```

### Sample output (JSON, pretty)
```json
{
  "provider": "codex",
  "version": "0.6.0",
  "source": "openai-web",
  "status": { "indicator": "none", "description": "Operational", "updatedAt": "2025-12-04T17:55:00Z", "url": "https://status.openai.com/" },
  "usage": {
    "primary": { "usedPercent": 28, "windowMinutes": 300, "resetsAt": "2025-12-04T19:15:00Z" },
    "secondary": { "usedPercent": 59, "windowMinutes": 10080, "resetsAt": "2025-12-05T17:00:00Z" },
    "tertiary": null,
    "updatedAt": "2025-12-04T18:10:22Z",
    "identity": {
      "providerID": "codex",
      "accountEmail": "user@example.com",
      "accountOrganization": null,
      "loginMethod": "plus"
    },
    "accountEmail": "user@example.com",
    "accountOrganization": null,
    "loginMethod": "plus"
  },
  "pace": {
    "primary": { "stage": "ahead", "deltaPercent": 12, "expectedUsedPercent": 16, "willLastToReset": false, "etaSeconds": 9000, "summary": "12% in deficit | Expected 16% used | Projected empty in 2h 30m" },
    "secondary": { "stage": "slightlyBehind", "deltaPercent": -6, "expectedUsedPercent": 47, "willLastToReset": true, "summary": "6% in reserve | Expected 47% used | Lasts until reset" }
  },
  "credits": { "remaining": 112.4, "updatedAt": "2025-12-04T18:10:21Z" },
  "antigravityPlanInfo": null,
  "openaiDashboard": {
    "signedInEmail": "user@example.com",
    "codeReviewRemainingPercent": 100,
    "creditEvents": [
      { "id": "00000000-0000-0000-0000-000000000000", "date": "2025-12-04T00:00:00Z", "service": "CLI", "creditsUsed": 123.45 }
    ],
    "dailyBreakdown": [
      {
        "day": "2025-12-04",
        "services": [{ "service": "CLI", "creditsUsed": 123.45 }],
        "totalCreditsUsed": 123.45
      }
    ],
    "updatedAt": "2025-12-04T18:10:21Z"
  }
}
```

## Exit codes
- 0: success
- 2: provider missing (binary not on PATH)
- 3: parse/format error
- 4: CLI timeout
- 1: unexpected failure

For `agentbar dashboard`, `0` includes a valid partial snapshot whose provider rows contain errors. The command exits
non-zero only when it cannot produce a valid snapshot document.

## Notes
- CLI uses the config file for enabled providers, ordering, and secrets.
- CLI binary discovery checks explicit overrides, captured login PATH, inherited PATH, and known install paths before falling back to an interactive shell probe.
- Reset lines follow the in-app reset time display setting when available (default: countdown).
- Text output uses ANSI colors when stdout is a rich TTY; disable with `--no-color` or `NO_COLOR`/`TERM=dumb`.
- Copilot CLI queries require an API token via config `apiKey` or `COPILOT_API_TOKEN`.
- OpenAI API charts require an Admin API key for organization costs/usage. Normal API keys can only use the legacy balance fallback.
- Claude Admin API charts require an Anthropic Admin API key (`sk-ant-admin...` or `ANTHROPIC_ADMIN_KEY`).
- Codex CLI `auto` tries the OpenAI web dashboard, then Codex CLI RPC/PTy; the app’s Codex `auto` path prefers OAuth when credentials are present, then CLI.
- Claude CLI `auto` tries web, then CLI PTY; the app’s Claude `auto` path prefers OAuth, then CLI, then web.
- Kilo text output splits identity into `Plan:` and `Activity:` lines; in `--source auto`, resolved CLI fetches add
  `Note: Using CLI fallback`.
- Kilo auto-mode failures include a fallback-attempt summary line in text mode (API attempt then CLI attempt).
- OpenAI web requires a signed-in `chatgpt.com` session in a supported browser or a manual cookie header. No passwords are stored; AgentBar reuses cookies.
- Safari cookie import may require granting AgentBar Full Disk Access (System Settings → Privacy & Security → Full Disk Access).
- The `openaiDashboard` JSON field is normally sourced from the app’s cached dashboard snapshot; `--source auto|web` refreshes it live via WebKit using a per-account cookie store.
- Future: optional `--from-cache` flag to read the menubar app’s persisted snapshot (if/when that file lands).
