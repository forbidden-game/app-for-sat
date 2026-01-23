import { describe, expect, it } from "vitest";

import { Agent } from "@mariozechner/pi-agent-core";

import { processCoachReplyJob } from "../src/jobs/processCoachReplyJob.js";
import { resolveModel } from "../src/model.js";
import { createSupabaseMock, makeConfig } from "./helpers.js";

class StubAgent {
  prompts: string[] = [];
  private listeners: Array<(event: any) => void> = [];

  subscribe(fn: (event: any) => void) {
    this.listeners.push(fn);
    return () => {
      this.listeners = this.listeners.filter((listener) => listener !== fn);
    };
  }

  async prompt(text: string): Promise<void> {
    this.prompts.push(text);
    for (const listener of this.listeners) {
      listener({
        type: "message_update",
        assistantMessageEvent: { type: "text_delta", delta: "OK" },
      });
    }
  }
}

describe("processCoachReplyJob", () => {
  it("throws when student_id missing", async () => {
    const agent = new StubAgent();
    const { supabase } = createSupabaseMock();

    await expect(
      processCoachReplyJob(supabase, agent as any, { id: "job", kind: "coach_reply" } as any),
    ).rejects.toThrow(/missing student_id/);
  });

  it("inserts assistant message", async () => {
    const agent = new StubAgent();
    const { supabase, calls } = createSupabaseMock({
      from: {
        student_snapshots: { select: [{ data: null, error: null }] },
        student_reports: { select: [{ data: [], error: null }] },
        attempt_insights: { select: [{ data: [], error: null }] },
        coach_thread_messages: {
          select: [
            {
              data: [
                {
                  id: "msg1",
                  student_id: "s1",
                  role: "user",
                  content: { text: "hi" },
                  created_at: "2025-01-01",
                },
              ],
              error: null,
            },
          ],
          insert: [{ data: { id: "assistant-1" }, error: null }],
          update: [{ data: null, error: null }],
        },
      },
    });

    await processCoachReplyJob(
      supabase,
      agent as any,
      { id: "job", kind: "coach_reply", student_id: "s1", payload: {} } as any,
    );

    const insertCall = calls.from.find(
      (call) => call.table === "coach_thread_messages" && call.action === "insert",
    );
    expect(insertCall).toBeTruthy();
  });

  it("updates assistant message with streaming content", async () => {
    const agent = new StubAgent();
    const { supabase, calls } = createSupabaseMock({
      from: {
        student_snapshots: { select: [{ data: null, error: null }] },
        student_reports: { select: [{ data: [], error: null }] },
        attempt_insights: { select: [{ data: [], error: null }] },
        coach_thread_messages: {
          select: [
            {
              data: [
                {
                  id: "msg1",
                  student_id: "s1",
                  role: "user",
                  content: { text: "hi" },
                  created_at: "2025-01-01",
                },
              ],
              error: null,
            },
          ],
          insert: [{ data: { id: "assistant-1" }, error: null }],
          update: [
            { data: null, error: null },
            { data: null, error: null },
          ],
        },
      },
    });

    await processCoachReplyJob(
      supabase,
      agent as any,
      { id: "job", kind: "coach_reply", student_id: "s1", payload: {} } as any,
    );

    const updateCalls = calls.from.filter(
      (call) => call.table === "coach_thread_messages" && call.action === "update",
    );
    expect(updateCalls.length).toBeGreaterThan(0);
  });

  it("includes snapshot in prompt", async () => {
    const agent = new StubAgent();
    const snapshot = { student_id: "s1", notes: "weak algebra" };
    const { supabase } = createSupabaseMock({
      from: {
        student_snapshots: { select: [{ data: snapshot, error: null }] },
        student_reports: { select: [{ data: [], error: null }] },
        attempt_insights: { select: [{ data: [], error: null }] },
        coach_thread_messages: {
          select: [
            {
              data: [
                {
                  id: "msg1",
                  student_id: "s1",
                  role: "user",
                  content: { text: "hi" },
                  created_at: "2025-01-01",
                },
              ],
              error: null,
            },
          ],
          insert: [{ data: { id: "assistant-1" }, error: null }],
          update: [{ data: null, error: null }],
        },
      },
    });

    await processCoachReplyJob(
      supabase,
      agent as any,
      { id: "job", kind: "coach_reply", student_id: "s1", payload: {} } as any,
    );

    expect(agent.prompts[0]).toContain("weak algebra");
  });

  it("includes reports in prompt", async () => {
    const agent = new StubAgent();
    const reports = [{ id: "r1", summary: "report" }];
    const { supabase } = createSupabaseMock({
      from: {
        student_snapshots: { select: [{ data: null, error: null }] },
        student_reports: { select: [{ data: reports, error: null }] },
        attempt_insights: { select: [{ data: [], error: null }] },
        coach_thread_messages: {
          select: [
            {
              data: [
                {
                  id: "msg1",
                  student_id: "s1",
                  role: "user",
                  content: { text: "hi" },
                  created_at: "2025-01-01",
                },
              ],
              error: null,
            },
          ],
          insert: [{ data: { id: "assistant-1" }, error: null }],
          update: [{ data: null, error: null }],
        },
      },
    });

    await processCoachReplyJob(
      supabase,
      agent as any,
      { id: "job", kind: "coach_reply", student_id: "s1", payload: {} } as any,
    );

    expect(agent.prompts[0]).toContain("report");
  });

  it("includes recent insights in prompt", async () => {
    const agent = new StubAgent();
    const insights = [{ attempt_id: "a1", explanation_short: "oops" }];
    const { supabase } = createSupabaseMock({
      from: {
        student_snapshots: { select: [{ data: null, error: null }] },
        student_reports: { select: [{ data: [], error: null }] },
        attempt_insights: { select: [{ data: insights, error: null }] },
        coach_thread_messages: {
          select: [
            {
              data: [
                {
                  id: "msg1",
                  student_id: "s1",
                  role: "user",
                  content: { text: "hi" },
                  created_at: "2025-01-01",
                },
              ],
              error: null,
            },
          ],
          insert: [{ data: { id: "assistant-1" }, error: null }],
          update: [{ data: null, error: null }],
        },
      },
    });

    await processCoachReplyJob(
      supabase,
      agent as any,
      { id: "job", kind: "coach_reply", student_id: "s1", payload: {} } as any,
    );

    expect(agent.prompts[0]).toContain("oops");
  });

  it("includes linked attempt insight when provided", async () => {
    const agent = new StubAgent();
    const linked = { attempt_id: "a1", explanation_short: "linked" };
    const { supabase } = createSupabaseMock({
      from: {
        student_snapshots: { select: [{ data: null, error: null }] },
        student_reports: { select: [{ data: [], error: null }] },
        attempt_insights: {
          select: [
            { data: [], error: null },
            { data: linked, error: null },
          ],
        },
        coach_thread_messages: {
          select: [
            {
              data: [
                {
                  id: "msg1",
                  student_id: "s1",
                  role: "user",
                  content: { text: "hi" },
                  created_at: "2025-01-01",
                },
              ],
              error: null,
            },
          ],
          insert: [{ data: { id: "assistant-1" }, error: null }],
          update: [{ data: null, error: null }],
        },
      },
    });

    await processCoachReplyJob(
      supabase,
      agent as any,
      {
        id: "job",
        kind: "coach_reply",
        student_id: "s1",
        payload: { linked_attempt_id: "a1" },
      } as any,
    );

    expect(agent.prompts[0]).toContain("linked");
  });

  it("replies to user_message_id when provided", async () => {
    const agent = new StubAgent();

    const targetRow = {
      id: "msg-target",
      student_id: "s1",
      role: "user",
      content: { text: "hi target" },
      created_at: "2025-01-02T00:00:00.000Z",
      linked_attempt_id: null,
    };

    const { supabase } = createSupabaseMock({
      from: {
        student_snapshots: { select: [{ data: null, error: null }] },
        student_reports: { select: [{ data: [], error: null }] },
        attempt_insights: { select: [{ data: [], error: null }] },
        coach_thread_messages: {
          select: [
            { data: targetRow, error: null },
            { data: [targetRow], error: null },
          ],
          insert: [{ data: { id: "assistant-1" }, error: null }],
          update: [
            { data: null, error: null },
            { data: null, error: null },
          ],
        },
      },
    });

    await processCoachReplyJob(
      supabase,
      agent as any,
      {
        id: "job",
        kind: "coach_reply",
        student_id: "s1",
        payload: { user_message_id: "msg-target" },
      } as any,
    );

    expect(agent.prompts[0]).toContain("msg-target");
    expect(agent.prompts[0]).toContain("hi target");
  });

  it("skips linked insight lookup when none", async () => {
    const agent = new StubAgent();
    const { supabase, calls } = createSupabaseMock({
      from: {
        student_snapshots: { select: [{ data: null, error: null }] },
        student_reports: { select: [{ data: [], error: null }] },
        attempt_insights: { select: [{ data: [], error: null }] },
        coach_thread_messages: {
          select: [
            {
              data: [
                {
                  id: "msg1",
                  student_id: "s1",
                  role: "user",
                  content: { text: "hi" },
                  created_at: "2025-01-01",
                },
              ],
              error: null,
            },
          ],
          insert: [{ data: { id: "assistant-1" }, error: null }],
          update: [{ data: null, error: null }],
        },
      },
    });

    await processCoachReplyJob(
      supabase,
      agent as any,
      { id: "job", kind: "coach_reply", student_id: "s1", payload: {} } as any,
    );

    const linkedCalls = calls.from.filter(
      (call) => call.table === "attempt_insights" && call.action === "select",
    );
    expect(linkedCalls).toHaveLength(1);
  });

  it("handles missing snapshot", async () => {
    const agent = new StubAgent();
    const { supabase } = createSupabaseMock({
      from: {
        student_snapshots: { select: [{ data: null, error: null }] },
        student_reports: { select: [{ data: [], error: null }] },
        attempt_insights: { select: [{ data: [], error: null }] },
        coach_thread_messages: {
          select: [
            {
              data: [
                {
                  id: "msg1",
                  student_id: "s1",
                  role: "user",
                  content: { text: "hi" },
                  created_at: "2025-01-01",
                },
              ],
              error: null,
            },
          ],
          insert: [{ data: { id: "assistant-1" }, error: null }],
          update: [{ data: null, error: null }],
        },
      },
    });

    await processCoachReplyJob(
      supabase,
      agent as any,
      { id: "job", kind: "coach_reply", student_id: "s1", payload: {} } as any,
    );

    expect(agent.prompts[0]).toContain("学生长期快照");
  });

  it("handles empty messages", async () => {
    const agent = new StubAgent();
    const { supabase } = createSupabaseMock({
      from: {
        student_snapshots: { select: [{ data: null, error: null }] },
        student_reports: { select: [{ data: [], error: null }] },
        attempt_insights: { select: [{ data: [], error: null }] },
        coach_thread_messages: {
          select: [{ data: [], error: null }],
          insert: [{ data: { id: "assistant-1" }, error: null }],
          update: [{ data: null, error: null }],
        },
      },
    });

    await processCoachReplyJob(
      supabase,
      agent as any,
      { id: "job", kind: "coach_reply", student_id: "s1", payload: {} } as any,
    );

    expect(agent.prompts[0]).toContain("最近对话");
  });

  it("throws when insert fails", async () => {
    const agent = new StubAgent();
    const { supabase } = createSupabaseMock({
      from: {
        student_snapshots: { select: [{ data: null, error: null }] },
        student_reports: { select: [{ data: [], error: null }] },
        attempt_insights: { select: [{ data: [], error: null }] },
        coach_thread_messages: {
          select: [
            {
              data: [
                {
                  id: "msg1",
                  student_id: "s1",
                  role: "user",
                  content: { text: "hi" },
                  created_at: "2025-01-01",
                },
              ],
              error: null,
            },
          ],
          insert: [{ data: null, error: { message: "insert_failed" } }],
        },
      },
    });

    await expect(
      processCoachReplyJob(
        supabase,
        agent as any,
        { id: "job", kind: "coach_reply", student_id: "s1", payload: {} } as any,
      ),
    ).rejects.toThrow(/insert_failed/);
  });

  it("handles update error during streaming", async () => {
    const agent = new StubAgent();
    const { supabase } = createSupabaseMock({
      from: {
        student_snapshots: { select: [{ data: null, error: null }] },
        student_reports: { select: [{ data: [], error: null }] },
        attempt_insights: { select: [{ data: [], error: null }] },
        coach_thread_messages: {
          select: [
            {
              data: [
                {
                  id: "msg1",
                  student_id: "s1",
                  role: "user",
                  content: { text: "hi" },
                  created_at: "2025-01-01",
                },
              ],
              error: null,
            },
          ],
          insert: [{ data: { id: "assistant-1" }, error: null }],
          update: [{ data: null, error: { message: "update_failed" } }],
        },
      },
    });

    await processCoachReplyJob(
      supabase,
      agent as any,
      { id: "job", kind: "coach_reply", student_id: "s1", payload: {} } as any,
    );
  });

  it("handles agent failure with fallback", async () => {
    const agent = new StubAgent();
    agent.prompt = async () => {
      throw new Error("llm_failed");
    };
    const { supabase, calls } = createSupabaseMock({
      from: {
        student_snapshots: { select: [{ data: null, error: null }] },
        student_reports: { select: [{ data: [], error: null }] },
        attempt_insights: { select: [{ data: [], error: null }] },
        coach_thread_messages: {
          select: [
            {
              data: [
                {
                  id: "msg1",
                  student_id: "s1",
                  role: "user",
                  content: { text: "hi" },
                  created_at: "2025-01-01",
                },
              ],
              error: null,
            },
          ],
          insert: [{ data: { id: "assistant-1" }, error: null }],
          update: [{ data: null, error: null }],
        },
      },
    });

    await expect(
      processCoachReplyJob(
        supabase,
        agent as any,
        { id: "job", kind: "coach_reply", student_id: "s1", payload: {} } as any,
      ),
    ).rejects.toThrow(/llm_failed/);

    const updateCalls = calls.from.filter(
      (call) => call.table === "coach_thread_messages" && call.action === "update",
    );
    expect(updateCalls.length).toBeGreaterThan(0);
  });

  it("streams multiple deltas", async () => {
    const agent = new StubAgent();
    agent.prompt = async () => {
      agent.prompts.push("prompt");
      for (const delta of ["A", "B", "C"]) {
        for (const listener of (agent as any).listeners ?? []) {
          listener({
            type: "message_update",
            assistantMessageEvent: { type: "text_delta", delta },
          });
        }
      }
    };
    const { supabase, calls } = createSupabaseMock({
      from: {
        student_snapshots: { select: [{ data: null, error: null }] },
        student_reports: { select: [{ data: [], error: null }] },
        attempt_insights: { select: [{ data: [], error: null }] },
        coach_thread_messages: {
          select: [
            {
              data: [
                {
                  id: "msg1",
                  student_id: "s1",
                  role: "user",
                  content: { text: "hi" },
                  created_at: "2025-01-01",
                },
              ],
              error: null,
            },
          ],
          insert: [{ data: { id: "assistant-1" }, error: null }],
          update: [
            { data: null, error: null },
            { data: null, error: null },
            { data: null, error: null },
          ],
        },
      },
    });

    await processCoachReplyJob(
      supabase,
      agent as any,
      { id: "job", kind: "coach_reply", student_id: "s1", payload: {} } as any,
    );

    const updates = calls.from.filter(
      (call) => call.table === "coach_thread_messages" && call.action === "update",
    );
    expect(updates.length).toBeGreaterThan(1);
  });

  it("continues when snapshot query fails", async () => {
    const agent = new StubAgent();
    const { supabase } = createSupabaseMock({
      from: {
        student_snapshots: { select: [{ data: null, error: { message: "snapshot_failed" } }] },
        student_reports: { select: [{ data: [], error: null }] },
        attempt_insights: {
          select: [
            { data: [], error: null },
            { data: null, error: null },
          ],
        },
        coach_thread_messages: {
          select: [
            {
              data: [
                {
                  id: "msg1",
                  student_id: "s1",
                  role: "user",
                  content: { text: "hi" },
                  created_at: "2025-01-01",
                },
              ],
              error: null,
            },
          ],
          insert: [{ data: { id: "assistant-1" }, error: null }],
          update: [{ data: null, error: null }],
        },
      },
    });

    await processCoachReplyJob(
      supabase,
      agent as any,
      { id: "job", kind: "coach_reply", student_id: "s1", payload: {} } as any,
    );

    expect(agent.prompts[0]).toContain("学生状态信号");
  });

  it("continues when reports query fails", async () => {
    const agent = new StubAgent();
    const { supabase } = createSupabaseMock({
      from: {
        student_snapshots: { select: [{ data: null, error: null }] },
        student_reports: { select: [{ data: null, error: { message: "reports_failed" } }] },
        attempt_insights: {
          select: [
            { data: [], error: null },
            { data: null, error: null },
          ],
        },
        coach_thread_messages: {
          select: [
            {
              data: [
                {
                  id: "msg1",
                  student_id: "s1",
                  role: "user",
                  content: { text: "hi" },
                  created_at: "2025-01-01",
                },
              ],
              error: null,
            },
          ],
          insert: [{ data: { id: "assistant-1" }, error: null }],
          update: [{ data: null, error: null }],
        },
      },
    });

    await processCoachReplyJob(
      supabase,
      agent as any,
      { id: "job", kind: "coach_reply", student_id: "s1", payload: {} } as any,
    );

    expect(agent.prompts[0]).toContain("最近进展报告");
  });

  it("continues when insights query fails", async () => {
    const agent = new StubAgent();
    const { supabase } = createSupabaseMock({
      from: {
        student_snapshots: { select: [{ data: null, error: null }] },
        student_reports: { select: [{ data: [], error: null }] },
        attempt_insights: {
          select: [
            { data: null, error: { message: "insights_failed" } },
            { data: null, error: null },
          ],
        },
        coach_thread_messages: {
          select: [
            {
              data: [
                {
                  id: "msg1",
                  student_id: "s1",
                  role: "user",
                  content: { text: "hi" },
                  created_at: "2025-01-01",
                },
              ],
              error: null,
            },
          ],
          insert: [{ data: { id: "assistant-1" }, error: null }],
          update: [{ data: null, error: null }],
        },
      },
    });

    await processCoachReplyJob(
      supabase,
      agent as any,
      { id: "job", kind: "coach_reply", student_id: "s1", payload: {} } as any,
    );

    expect(agent.prompts[0]).toContain("最近错题洞察");
  });

  it("continues when messages query fails", async () => {
    const agent = new StubAgent();
    const { supabase } = createSupabaseMock({
      from: {
        student_snapshots: { select: [{ data: null, error: null }] },
        student_reports: { select: [{ data: [], error: null }] },
        attempt_insights: {
          select: [
            { data: [], error: null },
            { data: null, error: null },
          ],
        },
        coach_thread_messages: {
          select: [{ data: null, error: { message: "messages_failed" } }],
          insert: [{ data: { id: "assistant-1" }, error: null }],
          update: [{ data: null, error: null }],
        },
      },
    });

    await processCoachReplyJob(
      supabase,
      agent as any,
      { id: "job", kind: "coach_reply", student_id: "s1", payload: {} } as any,
    );

    expect(agent.prompts[0]).toContain("最近对话");
  });

  it("continues when linked insight fails", async () => {
    const agent = new StubAgent();
    const { supabase } = createSupabaseMock({
      from: {
        student_snapshots: { select: [{ data: null, error: null }] },
        student_reports: { select: [{ data: [], error: null }] },
        attempt_insights: {
          select: [
            { data: [], error: null },
            { data: null, error: { message: "linked_failed" } },
          ],
        },
        coach_thread_messages: {
          select: [
            {
              data: [
                {
                  id: "msg1",
                  student_id: "s1",
                  role: "user",
                  content: { text: "hi" },
                  created_at: "2025-01-01",
                },
              ],
              error: null,
            },
          ],
          insert: [{ data: { id: "assistant-1" }, error: null }],
          update: [{ data: null, error: null }],
        },
      },
    });

    await processCoachReplyJob(
      supabase,
      agent as any,
      {
        id: "job",
        kind: "coach_reply",
        student_id: "s1",
        payload: { linked_attempt_id: "a1" },
      } as any,
    );

    expect(agent.prompts[0]).toContain("最近对话");
  });

  const minimaxKey = process.env.MINIMAX_API_KEY;
  if (!minimaxKey) {
    it.skip("requires MINIMAX_API_KEY for LLM integration tests", () => {});
    return;
  }

  it("LLM integration inserts assistant reply", { timeout: 120_000 }, async () => {
    const model = resolveModel("minimax/MiniMax-M2.1", "minimax");
    const agent = new Agent({
      initialState: {
        systemPrompt: "你是老师。",
        model,
        thinkingLevel: "off",
        tools: [],
        messages: [],
      },
      getApiKey: async () => minimaxKey,
    });

    const { supabase, calls } = createSupabaseMock({
      from: {
        student_snapshots: { select: [{ data: null, error: null }] },
        student_reports: { select: [{ data: [], error: null }] },
        attempt_insights: { select: [{ data: [], error: null }] },
        coach_thread_messages: {
          select: [
            {
              data: [
                {
                  id: "msg1",
                  student_id: "s1",
                  role: "user",
                  content: { text: "我卡住了" },
                  created_at: "2025-01-01",
                },
              ],
              error: null,
            },
          ],
          insert: [{ data: { id: "assistant-llm" }, error: null }],
          update: [
            { data: null, error: null },
            { data: null, error: null },
          ],
        },
      },
    });

    await processCoachReplyJob(supabase, agent, {
      id: "job",
      kind: "coach_reply",
      student_id: "s1",
      payload: {},
    } as any);

    const updates = calls.from.filter(
      (call) => call.table === "coach_thread_messages" && call.action === "update",
    );
    expect(updates.length).toBeGreaterThan(0);
  });
});
