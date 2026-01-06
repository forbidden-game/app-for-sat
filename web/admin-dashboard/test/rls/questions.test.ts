import { describe, it, expect, beforeAll } from "vitest";
import { createClientAs, skipIfNoSupabase, TestClient } from "@test/helpers";

describe("Questions RLS", () => {
  beforeAll(() => {
    if (skipIfNoSupabase()) return;
  });

  describe("student role", () => {
    let studentClient: TestClient;

    beforeAll(async () => {
      if (skipIfNoSupabase()) return;
      studentClient = await createClientAs("student");
    });

    it("cannot read questions directly", async () => {
      if (skipIfNoSupabase()) return;

      const { data, error } = await studentClient.from("questions").select("*");

      expect(error).toBeNull();
      expect(data).toEqual([]);
    });

    it("cannot insert questions", async () => {
      if (skipIfNoSupabase()) return;

      const { error } = await studentClient.from("questions").insert({
        stem: "Unauthorized question",
        subject: "Math",
        module: "Algebra",
        difficulty: 1,
        question_type: "mcq",
        answer_key: { correct: "A" },
      });

      expect(error).not.toBeNull();
    });

    it("cannot update questions", async () => {
      if (skipIfNoSupabase()) return;

      const { error } = await studentClient
        .from("questions")
        .update({ stem: "Hacked" })
        .eq("subject", "Math");

      expect(error).toBeNull();
    });

    it("cannot delete questions", async () => {
      if (skipIfNoSupabase()) return;

      const { error } = await studentClient
        .from("questions")
        .delete()
        .eq("subject", "Math");

      expect(error).toBeNull();
    });
  });

  describe("admin role", () => {
    let adminClient: TestClient;

    beforeAll(async () => {
      if (skipIfNoSupabase()) return;
      adminClient = await createClientAs("admin");
    });

    it("can read all questions", async () => {
      if (skipIfNoSupabase()) return;

      const { data, error } = await adminClient.from("questions").select("*");

      expect(error).toBeNull();
      expect(data).not.toBeNull();
    });

    it("can create questions", async () => {
      if (skipIfNoSupabase()) return;

      const { data, error } = await adminClient
        .from("questions")
        .insert({
          stem: `RLS test question ${Date.now()}`,
          subject: "Math",
          module: "Algebra",
          difficulty: 1,
          question_type: "mcq",
          answer_key: { correct: "A" },
        })
        .select()
        .single();

      expect(error).toBeNull();
      expect(data?.stem).toContain("RLS test question");
    });
  });
});
