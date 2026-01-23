import { afterAll, beforeAll, beforeEach, describe, expect, it, vi } from "vitest";

vi.mock("@mariozechner/pi-ai", () => ({
  completeSimple: async () => ({
    role: "assistant",
    content: [
      {
        type: "text",
        text: JSON.stringify({
          summary: "本周进展稳定。",
          plan: {
            focus_areas: [{ topic: "代数", reason: "保持基础" }],
            next_steps: [{ action: "复盘错题", why: "减少重复失误" }],
            pace: "每天 10 分钟",
          },
        }),
      },
    ],
    api: "openai-responses",
    provider: "mock",
    model: "mock",
    usage: {
      input: 0,
      output: 0,
      cacheRead: 0,
      cacheWrite: 0,
      cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, total: 0 },
    },
    stopReason: "stop",
    timestamp: Date.now(),
  }),
}));

import { processProgressReportJob } from "../src/jobs/processProgressReportJob.js";
import { processSnapshotRefreshJob } from "../src/jobs/processSnapshotRefreshJob.js";
import { scheduleRecurringJobs } from "../src/scheduler.js";
import { makeConfig, makeModel } from "./helpers.js";
import {
  cleanupAiJobs,
  cleanupAttemptInsights,
  cleanupAttempts,
  cleanupByIds,
  cleanupNotificationEvents,
  cleanupStudentReports,
  cleanupStudentSnapshots,
  createAttempt,
  createAttemptInsight,
  createLocalSupabase,
  createNotificationEvent,
  createProcedure,
  createProfile,
  createQuestion,
  createQuestionOptions,
  createSession,
} from "./localSupabase.js";

const config = makeConfig({
  reportWeeklyDays: 7,
  reportMonthlyDays: 30,
});

const RUN_SUPABASE_TESTS = process.env.RUN_SUPABASE_TESTS === "1";
const describeIntegration = RUN_SUPABASE_TESTS ? describe.sequential : describe.skip;

