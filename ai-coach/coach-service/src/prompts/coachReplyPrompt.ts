import type { CoachContextPacket } from "../context/coachContext.js";

export type CoachReplyToMessage = {
  id: string;
  role: "user" | "assistant" | "tool";
  text: string;
};

export type CoachReplyTargetMessage = {
  id: string;
  text: string;
  reply_to?: CoachReplyToMessage | null;
} | null;

export function buildCoachReplyPrompt(
  ctx: CoachContextPacket,
  target?: CoachReplyTargetMessage,
): string {
  return [
    "你是一位严格、精要的 SAT 全科老师。",
    "目标：用最短的文字帮助学生继续推进思考。",
    "优先使用学生个人数据库（长期快照 + 最近报告 + 历史错题）。",
    "输出要求：",
    "- 只用中文。",
    "- 先给 1 个最关键结论/下一步。",
    "- 最多问 1 个追问问题。",
    "- 避免长篇解释，不要列完整解析。",
    "",
    "学生状态信号（JSON）：",
    JSON.stringify(ctx.student ?? {}, null, 2),
    "",
    "学生长期快照（JSON，可能为空）：",
    JSON.stringify(ctx.snapshot ?? {}, null, 2),
    "",
    "最近进展报告（JSON，最多 2 条）：",
    JSON.stringify(ctx.reports ?? [], null, 2),
    "",
    "最近错题洞察（JSON，最多 5 条）：",
    JSON.stringify(ctx.recent_insights ?? [], null, 2),
    "",
    "最近对话（按时间顺序）：",
    JSON.stringify(ctx.recent_messages ?? [], null, 2),
    "",
    ctx.attempt && ctx.question
      ? [
          "关联错题上下文（JSON）：",
          JSON.stringify({ attempt: ctx.attempt, question: ctx.question }, null, 2),
          "",
        ].join("\n")
      : "",
    ctx.linked_attempt_insight
      ? ["关联错题洞察（JSON）：", JSON.stringify(ctx.linked_attempt_insight, null, 2), ""].join(
          "\n",
        )
      : "",
    target
      ? ["本次目标用户消息（必须回复这一条）：", JSON.stringify(target, null, 2), ""].join("\n")
      : "",
    target ? "现在请以老师身份回复目标用户消息。" : "现在请以老师身份回复学生最后一条消息。",
  ]
    .filter((s) => s.length > 0)
    .join("\n");
}
