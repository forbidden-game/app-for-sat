"use client";

import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { usePathname, useRouter, useSearchParams } from "next/navigation";

import { getSupabaseClient } from "@/lib/supabaseClient";

import {
  getCoachThreadDetail,
  listCoachThreads,
  searchCoachMessages,
  type CoachMessageSearchResult,
  type CoachReplyLogMeta,
  type CoachThreadDetail,
  type CoachThreadListItem,
  type CoachThreadMessage,
} from "./conversation-actions";
import { estimateTokens, formatDateTime, maskPII, serializeJson } from "./ai-log-utils";

type Turn = {
  user: CoachThreadMessage;
  assistants: CoachThreadMessage[];
  tools: CoachThreadMessage[];
  meta: CoachReplyLogMeta | null;
};

function extractText(content: unknown): string {
  if (!content || typeof content !== "object") return "";
  const maybeText = (content as { text?: unknown }).text;
  return typeof maybeText === "string" ? maybeText : "";
}

function extractStatus(content: unknown): "streaming" | "done" | "error" | null {
  if (!content || typeof content !== "object") return null;
  const value = (content as { status?: unknown }).status;
  return value === "streaming" || value === "done" || value === "error" ? value : null;
}

function normalizeForSearch(value: string) {
  return value.trim().toLowerCase();
}

function textPreview(value: string, maxChars = 120): string {
  const normalized = value.replace(/\s+/g, " ").trim();
  if (!normalized) return "";
  if (normalized.length <= maxChars) return normalized;
  return `${normalized.slice(0, maxChars - 1)}…`;
}

