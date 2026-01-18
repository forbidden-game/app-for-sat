"use client";

import { useEffect, useMemo, useState } from "react";
import Link from "next/link";
import { getSupabaseClient } from "@/lib/supabaseClient";
import {
  archiveAiPromptConfig,
  getAiProviderKeyStatus,
  listAiPromptConfigs,
  publishAiPromptConfig,
  upsertAiProviderKey,
  type AiPromptConfig,
  type AiPromptConfigInput,
  type AiPromptKind,
  type AiProviderKeyStatus,
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

const MODEL_DEFAULTS: Record<AiPromptConfigInput["model_provider"], string> = {
  minimax: "MiniMax-M2.1",
  openai: "gpt-5.2",
  openrouter: "anthropic/claude-haiku-4.5",
};

const MODEL_SUGGESTIONS: Record<AiPromptConfigInput["model_provider"], string[]> = {
  minimax: [MODEL_DEFAULTS.minimax],
  openai: [MODEL_DEFAULTS.openai],
  openrouter: [MODEL_DEFAULTS.openrouter, "deepseek/deepseek-r1-0528:free"],
};

const DEFAULT_PROMPTS: Record<AiPromptKind, AiPromptConfigInput> = {
  attempt_insight: {
    kind: "attempt_insight",
    prompt_version: "ai-coach-insight-v2",
    system_prompt:
      "You are a strict, concise SAT tutor. Prefer short, step-by-step guidance and ask questions instead of long explanations.",
    model_provider: "minimax",
    model_id: MODEL_DEFAULTS.minimax,
  },
  coach_reply: {
    kind: "coach_reply",
    prompt_version: "ai-coach-chat-v2",
    system_prompt:
      "你是一位严格、精要的 SAT 全科老师。默认用中文，先给最小可执行下一步，再问一个澄清问题。避免长篇大论。",
    model_provider: "minimax",
    model_id: MODEL_DEFAULTS.minimax,
  },
  progress_report: {
    kind: "progress_report",
    prompt_version: "ai-coach-report-v1",
    system_prompt: "你是严格、精要的 SAT 一对一老师，只输出 JSON。",
    model_provider: "minimax",
    model_id: MODEL_DEFAULTS.minimax,
  },
};

function normalizeForm(config: AiPromptConfig | undefined, kind: AiPromptKind): AiPromptConfigInput {
  if (!config) return { ...DEFAULT_PROMPTS[kind] };
  return {
    kind,
    prompt_version: config.prompt_version,
    system_prompt: config.system_prompt,
    model_provider:
      config.model_provider === "openai"
        ? "openai"
        : config.model_provider === "openrouter"
          ? "openrouter"
          : "minimax",
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
  const [keyStatus, setKeyStatus] = useState<AiProviderKeyStatus | null>(null);
  const [keyLoading, setKeyLoading] = useState(true);
  const [keyInputs, setKeyInputs] = useState<Record<AiPromptKind, string>>({
    attempt_insight: "",
    coach_reply: "",
    progress_report: "",
  });
  const [keyErrors, setKeyErrors] = useState<Partial<Record<AiPromptKind, string | null>>>({});
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
        setKeyLoading(false);
        return;
      }

      try {
        const [data, providerStatus] = await Promise.all([
          listAiPromptConfigs(session.access_token),
          getAiProviderKeyStatus(session.access_token, "openrouter"),
        ]);
        if (!active) return;
        setConfigs(data);
        setError(null);
        setKeyStatus(providerStatus);
        setKeyErrors({});
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
        if (active) {
          setLoading(false);
          setKeyLoading(false);
        }
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

  const keyStatusLabel = keyLoading
    ? "Loading…"
    : keyStatus?.hasKey
      ? `Stored · last4 ${keyStatus.last4 ?? "—"}`
      : "Not set";

  function updateForm(kind: AiPromptKind, next: Partial<AiPromptConfigInput>) {
    setForms((prev) => ({
      ...prev,
      [kind]: {
        ...prev[kind],
        ...next,
      },
    }));
  }

  function updateKeyInput(kind: AiPromptKind, value: string) {
    setKeyInputs((prev) => ({ ...prev, [kind]: value }));
    setKeyErrors((prev) => ({ ...prev, [kind]: null }));
  }

  function resetKeyInput(kind: AiPromptKind) {
    setKeyInputs((prev) => ({ ...prev, [kind]: "" }));
    setKeyErrors((prev) => ({ ...prev, [kind]: null }));
  }

  function isModelChanged(kind: AiPromptKind) {
    const published = configsByKind[kind].find((row) => row.status === "published");
    if (!published) return true;
    return (
      published.model_provider !== forms[kind].model_provider || published.model_id !== forms[kind].model_id
    );
  }

  function handleProviderChange(kind: AiPromptKind, provider: "minimax" | "openai" | "openrouter") {
    const defaultModel = MODEL_DEFAULTS[provider];
    updateForm(kind, {
      model_provider: provider,
      model_id: defaultModel,
    });
    resetKeyInput(kind);
  }

  function applyPublishedConfig(updated: AiPromptConfig) {
    setConfigs((prev) => {
      const next = prev.map<AiPromptConfig>((row) => {
        if (row.kind !== updated.kind || row.status !== "published") return row;
        return {
          ...row,
          status: "archived",
          updated_at: updated.updated_at,
        };
      });
      return [updated, ...next];
    });
    setForms((prev) => ({
      ...prev,
      [updated.kind]: normalizeForm(updated, updated.kind),
    }));
  }

  async function handlePublish(kind: AiPromptKind) {
    if (!supabase) return;
    const { data: sessionData } = await supabase.auth.getSession();
    const session = sessionData.session;
    if (!session) return;

    setSavingKind(kind);
    setError(null);
    setKeyErrors((prev) => ({ ...prev, [kind]: null }));

    try {
      const requiresKey = forms[kind].model_provider === "openrouter" && isModelChanged(kind);
      const keyValue = keyInputs[kind]?.trim() ?? "";

      if (requiresKey && !keyValue) {
        setKeyErrors((prev) => ({
          ...prev,
          [kind]: "OpenRouter API key is required when changing to an OpenRouter model.",
        }));
        return;
      }

      if (keyValue) {
        try {
          const status = await upsertAiProviderKey(session.access_token, "openrouter", keyValue);
          setKeyStatus(status);
          setKeyInputs((prev) => ({ ...prev, [kind]: "" }));
        } catch (err) {
          setKeyErrors((prev) => ({
            ...prev,
            [kind]: err instanceof Error ? err.message : "Failed to update OpenRouter key.",
          }));
          return;
        }
      }

      const updated = await publishAiPromptConfig(session.access_token, forms[kind]);
      applyPublishedConfig(updated);
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
      setConfigs((prev) => prev.map((row) => (row.id === configId ? { ...row, status: "archived" } : row)));
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to archive config.");
    } finally {
      setArchivingId(null);
    }
  }

  if (loading) {
    return (
      <main className="mx-auto max-w-[1440px] px-6 py-12">
        <p className="text-sm text-[color:var(--ink-muted)]" role="status" aria-live="polite">
          Loading AI configs…
        </p>
      </main>
    );
  }

  return (
    <main className="mx-auto flex max-w-[1440px] flex-col gap-6 px-6 pb-10 pt-8">
      <header className="flex flex-wrap items-center justify-between gap-4">
        <div>
          <p className="text-[11px] uppercase tracking-[0.2em] text-[color:var(--ink-muted)]">Admin Console</p>
          <h1 className="text-balance text-2xl font-semibold text-[color:var(--ink)]">AI Config</h1>
          <p className="text-sm text-[color:var(--ink-muted)]">
            Control prompt versions and model routing for the AI coach pipeline.
          </p>
        </div>
        <div className="rounded-full border border-[color:var(--border)] bg-[color:var(--surface)] px-3 py-1 text-[10px] uppercase tracking-[0.2em] text-[color:var(--ink-muted)]">
          OpenAI default: gpt-5.2 · OpenRouter default: anthropic/claude-haiku-4.5
        </div>
      </header>

      {error ? (
        <div
          className="rounded-2xl border border-[color:var(--danger)] bg-[color:var(--surface)] px-4 py-3 text-sm text-[color:var(--danger-strong)]"
          role="alert"
        >
          {error}
        </div>
      ) : null}

      <section className="rounded-2xl border border-[color:var(--border)] bg-[color:var(--surface)] p-6">
        <div className="flex flex-wrap items-start justify-between gap-4">
          <div>
            <h2 className="text-balance text-lg font-semibold text-[color:var(--ink)]">Providers & Routing</h2>
            <p className="text-sm text-[color:var(--ink-muted)]">
              Pick a model per job type. OpenRouter keys are required each time you switch a job to OpenRouter.
            </p>
          </div>
          <Link
            href="/admin/ai-logs"
            className="mt-2 inline-flex items-center rounded-full border border-[color:var(--border)] bg-[color:var(--surface)] px-4 py-2 text-[10px] font-semibold uppercase tracking-[0.2em] text-[color:var(--ink-muted)] transition hover:border-[color:var(--accent)] hover:text-[color:var(--ink)]"
          >
            Open AI Logs
          </Link>
        </div>

        <div className="mt-6 grid gap-6">
          {(Object.keys(KIND_META) as AiPromptKind[]).map((kind) => {
            const history = configsByKind[kind];
            const published = history.find((row) => row.status === "published");
            const keyValue = keyInputs[kind] ?? "";
            const needsKey = forms[kind].model_provider === "openrouter";
            const modelChanged =
              !published ||
              published.model_provider !== forms[kind].model_provider ||
              published.model_id !== forms[kind].model_id;
            const keyRequired = needsKey && modelChanged;
            const keyMissing = keyRequired && keyValue.trim().length === 0;
            const modelSuggestions = MODEL_SUGGESTIONS[forms[kind].model_provider];
            const modelListId = modelSuggestions.length > 0 ? `${kind}-model-list` : undefined;

            return (
              <section
                  key={kind}
                  className="rounded-2xl border border-[color:var(--border)] bg-[color:var(--surface)] p-6"
                >
                  <div className="flex flex-wrap items-start justify-between gap-4">
                    <div>
                      <p className="text-[11px] uppercase tracking-[0.2em] text-[color:var(--ink-muted)]">
                        {KIND_META[kind].label}
                      </p>
                      <h2 className="text-balance text-lg font-semibold text-[color:var(--ink)]">
                        {KIND_META[kind].description}
                      </h2>
                      {published ? (
                        <p className="mt-2 break-words text-xs text-[color:var(--ink-muted)]">
                          Published: {published.prompt_version} · {published.model_provider}/{published.model_id}
                        </p>
                      ) : (
                        <p className="mt-2 text-xs text-[color:var(--danger-strong)]">No published config yet.</p>
                      )}
                    </div>
                    <button
                      type="button"
                      onClick={() => handlePublish(kind)}
                      disabled={savingKind === kind || keyMissing}
                      className="rounded-full bg-[color:var(--accent)] px-4 py-2 text-[10px] font-semibold uppercase tracking-[0.2em] text-white transition hover:bg-[color:var(--accent-strong)] disabled:opacity-60"
                    >
                      {savingKind === kind ? "Publishing…" : "Publish New Version"}
                    </button>
                  </div>

                  <div className="mt-6 grid gap-4">
                    <div className="grid gap-3 md:grid-cols-3">
                      <label
                        className="grid gap-1 text-[10px] uppercase tracking-[0.2em] text-[color:var(--ink-muted)]"
                        htmlFor={`${kind}-version`}
                      >
                        Prompt version
                        <input
                          id={`${kind}-version`}
                          name={`${kind}-version`}
                          className="rounded-xl border border-[color:var(--border)] bg-[color:var(--surface)] px-3 py-2 text-sm text-[color:var(--ink)]"
                          value={forms[kind].prompt_version}
                          onChange={(e) => updateForm(kind, { prompt_version: e.target.value })}
                          placeholder="ai-coach-insight-v3…"
                          autoComplete="off"
                        />
                      </label>
                      <label
                        className="grid gap-1 text-[10px] uppercase tracking-[0.2em] text-[color:var(--ink-muted)]"
                        htmlFor={`${kind}-provider`}
                      >
                        Model provider
                        <select
                          id={`${kind}-provider`}
                          name={`${kind}-provider`}
                          className="rounded-xl border border-[color:var(--border)] bg-[color:var(--surface)] px-3 py-2 text-sm"
                          value={forms[kind].model_provider}
                          onChange={(e) =>
                            handleProviderChange(kind, e.target.value as "minimax" | "openai" | "openrouter")
                          }
                        >
                          <option value="minimax">MiniMax</option>
                          <option value="openai">OpenAI</option>
                          <option value="openrouter">OpenRouter</option>
                        </select>
                      </label>
                      <label
                        className="grid gap-1 text-[10px] uppercase tracking-[0.2em] text-[color:var(--ink-muted)]"
                        htmlFor={`${kind}-model`}
                      >
                        Model ID
                        <input
                          id={`${kind}-model`}
                          name={`${kind}-model`}
                          className="rounded-xl border border-[color:var(--border)] bg-[color:var(--surface)] px-3 py-2 text-sm text-[color:var(--ink)]"
                          value={forms[kind].model_id}
                          list={modelListId}
                          onChange={(e) => {
                            updateForm(kind, { model_id: e.target.value });
                            if (forms[kind].model_provider === "openrouter") {
                              resetKeyInput(kind);
                            }
                          }}
                          placeholder="gpt-5.2…"
                          autoComplete="off"
                        />
                        {modelListId ? (
                          <datalist id={modelListId}>
                            {modelSuggestions.map((modelId) => (
                              <option key={modelId} value={modelId} />
                            ))}
                          </datalist>
                        ) : null}
                        {modelSuggestions.length > 1 ? (
                          <div className="mt-2 flex flex-wrap items-center gap-2 text-xs text-[color:var(--ink-muted)]">
                            <span className="text-[10px] uppercase tracking-[0.2em]">Suggested</span>
                            {modelSuggestions.map((modelId) => (
                              <button
                                key={modelId}
                                type="button"
                                onClick={() => {
                                  updateForm(kind, { model_id: modelId });
                                  if (forms[kind].model_provider === "openrouter") {
                                    resetKeyInput(kind);
                                  }
                                }}
                                className={`rounded-full border px-3 py-1 font-mono text-[10px] transition ${
                                  forms[kind].model_id === modelId
                                    ? "border-[color:var(--accent)] text-[color:var(--ink)]"
                                    : "border-[color:var(--border)] text-[color:var(--ink-muted)] hover:border-[color:var(--accent)] hover:text-[color:var(--ink)]"
                                }`}
                              >
                                {modelId}
                              </button>
                            ))}
                          </div>
                        ) : null}
                      </label>
                    </div>

                    {needsKey ? (
                      <div className="rounded-xl border border-[color:var(--border)] bg-[color:var(--surface-soft)] p-4">
                        <div className="flex flex-wrap items-start justify-between gap-2">
                          <div>
                            <p className="text-[11px] uppercase tracking-[0.2em] text-[color:var(--ink-muted)]">
                              OpenRouter API Key
                            </p>
                            <p className="text-xs text-[color:var(--ink-muted)]">
                              {keyRequired ? "Required to publish this model change." : "Enter a key when you change the model."}
                            </p>
                          </div>
                          <div className="text-xs text-[color:var(--ink-muted)]">{keyStatusLabel}</div>
                        </div>
                        <label
                          className="mt-3 grid gap-1 text-[10px] uppercase tracking-[0.2em] text-[color:var(--ink-muted)]"
                          htmlFor={`${kind}-openrouter-key`}
                        >
                          OpenRouter API key
                          <input
                            id={`${kind}-openrouter-key`}
                            name={`${kind}-openrouter-key`}
                            type="password"
                            className="rounded-xl border border-[color:var(--border)] bg-[color:var(--surface)] px-3 py-2 text-sm text-[color:var(--ink)]"
                            value={keyValue}
                            onChange={(e) => updateKeyInput(kind, e.target.value)}
                            placeholder="sk-or-…"
                            autoComplete="off"
                          />
                        </label>
                        {keyErrors[kind] ? (
                          <p className="mt-2 text-xs text-[color:var(--danger-strong)]" role="alert">
                            {keyErrors[kind]}
                          </p>
                        ) : null}
                        {keyStatus?.updatedAt ? (
                          <p className="mt-2 text-xs text-[color:var(--ink-muted)]">Updated {keyStatus.updatedAt}</p>
                        ) : null}
                      </div>
                    ) : null}

                    <label
                      className="grid gap-2 text-[10px] uppercase tracking-[0.2em] text-[color:var(--ink-muted)]"
                      htmlFor={`${kind}-prompt`}
                    >
                      System prompt
                      <textarea
                        id={`${kind}-prompt`}
                        name={`${kind}-prompt`}
                        className="min-h-[120px] rounded-xl border border-[color:var(--border)] bg-[color:var(--surface)] px-3 py-2 text-sm text-[color:var(--ink)]"
                        value={forms[kind].system_prompt}
                        onChange={(e) => updateForm(kind, { system_prompt: e.target.value })}
                        autoComplete="off"
                      />
                    </label>
                  </div>

                  {history.length > 0 ? (
                    <div className="mt-6 border-t border-[color:var(--border)] pt-4">
                      <p className="text-[11px] uppercase tracking-[0.2em] text-[color:var(--ink-muted)]">
                        Recent Versions
                      </p>
                      <div className="mt-2 space-y-2">
                        {history.slice(0, 3).map((row) => (
                          <div
                            key={row.id}
                            className="flex flex-wrap items-center justify-between gap-2 rounded-xl border border-[color:var(--border)] bg-[color:var(--surface-soft)] px-3 py-2 text-xs"
                          >
                            <div className="min-w-0 break-words text-[color:var(--ink-muted)]">
                              {row.prompt_version} · {row.model_provider}/{row.model_id}
                            </div>
                            <div className="flex items-center gap-2">
                              <span
                                className={`rounded-full px-2 py-0.5 text-[10px] uppercase tracking-[0.2em] text-white ${
                                  row.status === "published"
                                    ? "bg-[color:var(--accent-strong)]"
                                    : row.status === "archived"
                                      ? "bg-[color:var(--surface-strong)] text-[color:var(--ink-muted)]"
                                      : "bg-[color:var(--danger-strong)]"
                                }`}
                              >
                                {row.status}
                              </span>
                              {row.status !== "archived" ? (
                                <button
                                  type="button"
                                  onClick={() => handleArchive(row.id)}
                                  disabled={archivingId === row.id}
                                  className="text-[10px] uppercase tracking-[0.2em] text-[color:var(--ink-muted)] hover:text-[color:var(--ink)]"
                                >
                                  {archivingId === row.id ? "Archiving…" : "Archive"}
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
      </section>
    </main>
  );
}
