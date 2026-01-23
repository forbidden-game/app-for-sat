import { afterAll, beforeAll, describe, expect, it } from "vitest";

import { fetchPeriodStats } from "../src/stats.js";
import { createSupabaseMock, makeStats, mockError } from "./helpers.js";
import {
  cleanupAttemptInsights,
  cleanupAttempts,
  cleanupByIds,
  createAttempt,
  createAttemptInsight,
  createLocalSupabase,
  createNotificationEvent,
  createProcedure,
  createProfile,
  createQuestion,
  createQuestionOptions,
  createSession,
  deleteProfile,
} from "./localSupabase.js";

const NOW = new Date("2025-01-10T00:00:00.000Z");

describe("RPC and stats", () => {
  it("fetchPeriodStats returns normalized attempts defaults", async () => {
    const { supabase } = createSupabaseMock({
      rpc: {
        get_student_period_stats: [{ data: {} }],
      },
    });

    const stats = await fetchPeriodStats(supabase, "student", "2025-01-01", "2025-01-02");

    expect(stats.attempts.total).toBe(0);
    expect(stats.attempts.correct).toBe(0);
    expect(stats.attempts.accuracy).toBeNull();
  });

  it("fetchPeriodStats coerces numeric strings", async () => {
    const { supabase } = createSupabaseMock({
      rpc: {
        get_student_period_stats: [
          {
            data: {
              attempts: {
                total: "5",
                correct: "3",
                accuracy: "0.6",
                avg_duration_ms: "12000",
                skipped: "1",
              },
              mistakes: { top_procedures: [], top_steps: [], top_error_modes: [] },
              coverage: { subjects: [], tags: [] },
            },
          },
        ],
      },
    });

    const stats = await fetchPeriodStats(supabase, "student", "2025-01-01", "2025-01-02");

    expect(stats.attempts.total).toBe(5);
    expect(stats.attempts.correct).toBe(3);
    expect(stats.attempts.accuracy).toBe(0.6);
    expect(stats.attempts.avg_duration_ms).toBe(12000);
    expect(stats.attempts.skipped).toBe(1);
  });

  it("fetchPeriodStats falls back for malformed attempts", async () => {
    const { supabase } = createSupabaseMock({
      rpc: {
        get_student_period_stats: [{ data: { attempts: { total: "bad" } } }],
      },
    });

    const stats = await fetchPeriodStats(supabase, "student", "2025-01-01", "2025-01-02");

    expect(stats.attempts.total).toBe(0);
  });

  it("fetchPeriodStats keeps arrays", async () => {
    const payload = makeStats({ mistakes: { top_procedures: [{ id: "p1" }] } });
    const { supabase } = createSupabaseMock({
      rpc: {
        get_student_period_stats: [{ data: payload }],
      },
    });

    const stats = await fetchPeriodStats(supabase, "student", "2025-01-01", "2025-01-02");

    expect(stats.mistakes.top_procedures).toEqual([{ id: "p1" }]);
  });

  it("fetchPeriodStats returns empty arrays when missing", async () => {
    const { supabase } = createSupabaseMock({
      rpc: {
        get_student_period_stats: [{ data: { attempts: { total: 0 } } }],
      },
    });

    const stats = await fetchPeriodStats(supabase, "student", "2025-01-01", "2025-01-02");

    expect(stats.mistakes.top_steps).toEqual([]);
    expect(stats.coverage.subjects).toEqual([]);
  });

  it("fetchPeriodStats throws on rpc error", async () => {
    const { supabase } = createSupabaseMock({
      rpc: {
        get_student_period_stats: [mockError("rpc_failed")],
      },
    });

    await expect(fetchPeriodStats(supabase, "student", "2025-01-01", "2025-01-02")).rejects.toThrow(
      /rpc_failed/,
    );
  });

  it("fetchPeriodStats tolerates non-object coverage", async () => {
    const { supabase } = createSupabaseMock({
      rpc: {
        get_student_period_stats: [{ data: { attempts: { total: 1 }, coverage: "bad" } }],
      },
    });

    const stats = await fetchPeriodStats(supabase, "student", "2025-01-01", "2025-01-02");
    expect(stats.coverage.subjects).toEqual([]);
  });
});

const RUN_SUPABASE_TESTS = process.env.RUN_SUPABASE_TESTS === "1";
const describeIntegration = RUN_SUPABASE_TESTS ? describe : describe.skip;

