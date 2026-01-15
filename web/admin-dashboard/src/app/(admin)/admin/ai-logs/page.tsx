"use client";

import { useEffect, useMemo, useState } from "react";
import { getSupabaseClient } from "@/lib/supabaseClient";
import { listAiAgentLogs, type AiAgentLog } from "./actions";

function formatDateTime(value: string) {
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return value;
  return date.toLocaleString();
}

export default function AiLogsPage() {
  const supabase = getSupabaseClient();
  const [logs, setLogs] = useState<AiAgentLog[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [query, setQuery] = useState("");
  const [kindFilter, setKindFilter] = useState("all");
  const [statusFilter, setStatusFilter] = useState("all");
  const [providerFilter, setProviderFilter] = useState("all");
  const [copyStatus, setCopyStatus] = useState<string | null>(null);

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
        const data = await listAiAgentLogs(session.access_token, 200);
        if (!active) return;
        setLogs(data);
        setError(null);
      } catch (err) {
        if (active) {
          setError(err instanceof Error ? err.message : "Failed to load agent logs.");
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

  const kindOptions = useMemo(() => {
    return Array.from(new Set(logs.map((log) => log.kind))).sort();
  }, [logs]);

  const providerOptions = useMemo(() => {
    return Array.from(new Set(logs.map((log) => log.model_provider))).sort();
  }, [logs]);

  const filteredLogs = useMemo(() => {
    const normalized = query.trim().toLowerCase();
    return logs.filter((log) => {
      if (kindFilter !== "all" && log.kind !== kindFilter) return false;
      if (statusFilter !== "all" && log.status !== statusFilter) return false;
      if (providerFilter !== "all" && log.model_provider !== providerFilter) return false;
      if (!normalized) return true;
      const haystack = [
        log.job_id ?? "",
        log.student_id ?? "",
        log.attempt_id ?? "",
        log.prompt_version ?? "",
        log.model_id,
        log.model_provider,
      ]
        .join(" ")
        .toLowerCase();
      return haystack.includes(normalized);
    });
  }, [logs, kindFilter, statusFilter, providerFilter, query]);

  useEffect(() => {
    if (filteredLogs.length === 0) {
      if (selectedId) setSelectedId(null);
      return;
    }
    const stillVisible = filteredLogs.some((log) => log.id === selectedId);
    if (!stillVisible) {
      setSelectedId(filteredLogs[0].id);
    }
  }, [filteredLogs, selectedId]);

  const selectedLog = useMemo(() => {
    return filteredLogs.find((log) => log.id === selectedId) ?? null;
  }, [filteredLogs, selectedId]);

  const events = useMemo(() => {
    if (!selectedLog || !Array.isArray(selectedLog.events)) return [];
    return selectedLog.events as Array<Record<string, unknown>>;
  }, [selectedLog]);

  const promptPack = useMemo(() => {
    if (!selectedLog) return "";
    return JSON.stringify(
      {
        system_prompt: selectedLog.system_prompt,
        prompts: selectedLog.prompts,
        model: `${selectedLog.model_provider}/${selectedLog.model_id}`,
        prompt_version: selectedLog.prompt_version,
      },
      null,
      2,
    );
  }, [selectedLog]);

  async function handleCopy(text: string) {
    try {
      await navigator.clipboard.writeText(text);
      setCopyStatus("Copied.");
    } catch {
      setCopyStatus("Copy failed.");
    } finally {
      setTimeout(() => setCopyStatus(null), 1600);
    }
  }

  if (loading) {
    return (
      <main className="mx-auto max-w-6xl px-6 py-12">
        <p className="text-sm text-[color:var(--ink-muted)]" role="status" aria-live="polite">
          Loading agent logs…
        </p>
      </main>
    );
  }

  return (
    <main className="mx-auto flex max-w-[1200px] flex-col gap-6 px-6 py-8">
      <header className="flex flex-wrap items-end justify-between gap-4">
        <div className="min-w-0">
          <p className="text-xs uppercase tracking-[0.2em] text-[color:var(--ink-muted)]">Admin Console</p>
          <h1 className="text-2xl font-semibold text-[color:var(--ink)]">AI Debug Workbench</h1>
          <p className="text-sm text-[color:var(--ink-muted)]">
            Unified view for runs, prompts, tool traces, and retry context.
          </p>
        </div>
        <div className="flex flex-wrap items-center gap-2 text-xs text-[color:var(--ink-muted)]">
          <span className="rounded-full border border-[color:var(--border)] px-3 py-1">Live</span>
          <span>{logs.length} sessions</span>
        </div>
      </header>

      {error ? (
        <div
          className="rounded-2xl border border-amber-200 bg-amber-50 px-4 py-3 text-sm text-amber-800"
          role="alert"
        >
          {error}
        </div>
      ) : null}

      <section className="grid gap-4 rounded-3xl border border-[color:var(--border)] bg-[color:var(--surface)] p-4 md:grid-cols-[280px_minmax(0,1fr)_320px]">
        <aside className="flex min-w-0 flex-col gap-4">
          <div className="rounded-2xl border border-[color:var(--border)] bg-[color:var(--surface-soft)] p-3">
            <div className="text-xs uppercase tracking-[0.2em] text-[color:var(--ink-muted)]">Filters</div>
            <div className="mt-3 grid gap-2">
              <input
                className="rounded-lg border border-[color:var(--border)] bg-[color:var(--surface)] px-3 py-2 text-xs text-[color:var(--ink)]"
                placeholder="Search job/student/model…"
                value={query}
                onChange={(e) => setQuery(e.target.value)}
              />
              <div className="grid gap-2">
                <select
                  className="rounded-lg border border-[color:var(--border)] bg-[color:var(--surface)] px-3 py-2 text-xs"
                  value={kindFilter}
                  onChange={(e) => setKindFilter(e.target.value)}
                >
                  <option value="all">All kinds</option>
                  {kindOptions.map((kind) => (
                    <option key={kind} value={kind}>
                      {kind}
                    </option>
                  ))}
                </select>
                <select
                  className="rounded-lg border border-[color:var(--border)] bg-[color:var(--surface)] px-3 py-2 text-xs"
                  value={statusFilter}
                  onChange={(e) => setStatusFilter(e.target.value)}
                >
                  <option value="all">All status</option>
                  <option value="done">done</option>
                  <option value="error">error</option>
                </select>
                <select
                  className="rounded-lg border border-[color:var(--border)] bg-[color:var(--surface)] px-3 py-2 text-xs"
                  value={providerFilter}
                  onChange={(e) => setProviderFilter(e.target.value)}
                >
                  <option value="all">All providers</option>
                  {providerOptions.map((provider) => (
                    <option key={provider} value={provider}>
                      {provider}
                    </option>
                  ))}
                </select>
              </div>
            </div>
          </div>

          <div className="flex-1 space-y-2 overflow-auto pr-1">
            {filteredLogs.length === 0 ? (
              <div className="rounded-xl border border-dashed border-[color:var(--border)] bg-[color:var(--surface-soft)] px-3 py-6 text-xs text-[color:var(--ink-muted)]">
                No sessions match.
              </div>
            ) : (
              filteredLogs.map((log) => (
                <button
                  key={log.id}
                  type="button"
                  onClick={() => setSelectedId(log.id)}
                  className={`flex w-full min-w-0 flex-col gap-2 rounded-2xl border px-3 py-3 text-left text-xs transition ${
                    log.id === selectedLog?.id
                      ? "border-[color:var(--accent)] bg-[color:var(--surface)]"
                      : "border-[color:var(--border)] bg-[color:var(--surface-soft)] hover:bg-[color:var(--surface)]"
                  }`}
                >
                  <div className="flex min-w-0 items-center justify-between gap-2 text-[color:var(--ink-muted)]">
                    <span className="truncate">{formatDateTime(log.created_at)}</span>
                    <span className="rounded-full bg-[color:var(--surface-strong)] px-2 py-0.5 text-[10px] uppercase tracking-[0.18em]">
                      {log.kind}
                    </span>
                  </div>
                  <div className="truncate font-medium text-[color:var(--ink)]">
                    {log.model_provider}/{log.model_id}
                  </div>
                  <div className="flex items-center gap-2 text-[10px] uppercase tracking-[0.2em] text-[color:var(--ink-muted)]">
                    <span
                      className={`rounded-full px-2 py-0.5 ${
                        log.status === "done" ? "bg-emerald-100 text-emerald-700" : "bg-amber-100 text-amber-700"
                      }`}
                    >
                      {log.status}
                    </span>
                    {log.error ? <span className="text-amber-700">error</span> : null}
                  </div>
                </button>
              ))
            )}
          </div>
        </aside>

        <section className="flex min-w-0 flex-col gap-4 rounded-2xl border border-[color:var(--border)] bg-[color:var(--surface)] p-4">
          {selectedLog ? (
            <>
              <div className="flex flex-wrap items-center justify-between gap-3">
                <div className="min-w-0">
                  <div className="text-xs uppercase tracking-[0.2em] text-[color:var(--ink-muted)]">Session</div>
                  <div className="text-lg font-semibold text-[color:var(--ink)]">{selectedLog.kind}</div>
                  <div className="truncate text-xs text-[color:var(--ink-muted)]">
                    {selectedLog.model_provider}/{selectedLog.model_id} · {selectedLog.prompt_version ?? "—"}
                  </div>
                </div>
                <span
                  className={`rounded-full px-3 py-1 text-[11px] uppercase tracking-[0.2em] ${
                    selectedLog.status === "done" ? "bg-emerald-100 text-emerald-700" : "bg-amber-100 text-amber-700"
                  }`}
                >
                  {selectedLog.status}
                </span>
              </div>

              <div className="grid gap-3">
                <div className="rounded-xl border border-[color:var(--border)] bg-[color:var(--surface-soft)] p-3">
                  <div className="text-[11px] uppercase tracking-[0.2em] text-[color:var(--ink-muted)]">
                    System prompt
                  </div>
                  <pre className="mt-2 max-h-40 overflow-auto whitespace-pre-wrap break-words text-xs text-[color:var(--ink)]">
                    {selectedLog.system_prompt ?? ""}
                  </pre>
                </div>

                <div className="rounded-xl border border-[color:var(--border)] bg-[color:var(--surface-soft)] p-3">
                  <div className="text-[11px] uppercase tracking-[0.2em] text-[color:var(--ink-muted)]">Prompts</div>
                  <pre className="mt-2 max-h-52 overflow-auto whitespace-pre-wrap break-words text-xs text-[color:var(--ink)]">
                    {JSON.stringify(selectedLog.prompts ?? [], null, 2)}
                  </pre>
                </div>

                <div className="rounded-xl border border-[color:var(--border)] bg-[color:var(--surface-soft)] p-3">
                  <div className="text-[11px] uppercase tracking-[0.2em] text-[color:var(--ink-muted)]">Event timeline</div>
                  <div className="mt-3 grid gap-2">
                    {events.length === 0 ? (
                      <div className="text-xs text-[color:var(--ink-muted)]">No event stream captured.</div>
                    ) : (
                      events.map((event, index) => {
                        const type = String(event.type ?? "event");
                        const stamp = typeof event.logged_at === "string" ? event.logged_at : "";
                        return (
                          <div key={`${type}-${index}`} className="flex flex-col gap-2 text-xs sm:flex-row sm:gap-3">
                            <div className="sm:min-w-[120px] text-[color:var(--ink-muted)]">
                              {stamp ? formatDateTime(stamp) : "—"}
                            </div>
                            <div className="min-w-0 flex-1 rounded-lg border border-[color:var(--border)] bg-[color:var(--surface)] px-3 py-2">
                              <div className="text-[11px] uppercase tracking-[0.2em] text-[color:var(--ink-muted)]">
                                {type}
                              </div>
                              <pre className="mt-1 max-h-40 overflow-auto whitespace-pre-wrap break-words text-[11px] text-[color:var(--ink)]">
                                {JSON.stringify(event, null, 2)}
                              </pre>
                            </div>
                          </div>
                        );
                      })
                    )}
                  </div>
                </div>
              </div>
            </>
          ) : (
            <div className="rounded-xl border border-dashed border-[color:var(--border)] bg-[color:var(--surface-soft)] px-4 py-8 text-sm text-[color:var(--ink-muted)]">
              Select a session to inspect.
            </div>
          )}
        </section>

        <aside className="flex min-w-0 flex-col gap-4 rounded-2xl border border-[color:var(--border)] bg-[color:var(--surface)] p-4">
          <div className="text-xs uppercase tracking-[0.2em] text-[color:var(--ink-muted)]">Debug Panel</div>
          {selectedLog ? (
            <>
              <div className="space-y-2 text-xs text-[color:var(--ink)]">
                <div className="flex min-w-0 items-start justify-between gap-2">
                  <span className="shrink-0 text-[color:var(--ink-muted)]">Job</span>
                  <span className="min-w-0 flex-1 truncate text-right">{selectedLog.job_id ?? "—"}</span>
                </div>
                <div className="flex min-w-0 items-start justify-between gap-2">
                  <span className="shrink-0 text-[color:var(--ink-muted)]">Student</span>
                  <span className="min-w-0 flex-1 truncate text-right">{selectedLog.student_id ?? "—"}</span>
                </div>
                <div className="flex min-w-0 items-start justify-between gap-2">
                  <span className="shrink-0 text-[color:var(--ink-muted)]">Attempt</span>
                  <span className="min-w-0 flex-1 truncate text-right">{selectedLog.attempt_id ?? "—"}</span>
                </div>
                <div className="flex min-w-0 items-start justify-between gap-2">
                  <span className="shrink-0 text-[color:var(--ink-muted)]">Updated</span>
                  <span className="min-w-0 flex-1 text-right">{formatDateTime(selectedLog.created_at)}</span>
                </div>
              </div>

              <div className="rounded-xl border border-[color:var(--border)] bg-[color:var(--surface-soft)] p-3 text-xs text-[color:var(--ink-muted)] break-words">
                {selectedLog.error ? selectedLog.error : "No errors reported."}
              </div>

              <button
                type="button"
                onClick={() => handleCopy(promptPack)}
                className="rounded-full bg-[color:var(--accent)] px-4 py-2 text-xs font-semibold text-white transition hover:bg-[color:var(--accent-strong)]"
              >
                Copy prompt pack
              </button>
              {copyStatus ? <div className="text-xs text-[color:var(--ink-muted)]">{copyStatus}</div> : null}
            </>
          ) : (
            <div className="text-xs text-[color:var(--ink-muted)]">No session selected.</div>
          )}
        </aside>
      </section>
    </main>
  );
}
