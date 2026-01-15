"use client";

import { useEffect, useMemo, useState } from "react";
import { getSupabaseClient } from "@/lib/supabaseClient";
import { listAdminAuditLogs, type AdminAuditLog } from "./actions";

function formatDateTime(value: string) {
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return value;
  return date.toLocaleString("en-US", {
    month: "short",
    day: "numeric",
    year: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  });
}

function csvEscape(value: string) {
  const escaped = value.replace(/"/g, '""');
  return `"${escaped}"`;
}

function buildCsv(logs: AdminAuditLog[]) {
  const header = [
    "created_at",
    "actor_email",
    "action",
    "resource_type",
    "resource_id",
    "metadata",
  ];
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
      <main className="mx-auto max-w-6xl px-6 py-12">
        <p className="text-sm text-zinc-500">Loading audit logs...</p>
      </main>
    );
  }

  return (
    <main className="mx-auto flex max-w-6xl flex-col gap-8 px-6 py-8">
      <header className="flex flex-wrap items-center justify-between gap-4">
        <div>
          <p className="text-xs uppercase tracking-[0.2em] text-zinc-400">Admin Console</p>
          <h1 className="text-2xl font-semibold text-zinc-900">Audit Log</h1>
          <p className="text-sm text-zinc-500">Last 7 days of admin activity.</p>
        </div>
        <button
          type="button"
          onClick={downloadCsv}
          className="rounded-full border border-zinc-200 px-4 py-2 text-xs text-zinc-700 hover:border-zinc-300"
        >
          Export CSV
        </button>
      </header>

      {error ? (
        <div className="rounded-2xl border border-amber-200 bg-amber-50 px-4 py-3 text-sm text-amber-800">
          {error}
        </div>
      ) : null}

      <div className="overflow-hidden rounded-2xl border border-zinc-200 bg-white">
        <table className="w-full text-left text-sm text-zinc-700">
          <thead className="bg-zinc-50 text-xs uppercase tracking-wide text-zinc-500">
            <tr>
              <th className="px-4 py-3">Time</th>
              <th className="px-4 py-3">Actor</th>
              <th className="px-4 py-3">Action</th>
              <th className="px-4 py-3">Resource</th>
              <th className="px-4 py-3">Details</th>
            </tr>
          </thead>
          <tbody>
            {logs.length === 0 ? (
              <tr>
                <td colSpan={5} className="px-4 py-8 text-center text-zinc-500">
                  No audit events yet.
                </td>
              </tr>
            ) : (
              logs.map((log) => (
                <tr key={log.id} className="border-t border-zinc-100">
                  <td className="px-4 py-3 text-xs text-zinc-500">
                    {formatDateTime(log.created_at)}
                  </td>
                  <td className="px-4 py-3 text-xs text-zinc-700">
                    {log.actor_email ?? "unknown"}
                  </td>
                  <td className="px-4 py-3 text-xs text-zinc-700">{log.action}</td>
                  <td className="px-4 py-3 text-xs text-zinc-700">
                    {log.resource_type}
                    {log.resource_id ? ` · ${log.resource_id.slice(0, 8)}` : ""}
                  </td>
                  <td className="px-4 py-3 text-[11px] text-zinc-500">
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
