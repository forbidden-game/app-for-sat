import { describe, expect, it } from "vitest";
import { parseImportText } from "./questionImport";

describe("parseImportText", () => {
  it("parses CSV into payload", () => {
    const csv = `subject,module,difficulty,question_type,stem,answer_key,options,tags,metadata
math,algebra,2,mcq,"What is 2 + 2?",B,"[{""label"":""A"",""content"":""3""},{""label"":""B"",""content"":""4""}]",tag1;tag2,"{""source"":""sample""}"
`;

    const result = parseImportText(csv, "csv");

    expect(result.errors).toHaveLength(0);
    expect(result.payload?.questions).toHaveLength(1);
    expect(result.payload?.questions[0].options?.length).toBe(2);
    expect(result.payload?.questions[0].tags?.length).toBe(2);
  });

  it("reports missing required columns", () => {
    const csv = `subject,module,stem
math,algebra,Missing columns`;

    const result = parseImportText(csv, "csv");

    expect(result.payload).toBeNull();
    expect(result.errors[0].message).toContain("Missing required columns");
  });

  it("parses JSON payload", () => {
    const json = JSON.stringify({
      questions: [
        {
          subject: "math",
          module: "algebra",
          difficulty: 3,
          question_type: "numeric",
          stem: "Solve 5x = 20",
          answer_key: { correct: 4 },
        },
      ],
    });

    const result = parseImportText(json, "json");

    expect(result.errors).toHaveLength(0);
    expect(result.payload?.questions).toHaveLength(1);
    expect(result.payload?.questions[0].answer_key.correct).toBe(4);
  });
});
