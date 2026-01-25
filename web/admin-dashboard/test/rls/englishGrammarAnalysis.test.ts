import { describe, it, expect, beforeAll } from "vitest";
import { createClientAs, skipIfNoSupabase, TestClient } from "@test/helpers";
import { serviceClient } from "@test/setup";

describe("English Grammar Analysis RPC", () => {
  let studentClient: TestClient;
  let questionId: string;

  beforeAll(async () => {
    if (skipIfNoSupabase()) return;
    if (!serviceClient) throw new Error("Service client not initialized");

    studentClient = await createClientAs("student");

    const { data, error } = await serviceClient
      .from("questions")
      .insert({
        subject: "reading",
        module: "Passages",
        difficulty: 1,
        question_type: "mcq",
        stem: `Grammar analysis test ${Date.now()}`,
        answer_key: { correct: "A" },
      })
      .select("id")
      .single();

    if (error) throw error;
    questionId = data.id;
  });

  it("can be called repeatedly without ambiguity errors", async () => {
    if (skipIfNoSupabase()) return;

    const first = await studentClient.rpc("request_english_grammar_analysis", {
      p_question_id: questionId,
    });

    expect(first.error).toBeNull();
    expect(first.data?.[0]?.question_id).toBe(questionId);

    const second = await studentClient.rpc("request_english_grammar_analysis", {
      p_question_id: questionId,
    });

    expect(second.error).toBeNull();
    expect(second.data?.[0]?.question_id).toBe(questionId);

    const { data: rows, error: readError } = await studentClient
      .from("english_grammar_analyses")
      .select("status")
      .eq("question_id", questionId);

    expect(readError).toBeNull();
    expect(rows && rows.length).toBeGreaterThan(0);
  });
});
