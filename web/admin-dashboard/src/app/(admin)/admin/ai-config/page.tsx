"use client";

import { useEffect, useMemo, useState } from "react";
import { getSupabaseClient } from "@/lib/supabaseClient";
import {
  archiveAiPromptConfig,
  listAiPromptConfigs,
  publishAiPromptConfig,
  type AiPromptConfig,
  type AiPromptConfigInput,
  type AiPromptKind,
} from "./actions";

const KIND_META: Record<AiPromptKind, { label: string; description: string }> = {
  attempt_insight: {
    label: "Attempt Insight",
    description: "Wrong-answer insight + steps. Writes attempt_insights.",
  },
  coach_reply: {
    label: "Coach Reply",
    description: "Student chat replies in the coach thread.",
  },
  progress_report: {
    label: "Progress Report",
    description: "Weekly/monthly report generation.",
  },
};

const DEFAULT_PROMPTS: Record<AiPromptKind, AiPromptConfigInput> = {
  attempt_insight: {
    kind: "attempt_insight",
    prompt_version: "ai-coach-insight-v2",
    system_prompt:
      "You are a strict, concise SAT tutor. Prefer short, step-by-step guidance and ask questions instead of long explanations.",
    model_provider: "minimax",
    model_id: "MiniMax-M2.1",
  },
  coach_reply: {
    kind: "coach_reply",
    prompt_version: "ai-coach-chat-v2",
    system_prompt:
      "你是一位严格、精要的 SAT 全科老师。默认用中文，先给最小可执行下一步，再问一个澄清问题。避免长篇大论。",
    model_provider: "minimax",
    model_id: "MiniMax-M2.1",
  },
  progress_report: {
    kind: "progress_report",
    prompt_version: "ai-coach-report-v1",
    system_prompt: "你是严格、精要的 SAT 一对一老师，只输出 JSON。",
    model_provider: "minimax",
    model_id: "MiniMax-M2.1",
  },
};

function normalizeForm(config: AiPromptConfig | undefined, kind: AiPromptKind): AiPromptConfigInput {
  if (!config) return { ...DEFAULT_PROMPTS[kind] };
  return {
    kind,
    prompt_version: config.prompt_version,
    system_prompt: config.system_prompt,
    model_provider: config.model_provider === "openai" ? "openai" : "minimax",
    model_id: config.model_id,
  };
}