export default function AiLogsConversations({
  maskEnabled,
  onToggleMask,
  onOpenWorkbench,
}: {
  maskEnabled: boolean;
  onToggleMask: (next: boolean) => void;
  onOpenWorkbench: (logId: string) => void;
}) {
  const supabase = getSupabaseClient();
  const router = useRouter();
  const pathname = usePathname();
  const searchParams = useSearchParams();

  const [threads, setThreads] = useState<CoachThreadListItem[]>([]);
  const [threadsLoading, setThreadsLoading] = useState(true);
  const [threadsError, setThreadsError] = useState<string | null>(null);

  const [selectedStudentId, setSelectedStudentId] = useState<string | null>(() => searchParams.get("student"));
  const [userQuery, setUserQuery] = useState(() => searchParams.get("uq") ?? "");
  const [globalMessageQuery, setGlobalMessageQuery] = useState(() => searchParams.get("mq") ?? "");
  const [threadMessageQuery, setThreadMessageQuery] = useState(() => searchParams.get("tq") ?? "");
  const [focusMessageId, setFocusMessageId] = useState<string | null>(() => searchParams.get("mid"));

  const [searchResults, setSearchResults] = useState<CoachMessageSearchResult[]>([]);
  const [searchLoading, setSearchLoading] = useState(false);
  const [searchError, setSearchError] = useState<string | null>(null);

  const [detail, setDetail] = useState<CoachThreadDetail | null>(null);
  const [detailLoading, setDetailLoading] = useState(false);
  const [detailError, setDetailError] = useState<string | null>(null);

  const scrollContainerRef = useRef<HTMLDivElement | null>(null);

  const getAccessToken = useCallback(async () => {
    if (!supabase) {
      setThreadsError("Supabase not configured.");
      return null;
    }

    const { data: sessionData } = await supabase.auth.getSession();
    const session = sessionData.session;
    if (!session) {
      setThreadsError("You are not signed in.");
      return null;
    }

    return session.access_token;
  }, [supabase]);

  useEffect(() => {
    let active = true;

    async function loadThreads() {
      setThreadsLoading(true);
      setThreadsError(null);

      const accessToken = await getAccessToken();
      if (!accessToken) {
        if (active) setThreadsLoading(false);
        return;
      }

      try {
        const data = await listCoachThreads(accessToken, 80);
        if (!active) return;
        setThreads(data);
        setThreadsError(null);
      } catch (err) {
        if (!active) return;
        setThreadsError(err instanceof Error ? err.message : "Failed to load coach threads.");
      } finally {
        if (active) setThreadsLoading(false);
      }
    }

    void loadThreads();

    return () => {
      active = false;
    };
  }, [getAccessToken]);

  const filteredThreads = useMemo(() => {
    const q = normalizeForSearch(userQuery);
    if (!q) return threads;
    return threads.filter((thread) => {
      const haystack = `${thread.display_name ?? ""} ${thread.student_id}`.toLowerCase();
      return haystack.includes(q);
    });
  }, [threads, userQuery]);

  useEffect(() => {
    if (selectedStudentId) return;
    if (filteredThreads.length === 0) return;
    setSelectedStudentId(filteredThreads[0].student_id);
  }, [filteredThreads, selectedStudentId]);

  useEffect(() => {
    let active = true;

    async function loadDetail(studentId: string) {
      setDetailLoading(true);
      setDetailError(null);

      const accessToken = await getAccessToken();
      if (!accessToken) {
        if (active) setDetailLoading(false);
        return;
      }

      try {
        const data = await getCoachThreadDetail(accessToken, studentId, 240);
        if (!active) return;
        setDetail(data);
      } catch (err) {
        if (!active) return;
        setDetail(null);
        setDetailError(err instanceof Error ? err.message : "Failed to load messages.");
      } finally {
        if (active) setDetailLoading(false);
      }
    }

    if (selectedStudentId) {
      void loadDetail(selectedStudentId);
    } else {
      setDetail(null);
    }

    return () => {
      active = false;
    };
  }, [getAccessToken, selectedStudentId]);

  useEffect(() => {
    if (!globalMessageQuery.trim()) {
      setSearchResults([]);
      setSearchError(null);
      setSearchLoading(false);
      return;
    }

    let active = true;
    setSearchLoading(true);
    setSearchError(null);

    const timer = window.setTimeout(() => {
      void (async () => {
        const accessToken = await getAccessToken();
        if (!accessToken) {
          if (active) setSearchLoading(false);
          return;
        }

        try {
          const results = await searchCoachMessages(accessToken, globalMessageQuery, 60);
          if (!active) return;
          setSearchResults(results);
        } catch (err) {
          if (!active) return;
          setSearchResults([]);
          setSearchError(err instanceof Error ? err.message : "Search failed.");
        } finally {
          if (active) setSearchLoading(false);
        }
      })();
    }, 350);

    return () => {
      active = false;
      window.clearTimeout(timer);
    };
  }, [getAccessToken, globalMessageQuery]);

  useEffect(() => {
    const nextParams = new URLSearchParams(searchParams);
    if (selectedStudentId) {
      nextParams.set("student", selectedStudentId);
    } else {
      nextParams.delete("student");
    }

    if (userQuery) {
      nextParams.set("uq", userQuery);
    } else {
      nextParams.delete("uq");
    }

    if (globalMessageQuery) {
      nextParams.set("mq", globalMessageQuery);
    } else {
      nextParams.delete("mq");
    }

    if (threadMessageQuery) {
      nextParams.set("tq", threadMessageQuery);
    } else {
      nextParams.delete("tq");
    }

    if (focusMessageId) {
      nextParams.set("mid", focusMessageId);
    } else {
      nextParams.delete("mid");
    }

    const nextQuery = nextParams.toString();
    const currentQuery = searchParams.toString();
    if (nextQuery !== currentQuery) {
      router.replace(nextQuery ? `${pathname}?${nextQuery}` : pathname, { scroll: false });
    }
  }, [selectedStudentId, userQuery, globalMessageQuery, threadMessageQuery, focusMessageId, pathname, router, searchParams]);

  useEffect(() => {
    setSelectedStudentId(searchParams.get("student"));
    setUserQuery(searchParams.get("uq") ?? "");
    setGlobalMessageQuery(searchParams.get("mq") ?? "");
    setThreadMessageQuery(searchParams.get("tq") ?? "");
    setFocusMessageId(searchParams.get("mid"));
  }, [searchParams]);

  const turns = useMemo(() => {
    const messages = detail?.messages ?? [];
    const metaByUser = detail?.coachReplyLogsByUserMessageId ?? {};

    const prelude: CoachThreadMessage[] = [];
    const output: Turn[] = [];
    let current: Turn | null = null;

    for (const msg of messages) {
      if (msg.role === "user") {
        current = {
          user: msg,
          assistants: [],
          tools: [],
          meta: metaByUser[msg.id] ?? null,
        };
        output.push(current);
        continue;
      }

      if (!current) {
        prelude.push(msg);
        continue;
      }

      if (msg.role === "assistant") {
        current.assistants.push(msg);
      } else {
        current.tools.push(msg);
      }
    }

    return {
      prelude,
      turns: output,
    };
  }, [detail]);

  const filteredTurns = useMemo(() => {
    const q = normalizeForSearch(threadMessageQuery);
    if (!q) return turns.turns;

    return turns.turns.filter((turn) => {
      const texts = [extractText(turn.user.content), ...turn.assistants.map((a) => extractText(a.content))].join("\n");
      return normalizeForSearch(texts).includes(q);
    });
  }, [turns.turns, threadMessageQuery]);

  useEffect(() => {
    if (!focusMessageId) return;
    if (!scrollContainerRef.current) return;

    const target = scrollContainerRef.current.querySelector<HTMLElement>(`#msg-${focusMessageId}`);
    if (!target) return;

    target.scrollIntoView({ block: "center" });
  }, [focusMessageId, detail]);

  const threadHeader = useMemo(() => {
    if (!detail) return null;
    const name = detail.student.display_name?.trim();
    return {
      title: name ? name : `Student ${detail.student.id.slice(0, 8)}…`,
      subtitle: detail.student.id,
    };
  }, [detail]);

  function renderMessageText(msg: CoachThreadMessage): string {
    const raw = msg.role === "tool" ? serializeJson(msg.content, 2) : extractText(msg.content);
    return maskEnabled ? maskPII(raw) : raw;
  }

  function handleSelectStudent(studentId: string) {
    setSelectedStudentId(studentId);
    setThreadMessageQuery("");
    setFocusMessageId(null);
  }

  function handlePickSearchResult(result: CoachMessageSearchResult) {
    setSelectedStudentId(result.student_id);
    setThreadMessageQuery(globalMessageQuery.trim());
    setFocusMessageId(result.id);
  }

  return (
    <section className="grid gap-4 lg:grid-cols-[360px_minmax(0,1fr)]">
      <aside className="flex min-w-0 flex-col gap-3 rounded-2xl border border-[color:var(--border)] bg-[color:var(--surface)] p-3">
        <div className="flex flex-wrap items-center justify-between gap-2">
          <div className="text-[11px] uppercase tracking-[0.2em] text-[color:var(--ink-muted)]">Conversations</div>
          <span className="rounded-full border border-[color:var(--border)] bg-[color:var(--surface-soft)] px-3 py-1 text-[11px] text-[color:var(--ink-muted)] tabular-nums">
            {filteredThreads.length} threads
          </span>
        </div>

        <div className="grid gap-2">
          <label className="sr-only" htmlFor="ai-log-user-search">
            Search users
          </label>
          <input
            id="ai-log-user-search"
            name="ai-log-user-search"
            type="search"
            inputMode="search"
            autoComplete="off"
            className="w-full rounded-full border border-[color:var(--border)] bg-[color:var(--surface)] px-4 py-2 text-xs text-[color:var(--ink)]"
            placeholder="Search users (name / id)…"
            value={userQuery}
            onChange={(e) => setUserQuery(e.target.value)}
          />

          <label className="sr-only" htmlFor="ai-log-message-search">
            Search messages
          </label>
          <input
            id="ai-log-message-search"
            name="ai-log-message-search"
            type="search"
            inputMode="search"
            autoComplete="off"
            className="w-full rounded-full border border-[color:var(--border)] bg-[color:var(--surface)] px-4 py-2 text-xs text-[color:var(--ink)]"
            placeholder="Search messages (all threads)…"
            value={globalMessageQuery}
            onChange={(e) => setGlobalMessageQuery(e.target.value)}
          />
        </div>

        {threadsError ? (
          <div className="rounded-xl border border-[color:var(--danger)] bg-[color:var(--surface)] px-3 py-2 text-xs text-[color:var(--danger-strong)]" role="alert">
            {threadsError}
          </div>
        ) : null}

        {threadsLoading ? (
          <div className="rounded-xl border border-dashed border-[color:var(--border)] bg-[color:var(--surface-soft)] px-3 py-6 text-xs text-[color:var(--ink-muted)]" role="status" aria-live="polite">
            Loading conversations…
          </div>
        ) : (
          <div
            className="flex-1 space-y-2 overflow-auto pr-1"
            style={{ contentVisibility: "auto", containIntrinsicSize: "800px 600px" }}
          >
            {filteredThreads.length === 0 ? (
              <div className="rounded-xl border border-dashed border-[color:var(--border)] bg-[color:var(--surface-soft)] px-3 py-6 text-xs text-[color:var(--ink-muted)]">
                No conversations found.
              </div>
            ) : (
              filteredThreads.map((thread) => {
                const isActive = thread.student_id === selectedStudentId;
                return (
                  <button
                    key={thread.student_id}
                    type="button"
                    onClick={() => handleSelectStudent(thread.student_id)}
                    className={`flex w-full min-w-0 flex-col gap-2 rounded-xl border px-3 py-3 text-left text-xs transition ${
                      isActive
                        ? "border-[color:var(--accent)] bg-[color:var(--surface)]"
                        : "border-[color:var(--border)] bg-[color:var(--surface-soft)] hover:bg-[color:var(--surface)]"
                    }`}
                  >
                    <div className="flex min-w-0 items-center justify-between gap-2 text-[color:var(--ink-muted)] tabular-nums">
                      <span className="truncate">{formatDateTime(thread.last_message_at)}</span>
                      <span className="rounded-full border border-[color:var(--border)] bg-[color:var(--surface)] px-2 py-0.5 text-[10px] uppercase tracking-[0.18em]">
                        {thread.last_message_role}
                      </span>
                    </div>
                    <div className="truncate font-medium text-[color:var(--ink)]">
                      {thread.display_name?.trim() ? thread.display_name : thread.student_id}
                    </div>
                    <div className="flex items-center justify-between gap-2 text-[11px] text-[color:var(--ink-muted)]">
                      <span className="min-w-0 flex-1 truncate">{maskEnabled ? maskPII(thread.last_message_preview) : thread.last_message_preview}</span>
                      {thread.last_message_status ? (
                        <span
                          className={`shrink-0 rounded-full px-2 py-0.5 text-[10px] font-semibold uppercase tracking-[0.18em] text-white ${
                            thread.last_message_status === "done"
                              ? "bg-[color:var(--accent-strong)]"
                              : thread.last_message_status === "streaming"
                                ? "bg-[color:var(--highlight)] text-[color:var(--ink)]"
                                : "bg-[color:var(--danger-strong)]"
                          }`}
                        >
                          {thread.last_message_status}
                        </span>
                      ) : null}
                    </div>
                  </button>
                );
              })
            )}
          </div>
        )}

        {globalMessageQuery.trim().length > 0 ? (
          <div className="mt-1 rounded-2xl border border-[color:var(--border)] bg-[color:var(--surface-soft)] p-3">
            <div className="flex items-center justify-between gap-2">
              <div className="text-[11px] uppercase tracking-[0.2em] text-[color:var(--ink-muted)]">Search Results</div>
              <span className="text-xs text-[color:var(--ink-muted)] tabular-nums">
                {searchLoading ? "…" : searchResults.length}
              </span>
            </div>

            {searchError ? (
              <div className="mt-2 text-xs text-[color:var(--danger-strong)]" role="alert">
                {searchError}
              </div>
            ) : null}

            <div className="mt-2 space-y-2">
              {searchLoading ? (
                <div className="text-xs text-[color:var(--ink-muted)]" role="status" aria-live="polite">
                  Searching…
                </div>
              ) : searchResults.length === 0 ? (
                <div className="text-xs text-[color:var(--ink-muted)]">No matches.</div>
              ) : (
                searchResults.map((result) => (
                  <button
                    key={result.id}
                    type="button"
                    onClick={() => handlePickSearchResult(result)}
                    className="flex w-full flex-col gap-1 rounded-xl border border-[color:var(--border)] bg-[color:var(--surface)] px-3 py-2 text-left text-xs transition hover:bg-[color:var(--surface-strong)]"
                  >
                    <div className="flex items-center justify-between gap-2 text-[11px] text-[color:var(--ink-muted)] tabular-nums">
                      <span className="truncate">{result.display_name?.trim() ? result.display_name : result.student_id}</span>
                      <span>{formatDateTime(result.created_at)}</span>
                    </div>
                    <div className="truncate text-[color:var(--ink)]">
                      {maskEnabled ? maskPII(result.text_preview) : result.text_preview}
                    </div>
                  </button>
                ))
              )}
            </div>
          </div>
        ) : null}
      </aside>

      <section className="flex min-w-0 flex-col gap-3 rounded-2xl border border-[color:var(--border)] bg-[color:var(--surface)] p-4">
        <div className="flex flex-wrap items-start justify-between gap-3">
          <div className="min-w-0">
            <div className="text-xs uppercase tracking-[0.2em] text-[color:var(--ink-muted)]">Thread</div>
            <div className="text-xl font-semibold text-[color:var(--ink)]">
              {threadHeader ? threadHeader.title : "Select a conversation"}
            </div>
            <div className="truncate text-xs text-[color:var(--ink-muted)]">
              {threadHeader ? threadHeader.subtitle : "—"}
            </div>
          </div>

          <div className="flex items-center gap-2">
            <button
              type="button"
              onClick={() => onToggleMask(!maskEnabled)}
              className={`rounded-full border px-3 py-1 text-[10px] uppercase tracking-[0.2em] transition ${
                maskEnabled
                  ? "border-[color:var(--accent)] text-[color:var(--accent-strong)]"
                  : "border-[color:var(--border)] text-[color:var(--ink-muted)]"
              }`}
            >
              {maskEnabled ? "Masked" : "Raw"}
            </button>
          </div>
        </div>

        <div className="flex flex-wrap items-center justify-between gap-3 rounded-2xl border border-[color:var(--border)] bg-[color:var(--surface-soft)] px-3 py-2">
          <label className="flex min-w-[220px] flex-1 items-center gap-2 text-xs text-[color:var(--ink-muted)]">
            <span className="shrink-0 text-[11px] uppercase tracking-[0.2em]">Search</span>
            <input
              type="search"
              inputMode="search"
              autoComplete="off"
              className="w-full rounded-full border border-[color:var(--border)] bg-[color:var(--surface)] px-4 py-2 text-xs text-[color:var(--ink)]"
              placeholder="Search in this conversation…"
              value={threadMessageQuery}
              onChange={(e) => setThreadMessageQuery(e.target.value)}
            />
          </label>
          <div className="text-xs text-[color:var(--ink-muted)] tabular-nums">
            {threadMessageQuery.trim() ? `${filteredTurns.length} matches` : `${turns.turns.length} turns`}
          </div>
        </div>

        {detailError ? (
          <div className="rounded-xl border border-[color:var(--danger)] bg-[color:var(--surface)] px-3 py-2 text-xs text-[color:var(--danger-strong)]" role="alert">
            {detailError}
          </div>
        ) : null}

        {detailLoading ? (
          <div className="rounded-xl border border-dashed border-[color:var(--border)] bg-[color:var(--surface-soft)] px-4 py-8 text-sm text-[color:var(--ink-muted)]" role="status" aria-live="polite">
            Loading messages…
          </div>
        ) : !detail ? (
          <div className="rounded-xl border border-dashed border-[color:var(--border)] bg-[color:var(--surface-soft)] px-4 py-8 text-sm text-[color:var(--ink-muted)]">
            Select a user to inspect their conversation.
          </div>
        ) : (
          <div
            ref={scrollContainerRef}
            className="flex-1 space-y-3 overflow-auto pr-1"
            style={{ contentVisibility: "auto", containIntrinsicSize: "800px 600px" }}
          >
            {turns.prelude.length > 0 ? (
              <details className="rounded-2xl border border-[color:var(--border)] bg-[color:var(--surface-soft)] p-3" open={false}>
                <summary className="cursor-pointer list-none text-xs font-semibold uppercase tracking-[0.2em] text-[color:var(--ink-muted)]">
                  Prelude ({turns.prelude.length})
                </summary>
                <div className="mt-3 space-y-2">
                  {turns.prelude.map((msg) => (
                    <div key={msg.id} id={`msg-${msg.id}`} className="rounded-xl border border-[color:var(--border)] bg-[color:var(--surface)] p-3">
                      <div className="flex items-center justify-between gap-2 text-[11px] uppercase tracking-[0.2em] text-[color:var(--ink-muted)]">
                        <span>{msg.role}</span>
                        <span className="tabular-nums">{formatDateTime(msg.created_at)}</span>
                      </div>
                      <pre className="mt-2 whitespace-pre-wrap break-words font-mono text-[11px] text-[color:var(--ink)]">
                        {renderMessageText(msg)}
                      </pre>
                    </div>
                  ))}
                </div>
              </details>
            ) : null}

            {filteredTurns.length === 0 ? (
              <div className="rounded-xl border border-dashed border-[color:var(--border)] bg-[color:var(--surface-soft)] px-4 py-8 text-sm text-[color:var(--ink-muted)]">
                No turns match.
              </div>
            ) : (
              filteredTurns.map((turn) => {
                const userText = extractText(turn.user.content);
                const assistantCombined = turn.assistants
                  .map((msg) => extractText(msg.content))
                  .filter((text) => text.trim().length > 0)
                  .join("\n\n");

                const promptTokens = turn.meta?.estimated_prompt_tokens ?? null;
                const outputTokens = assistantCombined ? estimateTokens(assistantCombined) : 0;
                const totalTokens = promptTokens !== null ? promptTokens + outputTokens : null;

                const status =
                  turn.meta?.status ??
                  turn.assistants.map((a) => extractStatus(a.content)).find(Boolean) ??
                  null;

                const openByDefault =
                  !!focusMessageId &&
                  (turn.user.id === focusMessageId ||
                    turn.assistants.some((msg) => msg.id === focusMessageId) ||
                    turn.tools.some((msg) => msg.id === focusMessageId));

                const showOpen = threadMessageQuery.trim().length > 0;

                return (
                  <details
                    key={turn.user.id}
                    open={openByDefault || showOpen}
                    className="rounded-2xl border border-[color:var(--border)] bg-[color:var(--surface-soft)] p-3"
                  >
                    <summary className="cursor-pointer list-none focus-visible:outline focus-visible:outline-2 focus-visible:outline-[color:var(--accent)] focus-visible:outline-offset-2">
                      <div className="flex flex-col gap-2 sm:flex-row sm:items-start sm:justify-between">
                        <div className="min-w-0">
                          <div className="flex flex-wrap items-center gap-2 text-[11px] uppercase tracking-[0.2em] text-[color:var(--ink-muted)] tabular-nums">
                            <span>{formatDateTime(turn.user.created_at)}</span>
                            {turn.user.linked_attempt_id ? (
                              <span className="rounded-full border border-[color:var(--border)] bg-[color:var(--surface)] px-2 py-0.5">
                                attempt
                              </span>
                            ) : null}
                            {status ? (
                              <span
                                className={`rounded-full px-2 py-0.5 text-white ${
                                  status === "done"
                                    ? "bg-[color:var(--accent-strong)]"
                                    : "bg-[color:var(--danger-strong)]"
                                }`}
                              >
                                {status}
                              </span>
                            ) : null}
                          </div>
                          <div className="mt-1 truncate text-sm font-medium text-[color:var(--ink)]">
                            {maskEnabled ? maskPII(textPreview(userText)) : textPreview(userText)}
                          </div>
                        </div>
                        <div className="flex flex-wrap items-center gap-2 text-[10px] uppercase tracking-[0.2em] text-[color:var(--ink-muted)]">
                          {turn.meta ? (
                            <span className="rounded-full border border-[color:var(--border)] bg-[color:var(--surface)] px-2 py-0.5">
                              {turn.meta.model_provider}/{turn.meta.model_id}
                            </span>
                          ) : (
                            <span className="rounded-full border border-dashed border-[color:var(--border)] bg-[color:var(--surface)] px-2 py-0.5">
                              no log
                            </span>
                          )}
                          {totalTokens !== null ? (
                            <span className="rounded-full border border-[color:var(--border)] bg-[color:var(--surface)] px-2 py-0.5 tabular-nums">
                              ~{totalTokens} tokens
                            </span>
                          ) : null}
                        </div>
                      </div>
                    </summary>

                    <div className="mt-3 space-y-3">
                      <div
                        id={`msg-${turn.user.id}`}
                        className={`rounded-xl border bg-[color:var(--surface)] p-3 ${
                          turn.user.id === focusMessageId ? "border-[color:var(--accent)]" : "border-[color:var(--border)]"
                        }`}
                      >
                        <div className="flex flex-wrap items-center justify-between gap-2">
                          <div className="text-[11px] font-semibold uppercase tracking-[0.2em] text-[color:var(--ink-muted)]">
                            User
                          </div>
                          <div className="text-[11px] text-[color:var(--ink-muted)] tabular-nums">
                            {formatDateTime(turn.user.created_at)}
                          </div>
                        </div>
                        {turn.user.linked_attempt_id ? (
                          <div className="mt-2 text-[11px] text-[color:var(--ink-muted)] tabular-nums">
                            linked_attempt_id: {turn.user.linked_attempt_id}
                          </div>
                        ) : null}
                        <pre className="mt-2 whitespace-pre-wrap break-words font-mono text-[11px] text-[color:var(--ink)]">
                          {renderMessageText(turn.user)}
                        </pre>
                      </div>

                      {turn.assistants.length > 0 ? (
                        <div className="space-y-2">
                          {turn.assistants.map((msg) => {
                            const assistantStatus = extractStatus(msg.content);
                            return (
                              <div
                                key={msg.id}
                                id={`msg-${msg.id}`}
                                className={`rounded-xl border bg-[color:var(--surface)] p-3 ${
                                  msg.id === focusMessageId ? "border-[color:var(--accent)]" : "border-[color:var(--border)]"
                                }`}
                              >
                                <div className="flex flex-wrap items-center justify-between gap-2">
                                  <div className="text-[11px] font-semibold uppercase tracking-[0.2em] text-[color:var(--ink-muted)]">
                                    Assistant
                                  </div>
                                  <div className="flex items-center gap-2 text-[11px] uppercase tracking-[0.2em] text-[color:var(--ink-muted)] tabular-nums">
                                    {assistantStatus ? (
                                      <span
                                        className={`rounded-full px-2 py-0.5 text-white ${
                                          assistantStatus === "done"
                                            ? "bg-[color:var(--accent-strong)]"
                                            : assistantStatus === "streaming"
                                              ? "bg-[color:var(--highlight)] text-[color:var(--ink)]"
                                              : "bg-[color:var(--danger-strong)]"
                                        }`}
                                      >
                                        {assistantStatus}
                                      </span>
                                    ) : null}
                                    <span>{formatDateTime(msg.created_at)}</span>
                                  </div>
                                </div>
                                <pre className="mt-2 whitespace-pre-wrap break-words font-mono text-[11px] text-[color:var(--ink)]">
                                  {renderMessageText(msg)}
                                </pre>
                              </div>
                            );
                          })}
                        </div>
                      ) : (
                        <div className="rounded-xl border border-dashed border-[color:var(--border)] bg-[color:var(--surface)] px-3 py-4 text-xs text-[color:var(--ink-muted)]">
                          No assistant reply captured.
                        </div>
                      )}

                      {turn.tools.length > 0 ? (
                        <details className="rounded-xl border border-[color:var(--border)] bg-[color:var(--surface)] p-3" open={false}>
                          <summary className="cursor-pointer text-[11px] font-semibold uppercase tracking-[0.2em] text-[color:var(--ink-muted)]">
                            Tool Messages ({turn.tools.length})
                          </summary>
                          <div className="mt-2 space-y-2">
                            {turn.tools.map((msg) => (
                              <div key={msg.id} id={`msg-${msg.id}`} className="rounded-xl border border-[color:var(--border)] bg-[color:var(--surface-soft)] p-3">
                                <div className="flex items-center justify-between gap-2 text-[10px] uppercase tracking-[0.2em] text-[color:var(--ink-muted)] tabular-nums">
                                  <span>tool</span>
                                  <span>{formatDateTime(msg.created_at)}</span>
                                </div>
                                <pre className="mt-2 max-h-64 overflow-auto whitespace-pre-wrap break-words font-mono text-[11px] text-[color:var(--ink)]">
                                  {renderMessageText(msg)}
                                </pre>
                              </div>
                            ))}
                          </div>
                        </details>
                      ) : null}

                      <div className="flex flex-wrap items-center justify-between gap-2 rounded-xl border border-[color:var(--border)] bg-[color:var(--surface)] px-3 py-2 text-[11px] text-[color:var(--ink-muted)]">
                        <div className="flex flex-wrap items-center gap-2">
                          {turn.meta ? (
                            <span className="tabular-nums">
                              prompt ~{turn.meta.estimated_prompt_tokens} + output ~{outputTokens} = total ~{totalTokens}
                            </span>
                          ) : (
                            <span>No ai_agent_log found for this user message.</span>
                          )}
                          {turn.meta?.prompt_version ? <span>· {turn.meta.prompt_version}</span> : null}
                        </div>
                        {turn.meta?.log_id ? (
                          <button
                            type="button"
                            onClick={() => onOpenWorkbench(turn.meta!.log_id)}
                            className="rounded-full border border-[color:var(--border)] bg-[color:var(--surface)] px-3 py-1 text-[10px] font-semibold uppercase tracking-[0.2em] text-[color:var(--ink)] transition hover:bg-[color:var(--surface-strong)]"
                          >
                            Open Workbench
                          </button>
                        ) : null}
                      </div>
                    </div>
                  </details>
                );
              })
            )}
          </div>
        )}
      </section>
    </section>
  );
}
