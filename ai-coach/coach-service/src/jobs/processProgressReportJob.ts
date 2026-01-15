import type { Model } from "@mariozechner/pi-ai";
import { completeSimple, getEnvApiKey } from "@mariozechner/pi-ai";
import type { SupabaseClient } from "@supabase/supabase-js";

import type { CoachConfig } from "../config.js";
import { logger } from "../logger.js";
import { getProviderApiKey } from "../providerKeys.js";
import { buildProgressReportPrompt } from "../prompts/progressReportPrompt.js";
import type { PeriodStats } from "../stats.js";
import { buildDelta, fetchPeriodStats } from "../stats.js";

const DAY_MS = 24 * 60 * 60 * 1000;

type ReportPayload = {
  student_id?: string;
  period_kind?: "weekly" | "monthly";
  period_key?: string;
  period_start?: string;
  period_end?: string;
};

type ReportOutput = {
  summary: string;
  plan: {
    focus_areas: Array<{ topic: string; reason: string }>;
    next_steps: Array<{ action: string; why: string }>;
    pace: string;
  };
};

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null;
}

function extractText(message: { content: Array<{ type: string; text?: string }> }): string {
  return message.content
    .filter((block) => block.type === "text")
    .map((block) => block.text ?? "")
    .join("")
    .trim();
}

function extractJson(text: string): unknown | null {
  const trimmed = text.trim();
  if (!trimmed) return null;

  const fenced = trimmed.match(/```json\s*([\s\S]*?)```/i);
  if (fenced && fenced[1]) {
    try {
      return JSON.parse(fenced[1].trim());
    } catch {
      return null;
    }
  }

  const first = trimmed.indexOf("{");
  const last = trimmed.lastIndexOf("}");
  if (first >= 0 && last > first) {
    try {
      return JSON.parse(trimmed.slice(first, last + 1));
    } catch {
      return null;
    }
  }

  try {
    return JSON.parse(trimmed);
  } catch {
    return null;
  }
}

function normalizeReportOutput(raw: unknown): ReportOutput | null {
  if (!isRecord(raw)) return null;
  if (typeof raw.summary !== "string" || !isRecord(raw.plan)) return null;

  const plan = raw.plan as Record<string, unknown>;
  const focus = Array.isArray(plan.focus_areas) ? plan.focus_areas : [];
  const steps = Array.isArray(plan.next_steps) ? plan.next_steps : [];

  return {
    summary: raw.summary.trim(),
    plan: {
      focus_areas: focus
        .filter(isRecord)
        .map((item) => ({
          topic: typeof item.topic === "string" ? item.topic : "",
          reason: typeof item.reason === "string" ? item.reason : "",
        }))
        .filter((item) => item.topic.length > 0),
      next_steps: steps
        .filter(isRecord)
        .map((item) => ({
          action: typeof item.action === "string" ? item.action : "",
          why: typeof item.why === "string" ? item.why : "",
        }))
        .filter((item) => item.action.length > 0),
      pace: typeof plan.pace === "string" ? plan.pace : "",
    },
  };
}

function fallbackReport(current: PeriodStats, periodKind: "weekly" | "monthly"): ReportOutput {
  const attempts = current.attempts;
  const accuracy = attempts.accuracy !== null ? `${Math.round(attempts.accuracy * 100)}%` : "暂无";
  const summary = `本${periodKind === "weekly" ? "周" : "月"}共完成 ${attempts.total} 题，正确率 ${accuracy}。接下来聚焦错题步骤与基础巩固。`;

  return {
    summary,
    plan: {
      focus_areas: [{ topic: "错题步骤回顾", reason: "提升关键步骤稳定性" }],
      next_steps: [{ action: "复盘最近错题并写出正确步骤", why: "减少重复失误" }],
      pace: "每次练习后用 5-10 分钟复盘错题。",
    },
  };
}