export default function AiConfigPage() {
  const supabase = getSupabaseClient();
  const [configs, setConfigs] = useState<AiPromptConfig[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [savingKind, setSavingKind] = useState<AiPromptKind | null>(null);
  const [archivingId, setArchivingId] = useState<string | null>(null);
  const [forms, setForms] = useState<Record<AiPromptKind, AiPromptConfigInput>>({
    attempt_insight: { ...DEFAULT_PROMPTS.attempt_insight },
    coach_reply: { ...DEFAULT_PROMPTS.coach_reply },
    progress_report: { ...DEFAULT_PROMPTS.progress_report },
  });

  useEffect(() => {
    let active = true;

    async function load() {
      if (!supabase) return;
      const { data: sessionData } = await supabase.auth.getSession();
      const session = sessionData.session;
      if (!session) {
        setError("You are not signed in.");
        setLoading(false);
        return;
      }

      try {
        const data = await listAiPromptConfigs(session.access_token);
        if (!active) return;
        setConfigs(data);
        setError(null);
        const publishedByKind: Partial<Record<AiPromptKind, AiPromptConfig>> = {};
        for (const row of data) {
          if (row.status === "published" && !publishedByKind[row.kind]) {
            publishedByKind[row.kind] = row;
          }
        }
        setForms({
          attempt_insight: normalizeForm(publishedByKind.attempt_insight, "attempt_insight"),
          coach_reply: normalizeForm(publishedByKind.coach_reply, "coach_reply"),
          progress_report: normalizeForm(publishedByKind.progress_report, "progress_report"),
        });
      } catch (err) {
        if (active) {
          setError(err instanceof Error ? err.message : "Failed to load configs.");
        }
      } finally {
        if (active) setLoading(false);
      }
    }

    load();

    return () => {
      active = false;
    };
  }, [supabase]);

  const configsByKind = useMemo(() => {
    const grouped: Record<AiPromptKind, AiPromptConfig[]> = {
      attempt_insight: [],
      coach_reply: [],
      progress_report: [],
    };
    for (const row of configs) {
      grouped[row.kind].push(row);
    }
    return grouped;
  }, [configs]);

  function updateForm(kind: AiPromptKind, next: Partial<AiPromptConfigInput>) {
    setForms((prev) => ({
      ...prev,
      [kind]: {
        ...prev[kind],
        ...next,
      },
    }));
  }

  function handleProviderChange(kind: AiPromptKind, provider: "minimax" | "openai") {
    const defaultModel = provider === "openai" ? "gpt-5.2" : "MiniMax-M2.1";
    updateForm(kind, {
      model_provider: provider,
      model_id: defaultModel,
    });
  }

  async function handlePublish(kind: AiPromptKind) {
    if (!supabase) return;
    const { data: sessionData } = await supabase.auth.getSession();
    const session = sessionData.session;
    if (!session) return;

    setSavingKind(kind);
    setError(null);

    try {
      const updated = await publishAiPromptConfig(session.access_token, forms[kind]);
      setConfigs((prev) => [updated, ...prev]);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to publish config.");
    } finally {
      setSavingKind(null);
    }
  }

  async function handleArchive(configId: string) {
    if (!supabase) return;
    const { data: sessionData } = await supabase.auth.getSession();
    const session = sessionData.session;
    if (!session) return;

    setArchivingId(configId);
    setError(null);

    try {
      await archiveAiPromptConfig(session.access_token, configId);
      setConfigs((prev) =>
        prev.map((row) => (row.id === configId ? { ...row, status: "archived" } : row)),
      );
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to archive config.");
    } finally {
      setArchivingId(null);
    }
  }

  if (loading) {
    return (
      <main className="mx-auto max-w-6xl px-6 py-12">
        <p className="text-sm text-zinc-500">Loading AI configs...</p>
      </main>
    );
  }

  return (
    <main className="mx-auto flex max-w-6xl flex-col gap-8 px-6 py-8">
      <header className="flex flex-wrap items-center justify-between gap-4">
        <div>
          <p className="text-xs uppercase tracking-[0.2em] text-zinc-400">Admin Console</p>
          <h1 className="text-2xl font-semibold text-zinc-900">AI Config</h1>
          <p className="text-sm text-zinc-500">
            Control prompt versions and model routing for the AI coach pipeline.
          </p>
        </div>
        <div className="text-xs text-zinc-400">OpenAI default: gpt-5.2</div>
      </header>

      {error ? (
        <div className="rounded-2xl border border-amber-200 bg-amber-50 px-4 py-3 text-sm text-amber-800">
          {error}
        </div>
      ) : null}

      <div className="grid gap-6">
        {(Object.keys(KIND_META) as AiPromptKind[]).map((kind) => {
          const history = configsByKind[kind];
          const published = history.find((row) => row.status === "published");

          return (
            <section key={kind} className="rounded-2xl border border-zinc-200 bg-white p-6">
              <div className="flex flex-wrap items-start justify-between gap-4">
                <div>
                  <h2 className="text-lg font-semibold text-zinc-900">{KIND_META[kind].label}</h2>
                  <p className="text-sm text-zinc-500">{KIND_META[kind].description}</p>
                  {published ? (
                    <p className="mt-2 text-xs text-zinc-400">
                      Published: {published.prompt_version} · {published.model_provider}/{published.model_id}
                    </p>
                  ) : (
                    <p className="mt-2 text-xs text-amber-600">No published config yet.</p>
                  )}
                </div>
                <button
                  type="button"
                  onClick={() => handlePublish(kind)}
                  disabled={savingKind === kind}
                  className="rounded-full bg-zinc-900 px-4 py-2 text-xs font-semibold text-white disabled:opacity-60"
                >
                  {savingKind === kind ? "Publishing..." : "Publish new version"}
                </button>
              </div>

              <div className="mt-6 grid gap-4">
                <div className="grid gap-3 md:grid-cols-3">
                  <label className="grid gap-1 text-xs uppercase tracking-[0.16em] text-zinc-400" htmlFor={`${kind}-version`}>
                    Prompt version
                    <input
                      id={`${kind}-version`}
                      className="rounded-lg border border-zinc-200 px-3 py-2 text-sm text-zinc-900"
                      value={forms[kind].prompt_version}
                      onChange={(e) => updateForm(kind, { prompt_version: e.target.value })}
                      placeholder="ai-coach-insight-v3"
                    />
                  </label>
                  <label className="grid gap-1 text-xs uppercase tracking-[0.16em] text-zinc-400" htmlFor={`${kind}-provider`}>
                    Model provider
                    <select
                      id={`${kind}-provider`}
                      className="rounded-lg border border-zinc-200 bg-white px-3 py-2 text-sm"
                      value={forms[kind].model_provider}
                      onChange={(e) => handleProviderChange(kind, e.target.value as "minimax" | "openai")}
                    >
                      <option value="minimax">MiniMax</option>
                      <option value="openai">OpenAI</option>
                    </select>
                  </label>
                  <label className="grid gap-1 text-xs uppercase tracking-[0.16em] text-zinc-400" htmlFor={`${kind}-model`}>
                    Model ID
                    <input
                      id={`${kind}-model`}
                      className="rounded-lg border border-zinc-200 px-3 py-2 text-sm text-zinc-900"
                      value={forms[kind].model_id}
                      onChange={(e) => updateForm(kind, { model_id: e.target.value })}
                      placeholder="gpt-5.2"
                    />
                  </label>
                </div>

                <label className="grid gap-2 text-xs uppercase tracking-[0.16em] text-zinc-400" htmlFor={`${kind}-prompt`}>
                  System prompt
                  <textarea
                    id={`${kind}-prompt`}
                    className="min-h-[120px] rounded-lg border border-zinc-200 px-3 py-2 text-sm text-zinc-900"
                    value={forms[kind].system_prompt}
                    onChange={(e) => updateForm(kind, { system_prompt: e.target.value })}
                  />
                </label>
              </div>

              {history.length > 0 ? (
                <div className="mt-6 border-t border-zinc-100 pt-4">
                  <p className="text-xs uppercase tracking-[0.2em] text-zinc-400">Recent versions</p>
                  <div className="mt-2 space-y-2">
                    {history.slice(0, 3).map((row) => (
                      <div
                        key={row.id}
                        className="flex flex-wrap items-center justify-between gap-2 rounded-xl border border-zinc-100 bg-zinc-50 px-3 py-2 text-xs"
                      >
                        <div className="text-zinc-600">
                          {row.prompt_version} · {row.model_provider}/{row.model_id}
                        </div>
                        <div className="flex items-center gap-2">
                          <span
                            className={`rounded-full px-2 py-0.5 text-[11px] ${
                              row.status === "published"
                                ? "bg-emerald-100 text-emerald-700"
                                : row.status === "archived"
                                  ? "bg-zinc-200 text-zinc-600"
                                  : "bg-amber-100 text-amber-700"
                            }`}
                          >
                            {row.status}
                          </span>
                          {row.status !== "archived" ? (
                            <button
                              type="button"
                              onClick={() => handleArchive(row.id)}
                              disabled={archivingId === row.id}
                              className="text-[11px] text-zinc-500 hover:text-zinc-700"
                            >
                              {archivingId === row.id ? "Archiving..." : "Archive"}
                            </button>
                          ) : null}
                        </div>
                      </div>
                    ))}
                  </div>
                </div>
              ) : null}
            </section>
          );
        })}
      </div>
    </main>
  );
}
