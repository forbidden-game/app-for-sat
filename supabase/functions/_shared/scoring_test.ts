import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { scoreAttempt } from "./scoring.ts";

Deno.test("scoreAttempt - mcq correct", () => {
  const result = scoreAttempt(
    { questionType: "mcq", answerKey: { correct: "B" } },
    { answer: "B" },
  );
  assertEquals(result.isCorrect, true);
});

Deno.test("scoreAttempt - numeric correct", () => {
  const result = scoreAttempt(
    { questionType: "numeric", answerKey: { correct: 12 } },
    { answer: 12 },
  );
  assertEquals(result.isCorrect, true);
});