describeIntegration("AI coach end-to-end flow", () => {
  const supabase = createLocalSupabase();
  const profileIds: string[] = [];
  const questionIds: string[] = [];
  const sessionIds: string[] = [];
  const attemptIds: string[] = [];
  const procedureIds: string[] = [];
  const insightAttemptIds: string[] = [];
  const reportIds: string[] = [];
  const jobIds: string[] = [];
  const notificationIds: string[] = [];

  let studentId = "";
  let questionId = "";
  let sessionId = "";

  beforeAll(async () => {
    const profile = await createProfile(supabase, { display_name: "E2E Student" });
    studentId = profile.id;
    profileIds.push(profile.id);

    const question = await createQuestion(supabase, { subject: "math", module: "algebra" });
    questionId = question.id;
    questionIds.push(question.id);
    await createQuestionOptions(supabase, questionId);

    const session = await createSession(supabase, studentId, { total_questions: 1 });
    sessionId = session.id;
    sessionIds.push(session.id);
  });

  beforeEach(async () => {
    await cleanupNotificationEvents(supabase, notificationIds);
    notificationIds.length = 0;
    await cleanupAiJobs(supabase, jobIds);
    jobIds.length = 0;
    await cleanupStudentReports(supabase, reportIds);
    reportIds.length = 0;
    await cleanupStudentSnapshots(supabase, [studentId]);
  });

  afterAll(async () => {
    await cleanupNotificationEvents(supabase, notificationIds);
    await cleanupAiJobs(supabase, jobIds);
    await cleanupStudentReports(supabase, reportIds);
    await cleanupStudentSnapshots(supabase, [studentId]);
    await cleanupAttemptInsights(supabase, insightAttemptIds);
    await cleanupAttempts(supabase, attemptIds);
    await cleanupByIds(supabase, "sessions", sessionIds);
    await cleanupByIds(supabase, "questions", questionIds);
    await cleanupByIds(supabase, "procedures", procedureIds);
    await cleanupByIds(supabase, "profiles", profileIds);
  });

  it("inserts ai_job on wrong attempt", async () => {
    const attempt = await createAttempt(supabase, {
      studentId,
      sessionId,
      questionId,
      isCorrect: false,
    });
    attemptIds.push(attempt.id);

    const { data } = await supabase.from("ai_jobs").select("id, kind").eq("attempt_id", attempt.id);
    const row = data?.find((item: any) => item.kind === "attempt_insight");
    expect(row).toBeTruthy();
    if (row?.id) jobIds.push(row.id);
  });

  it("snapshot_refresh writes student_snapshots", async () => {
    await processSnapshotRefreshJob(supabase, studentId, new Date().toISOString());

    const { data } = await supabase
      .from("student_snapshots")
      .select("student_id")
      .eq("student_id", studentId);
    expect(data?.length).toBe(1);
  });

  it("snapshot_refresh updates notes", async () => {
    const procedure = await createProcedure(supabase, { subject: "math" });
    procedureIds.push(procedure.id);
    const attempt = await createAttempt(supabase, {
      studentId,
      sessionId,
      questionId,
      isCorrect: false,
    });
    attemptIds.push(attempt.id);
    const insight = await createAttemptInsight(supabase, {
      attemptId: attempt.id,
      studentId,
      questionId,
      procedureId: procedure.id,
    });
    insightAttemptIds.push(insight.attempt_id);

    await processSnapshotRefreshJob(supabase, studentId, new Date().toISOString());

    const { data } = await supabase
      .from("student_snapshots")
      .select("notes")
      .eq("student_id", studentId)
      .single();
    expect(typeof data?.notes).toBe("string");
  });

  it("progress_report creates student_reports", async () => {
    const payload = {
      student_id: studentId,
      period_kind: "weekly",
      period_key: `weekly-${Date.now()}`,
      period_start: new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString(),
      period_end: new Date().toISOString(),
    };

    await processProgressReportJob(supabase, config, makeModel(), payload);

    const { data } = await supabase
      .from("student_reports")
      .select("id")
      .eq("student_id", studentId)
      .eq("period_key", payload.period_key);

    expect(data?.length).toBe(1);
    if (data?.[0]?.id) reportIds.push(data[0].id);
  });

  it("progress_report enqueues notification", async () => {
    const payload = {
      student_id: studentId,
      period_kind: "weekly",
      period_key: `weekly-${Date.now() + 1}`,
      period_start: new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString(),
      period_end: new Date().toISOString(),
    };

    await processProgressReportJob(supabase, config, makeModel(), payload);

    const { data } = await supabase
      .from("notification_events")
      .select("id,event_type")
      .eq("student_id", studentId)
      .eq("event_type", "progress_report_ready");

    expect(data?.length).toBeGreaterThan(0);
    data?.forEach((row: any) => notificationIds.push(row.id));
  });

  it("progress_report respects unique period_key", async () => {
    const periodKey = `weekly-${Date.now() + 2}`;
    const payload = {
      student_id: studentId,
      period_kind: "weekly",
      period_key: periodKey,
      period_start: new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString(),
      period_end: new Date().toISOString(),
    };

    await processProgressReportJob(supabase, config, makeModel(), payload);
    await processProgressReportJob(supabase, config, makeModel(), payload);

    const { data } = await supabase
      .from("student_reports")
      .select("id")
      .eq("period_key", periodKey);
    expect(data?.length).toBe(1);
    if (data?.[0]?.id) reportIds.push(data[0].id);
  });

  it("scheduleRecurringJobs enqueues jobs for active student", async () => {
    await scheduleRecurringJobs(config, supabase);

    const { data } = await supabase.from("ai_jobs").select("id, kind").eq("student_id", studentId);
    expect(data?.length).toBeGreaterThan(0);
    data?.forEach((row: any) => jobIds.push(row.id));
  });

  it("scheduleRecurringJobs enqueues both report kinds", async () => {
    await scheduleRecurringJobs(config, supabase);

    const { data } = await supabase.from("ai_jobs").select("kind").eq("student_id", studentId);
    const kinds = (data ?? []).map((row: any) => row.kind);
    expect(kinds).toContain("progress_report");
  });

  it("list_active_students returns student", async () => {
    const { data } = await supabase.rpc("list_active_students", {
      p_since: "2025-01-01T00:00:00.000Z",
    });
    const ids = (data as Array<{ student_id: string }>).map((row) => row.student_id);
    expect(ids).toContain(studentId);
  });

  it("get_student_period_stats returns coverage structure", async () => {
    const { data } = await supabase.rpc("get_student_period_stats", {
      p_student_id: studentId,
      p_start: "2025-01-01T00:00:00.000Z",
      p_end: "2025-12-31T00:00:00.000Z",
    });

    expect(Array.isArray((data as any).coverage.subjects)).toBe(true);
  });

  it("claim_notification_events works for report events", async () => {
    const event = await createNotificationEvent(supabase, {
      studentId,
      eventType: "progress_report_ready",
    });
    notificationIds.push(event.id);

    const { data } = await supabase.rpc("claim_notification_events", {
      p_worker_id: "worker-e2e",
      p_limit: 5,
    });
    const ids = (data as Array<{ id: string }>).map((row) => row.id);
    expect(ids).toContain(event.id);
  });

  it("progress_report writes prompt_version", async () => {
    const payload = {
      student_id: studentId,
      period_kind: "weekly",
      period_key: `weekly-${Date.now() + 3}`,
      period_start: new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString(),
      period_end: new Date().toISOString(),
    };

    await processProgressReportJob(supabase, config, makeModel(), payload);

    const { data } = await supabase
      .from("student_reports")
      .select("prompt_version")
      .eq("period_key", payload.period_key)
      .single();
    expect(data?.prompt_version).toBe("ai-coach-report-v1");
  });

  it("snapshot_refresh keeps subject_scope", async () => {
    await processSnapshotRefreshJob(supabase, studentId, new Date().toISOString());
    const { data } = await supabase
      .from("student_snapshots")
      .select("subject_scope")
      .eq("student_id", studentId)
      .single();
    expect(data?.subject_scope).toBe("all");
  });

  it("snapshot_refresh updates updated_at", async () => {
    await processSnapshotRefreshJob(supabase, studentId, new Date().toISOString());
    const { data } = await supabase
      .from("student_snapshots")
      .select("updated_at")
      .eq("student_id", studentId)
      .single();
    expect(typeof data?.updated_at).toBe("string");
  });

  it("progress_report stores metrics", async () => {
    const payload = {
      student_id: studentId,
      period_kind: "weekly",
      period_key: `weekly-${Date.now() + 4}`,
      period_start: new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString(),
      period_end: new Date().toISOString(),
    };

    await processProgressReportJob(supabase, config, makeModel(), payload);

    const { data } = await supabase
      .from("student_reports")
      .select("metrics")
      .eq("period_key", payload.period_key)
      .single();
    expect(data?.metrics).toBeTruthy();
  });

  it("notification_events are created for reports", async () => {
    const payload = {
      student_id: studentId,
      period_kind: "weekly",
      period_key: `weekly-${Date.now() + 5}`,
      period_start: new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString(),
      period_end: new Date().toISOString(),
    };

    await processProgressReportJob(supabase, config, makeModel(), payload);

    const { data } = await supabase
      .from("notification_events")
      .select("event_type")
      .eq("student_id", studentId)
      .eq("event_type", "progress_report_ready");
    expect((data ?? []).length).toBeGreaterThan(0);
  });

  it("scheduler creates snapshot_refresh job", async () => {
    await scheduleRecurringJobs(config, supabase);
    const { data } = await supabase.from("ai_jobs").select("kind").eq("student_id", studentId);
    const kinds = (data ?? []).map((row: any) => row.kind);
    expect(kinds).toContain("snapshot_refresh");
  });

  it("scheduler creates two progress_report jobs", async () => {
    await scheduleRecurringJobs(config, supabase);
    const { data } = await supabase.from("ai_jobs").select("kind").eq("student_id", studentId);
    const reports = (data ?? []).filter((row: any) => row.kind === "progress_report");
    expect(reports.length).toBeGreaterThanOrEqual(2);
  });

  it("progress_report populates summary", async () => {
    const payload = {
      student_id: studentId,
      period_kind: "weekly",
      period_key: `weekly-${Date.now() + 6}`,
      period_start: new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString(),
      period_end: new Date().toISOString(),
    };

    await processProgressReportJob(supabase, config, makeModel(), payload);

    const { data } = await supabase
      .from("student_reports")
      .select("summary")
      .eq("period_key", payload.period_key)
      .single();
    expect((data?.summary ?? "").length).toBeGreaterThan(0);
  });

  it("progress_report writes plan", async () => {
    const payload = {
      student_id: studentId,
      period_kind: "weekly",
      period_key: `weekly-${Date.now() + 7}`,
      period_start: new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString(),
      period_end: new Date().toISOString(),
    };

    await processProgressReportJob(supabase, config, makeModel(), payload);

    const { data } = await supabase
      .from("student_reports")
      .select("plan")
      .eq("period_key", payload.period_key)
      .single();
    expect(data?.plan).toBeTruthy();
  });

  it("cleanup attempt insights after use", async () => {
    const procedure = await createProcedure(supabase, { subject: "math" });
    procedureIds.push(procedure.id);
    const attempt = await createAttempt(supabase, {
      studentId,
      sessionId,
      questionId,
      isCorrect: false,
    });
    attemptIds.push(attempt.id);
    const insight = await createAttemptInsight(supabase, {
      attemptId: attempt.id,
      studentId,
      questionId,
      procedureId: procedure.id,
    });
    insightAttemptIds.push(insight.attempt_id);

    await cleanupAttemptInsights(supabase, [insight.attempt_id]);

    const { data } = await supabase
      .from("attempt_insights")
      .select("attempt_id")
      .eq("attempt_id", insight.attempt_id);
    expect(data?.length).toBe(0);
  });

  it("cleanup attempts after use", async () => {
    const attempt = await createAttempt(supabase, {
      studentId,
      sessionId,
      questionId,
      isCorrect: true,
    });
    await cleanupAttempts(supabase, [attempt.id]);

    const { data } = await supabase.from("attempts").select("id").eq("id", attempt.id);
    expect(data?.length).toBe(0);
  });
});
