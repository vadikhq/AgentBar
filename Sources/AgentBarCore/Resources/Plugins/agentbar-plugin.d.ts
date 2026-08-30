type AgentBarJSONPrimitive = boolean | number | string | null;
type AgentBarJSONValue = AgentBarJSONPrimitive | AgentBarJSONValue[] | { [key: string]: AgentBarJSONValue };

type AgentBarEndpoint =
  | string
  | {
      setting: string;
      policy: "https" | "https-or-loopback-http" | "https-or-private-network-http";
    };

type AgentBarAuth =
  | { type: "bearer" | "x-api-key"; secret: string }
  | { type: "header"; header: string; secret: string }
  | { type: "authorization-scheme"; scheme: string; secret: string };

interface AgentBarSetting {
  key: string;
  title: string;
  subtitle?: string;
  type?: "plain" | "secure";
}

interface AgentBarRateWindow {
  usedPercent: number;
  windowMinutes?: number | null;
  resetsAt?: Date | string | null;
  resetDescription?: string | null;
  nextRegenPercent?: number | null;
}

type AgentBarNamedRateWindow = { id: string; title: string } & (AgentBarRateWindow | { window: AgentBarRateWindow });

interface AgentBarCostSnapshot {
  used: number;
  limit?: number | null;
  currency: string;
  period?: string | null;
  resetsAt?: Date | string | null;
  nextRegenAmount?: number | null;
  balance?: number | null;
}

interface AgentBarCostUsageEntry {
  date: string;
  inputTokens: number;
  outputTokens: number;
  reasoningTokens?: number | null;
  requests: number;
  cost: number;
  /** Portion of cost that is estimated rather than deducted by the provider. */
  estimatedCost?: number | null;
  model?: string | null;
}

interface AgentBarCostUsageSnapshot {
  currency: string;
  historyDays: number;
  historyLabel?: string | null;
  /** Inclusive YYYY-MM-DD end of the reported window. */
  windowEnd: string;
  entries: AgentBarCostUsageEntry[];
}

interface AgentBarIdentitySnapshot {
  email?: string | null;
  organization?: string | null;
  loginMethod?: string | null;
  accountID?: string | null;
}

interface AgentBarDetailRow {
  label: string;
  value: string;
  secondaryValue?: string | null;
}

interface AgentBarDetailChart {
  kind: "bars" | "line";
  title?: string | null;
  unit?: string | null;
  points: Array<{ label: string; value: number }>;
}

interface AgentBarDetailSection {
  title?: string | null;
  rows: AgentBarDetailRow[];
  chart?: AgentBarDetailChart | null;
}

interface AgentBarUsageSnapshot {
  /** At least one rate window, cost, non-empty detail section, or non-empty identity field is required. */
  primary?: AgentBarRateWindow | null;
  secondary?: AgentBarRateWindow | null;
  tertiary?: AgentBarRateWindow | null;
  extraWindows?: AgentBarNamedRateWindow[] | null;
  cost?: AgentBarCostSnapshot | null;
  /** Exact provider-reported daily spend. The host validates and sums every numeric row. */
  costUsage?: AgentBarCostUsageSnapshot | null;
  identity?: AgentBarIdentitySnapshot | null;
  subscriptionRenewsAt?: Date | string | null;
  subscriptionExpiresAt?: Date | string | null;
  dataConfidence?: "exact" | "estimated" | "percentOnly" | "unknown";
  details?: AgentBarDetailSection[] | null;
}

interface AgentBarHTTPRequestOptions {
  headers?: Readonly<Record<string, string>>;
  timeoutSeconds?: number;
}

interface AgentBarHTTPResponse {
  /** `http-status` exposes non-2xx responses so the plugin can take over classification from the host. */
  status: number;
  headers: Readonly<Record<string, string>>;
}

interface AgentBarHTTPJSONResponse<T = unknown> extends AgentBarHTTPResponse {
  json: T;
}

interface AgentBarHTTPTextResponse extends AgentBarHTTPResponse {
  bodyText: string;
}

interface AgentBarRetryOptions {
  /** Requests the same one delayed retry used automatically for transient HTTP statuses; the host clamps it to 10 seconds. */
  retryAfterSeconds: number;
}

interface AgentBarFailures {
  authenticationExpired(message: unknown): Error;
  missingCredential(message: unknown): Error;
  permissionDenied(message: unknown): Error;
  rateLimited(message: unknown, options?: AgentBarRetryOptions): Error;
  providerUnavailable(message: unknown, options?: AgentBarRetryOptions): Error;
  parseFailure(message: unknown): Error;
  networkFailure(message: unknown, options?: AgentBarRetryOptions): Error;
  apiFailure(message: unknown, options?: AgentBarRetryOptions): Error;
}

interface AgentBarPluginContext {
  readonly http: {
    getJSON<T = unknown>(url: string, options?: AgentBarHTTPRequestOptions): Promise<AgentBarHTTPJSONResponse<T>>;
    get(url: string, options?: AgentBarHTTPRequestOptions): Promise<AgentBarHTTPTextResponse>;
    postJSON<T = unknown>(
      url: string,
      options: AgentBarHTTPRequestOptions & { body: AgentBarJSONValue },
    ): Promise<AgentBarHTTPJSONResponse<T>>;
  };
  readonly settings: {
    get(key: string): string | null;
    getSecret(key: string): string | null;
  };
  readonly browser: {
    cookieHeader(domain: string): Promise<string>;
  };
  readonly html: {
    metaContent(html: string, name: string): string | null;
    matchFirst(html: string, regexSource: string, flags?: string): string | null;
  };
  readonly date: {
    now(): Date;
    iso(value: string): Date;
    unixSeconds(value: number): Date;
    unixMillis(value: number): Date;
    nextDailyReset(timeZone: string, hour: number): Date;
  };
  readonly format: {
    number(value: number, options?: { minimumFractionDigits?: number; maximumFractionDigits?: number }): string;
    usd(value: number): string;
    monthDay(value: Date | number | string): string;
  };
  readonly fail: Readonly<AgentBarFailures>;
  readonly env: {
    readonly timeZone: string;
  };
  readonly cache: {
    get<T = unknown>(key: string): T | undefined;
    set(key: string, value: unknown, ttlSeconds: number): void;
  };
  readonly jwt: {
    decode<T = unknown>(token: string): T;
  };
  log(...values: unknown[]): void;
  pct(used: number, limit: number): number;
  amountFromPercent(percent: number, limit: number): number;
}

interface AgentBarProviderDefinition {
  id: string;
  name: string;
  icon?: { monogram?: string; tint?: string };
  endpoints: AgentBarEndpoint[];
  auth?: AgentBarAuth;
  settings: AgentBarSetting[];
  /** Grants declared browser-cookie access or lets the plugin observe and classify non-2xx HTTP responses. */
  capabilities?: Array<"browser-cookies" | "http-status">;
  cookieDomains?: string[];
  fetchUsage(ctx: AgentBarPluginContext): AgentBarUsageSnapshot | Promise<AgentBarUsageSnapshot>;
}

declare function defineProvider(definition: AgentBarProviderDefinition): void;
