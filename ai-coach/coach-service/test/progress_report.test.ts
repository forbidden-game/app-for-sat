import { describe, expect, it } from "vitest";

import { processProgressReportJob } from "../src/jobs/processProgressReportJob.js";
import { resolveModel } from "../src/model.js";
import {
  DAY_MS,
  createSupabaseMock,
  makeConfig,
  makeModel,
  makeReportPayload,
  makeStats,
  mockError,
} from "./helpers.js";

describe("processProgressReportJob", () => {
  const basePayload = makeReportPayload();
  const config = makeConfig();

  it("throws when student_id is missing", async () => {
    const { supabase } = createSupabaseMock();
    const model = makeModel();

    await expect(
      processProgressReportJob(supabase, config, model, { ...basePayload, student_id: undefined }),
    ).rejects.toThrow(/missing_report_payload/);
  });

  it("throws when period_key is missing", async () => {
    const { supabase } = createSupabaseMock();
    const model = makeModel();

    await expect(
      processProgressReportJob(supabase, config, model, { ...basePayload, period_key: undefined }),
    ).rejects.toThrow(/missing_report_payload/);
  });

  it("throws when period_start is missing", async () => {
    const { supabase } = createSupabaseMock();
    const model = makeModel();

    await expect(
      processProgressReportJob(supabase, config, model, {
        ...basePayload,
        period_start: undefined,
      }),
    ).rejects.toThrow(/missing_report_payload/);
  });

  it("throws when period_end is missing", async () => {
    const { supabase } = createSupabaseMock();
    const model = makeModel();

    await expect(
      processProgressReportJob(supabase, config, model, { ...basePayload, period_end: undefined }),
    ).rejects.toThrow(/missing_report_payload/);
  });

  it("throws when period end is not after start", async () => {
    const { supabase } = createSupabaseMock();
    const model = makeModel();

    await expect(
      processProgressReportJob(supabase, config, model, {
        ...basePayload,
        period_start: "2025-01-08T00:00:00.000Z",
        period_end: "2025-01-08T00:00:00.000Z",
      }),
    ).rejects.toThrow(/invalid_report_period/);
  });

  it("throws when period dates are invalid", async () => {
    const { supabase } = createSupabaseMock();
    const model = makeModel();

    await expect(
      processProgressReportJob(supabase, config, model, {
        ...basePayload,
        period_start: "not-a-date",
        period_end: "still-not-a-date",
      }),
    ).rejects.toThrow(/invalid_report_period/);
  });

  it("skips when report already exists", async () => {
    const { supabase } = createSupabaseMock({
      from: {
        student_reports: {
          select: [{ data: { id: "report-1" }, error: null }],
        },
      },
    });
    const model = makeModel();

    await processProgressReportJob(supabase, config, model, basePayload);
  });

  it("calls period stats for current and previous", async () => {
    const current = makeStats({ attempts: { total: 5, correct: 3 } });
    const previous = makeStats({ attempts: { total: 4, correct: 2 } });
    const { supabase, calls } = createSupabaseMock({
      rpc: {
        get_student_period_stats: [{ data: current }, { data: previous }],
      },
      from: {
        student_reports: {
          select: [{ data: null, error: null }],
          insert: [{ data: { id: "report-2" }, error: null }],
        },
        notification_events: {
          insert: [{ data: null, error: null }],
        },
      },
    });
    const model = makeModel();

    await processProgressReportJob(supabase, config, model, basePayload);

    expect(calls.rpc).toHaveLength(2);
    expect(calls.rpc[0]?.name).toBe("get_student_period_stats");
    expect(calls.rpc[1]?.name).toBe("get_student_period_stats");
  });

  it("stores metrics and delta payload", async () => {
    const current = makeStats({ attempts: { total: 5, correct: 3, accuracy: 0.6 } });
    const previous = makeStats({ attempts: { total: 4, correct: 2, accuracy: 0.5 } });
    const { supabase, calls } = createSupabaseMock({
      rpc: {
        get_student_period_stats: [{ data: current }, { data: previous }],
      },
      from: {
        student_reports: {
          select: [{ data: null, error: null }],
          insert: [{ data: { id: "report-3" }, error: null }],
        },
        notification_events: {
          insert: [{ data: null, error: null }],
        },
      },
    });
    const model = makeModel();

    await processProgressReportJob(supabase, config, model, basePayload);

    const payload = calls.from.find(
      (call) => call.table === "student_reports" && call.action === "insert",
    )?.payload as Record<string, unknown>;
    expect(payload.metrics).toEqual(current);
    const delta = payload.delta as Record<string, any>;
    expect(delta.attempts.total).toBe(1);
    expect(delta.attempts.correct).toBe(1);
    expect(delta.attempts.accuracy).toBeCloseTo(0.1, 6);
    expect(delta.attempts.avg_duration_ms).toBeNull();
    expect(delta.attempts.skipped).toBe(0);
  });

  it("stores summary and plan", async () => {
    const current = makeStats({ attempts: { total: 5, correct: 3 } });
    const previous = makeStats({ attempts: { total: 4, correct: 2 } });
    const { supabase, calls } = createSupabaseMock({
      rpc: {
        get_student_period_stats: [{ data: current }, { data: previous }],
      },
      from: {
        student_reports: {
          select: [{ data: null, error: null }],
          insert: [{ data: { id: "report-4" }, error: null }],
        },
        notification_events: {
          insert: [{ data: null, error: null }],
        },
      },
    });
    const model = makeModel({ provider: "mock" });

    await processProgressReportJob(supabase, config, model, basePayload);

    const payload = calls.from.find(
      (call) => call.table === "student_reports" && call.action === "insert",
    )?.payload as Record<string, unknown>;
    expect(typeof payload.summary).toBe("string");
    expect(payload.plan).toBeTruthy();
  });

  it("sends notification after insert", async () => {
    const current = makeStats({ attempts: { total: 5, correct: 3 } });
    const previous = makeStats({ attempts: { total: 4, correct: 2 } });
    const { supabase, calls } = createSupabaseMock({
      rpc: {
        get_student_period_stats: [{ data: current }, { data: previous }],
      },
      from: {
        student_reports: {
          select: [{ data: null, error: null }],
          insert: [{ data: { id: "report-5" }, error: null }],
        },
        notification_events: {
          insert: [{ data: null, error: null }],
        },
      },
    });
    const model = makeModel();

    await processProgressReportJob(supabase, config, model, basePayload);

    const notify = calls.from.find(
      (call) => call.table === "notification_events" && call.action === "insert",
    )?.payload as Record<string, unknown>;
    expect(notify.event_type).toBe("progress_report_ready");
  });

  it("uses fallback report when LLM output invalid", async () => {
    const current = makeStats({ attempts: { total: 2, correct: 1, accuracy: 0.5 } });
    const previous = makeStats({ attempts: { total: 1, correct: 1, accuracy: 1 } });
    const { supabase, calls } = createSupabaseMock({
      rpc: {
        get_student_period_stats: [{ data: current }, { data: previous }],
      },
      from: {
        student_reports: {
          select: [{ data: null, error: null }],
          insert: [{ data: { id: "report-6" }, error: null }],
        },
        notification_events: {
          insert: [{ data: null, error: null }],
        },
      },
    });
    const model = makeModel({ provider: "mock" });

    await processProgressReportJob(supabase, config, model, basePayload);

    const payload = calls.from.find(
      (call) => call.table === "student_reports" && call.action === "insert",
    )?.payload as Record<string, unknown>;
    expect((payload.summary as string).length).toBeGreaterThan(0);
  });

  it("handles duplicate report insert", async () => {
    const current = makeStats();
    const previous = makeStats();
    const { supabase } = createSupabaseMock({
      rpc: {
        get_student_period_stats: [{ data: current }, { data: previous }],
      },
      from: {
        student_reports: {
          select: [{ data: null, error: null }],
          insert: [mockError("duplicate", "23505")],
        },
      },
    });
    const model = makeModel();

    await processProgressReportJob(supabase, config, model, basePayload);
  });

  it("throws when stats rpc fails", async () => {
    const { supabase } = createSupabaseMock({
      rpc: {
        get_student_period_stats: [mockError("stats_failed")],
      },
    });
    const model = makeModel();

    await expect(processProgressReportJob(supabase, config, model, basePayload)).rejects.toThrow(
      /stats_failed/,
    );
  });

  it("throws when insert fails", async () => {
    const current = makeStats();
    const previous = makeStats();
    const { supabase } = createSupabaseMock({
      rpc: {
        get_student_period_stats: [{ data: current }, { data: previous }],
      },
      from: {
        student_reports: {
          select: [{ data: null, error: null }],
          insert: [mockError("insert_failed")],
        },
      },
    });
    const model = makeModel();

    await expect(processProgressReportJob(supabase, config, model, basePayload)).rejects.toThrow(
      /insert_failed/,
    );
  });

  it("defaults to weekly when period_kind is unknown", async () => {
    const current = makeStats();
    const previous = makeStats();
    const payload = makeReportPayload({ period_kind: "daily" });
    const { supabase, calls } = createSupabaseMock({
      rpc: {
        get_student_period_stats: [{ data: current }, { data: previous }],
      },
      from: {
        student_reports: {
          select: [{ data: null, error: null }],
          insert: [{ data: { id: "report-7" }, error: null }],
        },
        notification_events: {
          insert: [{ data: null, error: null }],
        },
      },
    });
    const model = makeModel();

    await processProgressReportJob(supabase, config, model, payload);

    const insertPayload = calls.from.find(
      (call) => call.table === "student_reports" && call.action === "insert",
    )?.payload as Record<string, unknown>;
    expect(insertPayload.period_kind).toBe("weekly");
  });

  it("uses monthly period_kind when provided", async () => {
    const current = makeStats();
    const previous = makeStats();
    const payload = makeReportPayload({ period_kind: "monthly" });
    const { supabase, calls } = createSupabaseMock({
      rpc: {
        get_student_period_stats: [{ data: current }, { data: previous }],
      },
      from: {
        student_reports: {
          select: [{ data: null, error: null }],
          insert: [{ data: { id: "report-8" }, error: null }],
        },
        notification_events: {
          insert: [{ data: null, error: null }],
        },
      },
    });
    const model = makeModel();

    await processProgressReportJob(supabase, config, model, payload);

    const insertPayload = calls.from.find(
      (call) => call.table === "student_reports" && call.action === "insert",
    )?.payload as Record<string, unknown>;
    expect(insertPayload.period_kind).toBe("monthly");
  });

  it("handles null accuracy delta", async () => {
    const current = makeStats({ attempts: { total: 0, correct: 0, accuracy: null } });
    const previous = makeStats({ attempts: { total: 0, correct: 0, accuracy: null } });
    const { supabase, calls } = createSupabaseMock({
      rpc: {
        get_student_period_stats: [{ data: current }, { data: previous }],
      },
      from: {
        student_reports: {
          select: [{ data: null, error: null }],
          insert: [{ data: { id: "report-9" }, error: null }],
        },
        notification_events: {
          insert: [{ data: null, error: null }],
        },
      },
    });
    const model = makeModel();

    await processProgressReportJob(supabase, config, model, basePayload);

    const insertPayload = calls.from.find(
      (call) => call.table === "student_reports" && call.action === "insert",
    )?.payload as Record<string, unknown>;
    const delta = insertPayload.delta as Record<string, any>;
    expect(delta.attempts.accuracy).toBeNull();
  });

  it("computes previous period range by payload length", async () => {
    const current = makeStats();
    const previous = makeStats();
    const payload = makeReportPayload({
      period_start: "2025-01-01T00:00:00.000Z",
      period_end: "2025-01-11T00:00:00.000Z",
    });
    const { supabase, calls } = createSupabaseMock({
      rpc: {
        get_student_period_stats: [{ data: current }, { data: previous }],
      },
      from: {
        student_reports: {
          select: [{ data: null, error: null }],
          insert: [{ data: { id: "report-10" }, error: null }],
        },
        notification_events: {
          insert: [{ data: null, error: null }],
        },
      },
    });
    const model = makeModel();

    await processProgressReportJob(supabase, config, model, payload);

    expect(calls.rpc[1]?.args.p_end).toBe(payload.period_start);
    const expectedPrevStart = new Date(
      Date.parse(payload.period_start) - 10 * DAY_MS,
    ).toISOString();
    expect(calls.rpc[1]?.args.p_start).toBe(expectedPrevStart);
  });

  it("uses report insert id for notification payload", async () => {
    const current = makeStats();
    const previous = makeStats();
    const { supabase, calls } = createSupabaseMock({
      rpc: {
        get_student_period_stats: [{ data: current }, { data: previous }],
      },
      from: {
        student_reports: {
          select: [{ data: null, error: null }],
          insert: [{ data: { id: "report-id" }, error: null }],
        },
        notification_events: {
          insert: [{ data: null, error: null }],
        },
      },
    });
    const model = makeModel();

    await processProgressReportJob(supabase, config, model, basePayload);

    const notify = calls.from.find(
      (call) => call.table === "notification_events" && call.action === "insert",
    )?.payload as Record<string, unknown>;
    const payload = notify.payload as Record<string, unknown>;
    expect(payload.report_id).toBe("report-id");
  });

  it("handles notification insert failure", async () => {
    const current = makeStats();
    const previous = makeStats();
    const { supabase } = createSupabaseMock({
      rpc: {
        get_student_period_stats: [{ data: current }, { data: previous }],
      },
      from: {
        student_reports: {
          select: [{ data: null, error: null }],
          insert: [{ data: { id: "report-id" }, error: null }],
        },
        notification_events: {
          insert: [mockError("notify_failed")],
        },
      },
    });
    const model = makeModel();

    await processProgressReportJob(supabase, config, model, basePayload);
  });

  it("falls back to report when LLM throws", async () => {
    const current = makeStats();
    const previous = makeStats();
    const { supabase, calls } = createSupabaseMock({
      rpc: {
        get_student_period_stats: [{ data: current }, { data: previous }],
      },
      from: {
        student_reports: {
          select: [{ data: null, error: null }],
          insert: [{ data: { id: "report-id" }, error: null }],
        },
        notification_events: {
          insert: [{ data: null, error: null }],
        },
      },
    });
    const model = makeModel({ provider: "mock" });

    await processProgressReportJob(supabase, config, model, basePayload);

    const insertPayload = calls.from.find(
      (call) => call.table === "student_reports" && call.action === "insert",
    )?.payload as Record<string, unknown>;
    expect((insertPayload.summary as string).length).toBeGreaterThan(0);
  });

  const minimaxKey = process.env.MINIMAX_API_KEY;
  if (!minimaxKey) {
    it.skip("requires MINIMAX_API_KEY for LLM integration tests", () => {});
    return;
  }

  it(
    "minimax integration: generates non-empty summary and plan (weekly)",
    { timeout: 120_000 },
    async () => {
      const current = makeStats({ attempts: { total: 10, correct: 6, accuracy: 0.6 } });
      const previous = makeStats({ attempts: { total: 8, correct: 4, accuracy: 0.5 } });
      const payload = makeReportPayload({
        period_key: `weekly-${Date.now()}`,
      });
      const { supabase, calls } = createSupabaseMock({
        rpc: {
          get_student_period_stats: [{ data: current }, { data: previous }],
        },
        from: {
          student_reports: {
            select: [{ data: null, error: null }],
            insert: [{ data: { id: "report-live-1" }, error: null }],
          },
          notification_events: {
            insert: [{ data: null, error: null }],
          },
        },
      });
      const liveConfig = makeConfig({ minimaxApiKey: minimaxKey ?? "" });
      const model = resolveModel(liveConfig.modelReport, "minimax");

      await processProgressReportJob(supabase, liveConfig, model, payload);

      const insertPayload = calls.from.find(
        (call) => call.table === "student_reports" && call.action === "insert",
      )?.payload as Record<string, unknown>;
      const summary = (insertPayload.summary as string | undefined)?.trim() ?? "";
      const plan = insertPayload.plan as Record<string, unknown>;
      const focus = Array.isArray(plan?.focus_areas) ? plan.focus_areas : [];
      const steps = Array.isArray(plan?.next_steps) ? plan.next_steps : [];
      const pace = typeof plan?.pace === "string" ? plan.pace.trim() : "";

      expect(summary.length).toBeGreaterThan(0);
      expect(focus.length + steps.length > 0 || pace.length > 0).toBe(true);
    },
  );

  it(
    "minimax integration: generates non-empty summary and plan (monthly)",
    { timeout: 120_000 },
    async () => {
      const current = makeStats({ attempts: { total: 18, correct: 12, accuracy: 0.67 } });
      const previous = makeStats({ attempts: { total: 15, correct: 9, accuracy: 0.6 } });
      const payload = makeReportPayload({
        period_kind: "monthly",
        period_key: `monthly-${Date.now()}`,
      });
      const { supabase, calls } = createSupabaseMock({
        rpc: {
          get_student_period_stats: [{ data: current }, { data: previous }],
        },
        from: {
          student_reports: {
            select: [{ data: null, error: null }],
            insert: [{ data: { id: "report-live-2" }, error: null }],
          },
          notification_events: {
            insert: [{ data: null, error: null }],
          },
        },
      });
      const liveConfig = makeConfig({ minimaxApiKey: minimaxKey ?? "" });
      const model = resolveModel(liveConfig.modelReport, "minimax");

      await processProgressReportJob(supabase, liveConfig, model, payload);

      const insertPayload = calls.from.find(
        (call) => call.table === "student_reports" && call.action === "insert",
      )?.payload as Record<string, unknown>;
      const summary = (insertPayload.summary as string | undefined)?.trim() ?? "";
      const plan = insertPayload.plan as Record<string, unknown>;
      const focus = Array.isArray(plan?.focus_areas) ? plan.focus_areas : [];
      const steps = Array.isArray(plan?.next_steps) ? plan.next_steps : [];
      const pace = typeof plan?.pace === "string" ? plan.pace.trim() : "";

      expect(summary.length).toBeGreaterThan(0);
      expect(focus.length + steps.length > 0 || pace.length > 0).toBe(true);
    },
  );

  it("stores model id in report", async () => {
    const current = makeStats();
    const previous = makeStats();
    const { supabase, calls } = createSupabaseMock({
      rpc: {
        get_student_period_stats: [{ data: current }, { data: previous }],
      },
      from: {
        student_reports: {
          select: [{ data: null, error: null }],
          insert: [{ data: { id: "report-11" }, error: null }],
        },
        notification_events: {
          insert: [{ data: null, error: null }],
        },
      },
    });
    const model = makeModel({ id: "report-model" });

    await processProgressReportJob(supabase, config, model, basePayload);

    const payload = calls.from.find(
      (call) => call.table === "student_reports" && call.action === "insert",
    )?.payload as Record<string, unknown>;
    expect(payload.model).toBe("report-model");
  });

  it("writes prompt_version", async () => {
    const current = makeStats();
    const previous = makeStats();
    const { supabase, calls } = createSupabaseMock({
      rpc: {
        get_student_period_stats: [{ data: current }, { data: previous }],
      },
      from: {
        student_reports: {
          select: [{ data: null, error: null }],
          insert: [{ data: { id: "report-12" }, error: null }],
        },
        notification_events: {
          insert: [{ data: null, error: null }],
        },
      },
    });
    const model = makeModel();

    await processProgressReportJob(supabase, config, model, basePayload);

    const payload = calls.from.find(
      (call) => call.table === "student_reports" && call.action === "insert",
    )?.payload as Record<string, unknown>;
    expect(payload.prompt_version).toBe("ai-coach-report-v1");
  });
});
