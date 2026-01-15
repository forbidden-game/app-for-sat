import { describe, it, expect, beforeAll, beforeEach } from "vitest";
import {
  listQuestions,
  getQuestion,
  createQuestion,
  updateQuestion,
  deleteQuestion,
  listQuestionTypes,
} from "../actions";
import { skipIfNoSupabase, getAdminClient, TestClient } from "@test/helpers";
import { questionFactory } from "@test/fixtures";

describe("Questions Actions", () => {
  let adminClient: TestClient;
  let accessToken: string;

  beforeAll(async () => {
    if (skipIfNoSupabase()) return;
    adminClient = await getAdminClient();
    const session = await adminClient.auth.getSession();
    accessToken = session.data.session?.access_token ?? "";
  });

  describe("listQuestionTypes", () => {
    it("returns available question types", async () => {
      if (skipIfNoSupabase()) return;

      const types = await listQuestionTypes(accessToken);

      expect(Array.isArray(types)).toBe(true);
      expect(types.length).toBeGreaterThan(0);
      expect(types.some((t) => t.name === "mcq")).toBe(true);
    });
  });

  describe("createQuestion", () => {
    it("creates MCQ question with options", async () => {
      if (skipIfNoSupabase()) return;

      const input = questionFactory.mcq({ stem: "Integration test MCQ" });
      const options = input.options ?? [];

      await createQuestion(
        accessToken,
        {
          subject: input.subject!,
          module: input.module!,
          difficulty: input.difficulty!,
          question_type: input.question_type!,
          stem: input.stem!,
          answer_key: input.answer_key!,
        },
        options,
        []
      );

      expect(question.id).toBeDefined();
      expect(question.stem).toBe("Integration test MCQ");
      expect(question.question_type).toBe("mcq");
      expect(question.options?.length).toBe(4);
    });

    it("creates numeric question", async () => {
      if (skipIfNoSupabase()) return;

      const input = questionFactory.numeric({ stem: "Integration test numeric" });

      await createQuestion(
        accessToken,
        {
          subject: input.subject!,
          module: input.module!,
          difficulty: input.difficulty!,
          question_type: input.question_type!,
          stem: input.stem!,
          answer_key: input.answer_key!,
        },
        [],
        []
      );

      expect(question.id).toBeDefined();
      expect(question.question_type).toBe("numeric");
      expect(question.answer_key).toEqual({ correct: 42 });
    });

    it("throws error for missing stem", async () => {
      if (skipIfNoSupabase()) return;

      await expect(
        createQuestion(
          accessToken,
          {
            subject: "Math",
            module: "Algebra",
            difficulty: 3,
            question_type: "mcq",
            stem: "",
            answer_key: { correct: "A" },
          },
          [],
          []
        )
      ).rejects.toThrow("Question stem is required");
    });

    it("throws error for invalid difficulty", async () => {
      if (skipIfNoSupabase()) return;

      await expect(
        createQuestion(
          accessToken,
          {
            subject: "Math",
            module: "Algebra",
            difficulty: 10,
            question_type: "mcq",
            stem: "Test",
            answer_key: { correct: "A" },
          },
          [],
          []
        )
      ).rejects.toThrow("Difficulty must be between 1 and 5");
    });
  });

  describe("listQuestions", () => {
    beforeEach(async () => {
      if (skipIfNoSupabase()) return;

      const input = questionFactory.mcq({
        stem: `List test question ${Date.now()}`,
        subject: "TestSubject",
      });

      await createQuestion(
        accessToken,
        {
          subject: input.subject!,
          module: input.module!,
          difficulty: input.difficulty!,
          question_type: input.question_type!,
          stem: input.stem!,
          answer_key: input.answer_key!,
        },
        input.options ?? [],
        []
      );
    });

    it("returns paginated questions", async () => {
      if (skipIfNoSupabase()) return;

      const result = await listQuestions(accessToken, { page: 1, pageSize: 10 });

      expect(result.questions).toBeDefined();
      expect(Array.isArray(result.questions)).toBe(true);
      expect(result.page).toBe(1);
      expect(result.pageSize).toBe(10);
      expect(result.total).toBeGreaterThan(0);
    });

    it("filters by subject", async () => {
      if (skipIfNoSupabase()) return;

      const result = await listQuestions(accessToken, {
        subject: "TestSubject",
        page: 1,
      });

      expect(result.questions.every((q) => q.subject === "TestSubject")).toBe(true);
    });

    it("searches by stem", async () => {
      if (skipIfNoSupabase()) return;

      const result = await listQuestions(accessToken, {
        search: "List test question",
        page: 1,
      });

      expect(result.questions.length).toBeGreaterThan(0);
      expect(result.questions.some((q) => q.stem.includes("List test question"))).toBe(
        true
      );
    });
  });

  describe("getQuestion", () => {
    it("returns question with options and tags", async () => {
      if (skipIfNoSupabase()) return;

      const input = questionFactory.mcq({ stem: "Get test question" });
      const created = await createQuestion(
        accessToken,
        {
          subject: input.subject!,
          module: input.module!,
          difficulty: input.difficulty!,
          question_type: input.question_type!,
          stem: input.stem!,
          answer_key: input.answer_key!,
        },
        input.options ?? [],
        []
      );

      const question = await getQuestion(accessToken, created.id);

      expect(question.id).toBe(created.id);
      expect(question.stem).toBe("Get test question");
      expect(question.options?.length).toBe(4);
    });

    it("throws error for non-existent question", async () => {
      if (skipIfNoSupabase()) return;

      await expect(
        getQuestion(accessToken, "00000000-0000-0000-0000-000000000000")
      ).rejects.toThrow();
    });
  });

  describe("updateQuestion", () => {
    it("updates question fields", async () => {
      if (skipIfNoSupabase()) return;

      const input = questionFactory.mcq({ stem: "Before update" });
      const created = await createQuestion(
        accessToken,
        {
          subject: input.subject!,
          module: input.module!,
          difficulty: input.difficulty!,
          question_type: input.question_type!,
          stem: input.stem!,
          answer_key: input.answer_key!,
        },
        input.options ?? [],
        []
      );

      const updated = await updateQuestion(
        accessToken,
        created.id,
        {
          subject: "UpdatedSubject",
          module: input.module!,
          difficulty: 5,
          question_type: input.question_type!,
          stem: "After update",
          answer_key: { correct: "B" },
        },
        input.options ?? [],
        []
      );

      expect(updated.stem).toBe("After update");
      expect(updated.subject).toBe("UpdatedSubject");
      expect(updated.difficulty).toBe(5);
      expect(updated.answer_key).toEqual({ correct: "B" });
    });
  });

  describe("deleteQuestion", () => {
    it("deletes question successfully", async () => {
      if (skipIfNoSupabase()) return;

      const input = questionFactory.mcq({ stem: "To be deleted" });
      const created = await createQuestion(
        accessToken,
        {
          subject: input.subject!,
          module: input.module!,
          difficulty: input.difficulty!,
          question_type: input.question_type!,
          stem: input.stem!,
          answer_key: input.answer_key!,
        },
        [],
        []
      );

      await deleteQuestion(accessToken, created.id);

      await expect(getQuestion(accessToken, created.id)).rejects.toThrow();
    });
  });
});
