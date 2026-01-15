"use client";

import { useEffect, useState } from "react";
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
    <main className="mx-auto flex max-w-6xl flex-col gap-6 px-6 py-8">
      <header>
        <p className="text-xs uppercase tracking-[0.2em] text-[color:var(--ink-muted)]">Admin Console</p>
        <h1 className="text-2xl font-semibold text-[color:var(--ink)]">AI Agent Logs</h1>
        <p className="text-sm text-[color:var(--ink-muted)]">
          Recent agent runs for prompt debugging and tool traces.
        </p>
      </header>

      {error ? (
        <div
          className="rounded-2xl border border-amber-200 bg-amber-50 px-4 py-3 text-sm text-amber-800"
          role="alert"
        >
          {error}
        </div>
      ) : null}

      <section className="rounded-2xl border border-[color:var(--border)] bg-[color:var(--surface)]">
        <div className="overflow-x-auto">
          <table className="min-w-full text-left text-sm">
            <thead className="border-b border-[color:var(--border)] text-xs uppercase tracking-[0.2em] text-[color:var(--ink-muted)]">
              <tr>
                <th className="px-4 py-3">Time</th>
                <th className="px-4 py-3">Kind</th>
                <th className="px-4 py-3">Status</th>
                <th className="px-4 py-3">Model</th>
                <th className="px-4 py-3">Prompt</th>
              </tr>
            </thead>
            <tbody>
              {logs.length === 0 ? (
                <tr>
                  <td className="px-4 py-6 text-sm text-[color:var(--ink-muted)]" colSpan={5}>
                    No agent logs yet.
                  </td>
                </tr>
              ) : (
                logs.map((log) => (
                  <tr key={log.id} className="border-t border-[color:var(--border)] align-top">
                    <td className="px-4 py-3 text-xs text-[color:var(--ink-muted)]">
                      {formatDateTime(log.created_at)}
                    </td>
                    <td className="px-4 py-3 text-xs text-[color:var(--ink)]">{log.kind}</td>
                    <td className="px-4 py-3 text-xs text-[color:var(--ink)]">
                      <span
                        className={`rounded-full px-2 py-0.5 text-[11px] ${
                          log.status === "done"
                            ? "bg-emerald-100 text-emerald-700"
                            : "bg-amber-100 text-amber-700"
                        }`}
                      >
                        {log.status}
                      </span>
                      {log.error ? <div className="mt-1 text-[11px] text-amber-700">{log.error}</div> : null}
                    </td>
                    <td className="px-4 py-3 text-xs text-[color:var(--ink)]">
                      {log.model_provider}/{log.model_id}
                    </td>
                    <td className="px-4 py-3 text-xs text-[color:var(--ink-muted)]">
                      <details className="group">
                        <summary className="cursor-pointer text-[color:var(--ink)] underline-offset-4 hover:underline">
                          View details
                        </summary>
                        <div className="mt-2 space-y-3">
                          <div>
                            <div className="text-[11px] uppercase tracking-[0.16em] text-[color:var(--ink-muted)]">
                              Prompt version
                            </div>
                            <div className="text-xs text-[color:var(--ink)]">{log.prompt_version ?? "—"}</div>
                          </div>
                          <div>
                            <div className="text-[11px] uppercase tracking-[0.16em] text-[color:var(--ink-muted)]">
                              System prompt
                            </div>
                            <pre className="mt-1 max-h-48 overflow-auto rounded-lg border border-[color:var(--border)] bg-[color:var(--surface-soft)] p-3 text-xs text-[color:var(--ink)]">
                              {log.system_prompt ?? ""}
                            </pre>
                          </div>
                          <div>
                            <div className="text-[11px] uppercase tracking-[0.16em] text-[color:var(--ink-muted)]">
                              Prompts
                            </div>
                            <pre className="mt-1 max-h-64 overflow-auto rounded-lg border border-[color:var(--border)] bg-[color:var(--surface-soft)] p-3 text-xs text-[color:var(--ink)]">
                              {JSON.stringify(log.prompts ?? [], null, 2)}
                            </pre>
                          </div>
                          <div>
                            <div className="text-[11px] uppercase tracking-[0.16em] text-[color:var(--ink-muted)]">
                              Events
                            </div>
                            <pre className="mt-1 max-h-64 overflow-auto rounded-lg border border-[color:var(--border)] bg-[color:var(--surface-soft)] p-3 text-xs text-[color:var(--ink)]">
                              {JSON.stringify(log.events ?? [], null, 2)}
                            </pre>
                          </div>
                        </div>
                      </details>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </section>
    </main>
  );
}
