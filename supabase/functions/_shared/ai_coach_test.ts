import { assertEquals, assertStringIncludes } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { buildAttemptInsightDraft, buildCoachReplyDraft } from "./ai_coach.ts";

Deno.test("buildAttemptInsightDraft uses selected step", () => {
  const draft = buildAttemptInsightDraft({
    attempt: {
      id: "A1",
      student_id: "S1",
      question_id: "Q1",
      answer: "B",
      student_selected_step_index: 2,
      student_selected_step_is_unknown: false,
    },
    question: {
      id: "Q1",
      subject: "math",
      question_type: "mcq",
      stem: "2 + 2 = ?",
      answer_key: { correct: "B" },
      options: null,
    },
  });

  assertEquals(draft.errorStepIndex, 2);
  assertStringIncludes(draft.explanationShort, "step 3");
});

Deno.test("buildAttemptInsightDraft handles unknown step", () => {
  const draft = buildAttemptInsightDraft({
    attempt: {
      id: "A2",
      student_id: "S2",
      question_id: "Q2",
      answer: "A",
      student_selected_step_index: null,
      student_selected_step_is_unknown: true,
    },
    question: {
      id: "Q2",
      subject: "math",
      question_type: "mcq",
      stem: "x + 1 = 2",
      answer_key: { correct: "B" },
      options: null,
    },
  });

  assertEquals(draft.errorStepIndex, 0);
  assertStringIncludes(draft.explanationShort, "unsure");
});

Deno.test("buildCoachReplyDraft includes context hint", () => {
  const reply = buildCoachReplyDraft({
    userText: "I do not understand the setup.",
    linkedAttemptId: "A3",
  });

  assertStringIncludes(reply.text, "linked attempt");
  assertEquals(reply.chunks.length, 2);
});
