import { describe, expect, it } from "vitest";

import { processSnapshotRefreshJob } from "../src/jobs/processSnapshotRefreshJob.js";
import { DAY_MS, createSupabaseMock, makeStats, mockError } from "./helpers.js";

describe("processSnapshotRefreshJob", () => {
  const studentId = "student-1";

  const setup = (stats7 = makeStats(), stats30 = makeStats(), stats90 = makeStats()) =>
    createSupabaseMock({
      rpc: {
        get_student_period_stats: [{ data: stats7 }, { data: stats30 }, { data: stats90 }],
      },
      from: {
        student_snapshots: {
          upsert: [{ data: null, error: null }],
        },
      },
    });

  it("uses provided period_end for stats windows", async () => {
    const periodEnd = new Date("2025-01-08T00:00:00.000Z");
    const { supabase, calls } = setup();

    await processSnapshotRefreshJob(supabase, studentId, periodEnd.toISOString());

    expect(calls.rpc).toHaveLength(3);
    expect(calls.rpc[0]?.args.p_end).toBe(periodEnd.toISOString());
    expect(calls.rpc[0]?.args.p_start).toBe(
      new Date(periodEnd.getTime() - 7 * DAY_MS).toISOString(),
    );
    expect(calls.rpc[1]?.args.p_start).toBe(
      new Date(periodEnd.getTime() - 30 * DAY_MS).toISOString(),
    );
    expect(calls.rpc[2]?.args.p_start).toBe(
      new Date(periodEnd.getTime() - 90 * DAY_MS).toISOString(),
    );
  });

  it("defaults to now when period_end is invalid", async () => {
    const before = Date.now();
    const { supabase, calls } = setup();

    await processSnapshotRefreshJob(supabase, studentId, "not-a-date");

    const end = Date.parse(calls.rpc[0]?.args.p_end as string);
    expect(Number.isFinite(end)).toBe(true);
    expect(end).toBeGreaterThanOrEqual(before - 1000);
    expect(end).toBeLessThanOrEqual(Date.now() + 5000);
  });

  it("defaults to now when period_end is missing", async () => {
    const before = Date.now();
    const { supabase, calls } = setup();

    await processSnapshotRefreshJob(supabase, studentId, undefined);

    const end = Date.parse(calls.rpc[0]?.args.p_end as string);
    expect(Number.isFinite(end)).toBe(true);
    expect(end).toBeGreaterThanOrEqual(before - 1000);
    expect(end).toBeLessThanOrEqual(Date.now() + 5000);
  });

  it("upserts weak arrays from the 30-day stats", async () => {
    const stats30 = makeStats({
      mistakes: {
        top_procedures: [{ name: "代数" }],
        top_steps: [{ step: 2 }],
        top_error_modes: [{ error_mode: "计算" }],
      },
    });
    const { supabase, calls } = setup(makeStats(), stats30, makeStats());

    await processSnapshotRefreshJob(supabase, studentId, "2025-01-08T00:00:00.000Z");

    const payload = calls.from.find((call) => call.table === "student_snapshots")
      ?.payload as Record<string, unknown>;
    expect(payload.weak_procedures_top).toEqual(stats30.mistakes.top_procedures);
    expect(payload.weak_steps_top).toEqual(stats30.mistakes.top_steps);
    expect(payload.common_error_modes_top).toEqual(stats30.mistakes.top_error_modes);
  });

  it("stores recent_trend windows", async () => {
    const stats7 = makeStats({ attempts: { total: 3 } });
    const stats30 = makeStats({ attempts: { total: 10 } });
    const stats90 = makeStats({ attempts: { total: 25 } });
    const { supabase, calls } = setup(stats7, stats30, stats90);

    await processSnapshotRefreshJob(supabase, studentId, "2025-01-08T00:00:00.000Z");

    const payload = calls.from.find((call) => call.table === "student_snapshots")
      ?.payload as Record<string, unknown>;
    const trend = payload.recent_trend as Record<string, unknown>;
    expect(trend.window_7d).toEqual(stats7);
    expect(trend.window_30d).toEqual(stats30);
    expect(trend.window_90d).toEqual(stats90);
  });

  it("sets subject_scope to all", async () => {
    const { supabase, calls } = setup();

    await processSnapshotRefreshJob(supabase, studentId, "2025-01-08T00:00:00.000Z");

    const payload = calls.from.find((call) => call.table === "student_snapshots")
      ?.payload as Record<string, unknown>;
    expect(payload.subject_scope).toBe("all");
  });

  it("sets updated_at", async () => {
    const before = Date.now();
    const { supabase, calls } = setup();

    await processSnapshotRefreshJob(supabase, studentId, "2025-01-08T00:00:00.000Z");

    const payload = calls.from.find((call) => call.table === "student_snapshots")
      ?.payload as Record<string, unknown>;
    const updatedAt = Date.parse(payload.updated_at as string);
    expect(Number.isFinite(updatedAt)).toBe(true);
    expect(updatedAt).toBeGreaterThanOrEqual(before - 1000);
  });

  it("writes empty notes when no patterns", async () => {
    const { supabase, calls } = setup();

    await processSnapshotRefreshJob(supabase, studentId, "2025-01-08T00:00:00.000Z");

    const payload = calls.from.find((call) => call.table === "student_snapshots")
      ?.payload as Record<string, unknown>;
    expect(payload.notes).toBeNull();
  });

  it("writes notes with top procedures", async () => {
    const stats30 = makeStats({
      mistakes: {
        top_procedures: [{ name: "函数" }, { name: "几何" }],
        top_steps: [],
        top_error_modes: [],
      },
    });
    const { supabase, calls } = setup(makeStats(), stats30, makeStats());

    await processSnapshotRefreshJob(supabase, studentId, "2025-01-08T00:00:00.000Z");

    const payload = calls.from.find((call) => call.table === "student_snapshots")
      ?.payload as Record<string, unknown>;
    expect(payload.notes).toContain("函数");
    expect(payload.notes).toContain("几何");
  });

  it("writes notes with top error modes", async () => {
    const stats30 = makeStats({
      mistakes: {
        top_procedures: [],
        top_steps: [],
        top_error_modes: [{ error_mode: "粗心" }, { error_mode: "计算" }],
      },
    });
    const { supabase, calls } = setup(makeStats(), stats30, makeStats());

    await processSnapshotRefreshJob(supabase, studentId, "2025-01-08T00:00:00.000Z");

    const payload = calls.from.find((call) => call.table === "student_snapshots")
      ?.payload as Record<string, unknown>;
    expect(payload.notes).toContain("粗心");
    expect(payload.notes).toContain("计算");
  });

  it("writes notes with both procedures and modes", async () => {
    const stats30 = makeStats({
      mistakes: {
        top_procedures: [{ name: "函数" }],
        top_steps: [],
        top_error_modes: [{ error_mode: "粗心" }],
      },
    });
    const { supabase, calls } = setup(makeStats(), stats30, makeStats());

    await processSnapshotRefreshJob(supabase, studentId, "2025-01-08T00:00:00.000Z");

    const payload = calls.from.find((call) => call.table === "student_snapshots")
      ?.payload as Record<string, unknown>;
    expect(payload.notes).toContain("函数");
    expect(payload.notes).toContain("粗心");
  });

  it("ignores missing procedure names", async () => {
    const stats30 = makeStats({
      mistakes: {
        top_procedures: [{ id: "p1" }],
        top_steps: [],
        top_error_modes: [],
      },
    });
    const { supabase, calls } = setup(makeStats(), stats30, makeStats());

    await processSnapshotRefreshJob(supabase, studentId, "2025-01-08T00:00:00.000Z");

    const payload = calls.from.find((call) => call.table === "student_snapshots")
      ?.payload as Record<string, unknown>;
    expect(payload.notes).toBeNull();
  });

  it("ignores missing error mode names", async () => {
    const stats30 = makeStats({
      mistakes: {
        top_procedures: [],
        top_steps: [],
        top_error_modes: [{ code: "x" }],
      },
    });
    const { supabase, calls } = setup(makeStats(), stats30, makeStats());

    await processSnapshotRefreshJob(supabase, studentId, "2025-01-08T00:00:00.000Z");

    const payload = calls.from.find((call) => call.table === "student_snapshots")
      ?.payload as Record<string, unknown>;
    expect(payload.notes).toBeNull();
  });

  it("prefers procedure_name fallback", async () => {
    const stats30 = makeStats({
      mistakes: {
        top_procedures: [{ procedure_name: "方程" }],
        top_steps: [],
        top_error_modes: [],
      },
    });
    const { supabase, calls } = setup(makeStats(), stats30, makeStats());

    await processSnapshotRefreshJob(supabase, studentId, "2025-01-08T00:00:00.000Z");

    const payload = calls.from.find((call) => call.table === "student_snapshots")
      ?.payload as Record<string, unknown>;
    expect(payload.notes).toContain("方程");
  });

  it("handles empty top arrays", async () => {
    const stats30 = makeStats({
      mistakes: { top_procedures: [], top_steps: [], top_error_modes: [] },
    });
    const { supabase, calls } = setup(makeStats(), stats30, makeStats());

    await processSnapshotRefreshJob(supabase, studentId, "2025-01-08T00:00:00.000Z");

    const payload = calls.from.find((call) => call.table === "student_snapshots")
      ?.payload as Record<string, unknown>;
    expect(payload.notes).toBeNull();
  });

  it("throws when rpc fails", async () => {
    const { supabase } = createSupabaseMock({
      rpc: {
        get_student_period_stats: [mockError("rpc_failed")],
      },
    });

    await expect(
      processSnapshotRefreshJob(supabase, studentId, "2025-01-08T00:00:00.000Z"),
    ).rejects.toThrow(/rpc_failed/);
  });

  it("throws when upsert fails", async () => {
    const { supabase } = createSupabaseMock({
      rpc: {
        get_student_period_stats: [
          { data: makeStats() },
          { data: makeStats() },
          { data: makeStats() },
        ],
      },
      from: {
        student_snapshots: {
          upsert: [mockError("upsert_failed")],
        },
      },
    });

    await expect(
      processSnapshotRefreshJob(supabase, studentId, "2025-01-08T00:00:00.000Z"),
    ).rejects.toThrow(/upsert_failed/);
  });

  it("uses 7 day window correctly", async () => {
    const periodEnd = new Date("2025-01-10T00:00:00.000Z");
    const { supabase, calls } = setup();

    await processSnapshotRefreshJob(supabase, studentId, periodEnd.toISOString());

    expect(calls.rpc[0]?.args.p_start).toBe(
      new Date(periodEnd.getTime() - 7 * DAY_MS).toISOString(),
    );
  });

  it("uses 30 day window correctly", async () => {
    const periodEnd = new Date("2025-02-01T00:00:00.000Z");
    const { supabase, calls } = setup();

    await processSnapshotRefreshJob(supabase, studentId, periodEnd.toISOString());

    expect(calls.rpc[1]?.args.p_start).toBe(
      new Date(periodEnd.getTime() - 30 * DAY_MS).toISOString(),
    );
  });

  it("uses 90 day window correctly", async () => {
    const periodEnd = new Date("2025-03-01T00:00:00.000Z");
    const { supabase, calls } = setup();

    await processSnapshotRefreshJob(supabase, studentId, periodEnd.toISOString());

    expect(calls.rpc[2]?.args.p_start).toBe(
      new Date(periodEnd.getTime() - 90 * DAY_MS).toISOString(),
    );
  });

  it("keeps student_id in snapshot payload", async () => {
    const { supabase, calls } = setup();

    await processSnapshotRefreshJob(supabase, studentId, "2025-01-08T00:00:00.000Z");

    const payload = calls.from.find((call) => call.table === "student_snapshots")
      ?.payload as Record<string, unknown>;
    expect(payload.student_id).toBe(studentId);
  });

  it("keeps subject_scope even when stats empty", async () => {
    const { supabase, calls } = setup();

    await processSnapshotRefreshJob(supabase, studentId, "2025-01-08T00:00:00.000Z");

    const payload = calls.from.find((call) => call.table === "student_snapshots")
      ?.payload as Record<string, unknown>;
    expect(payload.subject_scope).toBe("all");
  });

  it("handles missing stats fields gracefully", async () => {
    const stats30 = makeStats({
      mistakes: { top_procedures: [], top_steps: [], top_error_modes: [] },
    });
    const { supabase, calls } = setup(makeStats(), stats30, makeStats());

    await processSnapshotRefreshJob(supabase, studentId, "2025-01-08T00:00:00.000Z");

    const payload = calls.from.find((call) => call.table === "student_snapshots")
      ?.payload as Record<string, unknown>;
    expect(payload.weak_procedures_top).toEqual([]);
    expect(payload.common_error_modes_top).toEqual([]);
  });
});
