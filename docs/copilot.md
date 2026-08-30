---
summary: "Copilot provider data sources: GitHub device flow, Copilot internal usage API, and optional GitHub web budgets."
read_when:
  - Debugging Copilot login or usage parsing
  - Updating GitHub OAuth device flow behavior
---

# Copilot provider

Copilot uses GitHub OAuth device flow and the Copilot internal usage API for primary usage. Optional budget extras use GitHub web cookies only when enabled.

## Data sources + fallback order

1) **GitHub OAuth device flow** (user initiated)
   - Device code request:
     - `POST https://github.com/login/device/code`
   - Token polling:
     - `POST https://github.com/login/oauth/access_token`
   - Optional enterprise host:
     - set Copilot `enterpriseHost` in `~/.agentbar/config.json` or the provider settings UI
     - AgentBar normalizes values such as `https://octocorp.ghe.com/login` to `octocorp.ghe.com`
     - device flow uses `https://<enterpriseHost>/login/...`
   - Scope: `read:user`.
   - Token stored in config:
     - `~/.agentbar/config.json` → `providers[].apiKey` for `copilot`
     - token accounts use `providers[].tokenAccounts`

2) **Usage fetch**
   - `GET https://api.github.com/copilot_internal/user`
   - With an enterprise host, the API host is `api.<enterpriseHost>`.
   - Headers:
     - `Authorization: token <github_oauth_token>`
     - `Accept: application/json`
     - `Editor-Version: vscode/1.96.2`
     - `Editor-Plugin-Version: copilot-chat/0.26.7`
     - `User-Agent: GitHubCopilotChat/0.26.7`
     - `X-Github-Api-Version: 2025-04-01`

3) **Budget fetch** (optional GitHub web endpoint, best-effort)
   - Disabled by default. The Copilot provider's "Budget extras" setting must be enabled before AgentBar imports
     github.com cookies or renders budget bars.
   - AgentBar asks the logged-in GitHub web endpoint for customer-scope budgets:
     - `GET https://github.com/settings/billing/budgets?page=<page>&page_size=10&scope=customer`
   - Headers:
     - `Cookie: <github.com browser cookies>`
     - `Accept: application/json`
     - `X-Requested-With: XMLHttpRequest`
     - `GitHub-Verified-Fetch: true`
     - `X-Fetch-Nonce: <fresh nonce when available>`
   - AgentBar first tries to read a fresh nonce from `https://github.com/settings/billing/budgets`, then calls the JSON
     endpoint. If GitHub rejects the web request, AgentBar keeps the normal Copilot quota bars and omits budget bars.
   - This is intentionally not the public GitHub REST billing API. The REST API did not expose the personal budget list
     for the tested individual account.

## Snapshot mapping
- Primary: `quotaSnapshots.premiumInteractions` percent remaining → used percent.
- Secondary: `quotaSnapshots.chat` percent remaining → used percent.
- Extra: positive Copilot billing budgets from the GitHub web endpoint → `extraRateWindows`, only when "Budget extras"
  is enabled.
  - Product budget: `copilot`
  - SKU budgets: `copilot_premium_request`, `copilot_agent_premium_request`, `spark_premium_request`
- Reset dates are not provided by the API.
- Plan label from `copilotPlan`.

## Key files
- `Sources/AgentBarCore/Providers/Copilot/CopilotUsageFetcher.swift`
- `Sources/AgentBarCore/Providers/Copilot/CopilotDeviceFlow.swift`
- `Sources/AgentBar/Providers/Copilot/CopilotLoginFlow.swift`
- `Sources/AgentBar/CopilotTokenStore.swift` (legacy migration helper)
