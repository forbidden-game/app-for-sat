"use client";

import { useEffect, useMemo, useState } from "react";
import type { ReactNode } from "react";

import { estimateTokens, formatDateTime, serializeJson } from "./ai-log-utils";
import type { AiAgentLog } from "./actions";
import {
  CONTEXT_KEYS,
  CONTEXT_LABELS,
  buildPromptPack,
  extractContextStack,
  extractProvenance,
  formatPlain,
  parseOverride,
  stringifyWithMask,
  type ContextEntry,
  type ContextKey,
} from "./debug-helpers";
import { DiffField } from "./PromptDiff";

const LOCAL_STORAGE_PREFIX = "ai-debug-note";

type DebugPanelProps = {
  selectedLog: AiAgentLog | null;
  previousSuccessLog: AiAgentLog | null;
  maskEnabled: boolean;
  onToggleMask: (next: boolean) => void;
};

function useLocalStorageState(key: string | null, fallback: string) {
  const [state, setState] = useState(() => {
    if (!key || typeof window === "undefined") return fallback;
    return localStorage.getItem(key) ?? fallback;
  });

  useEffect(() => {
    if (!key) return;
    localStorage.setItem(key, state);
  }, [key, state]);

  return [state, setState] as const;
}

function Section({
  title,
  subtitle,
  children,
  defaultOpen = true,
}: {
  title: string;
  subtitle?: string;
  children: ReactNode;
  defaultOpen?: boolean;
}) {
  return (
    <details
      open={defaultOpen}
      className="rounded-2xl border border-[color:var(--border)] bg-[color:var(--surface-soft)] p-3"
    >
      <summary className="cursor-pointer list-none text-xs font-semibold uppercase tracking-[0.2em] text-[color:var(--ink-muted)] focus-visible:outline focus-visible:outline-2 focus-visible:outline-[color:var(--accent)] focus-visible:outline-offset-2">
        <div className="flex items-center justify-between gap-2">
          <span>{title}</span>
          {subtitle ? (
            <span className="text-[11px] font-normal uppercase tracking-[0.2em] text-[color:var(--ink-muted)]">
              {subtitle}
            </span>
          ) : null}
        </div>
      </summary>
      <div className="mt-3 space-y-3">{children}</div>
    </details>
  );
}

