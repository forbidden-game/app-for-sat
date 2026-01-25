import { describe, it, expect, beforeAll } from "vitest";
import { createClientAs, skipIfNoSupabase, TestClient } from "@test/helpers";
import { serviceClient } from "@test/setup";

describe("Study behavior RPC", () => {
  let studentClient: TestClient;
  let otherStudentClient: TestClient;
  let parentClient: TestClient;
  let parentNoLinkClient: TestClient;
  let adminClient: TestClient;
  let questionId: string;

  beforeAll(async () => {
    if (skipIfNoSupabase()) return;
    if (!serviceClient) throw new Error("Service client not initialized");

    studentClient = await createClientAs("student");
    otherStudentClient = await createClientAs("student");
    parentClient = await createClientAs("parent");
    parentNoLinkClient = await createClientAs("parent");
    adminClient = await createClientAs("admin");

    const { data: question, error: questionError } = await serviceClient
      .from("questions")
      .insert({
        subject: "math",
        module: "algebra",
        difficulty: 1,
        question_type: "mcq",
        stem: `Study behavior test ${Date.now()}`,
        answer_key: { correct: "A" },
      })
      .select("id")
      .single();

    if (questionError) throw questionError;
    questionId = question.id;

    await seedAttempt(studentClient.userId, true, 60000);
    await seedAttempt(otherStudentClient.userId, false, 45000);

    const { error: linkError } = await serviceClient.from("parent_student_links").insert({
      parent_id: parentClient.userId,
      student_id: studentClient.userId,
      status: "active",
    });

    if (linkError) throw linkError;
  });

  async function seedAttempt(studentId: string, isCorrect: boolean, durationMs: number) {
    if (!serviceClient) throw new Error("Service client not initialized");

    const { data: session, error: sessionError } = await serviceClient
      .from("sessions")
      .insert({
        student_id: studentId,
        mode: "practice",
        total_questions: 1,
        correct_count: isCorrect ? 1 : 0,
      })
      .select("id")
      .single();

    if (sessionError) throw sessionError;

    const { error: attemptError } = await serviceClient.from("attempts").insert({
      session_id: session.id,
      question_id: questionId,
      student_id: studentId,
      answer: { selected: "A" },
      is_correct: isCorrect,
      duration_ms: durationMs,
      skipped: false,
    });

    if (attemptError) throw attemptError;
  }

  it("allows students to read their own behavior", async () => {
    if (skipIfNoSupabase()) return;

    const { data, error } = await studentClient.rpc("get_study_behavior", {
      target_student_id: studentClient.userId,
      window_days: 7,
      history_weeks: 4,
    });

    expect(error).toBeNull();
    expect(data?.student_id).toBe(studentClient.userId);
  });

  it("prevents students from reading other students", async () => {
    if (skipIfNoSupabase()) return;

    const { error } = await studentClient.rpc("get_study_behavior", {
      target_student_id: otherStudentClient.userId,
      window_days: 7,
      history_weeks: 4,
    });

    expect(error).not.toBeNull();
  });

  it("allows linked parents to read behavior", async () => {
    if (skipIfNoSupabase()) return;

    const { data, error } = await parentClient.rpc("get_study_behavior", {
      target_student_id: studentClient.userId,
      window_days: 7,
      history_weeks: 4,
    });

    expect(error).toBeNull();
    expect(data?.student_id).toBe(studentClient.userId);
  });

  it("blocks unlinked parents", async () => {
    if (skipIfNoSupabase()) return;

    const { error } = await parentNoLinkClient.rpc("get_study_behavior", {
      target_student_id: studentClient.userId,
      window_days: 7,
      history_weeks: 4,
    });

    expect(error).not.toBeNull();
  });

  it("allows admins to read behavior", async () => {
    if (skipIfNoSupabase()) return;

    const { data, error } = await adminClient.rpc("get_study_behavior", {
      target_student_id: studentClient.userId,
      window_days: 7,
      history_weeks: 4,
    });

    expect(error).toBeNull();
    expect(data?.student_id).toBe(studentClient.userId);
  });
});
