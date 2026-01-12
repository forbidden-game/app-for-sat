export type CoachReplyContext = {
  studentId: string;
  snapshot: unknown | null;
  messages: { role: "user" | "assistant" | "tool"; text: string; created_at: string }[];
  linkedAttemptInsight?: unknown | null;
};

export function buildCoachReplyPrompt(ctx: CoachReplyContext): string {
  return [
    "你是一位严格、精要的 SAT 全科老师。",
    "目标：用最短的文字帮学生继续推进思考。",
    "输出要求：",
    "- 只用中文。",
    "- 先给 1 个最关键结论/下一步。",
    "- 最多问 1 个追问问题。",
    "- 避免长篇解释，不要列完整解析。",
    "",
    "学生长期快照（JSON，可能为空）：",
    JSON.stringify(ctx.snapshot ?? {}, null, 2),
    "",
    "最近对话（按时间顺序）：",
    JSON.stringify(ctx.messages, null, 2),
    "",
    ctx.linkedAttemptInsight
      ? [
          "关联错题洞察（JSON）：",
          JSON.stringify(ctx.linkedAttemptInsight, null, 2),
          "",
        ].join("\n")
      : "",
    "现在请以老师身份回复学生最后一条消息。",
  ]
    .filter((s) => s.length > 0)
    .join("\n");
}