export function DebugPanel({ selectedLog, previousSuccessLog, maskEnabled, onToggleMask }: DebugPanelProps) {
  const contextEntries = useMemo(() => extractContextStack(selectedLog?.events ?? []), [selectedLog]);
  const provenance = useMemo(() => extractProvenance(selectedLog?.events ?? []), [selectedLog]);
  const promptPack = useMemo(() => (selectedLog ? buildPromptPack(selectedLog) : null), [selectedLog]);
  const previousPromptPack = useMemo(
    () => (previousSuccessLog ? buildPromptPack(previousSuccessLog) : null),
    [previousSuccessLog],
  );
  const defaultPinned = useMemo(
    () =>
      CONTEXT_KEYS.reduce((acc, key) => {
        acc[key] = contextEntries.some((entry) => entry.key === key);
        return acc;
      }, {} as Record<ContextKey, boolean>),
    [contextEntries],
  );

  const storageKey = selectedLog ? `${LOCAL_STORAGE_PREFIX}:${selectedLog.id}` : null;
  const prefsKey = storageKey ? `${storageKey}:prefs` : null;

  const [pinned, setPinned] = useState<Record<ContextKey, boolean>>(() => {
    if (!prefsKey || typeof window === "undefined") return defaultPinned;
    const stored = localStorage.getItem(prefsKey);
    if (!stored) return defaultPinned;
    try {
      const parsed = JSON.parse(stored) as { pinned?: Record<ContextKey, boolean> };
      return { ...defaultPinned, ...parsed.pinned };
    } catch {
      return defaultPinned;
    }
  });

  const [overrideText, setOverrideText] = useState<Record<ContextKey, string>>(() => {
    if (!prefsKey || typeof window === "undefined") {
      return {
        studentSnapshot: "",
        attemptContext: "",
        recentPerformance: "",
        curriculumState: "",
      };
    }
    const stored = localStorage.getItem(prefsKey);
    if (!stored) {
      return {
        studentSnapshot: "",
        attemptContext: "",
        recentPerformance: "",
        curriculumState: "",
      };
    }
    try {
      const parsed = JSON.parse(stored) as { overrides?: Record<ContextKey, string> };
      return {
        studentSnapshot: "",
        attemptContext: "",
        recentPerformance: "",
        curriculumState: "",
        ...parsed.overrides,
      };
    } catch {
      return {
        studentSnapshot: "",
        attemptContext: "",
        recentPerformance: "",
        curriculumState: "",
      };
    }
  });

  const [note, setNote] = useLocalStorageState(storageKey ? `${storageKey}:note` : null, "");
  const [copyStatus, setCopyStatus] = useState<string | null>(null);

  useEffect(() => {
    if (!prefsKey) return;
    const payload = JSON.stringify({ pinned, overrides: overrideText });
    localStorage.setItem(prefsKey, payload);
  }, [prefsKey, pinned, overrideText]);

  const replayPayload = useMemo(() => {
    if (!selectedLog || !promptPack) return null;

    const contextMap = contextEntries.reduce((acc, entry) => {
      acc[entry.key] = entry;
      return acc;
    }, {} as Record<ContextKey, ContextEntry>);

    const overrides: Record<string, unknown> = {};
    const overrideErrors: Record<string, string> = {};

    for (const key of CONTEXT_KEYS) {
      const parsed = parseOverride(overrideText[key]);
      if (parsed.error) {
        overrideErrors[key] = parsed.error;
      } else if (parsed.value !== null) {
        overrides[key] = parsed.value;
      }
    }

    return {
      payload: {
        log_id: selectedLog.id,
        kind: selectedLog.kind,
        created_at: selectedLog.created_at,
        prompt_pack: promptPack,
        pinned_context: CONTEXT_KEYS.reduce((acc, key) => {
          if (pinned[key] && contextMap[key]) {
            acc[key] = contextMap[key].data;
          }
          return acc;
        }, {} as Record<string, unknown>),
        overrides,
        note: note.trim() || null,
      },
      overrideErrors,
    };
  }, [selectedLog, promptPack, contextEntries, pinned, overrideText, note]);

  const tokenEstimate = useMemo(() => {
    if (!promptPack) return null;
    const current = serializeJson(promptPack, 2);
    const previous = previousPromptPack ? serializeJson(previousPromptPack, 2) : "";
    const currentTokens = estimateTokens(current);
    const previousTokens = previous ? estimateTokens(previous) : 0;
    return {
      currentTokens,
      previousTokens,
      delta: currentTokens - previousTokens,
    };
  }, [promptPack, previousPromptPack]);

  async function handleCopy(value: string) {
    try {
      await navigator.clipboard.writeText(value);
      setCopyStatus("Copied.");
    } catch {
      setCopyStatus("Copy failed. Try again.");
    } finally {
      setTimeout(() => setCopyStatus(null), 1400);
    }
  }

  return (
    <aside className="flex min-w-0 flex-col gap-4 rounded-2xl border border-[color:var(--border)] bg-[color:var(--surface)] p-4">
      <div className="text-xs uppercase tracking-[0.2em] text-[color:var(--ink-muted)]">Debug Panel</div>
      {!selectedLog ? <div className="text-xs text-[color:var(--ink-muted)]">No session selected.</div> : null}

      {selectedLog ? (
        <Section title="Session Meta" subtitle={selectedLog.status}>
          <div className="space-y-2 text-xs text-[color:var(--ink)]">
            <div className="flex min-w-0 items-start justify-between gap-2">
              <span className="shrink-0 text-[color:var(--ink-muted)]">Job</span>
              <span className="min-w-0 flex-1 truncate text-right tabular-nums">{selectedLog.job_id ?? "—"}</span>
            </div>
            <div className="flex min-w-0 items-start justify-between gap-2">
              <span className="shrink-0 text-[color:var(--ink-muted)]">Student</span>
              <span className="min-w-0 flex-1 truncate text-right tabular-nums">{selectedLog.student_id ?? "—"}</span>
            </div>
            <div className="flex min-w-0 items-start justify-between gap-2">
              <span className="shrink-0 text-[color:var(--ink-muted)]">Attempt</span>
              <span className="min-w-0 flex-1 truncate text-right tabular-nums">{selectedLog.attempt_id ?? "—"}</span>
            </div>
            <div className="flex min-w-0 items-start justify-between gap-2">
              <span className="shrink-0 text-[color:var(--ink-muted)]">Updated</span>
              <span className="min-w-0 flex-1 text-right tabular-nums">{formatDateTime(selectedLog.created_at)}</span>
            </div>
          </div>

          <div className="rounded-xl border border-[color:var(--border)] bg-[color:var(--surface)] p-3 text-[11px] text-[color:var(--ink-muted)] break-words">
            {selectedLog.error ? selectedLog.error : "No errors reported."}
          </div>
        </Section>
      ) : null}

      {selectedLog ? (
        <Section title="Context Stack" subtitle="Student/Attempt/Perf/Curriculum">
          {contextEntries.length === 0 ? (
            <div className="rounded-xl border border-dashed border-[color:var(--border)] bg-[color:var(--surface)] px-3 py-4 text-xs text-[color:var(--ink-muted)]">
              No context captured in events.
            </div>
          ) : (
            <div className="space-y-2">
              {contextEntries.map((entry) => (
                <details key={entry.key} className="rounded-xl border border-[color:var(--border)] bg-[color:var(--surface)] p-3">
                  <summary className="cursor-pointer list-none text-xs font-semibold text-[color:var(--ink)] focus-visible:outline focus-visible:outline-2 focus-visible:outline-[color:var(--accent)] focus-visible:outline-offset-2">
                    <div className="flex flex-wrap items-center justify-between gap-2">
                      <span>{entry.title}</span>
                      <div className="flex flex-wrap items-center gap-2 text-[10px] uppercase tracking-[0.2em] text-[color:var(--ink-muted)]">
                        <span className="rounded-full border border-[color:var(--border)] px-2 py-0.5">
                          {entry.source ?? "source: unknown"}
                        </span>
                        {entry.timestamp ? <span>{formatDateTime(entry.timestamp)}</span> : null}
                      </div>
                    </div>
                  </summary>
                  <pre className="mt-2 max-h-40 overflow-auto whitespace-pre-wrap break-words text-[11px] text-[color:var(--ink)]">
                    {stringifyWithMask(entry.data, maskEnabled)}
                  </pre>
                </details>
              ))}
            </div>
          )}
        </Section>
      ) : null}

      {selectedLog ? (
        <Section
          title="Prompt Pack Diff"
          subtitle={previousPromptPack ? "vs last success" : "no baseline"}
          defaultOpen={false}
        >
          {!promptPack ? (
            <div className="text-xs text-[color:var(--ink-muted)]">No prompt pack.</div>
          ) : previousPromptPack ? (
            <div className="space-y-3">
              {tokenEstimate ? (
                <div className="rounded-xl border border-[color:var(--border)] bg-[color:var(--surface)] px-3 py-2 text-[11px] text-[color:var(--ink-muted)]">
                  Tokens ~ {tokenEstimate.currentTokens}
                  {tokenEstimate.previousTokens
                    ? ` (prev ${tokenEstimate.previousTokens}, Δ ${tokenEstimate.delta >= 0 ? "+" : ""}${tokenEstimate.delta})`
                    : null}
                </div>
              ) : null}
              <DiffField
                label="system_prompt"
                currentValue={promptPack.system_prompt}
                previousValue={previousPromptPack.system_prompt}
                maskEnabled={maskEnabled}
              />
              <DiffField
                label="prompts"
                currentValue={promptPack.prompts}
                previousValue={previousPromptPack.prompts}
                maskEnabled={maskEnabled}
              />
              <DiffField
                label="model"
                currentValue={promptPack.model}
                previousValue={previousPromptPack.model}
                maskEnabled={maskEnabled}
              />
              <DiffField
                label="prompt_version"
                currentValue={promptPack.prompt_version}
                previousValue={previousPromptPack.prompt_version}
                maskEnabled={maskEnabled}
              />
            </div>
          ) : (
            <div className="text-xs text-[color:var(--ink-muted)]">No previous successful run found.</div>
          )}
        </Section>
      ) : null}

      {selectedLog ? (
        <Section title="Provenance" subtitle="Sources + raw JSON" defaultOpen={false}>
          {Object.keys(provenance).length === 0 ? (
            <div className="text-xs text-[color:var(--ink-muted)]">No provenance payload found in events.</div>
          ) : (
            <div className="space-y-2">
              {Object.entries(provenance).map(([key, entries]) => (
                <details key={key} className="rounded-xl border border-[color:var(--border)] bg-[color:var(--surface)] p-3">
                  <summary className="cursor-pointer list-none text-xs font-semibold text-[color:var(--ink)] focus-visible:outline focus-visible:outline-2 focus-visible:outline-[color:var(--accent)] focus-visible:outline-offset-2">
                    <div className="flex items-center justify-between gap-2">
                      <span>{key}</span>
                      <span className="text-[10px] uppercase tracking-[0.2em] text-[color:var(--ink-muted)]">
                        {entries.length} sources
                      </span>
                    </div>
                  </summary>
                  <div className="mt-2 space-y-2">
                    {entries.map((entry, index) => (
                      <div key={`${entry.label}-${index}`} className="rounded-lg border border-[color:var(--border)] bg-[color:var(--surface-soft)] px-3 py-2 text-[11px] text-[color:var(--ink-muted)]">
                        <div className="flex flex-wrap items-center justify-between gap-2">
                          <span className="text-[color:var(--ink)]">{entry.label}</span>
                          {entry.timestamp ? <span>{formatDateTime(entry.timestamp)}</span> : null}
                        </div>
                        <details className="mt-2">
                          <summary className="cursor-pointer text-[10px] uppercase tracking-[0.2em] focus-visible:outline focus-visible:outline-2 focus-visible:outline-[color:var(--accent)] focus-visible:outline-offset-2">
                            Raw JSON
                          </summary>
                          <pre className="mt-1 max-h-32 overflow-auto whitespace-pre-wrap break-words text-[10px] text-[color:var(--ink)]">
                            {stringifyWithMask(entry.raw, maskEnabled)}
                          </pre>
                        </details>
                      </div>
                    ))}
                  </div>
                </details>
              ))}
            </div>
          )}
        </Section>
      ) : null}

      {selectedLog ? (
        <Section title="Privacy" subtitle={maskEnabled ? "mask on" : "mask off"} defaultOpen={false}>
          <div className="flex flex-wrap items-center justify-between gap-3 text-xs text-[color:var(--ink)]">
            <span>PII masking (emails, phones, ids, UUIDs)</span>
            <button
              type="button"
              onClick={() => onToggleMask(!maskEnabled)}
              className={`rounded-full px-3 py-1 text-[11px] font-semibold uppercase tracking-[0.2em] transition hover:opacity-80 ${
                maskEnabled
                  ? "bg-emerald-100 text-emerald-700"
                  : "bg-[color:var(--surface-strong)] text-[color:var(--ink-muted)]"
              }`}
            >
              {maskEnabled ? "Masked" : "Raw"}
            </button>
          </div>
          <div className="grid gap-2 text-xs text-[color:var(--ink-muted)]">
            <button
              type="button"
              onClick={() => handleCopy(formatPlain(serializeJson(promptPack, 2), maskEnabled))}
              className="rounded-full border border-[color:var(--border)] bg-[color:var(--surface)] px-3 py-2 text-[11px] font-semibold uppercase tracking-[0.2em] text-[color:var(--ink)] transition hover:bg-[color:var(--surface-strong)]"
            >
              Copy Prompt Pack ({maskEnabled ? "masked" : "raw"})
            </button>
            {copyStatus ? <span role="status">{copyStatus}</span> : null}
          </div>
        </Section>
      ) : null}

      {selectedLog ? (
        <Section title="Replay Controls" subtitle="Pin + override + notes" defaultOpen={false}>
          <div className="space-y-3">
            {CONTEXT_KEYS.map((key) => {
              const parsed = parseOverride(overrideText[key]);
              const entry = contextEntries.find((item) => item.key === key);
              return (
                <div key={key} className="rounded-xl border border-[color:var(--border)] bg-[color:var(--surface)] p-3">
                  <div className="flex flex-wrap items-center justify-between gap-2">
                    <span className="text-xs font-semibold text-[color:var(--ink)]">{CONTEXT_LABELS[key]}</span>
                    <button
                      type="button"
                      onClick={() => setPinned((prev) => ({ ...prev, [key]: !prev[key] }))}
                      className={`rounded-full px-3 py-1 text-[10px] uppercase tracking-[0.2em] transition hover:opacity-80 ${
                        pinned[key]
                          ? "bg-[color:var(--accent)] text-white"
                          : "bg-[color:var(--surface-strong)] text-[color:var(--ink-muted)]"
                      }`}
                    >
                      {pinned[key] ? "Pinned" : "Unpinned"}
                    </button>
                  </div>
                  <div className="mt-2 text-[11px] text-[color:var(--ink-muted)]">
                    {entry ? "Using context captured in events." : "No context found; override JSON to inject."}
                  </div>
                  <label className="mt-2 grid gap-1 text-[10px] uppercase tracking-[0.2em] text-[color:var(--ink-muted)]">
                    Override JSON
                    <textarea
                      value={overrideText[key]}
                      name={`override-${key}`}
                      autoComplete="off"
                      spellCheck={false}
                      onChange={(event) =>
                        setOverrideText((prev) => ({
                          ...prev,
                          [key]: event.target.value,
                        }))
                      }
                      className="min-h-[80px] rounded-lg border border-[color:var(--border)] bg-[color:var(--surface)] px-3 py-2 text-[11px] text-[color:var(--ink)]"
                      placeholder='{"field": "value"}'
                    />
                  </label>
                  {parsed.error ? <div className="text-[11px] text-amber-700">{parsed.error}</div> : null}
                </div>
              );
            })}

            <label className="grid gap-1 text-[10px] uppercase tracking-[0.2em] text-[color:var(--ink-muted)]">
              Debug note
              <textarea
                value={note}
                name="debug-note"
                autoComplete="off"
                onChange={(event) => setNote(event.target.value)}
                className="min-h-[80px] rounded-lg border border-[color:var(--border)] bg-[color:var(--surface)] px-3 py-2 text-[11px] text-[color:var(--ink)]"
                placeholder="Why this replay matters…"
              />
            </label>

            <div className="grid gap-2">
              <button
                type="button"
                className="rounded-full bg-[color:var(--accent)] px-4 py-2 text-[11px] font-semibold uppercase tracking-[0.2em] text-white transition hover:bg-[color:var(--accent-strong)]"
                onClick={() =>
                  handleCopy(
                    formatPlain(
                      serializeJson(replayPayload?.payload ?? {}, 2),
                      maskEnabled,
                    ),
                  )
                }
              >
                Copy Replay Payload
              </button>
              {Object.values(replayPayload?.overrideErrors ?? {}).length > 0 ? (
                <div className="text-[11px] text-amber-700">Fix override JSON errors before replay.</div>
              ) : null}
              {copyStatus ? (
                <div className="text-[11px] text-[color:var(--ink-muted)]" role="status" aria-live="polite">
                  {copyStatus}
                </div>
              ) : null}
            </div>
          </div>
        </Section>
      ) : null}
    </aside>
  );
}
