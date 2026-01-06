import { describe, it, expect, beforeAll } from "vitest";
import { createClientAs, skipIfNoSupabase, TestClient } from "@test/helpers";

describe("Attempts RLS", () => {
  beforeAll(() => {
    if (skipIfNoSupabase()) return;
  });

  describe("student role", () => {
    let studentClient: TestClient;

    beforeAll(async () => {
      if (skipIfNoSupabase()) return;
      studentClient = await createClientAs("student");
    });

    it("can only read own attempts", async () => {
      if (skipIfNoSupabase()) return;

      const { data, error } = await studentClient.from("attempts").select("*");

      expect(error).toBeNull();
      if (data && data.length > 0) {
        expect(data.every((a) => a.student_id === studentClient.userId)).toBe(true);
      }
    });

    it("cannot read other students attempts", async () => {
      if (skipIfNoSupabase()) return;

      const { data, error } = await studentClient
        .from("attempts")
        .select("*")
        .neq("student_id", studentClient.userId);

      expect(error).toBeNull();
      expect(data).toEqual([]);
    });

    it("cannot insert attempts directly", async () => {
      if (skipIfNoSupabase()) return;

      const { error } = await studentClient.from("attempts").insert({
        session_id: "00000000-0000-0000-0000-000000000000",
        question_id: "00000000-0000-0000-0000-000000000000",
        student_id: studentClient.userId,
        answer: { selected: "A" },
        is_correct: true,
      });

      expect(error).not.toBeNull();
    });
  });

  describe("admin role", () => {
    let adminClient: TestClient;

    beforeAll(async () => {
      if (skipIfNoSupabase()) return;
      adminClient = await createClientAs("admin");
    });

    it("can read all attempts", async () => {
      if (skipIfNoSupabase()) return;

      const { data, error } = await adminClient.from("attempts").select("*");

      expect(error).toBeNull();
      expect(data).not.toBeNull();
    });
  });
});