describeIntegration("RPC integration", () => {
  const supabase = createLocalSupabase();
  const profileIds: string[] = [];
  const questionIds: string[] = [];
  const sessionIds: string[] = [];
  const attemptIds: string[] = [];
  const procedureIds: string[] = [];
  const insightAttemptIds: string[] = [];
  const notificationIds: string[] = [];
  const jobIds: string[] = [];

  beforeAll(async () => {
    const profile = await createProfile(supabase);
    profileIds.push(profile.id);

    const question = await createQuestion(supabase, { subject: "math", module: "algebra" });
    questionIds.push(question.id);
    await createQuestionOptions(supabase, question.id);

    const session = await createSession(supabase, profile.id, { total_questions: 2 });
    sessionIds.push(session.id);

    const attempt = await createAttempt(supabase, {
      studentId: profile.id,
      sessionId: session.id,
      questionId: question.id,
      isCorrect: false,
      createdAt: NOW.toISOString(),
    });
    attemptIds.push(attempt.id);

    const { data: jobs } = await supabase
      .from("ai_jobs")
      .select("id")
      .eq("attempt_id", attempt.id)
      .eq("kind", "attempt_insight");
    jobs?.forEach((row: any) => jobIds.push(row.id));

    const procedure = await createProcedure(supabase, { subject: "math" });
    procedureIds.push(procedure.id);

    const insight = await createAttemptInsight(supabase, {
      attemptId: attempt.id,
      studentId: profile.id,
      questionId: question.id,
      procedureId: procedure.id,
      errorStepIndex: 1,
      createdAt: NOW.toISOString(),
    });
    insightAttemptIds.push(insight.attempt_id);

    const notification = await createNotificationEvent(supabase, { studentId: profile.id });
    notificationIds.push(notification.id);
  });

  afterAll(async () => {
    await cleanupAttemptInsights(supabase, insightAttemptIds);
    await cleanupAttempts(supabase, attemptIds);
    await cleanupByIds(supabase, "ai_jobs", jobIds);
    await cleanupByIds(supabase, "sessions", sessionIds);
    await cleanupByIds(supabase, "questions", questionIds);
    await cleanupByIds(supabase, "procedures", procedureIds);
    await cleanupByIds(supabase, "notification_events", notificationIds);
    for (const id of profileIds) {
      await deleteProfile(supabase, id);
    }
  });

  it("get_student_period_stats returns attempts counts", async () => {
    const { data, error } = await supabase.rpc("get_student_period_stats", {
      p_student_id: profileIds[0],
      p_start: "2025-01-01T00:00:00.000Z",
      p_end: "2025-01-20T00:00:00.000Z",
    });

    expect(error).toBeNull();
    const attempts = (data as any).attempts;
    expect(attempts.total).toBe(1);
    expect(attempts.correct).toBe(0);
  });

  it("get_student_period_stats returns top procedures", async () => {
    const { data } = await supabase.rpc("get_student_period_stats", {
      p_student_id: profileIds[0],
      p_start: "2025-01-01T00:00:00.000Z",
      p_end: "2025-01-20T00:00:00.000Z",
    });

    const mistakes = (data as any).mistakes;
    expect(mistakes.top_procedures.length).toBeGreaterThan(0);
  });

  it("get_student_period_stats returns top error modes", async () => {
    const { data } = await supabase.rpc("get_student_period_stats", {
      p_student_id: profileIds[0],
      p_start: "2025-01-01T00:00:00.000Z",
      p_end: "2025-01-20T00:00:00.000Z",
    });

    const mistakes = (data as any).mistakes;
    expect(mistakes.top_error_modes.length).toBeGreaterThan(0);
  });

  it("list_active_students returns student within window", async () => {
    const { data, error } = await supabase.rpc("list_active_students", {
      p_since: "2025-01-01T00:00:00.000Z",
    });

    expect(error).toBeNull();
    const ids = (data as Array<{ student_id: string }>).map((row) => row.student_id);
    expect(ids).toContain(profileIds[0]);
  });

  it("list_active_students excludes old activity", async () => {
    const { data } = await supabase.rpc("list_active_students", {
      p_since: "2025-02-01T00:00:00.000Z",
    });

    const ids = (data as Array<{ student_id: string }>).map((row) => row.student_id);
    expect(ids).not.toContain(profileIds[0]);
  });

  it("claim_notification_events marks queued as sending", async () => {
    const { data, error } = await supabase.rpc("claim_notification_events", {
      p_worker_id: "worker-1",
      p_limit: 5,
    });

    expect(error).toBeNull();
    const rows = data as Array<{ id: string; status: string; locked_by: string | null }>;
    expect(rows.length).toBeGreaterThan(0);
    expect(rows[0]?.status).toBe("sending");
    expect(rows[0]?.locked_by).toBe("worker-1");
  });

  it("claim_notification_events does not return sent", async () => {
    await supabase
      .from("notification_events")
      .update({ status: "sent" })
      .eq("id", notificationIds[0]);

    const { data } = await supabase.rpc("claim_notification_events", {
      p_worker_id: "worker-2",
      p_limit: 5,
    });

    const rows = (data as Array<{ id: string }>).map((row) => row.id);
    expect(rows).not.toContain(notificationIds[0]);
  });

  it("claim_notification_events reclaims stale sending", async () => {
    const staleId = (await createNotificationEvent(supabase, { studentId: profileIds[0] })).id;
    notificationIds.push(staleId);
    await supabase
      .from("notification_events")
      .update({ status: "sending", updated_at: "2025-01-01T00:00:00.000Z" })
      .eq("id", staleId);

    const { data } = await supabase.rpc("claim_notification_events", {
      p_worker_id: "worker-3",
      p_limit: 10,
    });

    const ids = (data as Array<{ id: string }>).map((row) => row.id);
    expect(ids).toContain(staleId);
  });

  it("claim_notification_events respects limit", async () => {
    const extra1 = await createNotificationEvent(supabase, { studentId: profileIds[0] });
    const extra2 = await createNotificationEvent(supabase, { studentId: profileIds[0] });
    notificationIds.push(extra1.id, extra2.id);

    const { data } = await supabase.rpc("claim_notification_events", {
      p_worker_id: "worker-4",
      p_limit: 1,
    });

    expect((data as Array<{ id: string }>).length).toBe(1);
  });

  it("get_student_period_stats includes coverage subjects", async () => {
    const { data } = await supabase.rpc("get_student_period_stats", {
      p_student_id: profileIds[0],
      p_start: "2025-01-01T00:00:00.000Z",
      p_end: "2025-01-20T00:00:00.000Z",
    });

    const coverage = (data as any).coverage;
    expect(Array.isArray(coverage.subjects)).toBe(true);
  });

  it("get_student_period_stats includes coverage tags", async () => {
    const { data } = await supabase.rpc("get_student_period_stats", {
      p_student_id: profileIds[0],
      p_start: "2025-01-01T00:00:00.000Z",
      p_end: "2025-01-20T00:00:00.000Z",
    });

    const coverage = (data as any).coverage;
    expect(Array.isArray(coverage.tags)).toBe(true);
  });

  it("get_student_period_stats returns empty when no attempts", async () => {
    const newProfile = await createProfile(supabase, { display_name: "Empty Student" });
    profileIds.push(newProfile.id);

    const { data } = await supabase.rpc("get_student_period_stats", {
      p_student_id: newProfile.id,
      p_start: "2025-01-01T00:00:00.000Z",
      p_end: "2025-01-20T00:00:00.000Z",
    });

    const attempts = (data as any).attempts;
    expect(attempts.total).toBe(0);
  });

  it("list_active_students includes multiple students", async () => {
    const extraProfile = await createProfile(supabase, { display_name: "Extra" });
    profileIds.push(extraProfile.id);
    const session = await createSession(supabase, extraProfile.id, { total_questions: 1 });
    sessionIds.push(session.id);
    const question = await createQuestion(supabase, { subject: "math", module: "algebra" });
    questionIds.push(question.id);
    await createQuestionOptions(supabase, question.id);
    const attempt = await createAttempt(supabase, {
      studentId: extraProfile.id,
      sessionId: session.id,
      questionId: question.id,
      isCorrect: true,
      createdAt: NOW.toISOString(),
    });
    attemptIds.push(attempt.id);

    const { data } = await supabase.rpc("list_active_students", {
      p_since: "2025-01-01T00:00:00.000Z",
    });

    const ids = (data as Array<{ student_id: string }>).map((row) => row.student_id);
    expect(ids).toContain(extraProfile.id);
  });
});
