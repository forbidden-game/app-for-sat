import { describe, expect, it, vi } from "vitest";

import type { CoachConfig } from "../src/config.js";
import { scheduleRecurringJobs } from "../src/scheduler.js";
import { createSupabaseMock, makeConfig, mockError } from "./helpers.js";

function baseConfig(overrides: Partial<CoachConfig> = {}): CoachConfig {
  return makeConfig({
    activeLookbackDays: 30,
    reportWeeklyDays: 7,
    reportMonthlyDays: 30,
    ...overrides,
  });
}

function extractInserts(calls: ReturnType<typeof createSupabaseMock>["calls"]) {
  return calls.from.filter((call) => call.table === "ai_jobs" && call.action === "insert");
}

describe("scheduleRecurringJobs", () => {
  it("skips when no students", async () => {
    const { supabase, calls } = createSupabaseMock({
      rpc: {
        list_active_students: [{ data: [] }],
      },
    });

    await scheduleRecurringJobs(baseConfig(), supabase);

    expect(extractInserts(calls)).toHaveLength(0);
  });

  it("enqueues snapshot_refresh for each student", async () => {
    const { supabase, calls } = createSupabaseMock({
      rpc: {
        list_active_students: [{ data: [{ student_id: "s1" }, { student_id: "s2" }] }],
      },
      from: {
        ai_jobs: {
          insert: [{ data: null, error: null }],
        },
      },
    });

    await scheduleRecurringJobs(baseConfig(), supabase);

    const inserts = extractInserts(calls);
    const snapshotCalls = inserts.filter(
      (call) => (call.payload as any).kind === "snapshot_refresh",
    );
    expect(snapshotCalls).toHaveLength(2);
  });

  it("enqueues weekly reports", async () => {
    const { supabase, calls } = createSupabaseMock({
      rpc: {
        list_active_students: [{ data: [{ student_id: "s1" }] }],
      },
      from: {
        ai_jobs: {
          insert: [{ data: null, error: null }],
        },
      },
    });

    await scheduleRecurringJobs(baseConfig(), supabase);

    const weekly = extractInserts(calls).filter(
      (call) => (call.payload as any).kind === "progress_report",
    );
    expect(weekly.length).toBeGreaterThan(0);
    expect((weekly[0]?.payload as any).payload.period_kind).toBe("weekly");
  });

  it("enqueues monthly reports", async () => {
    const { supabase, calls } = createSupabaseMock({
      rpc: {
        list_active_students: [{ data: [{ student_id: "s1" }] }],
      },
      from: {
        ai_jobs: {
          insert: [{ data: null, error: null }],
        },
      },
    });

    await scheduleRecurringJobs(baseConfig(), supabase);

    const reports = extractInserts(calls).filter(
      (call) => (call.payload as any).kind === "progress_report",
    );
    const kinds = reports.map((call) => (call.payload as any).payload.period_kind);
    expect(kinds).toContain("monthly");
  });

  it("uses activeLookbackDays for list_active_students", async () => {
    const { supabase, calls } = createSupabaseMock({
      rpc: {
        list_active_students: [{ data: [{ student_id: "s1" }] }],
      },
      from: {
        ai_jobs: {
          insert: [{ data: null, error: null }],
        },
      },
    });

    const config = baseConfig({ activeLookbackDays: 60 });
    await scheduleRecurringJobs(config, supabase);

    expect(calls.rpc[0]?.args.p_since).toContain("T");
  });

  it("uses start-of-day UTC for period_end", async () => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date("2025-01-09T15:32:10.000Z"));

    const { supabase, calls } = createSupabaseMock({
      rpc: {
        list_active_students: [{ data: [{ student_id: "s1" }] }],
      },
      from: {
        ai_jobs: {
          insert: [{ data: null, error: null }],
        },
      },
    });

    await scheduleRecurringJobs(baseConfig(), supabase);

    const report = extractInserts(calls).find(
      (call) => (call.payload as any).kind === "progress_report",
    );
    expect((report?.payload as any).payload.period_end).toBe("2025-01-09T00:00:00.000Z");

    vi.useRealTimers();
  });

  it("uses configured weekly period days", async () => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date("2025-01-10T05:00:00.000Z"));

    const { supabase, calls } = createSupabaseMock({
      rpc: {
        list_active_students: [{ data: [{ student_id: "s1" }] }],
      },
      from: {
        ai_jobs: {
          insert: [{ data: null, error: null }],
        },
      },
    });

    const config = baseConfig({ reportWeeklyDays: 14 });
    await scheduleRecurringJobs(config, supabase);

    const report = extractInserts(calls).find(
      (call) => (call.payload as any).payload.period_kind === "weekly",
    );
    expect((report?.payload as any).payload.period_start).toBe("2024-12-27T00:00:00.000Z");

    vi.useRealTimers();
  });

  it("uses configured monthly period days", async () => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date("2025-01-10T05:00:00.000Z"));

    const { supabase, calls } = createSupabaseMock({
      rpc: {
        list_active_students: [{ data: [{ student_id: "s1" }] }],
      },
      from: {
        ai_jobs: {
          insert: [{ data: null, error: null }],
        },
      },
    });

    const config = baseConfig({ reportMonthlyDays: 45 });
    await scheduleRecurringJobs(config, supabase);

    const report = extractInserts(calls).find(
      (call) => (call.payload as any).payload.period_kind === "monthly",
    );
    expect((report?.payload as any).payload.period_start).toBe("2024-11-26T00:00:00.000Z");

    vi.useRealTimers();
  });

  it("includes dedupe_key for snapshot", async () => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date("2025-01-02T10:00:00.000Z"));

    const { supabase, calls } = createSupabaseMock({
      rpc: {
        list_active_students: [{ data: [{ student_id: "s1" }] }],
      },
      from: {
        ai_jobs: {
          insert: [{ data: null, error: null }],
        },
      },
    });

    await scheduleRecurringJobs(baseConfig(), supabase);

    const snapshot = extractInserts(calls).find(
      (call) => (call.payload as any).kind === "snapshot_refresh",
    );
    expect((snapshot?.payload as any).dedupe_key).toContain("snapshot:s1:2025-01-02");

    vi.useRealTimers();
  });

  it("includes dedupe_key for report", async () => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date("2025-01-02T10:00:00.000Z"));

    const { supabase, calls } = createSupabaseMock({
      rpc: {
        list_active_students: [{ data: [{ student_id: "s1" }] }],
      },
      from: {
        ai_jobs: {
          insert: [{ data: null, error: null }],
        },
      },
    });

    await scheduleRecurringJobs(baseConfig(), supabase);

    const report = extractInserts(calls).find(
      (call) => (call.payload as any).kind === "progress_report",
    );
    expect((report?.payload as any).dedupe_key).toContain("report:s1:weekly-2025-01-02");

    vi.useRealTimers();
  });

  it("uses run_after for immediate scheduling", async () => {
    const { supabase, calls } = createSupabaseMock({
      rpc: {
        list_active_students: [{ data: [{ student_id: "s1" }] }],
      },
      from: {
        ai_jobs: {
          insert: [{ data: null, error: null }],
        },
      },
    });

    await scheduleRecurringJobs(baseConfig(), supabase);

    const insert = extractInserts(calls)[0]?.payload as any;
    expect(typeof insert.run_after).toBe("string");
  });

  it("ignores duplicate insert errors", async () => {
    const { supabase } = createSupabaseMock({
      rpc: {
        list_active_students: [{ data: [{ student_id: "s1" }] }],
      },
      from: {
        ai_jobs: {
          insert: [mockError("duplicate", "23505")],
        },
      },
    });

    await scheduleRecurringJobs(baseConfig(), supabase);
  });

  it("throws when list_active_students fails", async () => {
    const { supabase } = createSupabaseMock({
      rpc: {
        list_active_students: [mockError("rpc_failed")],
      },
    });

    await expect(scheduleRecurringJobs(baseConfig(), supabase)).rejects.toThrow(/rpc_failed/);
  });

  it("enqueues payload with student_id", async () => {
    const { supabase, calls } = createSupabaseMock({
      rpc: {
        list_active_students: [{ data: [{ student_id: "s1" }] }],
      },
      from: {
        ai_jobs: {
          insert: [{ data: null, error: null }],
        },
      },
    });

    await scheduleRecurringJobs(baseConfig(), supabase);

    const payload = extractInserts(calls)[0]?.payload as any;
    expect(payload.student_id).toBe("s1");
  });

  it("enqueues payload with period_key", async () => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date("2025-01-02T10:00:00.000Z"));

    const { supabase, calls } = createSupabaseMock({
      rpc: {
        list_active_students: [{ data: [{ student_id: "s1" }] }],
      },
      from: {
        ai_jobs: {
          insert: [{ data: null, error: null }],
        },
      },
    });

    await scheduleRecurringJobs(baseConfig(), supabase);

    const report = extractInserts(calls).find(
      (call) => (call.payload as any).kind === "progress_report",
    );
    expect((report?.payload as any).payload.period_key).toBe("weekly-2025-01-02");

    vi.useRealTimers();
  });

  it("includes period_start and period_end in report payload", async () => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date("2025-01-02T10:00:00.000Z"));

    const { supabase, calls } = createSupabaseMock({
      rpc: {
        list_active_students: [{ data: [{ student_id: "s1" }] }],
      },
      from: {
        ai_jobs: {
          insert: [{ data: null, error: null }],
        },
      },
    });

    await scheduleRecurringJobs(baseConfig(), supabase);

    const report = extractInserts(calls).find(
      (call) => (call.payload as any).kind === "progress_report",
    );
    expect((report?.payload as any).payload.period_start).toBe("2024-12-26T00:00:00.000Z");
    expect((report?.payload as any).payload.period_end).toBe("2025-01-02T00:00:00.000Z");

    vi.useRealTimers();
  });

  it("enqueues all three job types per student", async () => {
    const { supabase, calls } = createSupabaseMock({
      rpc: {
        list_active_students: [{ data: [{ student_id: "s1" }] }],
      },
      from: {
        ai_jobs: {
          insert: [{ data: null, error: null }],
        },
      },
    });

    await scheduleRecurringJobs(baseConfig(), supabase);

    const kinds = extractInserts(calls).map((call) => (call.payload as any).kind);
    expect(kinds.filter((k) => k === "snapshot_refresh").length).toBe(1);
    expect(kinds.filter((k) => k === "progress_report").length).toBe(2);
  });

  it("supports multiple students", async () => {
    const { supabase, calls } = createSupabaseMock({
      rpc: {
        list_active_students: [{ data: [{ student_id: "s1" }, { student_id: "s2" }] }],
      },
      from: {
        ai_jobs: {
          insert: [{ data: null, error: null }],
        },
      },
    });

    await scheduleRecurringJobs(baseConfig(), supabase);

    const inserts = extractInserts(calls);
    const students = inserts.map((call) => (call.payload as any).student_id);
    expect(students).toContain("s1");
    expect(students).toContain("s2");
  });

  it("skips enqueue when insert returns duplicate", async () => {
    const { supabase } = createSupabaseMock({
      rpc: {
        list_active_students: [{ data: [{ student_id: "s1" }] }],
      },
      from: {
        ai_jobs: {
          insert: [mockError("duplicate", "23505")],
        },
      },
    });

    await scheduleRecurringJobs(baseConfig(), supabase);
  });

  it("handles multiple inserts with mixed errors", async () => {
    const { supabase } = createSupabaseMock({
      rpc: {
        list_active_students: [{ data: [{ student_id: "s1" }] }],
      },
      from: {
        ai_jobs: {
          insert: [
            mockError("duplicate", "23505"),
            { data: null, error: null },
            { data: null, error: null },
          ],
        },
      },
    });

    await scheduleRecurringJobs(baseConfig(), supabase);
  });

  it("uses configured workerId in dedupe_key", async () => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date("2025-01-02T10:00:00.000Z"));

    const { supabase, calls } = createSupabaseMock({
      rpc: {
        list_active_students: [{ data: [{ student_id: "s1" }] }],
      },
      from: {
        ai_jobs: {
          insert: [{ data: null, error: null }],
        },
      },
    });

    await scheduleRecurringJobs(baseConfig({ workerId: "worker-x" }), supabase);

    const snapshot = extractInserts(calls).find(
      (call) => (call.payload as any).kind === "snapshot_refresh",
    );
    expect((snapshot?.payload as any).dedupe_key).toContain("snapshot:s1:2025-01-02");

    vi.useRealTimers();
  });
});
