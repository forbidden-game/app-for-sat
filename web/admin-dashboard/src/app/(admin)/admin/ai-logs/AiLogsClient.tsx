"use client";

import { useCallback, useMemo, useState } from "react";
import { usePathname, useRouter, useSearchParams } from "next/navigation";

import AiLogsConversations from "./AiLogsConversations";
import AiLogsWorkbench from "./AiLogsWorkbench";

type ViewId = "conversations" | "workbench";

function resolveView(searchParams: ReturnType<typeof useSearchParams>): ViewId {
  const raw = searchParams.get("view");
  if (raw === "conversations" || raw === "workbench") return raw;

  // Backward-compatible: if someone links directly to a specific log/workbench filter,
  // default to the workbench.
  const hasWorkbenchParams = Boolean(
    searchParams.get("log") ||
      searchParams.get("q") ||
      searchParams.get("kind") ||
      searchParams.get("status") ||
      searchParams.get("provider"),
  );

  return hasWorkbenchParams ? "workbench" : "conversations";
}

export default function AiLogsClient() {
  const router = useRouter();
  const pathname = usePathname();
  const searchParams = useSearchParams();

  const view = useMemo(() => resolveView(searchParams), [searchParams]);
  const [maskEnabled, setMaskEnabled] = useState(true);


  const setView = useCallback(
    (next: ViewId) => {
      const params = new URLSearchParams(searchParams);
      params.set("view", next);
      const nextQuery = params.toString();
      router.replace(nextQuery ? `${pathname}?${nextQuery}` : pathname, { scroll: false });
    },
    [pathname, router, searchParams],
  );

  const handleOpenWorkbench = useCallback(
    (logId: string) => {
      const params = new URLSearchParams(searchParams);
      params.set("view", "workbench");
      params.set("log", logId);
      const nextQuery = params.toString();
      router.replace(nextQuery ? `${pathname}?${nextQuery}` : pathname, { scroll: false });
    },
    [pathname, router, searchParams],
  );

  return (
    <>
      <a
        href="#ai-logs-main"
        className="sr-only focus:not-sr-only focus:fixed focus:left-6 focus:top-6 focus:z-50 focus:rounded-full focus:bg-[color:var(--accent)] focus:px-4 focus:py-2 focus:text-xs focus:font-semibold focus:text-white"
      >
        Skip to main content
      </a>

      <main id="ai-logs-main" className="mx-auto flex max-w-[1440px] flex-col gap-5 overflow-x-hidden px-6 pb-10 pt-8">
        <header className="flex flex-wrap items-end justify-between gap-4">
          <div className="min-w-0">
            <p className="text-[11px] uppercase tracking-[0.2em] text-[color:var(--ink-muted)]">Admin Console</p>
            <h1 className="text-balance text-2xl font-semibold text-[color:var(--ink)]">AI Logs</h1>
            <p className="text-sm text-[color:var(--ink-muted)]">
              Conversation-first view for coach chat, plus the original debug workbench.
            </p>
          </div>

          <div className="flex flex-wrap items-center gap-2">
            <div className="flex items-center gap-2 rounded-full border border-[color:var(--border)] bg-[color:var(--surface)] p-1 text-[10px] font-semibold uppercase tracking-[0.2em]">
              <button
                type="button"
                onClick={() => setView("conversations")}
                className={`rounded-full px-3 py-1 transition ${
                  view === "conversations"
                    ? "bg-[color:var(--surface-strong)] text-[color:var(--ink)]"
                    : "text-[color:var(--ink-muted)] hover:text-[color:var(--ink)]"
                }`}
                aria-current={view === "conversations" ? "page" : undefined}
              >
                Conversations
              </button>
              <button
                type="button"
                onClick={() => setView("workbench")}
                className={`rounded-full px-3 py-1 transition ${
                  view === "workbench"
                    ? "bg-[color:var(--surface-strong)] text-[color:var(--ink)]"
                    : "text-[color:var(--ink-muted)] hover:text-[color:var(--ink)]"
                }`}
                aria-current={view === "workbench" ? "page" : undefined}
              >
                Debug Workbench
              </button>
            </div>
          </div>
        </header>

        {view === "conversations" ? (
          <AiLogsConversations
            maskEnabled={maskEnabled}
            onToggleMask={setMaskEnabled}
            onOpenWorkbench={handleOpenWorkbench}
          />
        ) : (
          <AiLogsWorkbench maskEnabled={maskEnabled} onToggleMask={setMaskEnabled} />
        )}
      </main>
    </>
  );
}