export async function processProgressReportJob(
  supabase: SupabaseClient,
  config: CoachConfig,
  model: Model<any>,
  payload: ReportPayload,
  systemPrompt: string = "你是严格、精要的 SAT 一对一老师，只输出 JSON。",
  promptVersion: string = "ai-coach-report-v1",
): Promise<void> {
  const studentId = payload.student_id;
  const periodKind = payload.period_kind === "monthly" ? "monthly" : "weekly";
  const periodKey = payload.period_key;
  const periodStart = payload.period_start;
  const periodEnd = payload.period_end;

  if (!studentId || !periodKey || !periodStart || !periodEnd) {
    throw new Error("missing_report_payload");
  }

  const startMs = Date.parse(periodStart);
  const endMs = Date.parse(periodEnd);
  if (!Number.isFinite(startMs) || !Number.isFinite(endMs) || endMs <= startMs) {
    throw new Error("invalid_report_period");
  }

  const { data: existing, error: existingError } = await supabase
    .from("student_reports")
    .select("id")
    .eq("student_id", studentId)
    .eq("period_key", periodKey)
    .maybeSingle();

  if (existingError) throw new Error(existingError.message);
  if (existing?.id) {
    logger.info({ studentId, periodKey }, "report already exists, skipping");
    return;
  }

  const currentStats = await fetchPeriodStats(supabase, studentId, periodStart, periodEnd);
  const periodLengthDays = Math.max(1, Math.round((endMs - startMs) / DAY_MS));
  const prevEnd = new Date(startMs);
  const prevStart = new Date(prevEnd.getTime() - periodLengthDays * DAY_MS);

  const previousStats = await fetchPeriodStats(
    supabase,
    studentId,
    prevStart.toISOString(),
    prevEnd.toISOString(),
  );

  const delta = buildDelta(currentStats, previousStats);

  const prompt = buildProgressReportPrompt({
    studentId,
    periodKind,
    periodStart,
    periodEnd,
    metrics: currentStats,
    delta,
  });

  let output: ReportOutput | null = null;
  let costUsd: number | null = null;
  try {
    const apiKey =
      model.provider === "minimax"
        ? config.minimaxApiKey
        : (await getProviderApiKey(supabase, model.provider)) ?? getEnvApiKey(model.provider);
    const response = await completeSimple(
      model,
      {
        systemPrompt,
        messages: [{ role: "user", content: prompt, timestamp: Date.now() }],
      },
      apiKey ? { apiKey } : undefined,
    );

    costUsd = response.usage?.cost?.total ?? null;
    const text = extractText(response);
    output = normalizeReportOutput(extractJson(text));
  } catch (err) {
    logger.warn({ err, studentId, periodKey }, "report generation failed, using fallback");
  }

  if (!output || output.summary.length === 0) {
    output = fallbackReport(currentStats, periodKind);
  }

  const { data: reportRow, error: insertError } = await supabase
    .from("student_reports")
    .insert({
      student_id: studentId,
      period_kind: periodKind,
      period_key: periodKey,
      period_start: periodStart,
      period_end: periodEnd,
      metrics: currentStats,
      delta,
      summary: output.summary,
      plan: output.plan,
      model: model.id,
      prompt_version: promptVersion,
      cost_usd: costUsd,
    })
    .select("id")
    .single();

  if (insertError) {
    if (insertError.code === "23505") {
      logger.info({ studentId, periodKey }, "report already inserted (duplicate)");
      return;
    }
    throw new Error(insertError.message);
  }

  const { error: notifyError } = await supabase.from("notification_events").insert({
    student_id: studentId,
    event_type: "progress_report_ready",
    payload: {
      student_id: studentId,
      report_id: reportRow?.id ?? null,
      period_kind: periodKind,
      period_start: periodStart,
      period_end: periodEnd,
    },
    status: "queued",
  });

  if (notifyError) {
    logger.warn({ err: notifyError, studentId }, "failed to enqueue report notification");
  }
}
