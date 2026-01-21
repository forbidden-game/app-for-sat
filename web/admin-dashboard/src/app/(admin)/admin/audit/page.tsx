"use client";

import { useEffect, useMemo, useState } from "react";
import { getSupabaseClient } from "@/lib/supabaseClient";
import { listAdminAuditLogs, type AdminAuditLog } from "./actions";
import { useSortable, SortableHeader } from "@/hooks/useSortable";

function formatDateTime(value: string) {
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

function csvEscape(value: string) {
  const escaped = value.replace(/"/g, '""');
  return `"${escaped}"`;
}

function buildCsv(logs: AdminAuditLog[]) {
  const header = ["created_at", "actor_email", "action", "resource_type", "resource_id", "metadata"];
  const rows = logs.map((log) => [
    log.created_at,
    log.actor_email ?? "",
    log.action,
    log.resource_type,
    log.resource_id ?? "",
    JSON.stringify(log.metadata ?? {}),
  ]);
  return [header, ...rows]
    .map((row) => row.map((col) => csvEscape(String(col ?? ""))).join(","))
    .join("\n");
}

export default function AuditLogPage() {
  const supabase = getSupabaseClient();
  const [logs, setLogs] = useState<AdminAuditLog[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

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
        const data = await listAdminAuditLogs(session.access_token, 300);
        if (!active) return;
        setLogs(data);
        setError(null);
      } catch (err) {
        if (active) {
          setError(err instanceof Error ? err.message : "Failed to load audit logs.");
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

  const csv = useMemo(() => buildCsv(logs), [logs]);

  // Sortable hook for audit log table
  const { sortedData: sortedLogs, handleSort: handleAuditSort, sortConfig: auditSortConfig } = useSortable(
    logs,
    "created_at",
    "desc",
  );

  function downloadCsv() {
    const blob = new Blob([csv], { type: "text/csv;charset=utf-8;" });
    const url = URL.createObjectURL(blob);
    const link = document.createElement("a");
    link.href = url;
    link.download = `admin-audit-${new Date().toISOString().slice(0, 10)}.csv`;
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    URL.revokeObjectURL(url);
  }

  if (loading) {
    return (
      <main className="mx-auto max-w-[1280px] px-6 py-12">
        <p className="text-sm text-[color:var(--ink-muted)]" role="status" aria-live="polite">
          Loading audit logs…
        </p>
      </main>
    );
  }

  return (
    <main className="mx-auto flex max-w-[1280px] flex-col gap-6 px-6 pb-10 pt-8">
      <header className="flex flex-wrap items-center justify-between gap-4">
        <div>
          <p className="text-xs font-medium text-[color:var(--ink-muted)]">Admin Console</p>
          <h1 className="text-2xl font-semibold tracking-tight text-[color:var(--ink)]">Audit Log</h1>
          <p className="text-sm text-[color:var(--ink-muted)]">Last 7 days of admin activity.</p>
        </div>
        <button
          type="button"
          onClick={downloadCsv}
          className="rounded-full border border-[color:var(--border)] bg-[color:var(--surface)] px-4 py-2 text-xs font-medium text-[color:var(--ink-muted)] transition hover:border-[color:var(--accent)] hover:text-[color:var(--ink)]"
        >
          Export CSV
        </button>
      </header>

      {error ? (
        <div
          className="rounded-xl border border-[color:var(--danger)] bg-[color:var(--surface)] px-4 py-3 text-sm text-[color:var(--danger-strong)]"
          role="alert"
        >
          {error}
        </div>
      ) : null}

      <div className="overflow-hidden rounded-xl border border-[color:var(--border)] bg-[color:var(--surface)]">
        <table className="w-full text-left text-sm text-[color:var(--ink-muted)]">
          <thead className="bg-[color:var(--surface-soft)] text-xs font-medium text-[color:var(--ink-muted)]">
            <tr>
              <SortableHeader
                column="created_at"
                label="Time"
                currentSort={auditSortConfig}
                onSort={(col) => handleAuditSort(col as keyof AdminAuditLog)}
                className="px-4 py-3"
              />
              <SortableHeader
                column="actor_email"
                label="Actor"
                currentSort={auditSortConfig}
                onSort={(col) => handleAuditSort(col as keyof AdminAuditLog)}
                className="px-4 py-3"
              />
              <SortableHeader
                column="action"
                label="Action"
                currentSort={auditSortConfig}
                onSort={(col) => handleAuditSort(col as keyof AdminAuditLog)}
                className="px-4 py-3"
              />
              <SortableHeader
                column="resource_type"
                label="Resource"
                currentSort={auditSortConfig}
                onSort={(col) => handleAuditSort(col as keyof AdminAuditLog)}
                className="px-4 py-3"
              />
              <th scope="col" className="px-4 py-3">Details</th>
            </tr>
          </thead>
          <tbody>
            {sortedLogs.length === 0 ? (
              <tr>
                <td
                  colSpan={5}
                  className="px-4 py-8 text-center text-[color:var(--ink-muted)]"
                  role="status"
                  aria-live="polite"
                >
                  No audit events yet.
                </td>
              </tr>
            ) : (
              sortedLogs.map((log) => (
                <tr key={log.id} className="border-t border-[color:var(--border)] hover:bg-[color:var(--surface-soft)]">
                  <td className="px-4 py-3 text-xs text-[color:var(--ink-muted)]">
                    {formatDateTime(log.created_at)}
                  </td>
                  <td className="px-4 py-3 text-xs text-[color:var(--ink)]">{log.actor_email ?? "unknown"}</td>
                  <td className="px-4 py-3 text-xs text-[color:var(--ink)]">{log.action}</td>
                  <td className="px-4 py-3 text-xs text-[color:var(--ink)]">
                    {log.resource_type}
                    {log.resource_id ? ` · ${log.resource_id.slice(0, 8)}` : ""}
                  </td>
                  <td className="px-4 py-3 text-[11px] text-[color:var(--ink-muted)]">
                    {JSON.stringify(log.metadata ?? {})}
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>
    </main>
  );
}
