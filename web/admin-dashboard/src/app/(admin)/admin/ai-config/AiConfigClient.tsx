"use client";

import { useEffect, useMemo, useState } from "react";
import Link from "next/link";
import { getSupabaseClient } from "@/lib/supabaseClient";
import {
  archiveAiPromptConfig,
  getAiJobStatusSummary,
  getAiProviderKeyStatus,
  listAiJobControls,
  listAiPromptConfigs,
  publishAiPromptConfig,
  updateAiJobControl,
  upsertAiProviderKey,
  type AiJobControl,
  type AiJobKind,
  type AiJobStatusSummary,
  type AiPromptConfig,
  type AiPromptConfigInput,
  type AiPromptKind,
  type AiProvider,
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
  english_grammar_analysis: {
    label: "English Grammar Analysis",
    description: "Grammar analysis cache + job pipeline for reading questions.",
  },
};

const JOB_KIND_META: Record<AiJobKind, { label: string; description: string }> = {
  attempt_insight: {
    label: "Attempt Insight",
    description: "Wrong-answer insight pipeline.",
  },
  coach_reply: {
    label: "Coach Reply",
    description: "AI coach replies in student chat.",
  },
  progress_report: {
    label: "Progress Report",
    description: "Weekly/monthly report generation.",
  },
  english_grammar_analysis: {
    label: "English Grammar Analysis",
    description: "Grammar analysis for reading questions.",
  },
  snapshot_refresh: {
    label: "Snapshot Refresh",
    description: "Rebuild student snapshot summaries.",
  },
  thread_summary: {
    label: "Thread Summary",
    description: "Summarize long coach threads.",
  },
  procedure_merge: {
    label: "Procedure Merge",
    description: "Merge duplicate procedures.",
  },
};

const JOB_KIND_ORDER: AiJobKind[] = [
  "attempt_insight",
  "coach_reply",
  "progress_report",
  "english_grammar_analysis",
  "snapshot_refresh",
  "thread_summary",
  "procedure_merge",
];

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

const PROVIDER_LABELS: Record<AiProvider, string> = {
  minimax: "MiniMax",
  openai: "OpenAI",
  openrouter: "OpenRouter",
};

const PROVIDERS: AiProvider[] = ["minimax", "openai", "openrouter"];

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
  english_grammar_analysis: {
    kind: "english_grammar_analysis",
    prompt_version: "english-grammar-v2",
    system_prompt:
      "You are an expert English grammar analyst. Output only valid JSON per the schema.",
    model_provider: "minimax",
    model_id: MODEL_DEFAULTS.minimax,
  },
};

function formatDateTime(value: string | null | undefined) {
  if (!value) return "—";
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return value;
  return new Intl.DateTimeFormat(undefined, {
    month: "short",
    day: "numeric",
    year: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  }).format(date);
}

