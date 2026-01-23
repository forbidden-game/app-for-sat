import type { Model } from "@mariozechner/pi-ai";
import type { SupabaseClient } from "@supabase/supabase-js";

import type { CoachConfig } from "../src/config.js";
import type { PeriodStats } from "../src/stats.js";

export const DAY_MS = 24 * 60 * 60 * 1000;

export type MockError = { message: string; code?: string };
export type MockResponse<T = unknown> = { data?: T | null; error?: MockError | null };

type QueryAction = "select" | "insert" | "update" | "upsert";

type MockState = {
  type: "rpc" | "from";
  name?: string;
  args?: Record<string, unknown>;
  table?: string;
  action?: QueryAction;
  terminalAction?: string;
  payload?: unknown;
  filters?: Array<{ column: string; value: unknown }>;
  select?: string | null;
  options?: unknown;
};

type HandlerValue =
  | MockResponse
  | MockResponse[]
  | ((state: MockState) => MockResponse | Promise<MockResponse>);

type SupabaseMockConfig = {
  rpc?: Record<string, HandlerValue>;
  from?: Record<string, Partial<Record<QueryAction, HandlerValue>>>;
};

type RpcCall = { name: string; args: Record<string, unknown> };

type FromCall = {
  table: string;
  action: QueryAction;
  terminalAction: string;
  payload?: unknown;
  filters: Array<{ column: string; value: unknown }>;
  select: string | null;
  options?: unknown;
};

export type SupabaseMockCalls = {
  rpc: RpcCall[];
  from: FromCall[];
};

export function mockError(message: string, code?: string): MockResponse<null> {
  return { data: null, error: { message, code } };
}

async function resolveHandler(
  value: HandlerValue | undefined,
  state: MockState,
): Promise<MockResponse> {
  if (!value) return { data: null, error: null };
  if (Array.isArray(value)) {
    const next = value.shift();
    return next ?? { data: null, error: null };
  }
  if (typeof value === "function") {
    return value(state);
  }
  return value;
}

export function createSupabaseMock(config: SupabaseMockConfig = {}): {
  supabase: SupabaseClient;
  calls: SupabaseMockCalls;
} {
  const calls: SupabaseMockCalls = { rpc: [], from: [] };

  const supabase = {
    rpc: async (name: string, args: Record<string, unknown>) => {
      calls.rpc.push({ name, args });
      return resolveHandler(config.rpc?.[name], { type: "rpc", name, args });
    },
    from: (table: string) => {
      const state: {
        baseAction?: QueryAction;
        payload?: unknown;
        select?: string | null;
        options?: unknown;
        filters: Array<{ column: string; value: unknown }>;
      } = {
        filters: [],
      };

      const run = async (terminalAction: string): Promise<MockResponse> => {
        const action = state.baseAction ?? "select";
        const response = await resolveHandler(config.from?.[table]?.[action], {
          type: "from",
          table,
          action,
          terminalAction,
          payload: state.payload,
          filters: state.filters,
          select: state.select ?? null,
          options: state.options,
        });
        calls.from.push({
          table,
          action,
          terminalAction,
          payload: state.payload,
          filters: [...state.filters],
          select: state.select ?? null,
          options: state.options,
        });
        return response;
      };

      const builder = {
        select: (columns: string) => {
          state.select = columns;
          if (!state.baseAction) state.baseAction = "select";
          return builder;
        },
        eq: (column: string, value: unknown) => {
          state.filters.push({ column, value });
          return builder;
        },
        lte: (column: string, value: unknown) => {
          state.filters.push({ column, value });
          return builder;
        },
        order: () => builder,
        limit: () => builder,
        insert: (payload: unknown) => {
          state.payload = payload;
          state.baseAction = "insert";
          return builder;
        },
        update: (payload: unknown) => {
          state.payload = payload;
          state.baseAction = "update";
          return builder;
        },
        upsert: (payload: unknown, options?: unknown) => {
          state.payload = payload;
          state.options = options;
          state.baseAction = "upsert";
          return run("upsert");
        },
        maybeSingle: () => run("maybeSingle"),
        single: () => run("single"),
        then: (
          onFulfilled: (value: MockResponse) => unknown,
          onRejected: (reason: unknown) => unknown,
        ) => run("execute").then(onFulfilled, onRejected),
      };

      return builder;
    },
  } satisfies Partial<SupabaseClient> as SupabaseClient;

  return { supabase, calls };
}

export function makeStats(overrides: Partial<PeriodStats> = {}): PeriodStats {
  const base: PeriodStats = {
    attempts: {
      total: 0,
      correct: 0,
      accuracy: null,
      avg_duration_ms: null,
      skipped: 0,
    },
    mistakes: {
      top_procedures: [],
      top_steps: [],
      top_error_modes: [],
    },
    coverage: {
      subjects: [],
      tags: [],
    },
  };

  return {
    attempts: { ...base.attempts, ...(overrides.attempts ?? {}) },
    mistakes: { ...base.mistakes, ...(overrides.mistakes ?? {}) },
    coverage: { ...base.coverage, ...(overrides.coverage ?? {}) },
  };
}

export type ReportPayload = {
  student_id: string;
  period_kind: "weekly" | "monthly" | string;
  period_key: string;
  period_start: string;
  period_end: string;
};

export function makeReportPayload(overrides: Partial<ReportPayload> = {}): ReportPayload {
  return {
    student_id: "student-1",
    period_kind: "weekly",
    period_key: "weekly-2025-01-08",
    period_start: "2025-01-01T00:00:00.000Z",
    period_end: "2025-01-08T00:00:00.000Z",
    ...overrides,
  };
}

export function makeConfig(overrides: Partial<CoachConfig> = {}): CoachConfig {
  return {
    supabaseUrl: "http://localhost:54321",
    supabaseServiceRoleKey: "service-role-key",
    workerId: "test-worker",
    pollIntervalMs: 1000,
    claimLimit: 1,
    minimaxApiKey: process.env.MINIMAX_API_KEY ?? "test-minimax-key",
    scheduleIntervalMs: 60_000,
    activeLookbackDays: 90,
    reportWeeklyDays: 7,
    reportMonthlyDays: 30,
    modelDefault: "minimax/MiniMax-M2.1",
    modelInsight: "minimax/MiniMax-M2.1",
    modelChat: "minimax/MiniMax-M2.1",
    modelReport: "minimax/MiniMax-M2.1",
    ...overrides,
  };
}

export function makeModel(overrides: Partial<Model<any>> = {}): Model<any> {
  return {
    id: "mock-model",
    name: "Mock Model",
    api: "openai-responses",
    provider: "mock-provider",
    baseUrl: "https://example.com",
    reasoning: false,
    input: ["text"],
    cost: {
      input: 0,
      output: 0,
      cacheRead: 0,
      cacheWrite: 0,
    },
    contextWindow: 1024,
    maxTokens: 512,
    ...overrides,
  };
}
