import type { SupabaseClient } from "@supabase/supabase-js";

export type PeriodAttemptsStats = {
  total: number;
  correct: number;
  accuracy: number | null;
  avg_duration_ms: number | null;
  skipped: number;
};

export type PeriodStats = {
  attempts: PeriodAttemptsStats;
  mistakes: {
    top_procedures: unknown[];
    top_steps: unknown[];
    top_error_modes: unknown[];
  };
  coverage: {
    subjects: unknown[];
    tags: unknown[];
  };
};

const EMPTY_STATS: PeriodStats = {
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

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null;
}

function asNumber(value: unknown, fallback = 0): number {
  if (typeof value === "number" && Number.isFinite(value)) return value;
  if (typeof value === "string") {
    const parsed = Number.parseFloat(value);
    if (Number.isFinite(parsed)) return parsed;
  }
  return fallback;
}

function asNullableNumber(value: unknown): number | null {
  if (value === null || value === undefined) return null;
  if (typeof value === "number" && Number.isFinite(value)) return value;
  if (typeof value === "string") {
    const parsed = Number.parseFloat(value);
    return Number.isFinite(parsed) ? parsed : null;
  }
  return null;
}

function asArray(value: unknown): unknown[] {
  return Array.isArray(value) ? value : [];
}

function normalizeStats(raw: unknown): PeriodStats {
  if (!isRecord(raw)) return { ...EMPTY_STATS };

  const attemptsRaw = isRecord(raw.attempts) ? raw.attempts : {};
  const mistakesRaw = isRecord(raw.mistakes) ? raw.mistakes : {};
  const coverageRaw = isRecord(raw.coverage) ? raw.coverage : {};

  return {
    attempts: {
      total: asNumber(attemptsRaw.total),
      correct: asNumber(attemptsRaw.correct),
      accuracy: asNullableNumber(attemptsRaw.accuracy),
      avg_duration_ms: asNullableNumber(attemptsRaw.avg_duration_ms),
      skipped: asNumber(attemptsRaw.skipped),
    },
    mistakes: {
      top_procedures: asArray(mistakesRaw.top_procedures),
      top_steps: asArray(mistakesRaw.top_steps),
      top_error_modes: asArray(mistakesRaw.top_error_modes),
    },
    coverage: {
      subjects: asArray(coverageRaw.subjects),
      tags: asArray(coverageRaw.tags),
    },
  };
}

export async function fetchPeriodStats(
  supabase: SupabaseClient,
  studentId: string,
  startIso: string,
  endIso: string,
): Promise<PeriodStats> {
  const { data, error } = await supabase.rpc("get_student_period_stats", {
    p_student_id: studentId,
    p_start: startIso,
    p_end: endIso,
  });

  if (error) throw new Error(error.message);
  return normalizeStats(data);
}

export function buildDelta(current: PeriodStats, previous: PeriodStats): Record<string, unknown> {
  const currentAttempts = current.attempts;
  const previousAttempts = previous.attempts;

  return {
    attempts: {
      total: currentAttempts.total - previousAttempts.total,
      correct: currentAttempts.correct - previousAttempts.correct,
      accuracy: asNullableNumber(
        currentAttempts.accuracy !== null && previousAttempts.accuracy !== null
          ? currentAttempts.accuracy - previousAttempts.accuracy
          : null,
      ),
      avg_duration_ms: asNullableNumber(
        currentAttempts.avg_duration_ms !== null && previousAttempts.avg_duration_ms !== null
          ? currentAttempts.avg_duration_ms - previousAttempts.avg_duration_ms
          : null,
      ),
      skipped: currentAttempts.skipped - previousAttempts.skipped,
    },
  };
}