function normalizeForm(
  config: AiPromptConfig | undefined,
  kind: AiPromptKind,
): AiPromptConfigInput {
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

function isPromptKind(value: string): value is AiPromptKind {
  return value in KIND_META;
}

function buildForms(configs: AiPromptConfig[]) {
  const publishedByKind: Partial<Record<AiPromptKind, AiPromptConfig>> = {};
  for (const row of configs) {
    if (!isPromptKind(row.kind)) continue;
    if (row.status === "published" && !publishedByKind[row.kind]) {
      publishedByKind[row.kind] = row;
    }
  }
  return {
    attempt_insight: normalizeForm(publishedByKind.attempt_insight, "attempt_insight"),
    coach_reply: normalizeForm(publishedByKind.coach_reply, "coach_reply"),
    progress_report: normalizeForm(publishedByKind.progress_report, "progress_report"),
    english_grammar_analysis: normalizeForm(
      publishedByKind.english_grammar_analysis,
      "english_grammar_analysis",
    ),
  };
}

type AiConfigClientProps = {
  initialConfigs?: AiPromptConfig[];
  initialKeyStatuses?: Partial<Record<AiProvider, AiProviderKeyStatus>>;
  initialJobControls?: AiJobControl[];
  initialJobStatus?: AiJobStatusSummary[];
  initialError?: string | null;
};

export default function AiConfigClient({
  initialConfigs,
  initialKeyStatuses,
  initialJobControls,
  initialJobStatus,
  initialError = null,
}: AiConfigClientProps) {
  const supabase = getSupabaseClient();
  const hasInitialConfigs = initialConfigs !== undefined;
  const hasInitialKeyStatuses = initialKeyStatuses !== undefined;
  const hasInitialJobControls = initialJobControls !== undefined;
  const hasInitialJobStatus = initialJobStatus !== undefined;
  const hasInitialData = hasInitialConfigs && hasInitialKeyStatuses;
  const hasInitialJobData = hasInitialJobControls && hasInitialJobStatus;
  const [configs, setConfigs] = useState<AiPromptConfig[]>(initialConfigs ?? []);
  const [loading, setLoading] = useState(!hasInitialConfigs && !initialError);
  const [error, setError] = useState<string | null>(initialError);
  const [savingKind, setSavingKind] = useState<AiPromptKind | null>(null);
  const [archivingId, setArchivingId] = useState<string | null>(null);
  const [keyStatuses, setKeyStatuses] = useState<Partial<Record<AiProvider, AiProviderKeyStatus>>>(
    initialKeyStatuses ?? {},
  );
  const [keyLoading, setKeyLoading] = useState(!hasInitialKeyStatuses && !initialError);
  const [jobControls, setJobControls] = useState<AiJobControl[]>(initialJobControls ?? []);
  const [jobStatus, setJobStatus] = useState<AiJobStatusSummary[]>(initialJobStatus ?? []);
  const [jobLoading, setJobLoading] = useState(!hasInitialJobControls && !initialError);
  const [jobStatusLoading, setJobStatusLoading] = useState(!hasInitialJobStatus && !initialError);
  const [jobError, setJobError] = useState<string | null>(null);
  const [keyInputs, setKeyInputs] = useState<Record<AiPromptKind, string>>({
    attempt_insight: "",
    coach_reply: "",
    progress_report: "",
    english_grammar_analysis: "",
  });
  const [keyErrors, setKeyErrors] = useState<Partial<Record<AiPromptKind, string | null>>>({});
  const [forms, setForms] = useState<Record<AiPromptKind, AiPromptConfigInput>>(() =>
    buildForms(initialConfigs ?? []),
  );

  useEffect(() => {
    if ((hasInitialData && hasInitialJobData) || initialError) return;
    let active = true;

    async function load() {
      if (!supabase) {
        setError("Supabase not configured.");
        setLoading(false);
        setKeyLoading(false);
        setJobLoading(false);
        setJobStatusLoading(false);
        return;
      }
      const { data: sessionData } = await supabase.auth.getSession();
      const session = sessionData.session;
      if (!session) {
        setError("You are not signed in.");
        setLoading(false);
        setKeyLoading(false);
        setJobLoading(false);
        setJobStatusLoading(false);
        return;
      }

      try {
        const [data, providerStatuses, controls, statusSummary] = await Promise.all([
          listAiPromptConfigs(session.access_token),
          Promise.all(
            PROVIDERS.map((provider) => getAiProviderKeyStatus(session.access_token, provider)),
          ),
          listAiJobControls(session.access_token),
          getAiJobStatusSummary(session.access_token),
        ]);
        if (!active) return;
        setConfigs(data);
        setError(null);
        setKeyStatuses(
          providerStatuses.reduce<Partial<Record<AiProvider, AiProviderKeyStatus>>>(
            (acc, status) => {
              acc[status.provider] = status;
              return acc;
            },
            {},
          ),
        );
        setKeyErrors({});
        setForms(buildForms(data));
        setJobControls(controls);
        setJobStatus(statusSummary);
        setJobError(null);
      } catch (err) {
        if (active) {
          setError(err instanceof Error ? err.message : "Failed to load configs.");
        }
      } finally {
        if (active) {
          setLoading(false);
          setKeyLoading(false);
          setJobLoading(false);
          setJobStatusLoading(false);
        }
      }
    }

    load();

    return () => {
      active = false;
    };
  }, [hasInitialData, hasInitialJobData, initialError, supabase]);

  const configsByKind = useMemo(() => {
    const grouped: Record<AiPromptKind, AiPromptConfig[]> = {
      attempt_insight: [],
      coach_reply: [],
      progress_report: [],
      english_grammar_analysis: [],
    };
    for (const row of configs) {
      if (!isPromptKind(row.kind)) continue;
      grouped[row.kind].push(row);
    }
    return grouped;
  }, [configs]);

  const jobControlByKind = useMemo(() => {
    const map: Partial<Record<AiJobKind, AiJobControl>> = {};
    for (const row of jobControls) {
      map[row.kind] = row;
    }
    return map;
  }, [jobControls]);

  const jobStatusByKind = useMemo(() => {
    const map: Partial<Record<AiJobKind, AiJobStatusSummary>> = {};
    for (const row of jobStatus) {
      map[row.kind] = row;
    }
    return map;
  }, [jobStatus]);

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
      const provider = forms[kind].model_provider;
      const keyValue = keyInputs[kind]?.trim() ?? "";

      if (keyValue) {
        try {
          const status = await upsertAiProviderKey(session.access_token, provider, keyValue);
          setKeyStatuses((prev) => ({ ...prev, [provider]: status }));
          setKeyInputs((prev) => ({ ...prev, [kind]: "" }));
        } catch (err) {
          setKeyErrors((prev) => ({
            ...prev,
            [kind]:
              err instanceof Error
                ? err.message
                : `Failed to update ${PROVIDER_LABELS[provider]} key.`,
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
      setConfigs((prev) =>
        prev.map((row) => (row.id === configId ? { ...row, status: "archived" } : row)),
      );
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to archive config.");
    } finally {
      setArchivingId(null);
    }
  }

  async function refreshJobStatus() {
    if (!supabase) return;
    const { data: sessionData } = await supabase.auth.getSession();
    const session = sessionData.session;
    if (!session) return;

    setJobStatusLoading(true);
    setJobError(null);

    try {
      const statusSummary = await getAiJobStatusSummary(session.access_token);
      setJobStatus(statusSummary);
    } catch (err) {
      setJobError(err instanceof Error ? err.message : "Failed to load AI job status.");
    } finally {
      setJobStatusLoading(false);
    }
  }

  async function handleJobControlChange(
    kind: AiJobKind,
    updates: Pick<AiJobControl, "allow_enqueue" | "allow_process">,
  ) {
    if (!supabase) return;
    const { data: sessionData } = await supabase.auth.getSession();
    const session = sessionData.session;
    if (!session) return;

    setJobLoading(true);
    setJobError(null);

    try {
      const updated = await updateAiJobControl(session.access_token, kind, updates);
      setJobControls((prev) => {
        const next = prev.filter((row) => row.kind !== kind);
        return [...next, updated].sort((a, b) => a.kind.localeCompare(b.kind));
      });
    } catch (err) {
      setJobError(err instanceof Error ? err.message : "Failed to update job control.");
    } finally {
      setJobLoading(false);
    }
  }

  if (loading) {
    return (
      <main className="mx-auto max-w-[1280px] px-6 py-12">
        <p className="text-sm text-[color:var(--ink-muted)]" role="status" aria-live="polite">
          Loading AI configs…
        </p>
      </main>
    );
  }

  return (
    <main className="mx-auto flex max-w-[1280px] flex-col gap-6 px-6 pb-10 pt-8">
      <header className="flex flex-wrap items-center justify-between gap-4">
        <div>
          <p className="text-xs font-medium text-[color:var(--ink-muted)]">Admin Console</p>
          <h1 className="text-balance text-2xl font-semibold tracking-tight text-[color:var(--ink)]">
            AI Config
          </h1>
          <p className="text-sm text-[color:var(--ink-muted)]">
            Control prompt versions and model routing for the AI coach pipeline.
          </p>
        </div>
        <div className="rounded-full border border-[color:var(--border)] bg-[color:var(--surface-soft)] px-3 py-1 text-xs font-medium text-[color:var(--ink-muted)]">
          OpenAI default: gpt-5.2 · OpenRouter default: anthropic/claude-haiku-4.5
        </div>
      </header>

      {error ? (
        <div
          className="rounded-xl border border-[color:var(--danger)] bg-[color:var(--surface)] px-4 py-3 text-sm text-[color:var(--danger-strong)]"
          role="alert"
        >
          {error}
        </div>
      ) : null}

      <section className="rounded-xl border border-[color:var(--border)] bg-[color:var(--surface)] p-6">
        <div className="flex flex-wrap items-start justify-between gap-4">
          <div>
            <h2 className="text-balance text-lg font-semibold tracking-tight text-[color:var(--ink)]">
              Service Controls & Status
            </h2>
            <p className="text-sm text-[color:var(--ink-muted)]">
              Toggle enqueue/processing per job kind and review current queue status.
            </p>
          </div>
          <button
            type="button"
            onClick={() => void refreshJobStatus()}
            disabled={jobStatusLoading}
            className="mt-2 inline-flex items-center rounded-full border border-[color:var(--border)] bg-[color:var(--surface)] px-4 py-2 text-xs font-medium text-[color:var(--ink-muted)] transition hover:border-[color:var(--accent)] hover:text-[color:var(--ink)] disabled:opacity-60"
          >
            {jobStatusLoading ? "Refreshing…" : "Refresh Status"}
          </button>
        </div>

        {jobError ? (
          <p className="mt-4 text-sm text-[color:var(--danger-strong)]" role="alert">
            {jobError}
          </p>
        ) : null}

        <div className="mt-6 grid gap-4 lg:grid-cols-2">
          {JOB_KIND_ORDER.map((kind) => {
            const control = jobControlByKind[kind];
            const status = jobStatusByKind[kind];
            const allowEnqueue = control?.allow_enqueue ?? true;
            const allowProcess = control?.allow_process ?? true;
            const toggleClass = (enabled: boolean) =>
              `rounded-full border px-3 py-1 text-xs font-medium transition ${
                enabled
                  ? "border-[color:var(--accent)] text-[color:var(--ink)]"
                  : "border-[color:var(--border)] text-[color:var(--ink-muted)]"
              }`;

            return (
              <div
                key={kind}
                className="rounded-xl border border-[color:var(--border)] bg-[color:var(--surface)] p-4"
              >
                <div className="flex items-start justify-between gap-3">
                  <div>
                    <p className="text-xs font-medium text-[color:var(--ink-muted)]">
                      {JOB_KIND_META[kind].label}
                    </p>
                    <p className="mt-1 text-sm font-semibold text-[color:var(--ink)]">
                      {JOB_KIND_META[kind].description}
                    </p>
                  </div>
                  <span className="rounded-full border border-[color:var(--border)] bg-[color:var(--surface-soft)] px-2 py-1 text-[11px] font-medium text-[color:var(--ink-muted)]">
                    {kind}
                  </span>
                </div>

                <div className="mt-4 grid gap-3 sm:grid-cols-2">
                  <button
                    type="button"
                    role="switch"
                    aria-checked={allowEnqueue}
                    onClick={() =>
                      handleJobControlChange(kind, {
                        allow_enqueue: !allowEnqueue,
                        allow_process: allowProcess,
                      })
                    }
                    disabled={jobLoading}
                    className={toggleClass(allowEnqueue)}
                  >
                    Enqueue: {allowEnqueue ? "Enabled" : "Disabled"}
                  </button>
                  <button
                    type="button"
                    role="switch"
                    aria-checked={allowProcess}
                    onClick={() =>
                      handleJobControlChange(kind, {
                        allow_enqueue: allowEnqueue,
                        allow_process: !allowProcess,
                      })
                    }
                    disabled={jobLoading}
                    className={toggleClass(allowProcess)}
                  >
                    Process: {allowProcess ? "Enabled" : "Disabled"}
                  </button>
                </div>

                <div className="mt-4 grid gap-2 text-xs text-[color:var(--ink-muted)] sm:grid-cols-3">
                  <div className="rounded-lg border border-[color:var(--border)] bg-[color:var(--surface-soft)] px-3 py-2">
                    queued {status?.queued_count ?? 0}
                  </div>
                  <div className="rounded-lg border border-[color:var(--border)] bg-[color:var(--surface-soft)] px-3 py-2">
                    running {status?.running_count ?? 0}
                  </div>
                  <div className="rounded-lg border border-[color:var(--border)] bg-[color:var(--surface-soft)] px-3 py-2">
                    error {status?.error_count ?? 0}
                  </div>
                </div>

                <p className="mt-3 text-xs text-[color:var(--ink-muted)]">
                  Updated {formatDateTime(status?.last_updated_at)} · Last success{" "}
                  {formatDateTime(status?.last_success_at)}
                </p>
              </div>
            );
          })}
        </div>
      </section>

      <section className="rounded-xl border border-[color:var(--border)] bg-[color:var(--surface)] p-6">
        <div className="flex flex-wrap items-start justify-between gap-4">
          <div>
            <h2 className="text-balance text-lg font-semibold tracking-tight text-[color:var(--ink)]">
              Providers & Routing
            </h2>
            <p className="text-sm text-[color:var(--ink-muted)]">
              Pick a model per job type. Provider keys are optional and override stored or env
              defaults when supplied.
            </p>
          </div>
          <Link
            href="/admin/ai-logs"
            className="mt-2 inline-flex items-center rounded-full border border-[color:var(--border)] bg-[color:var(--surface)] px-4 py-2 text-xs font-medium text-[color:var(--ink-muted)] transition hover:border-[color:var(--accent)] hover:text-[color:var(--ink)]"
          >
            Open AI Logs
          </Link>
        </div>

        <div className="mt-6 grid gap-6">
          {(Object.keys(KIND_META) as AiPromptKind[]).map((kind) => {
            const history = configsByKind[kind];
            const published = history.find((row) => row.status === "published");
            const provider = forms[kind].model_provider;
            const keyValue = keyInputs[kind] ?? "";
            const keyStatus = keyStatuses[provider];
            const keyStatusLabel = keyLoading
              ? "Loading…"
              : keyStatus?.hasKey
                ? `Stored · last4 ${keyStatus.last4 ?? "—"}`
                : "Not set";
            const keyHint = "Optional. Leave blank to keep the stored key.";
            const providerLabel = PROVIDER_LABELS[provider];
            const modelSuggestions = MODEL_SUGGESTIONS[provider];
            const modelListId = modelSuggestions.length > 0 ? `${kind}-model-list` : undefined;

            return (
              <section
                key={kind}
                className="rounded-xl border border-[color:var(--border)] bg-[color:var(--surface)] p-6"
              >
                <div className="flex flex-wrap items-start justify-between gap-4">
                  <div>
                    <p className="text-xs font-medium text-[color:var(--ink-muted)]">
                      {KIND_META[kind].label}
                    </p>
                    <h2 className="text-balance text-lg font-semibold tracking-tight text-[color:var(--ink)]">
                      {KIND_META[kind].description}
                    </h2>
                    {published ? (
                      <p className="mt-2 break-words text-xs text-[color:var(--ink-muted)]">
                        Published: {published.prompt_version} · {published.model_provider}/
                        {published.model_id}
                      </p>
                    ) : (
                      <p className="mt-2 text-xs text-[color:var(--danger-strong)]">
                        No published config yet.
                      </p>
                    )}
                  </div>
                  <button
                    type="button"
                    onClick={() => handlePublish(kind)}
                    disabled={savingKind === kind}
                    className="rounded-full bg-[color:var(--accent)] px-4 py-2 text-xs font-semibold text-white transition hover:bg-[color:var(--accent-strong)] disabled:opacity-60"
                  >
                    {savingKind === kind ? "Publishing…" : "Publish New Version"}
                  </button>
                </div>

                <div className="mt-6 grid gap-4">
                  <div className="grid gap-3 md:grid-cols-3">
                    <label
                      className="grid gap-1 text-xs font-medium text-[color:var(--ink-muted)]"
                      htmlFor={`${kind}-version`}
                    >
                      Prompt version
                      <input
                        id={`${kind}-version`}
                        name={`${kind}-version`}
                        className="rounded-lg border border-[color:var(--border)] bg-[color:var(--surface)] px-3 py-2 text-sm text-[color:var(--ink)]"
                        value={forms[kind].prompt_version}
                        onChange={(e) => updateForm(kind, { prompt_version: e.target.value })}
                        placeholder="ai-coach-insight-v3…"
                        autoComplete="off"
                      />
                    </label>
                    <label
                      className="grid gap-1 text-xs font-medium text-[color:var(--ink-muted)]"
                      htmlFor={`${kind}-provider`}
                    >
                      Model provider
                      <select
                        id={`${kind}-provider`}
                        name={`${kind}-provider`}
                        className="rounded-lg border border-[color:var(--border)] bg-[color:var(--surface)] px-3 py-2 text-sm text-[color:var(--ink)]"
                        value={forms[kind].model_provider}
                        onChange={(e) =>
                          handleProviderChange(
                            kind,
                            e.target.value as "minimax" | "openai" | "openrouter",
                          )
                        }
                      >
                        <option value="minimax">MiniMax</option>
                        <option value="openai">OpenAI</option>
                        <option value="openrouter">OpenRouter</option>
                      </select>
                    </label>
                    <label
                      className="grid gap-1 text-xs font-medium text-[color:var(--ink-muted)]"
                      htmlFor={`${kind}-model`}
                    >
                      Model ID
                      <input
                        id={`${kind}-model`}
                        name={`${kind}-model`}
                        className="rounded-lg border border-[color:var(--border)] bg-[color:var(--surface)] px-3 py-2 text-sm text-[color:var(--ink)]"
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
                          <span className="text-[11px] font-medium">Suggested</span>
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
                              className={`rounded-full border px-3 py-1 font-mono text-[11px] transition ${
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

                  <div className="rounded-xl border border-[color:var(--border)] bg-[color:var(--surface-soft)] p-4">
                    <div className="flex flex-wrap items-start justify-between gap-2">
                      <div>
                        <p className="text-xs font-medium text-[color:var(--ink-muted)]">
                          {providerLabel} API Key
                        </p>
                        <p className="text-xs text-[color:var(--ink-muted)]">{keyHint}</p>
                      </div>
                      <div className="text-xs text-[color:var(--ink-muted)]">{keyStatusLabel}</div>
                    </div>
                    <label
                      className="mt-3 grid gap-1 text-xs font-medium text-[color:var(--ink-muted)]"
                      htmlFor={`${kind}-${provider}-key`}
                    >
                      {providerLabel} API key
                      <input
                        id={`${kind}-${provider}-key`}
                        name={`${kind}-${provider}-key`}
                        type="password"
                        className="rounded-lg border border-[color:var(--border)] bg-[color:var(--surface)] px-3 py-2 text-sm text-[color:var(--ink)]"
                        value={keyValue}
                        onChange={(e) => updateKeyInput(kind, e.target.value)}
                        placeholder="sk-…"
                        autoComplete="off"
                      />
                    </label>
                    {keyErrors[kind] ? (
                      <p className="mt-2 text-xs text-[color:var(--danger-strong)]" role="alert">
                        {keyErrors[kind]}
                      </p>
                    ) : null}
                    {keyStatus?.updatedAt ? (
                      <p className="mt-2 text-xs text-[color:var(--ink-muted)]">
                        Updated {keyStatus.updatedAt}
                      </p>
                    ) : null}
                  </div>

                  <label
                    className="grid gap-2 text-xs font-medium text-[color:var(--ink-muted)]"
                    htmlFor={`${kind}-prompt`}
                  >
                    System prompt
                    <textarea
                      id={`${kind}-prompt`}
                      name={`${kind}-prompt`}
                      className="min-h-[120px] rounded-lg border border-[color:var(--border)] bg-[color:var(--surface)] px-3 py-2 text-sm text-[color:var(--ink)]"
                      value={forms[kind].system_prompt}
                      onChange={(e) => updateForm(kind, { system_prompt: e.target.value })}
                      autoComplete="off"
                    />
                  </label>
                </div>

                {history.length > 0 ? (
                  <div className="mt-6 border-t border-[color:var(--border)] pt-4">
                    <p className="text-xs font-medium text-[color:var(--ink-muted)]">
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
                              className={`rounded-full px-2 py-0.5 text-[11px] font-medium text-white ${
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
                                className="text-[11px] font-medium text-[color:var(--ink-muted)] hover:text-[color:var(--ink)]"
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
