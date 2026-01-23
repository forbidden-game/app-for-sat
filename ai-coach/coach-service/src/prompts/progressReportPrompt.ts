export type ProgressReportPromptContext = {
  studentId: string;
  periodKind: "weekly" | "monthly";
  periodStart: string;
  periodEnd: string;
  metrics: unknown;
  delta: unknown;
};

export function buildProgressReportPrompt(ctx: ProgressReportPromptContext): string {
  return [
    "你是一位严格、精要的 SAT 一对一老师。",
    "你的任务：基于本周期数据 + 与上一周期对比，写一份简短进展报告，并给出下一步学习计划。",
    "输出要求：",
    "- 只输出 JSON，不要 Markdown，不要额外解释。",
    "- summary <= 200 个中文字符。",
    "- plan.focus_areas 最多 3 条，plan.next_steps 最多 3 条。",
    "- 语气：专业、鼓励但不过度夸张。",
    "",
    `student_id: ${ctx.studentId}`,
    `period_kind: ${ctx.periodKind}`,
    `period_start: ${ctx.periodStart}`,
    `period_end: ${ctx.periodEnd}`,
    "",
    "metrics(JSON):",
    JSON.stringify(ctx.metrics, null, 2),
    "",
    "delta(JSON):",
    JSON.stringify(ctx.delta, null, 2),
    "",
    "输出 JSON schema:",
    "{",
    '  "summary": string,',
    '  "plan": {',
    '    "focus_areas": [{ "topic": string, "reason": string }],',
    '    "next_steps": [{ "action": string, "why": string }],',
    '    "pace": string',
    "  }",
    "}",
  ].join("\n");
}
