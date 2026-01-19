"use client";

import { useEffect, useMemo, useState } from "react";
import { usePathname, useRouter, useSearchParams } from "next/navigation";
import { getSupabaseClient } from "@/lib/supabaseClient";
import { createTag, deleteTag, listTags, updateTag, type Tag, type TagInput } from "./actions";

const TAG_CATEGORIES = ["topic", "skill", "difficulty", "source", "general"];

const EMPTY_FORM: TagInput = {
  name: "",
  category: "general",
};

export default function TagsPage() {
  const supabase = getSupabaseClient();
  const router = useRouter();
  const pathname = usePathname();
  const searchParams = useSearchParams();
  const [tags, setTags] = useState<Tag[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [form, setForm] = useState<TagInput>({ ...EMPTY_FORM });
  const [editingId, setEditingId] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);
  const [filterCategory, setFilterCategory] = useState<string>(() => searchParams.get("category") ?? "");
  const [drawerOpen, setDrawerOpen] = useState(false);
  const [drawerMode, setDrawerMode] = useState<"create" | "edit">("create");
  const [selectedTag, setSelectedTag] = useState<Tag | null>(null);

  useEffect(() => {
    let active = true;

    async function loadTags() {
      if (!supabase) {
        if (active) {
          setError("Supabase not configured.");
          setLoading(false);
        }
        return;
      }

      const { data: sessionData } = await supabase.auth.getSession();
      const session = sessionData.session;
      if (!session) {
        if (active) {
          setError("You are not signed in.");
          setLoading(false);
        }
        return;
      }

      try {
        const data = await listTags(session.access_token);
        if (active) {
          setTags(data);
          setError(null);
        }
      } catch (loadError) {
        if (active) {
          setError(loadError instanceof Error ? loadError.message : "Failed to load tags.");
        }
      } finally {
        if (active) {
          setLoading(false);
        }
      }
    }

    loadTags();

    return () => {
      active = false;
    };
  }, [supabase]);

  useEffect(() => {
    setFilterCategory(searchParams.get("category") ?? "");
  }, [searchParams]);

  useEffect(() => {
    const nextParams = new URLSearchParams(searchParams);
    if (filterCategory) {
      nextParams.set("category", filterCategory);
    } else {
      nextParams.delete("category");
    }

    const nextQuery = nextParams.toString();
    const currentQuery = searchParams.toString();
    if (nextQuery !== currentQuery) {
      router.replace(nextQuery ? `${pathname}?${nextQuery}` : pathname, { scroll: false });
    }
  }, [filterCategory, pathname, router, searchParams]);

  const filteredTags = useMemo(() => {
    if (!filterCategory) return tags;
    return tags.filter((tag) => tag.category === filterCategory);
  }, [tags, filterCategory]);

  const groupedTags = useMemo(() => {
    const groups: Record<string, Tag[]> = {};
    for (const tag of filteredTags) {
      if (!groups[tag.category]) {
        groups[tag.category] = [];
      }
      groups[tag.category].push(tag);
    }
    return groups;
  }, [filteredTags]);

  function resetForm() {
    setForm({ ...EMPTY_FORM });
    setEditingId(null);
  }

  function openCreateDrawer() {
    resetForm();
    setDrawerMode("create");
    setSelectedTag(null);
    setDrawerOpen(true);
  }

  function openEditDrawer(tag: Tag) {
    setEditingId(tag.id);
    setForm({
      name: tag.name,
      category: tag.category,
    });
    setDrawerMode("edit");
    setSelectedTag(tag);
    setDrawerOpen(true);
  }

  function closeDrawer() {
    setDrawerOpen(false);
  }

  async function handleSave() {
    if (!supabase) return;
    setSaving(true);
    setError(null);

    const { data: sessionData } = await supabase.auth.getSession();
    const session = sessionData.session;
    if (!session) {
      setError("You are not signed in.");
      setSaving(false);
      return;
    }

    try {
      if (editingId) {
        const updated = await updateTag(session.access_token, editingId, form);
        setTags((prev) => prev.map((tag) => (tag.id === updated.id ? updated : tag)));
        setSelectedTag(updated);
      } else {
        const created = await createTag(session.access_token, form);
        setTags((prev) => [...prev, created]);
      }
      resetForm();
      setDrawerOpen(false);
    } catch (saveError) {
      setError(saveError instanceof Error ? saveError.message : "Failed to save tag.");
    } finally {
      setSaving(false);
    }
  }

  async function handleDelete(tag: Tag) {
    if (!supabase) return;
    const confirmed = window.confirm(`Delete tag "${tag.name}"? Questions using this tag will be untagged.`);
    if (!confirmed) return;

    setSaving(true);
    setError(null);

    const { data: sessionData } = await supabase.auth.getSession();
    const session = sessionData.session;
    if (!session) {
      setError("You are not signed in.");
      setSaving(false);
      return;
    }

    try {
      await deleteTag(session.access_token, tag.id);
      setTags((prev) => prev.filter((item) => item.id !== tag.id));
      if (editingId === tag.id) {
        resetForm();
        setSelectedTag(null);
        setDrawerOpen(false);
      }
    } catch (deleteError) {
      setError(deleteError instanceof Error ? deleteError.message : "Failed to delete tag.");
    } finally {
      setSaving(false);
    }
  }

  if (loading) {
    return (
      <main className="mx-auto max-w-[1280px] px-6 py-12">
        <p className="text-sm text-[color:var(--ink-muted)]" role="status" aria-live="polite">
          Loading tags…
        </p>
      </main>
    );
  }

  if (error && tags.length === 0) {
    return (
      <main className="mx-auto max-w-[1280px] px-6 py-12">
        <p className="text-sm text-[color:var(--danger-strong)]" role="alert">
          {error} Try refreshing or checking Supabase config.
        </p>
      </main>
    );
  }

  return (
    <main className="mx-auto flex max-w-[1280px] flex-col gap-6 px-6 pb-10 pt-8">
      <header className="flex flex-wrap items-center justify-between gap-4">
        <div>
          <p className="text-[11px] uppercase tracking-[0.2em] text-[color:var(--ink-muted)]">Admin Console</p>
          <h1 className="text-2xl font-semibold text-[color:var(--ink)]">Tags</h1>
          <p className="text-sm text-[color:var(--ink-muted)]">Manage tags for categorizing questions.</p>
        </div>
        <div className="flex items-center gap-3">
          <select
            className="rounded-full border border-[color:var(--border)] bg-[color:var(--surface)] px-3 py-2 text-[11px]"
            value={filterCategory}
            onChange={(e) => setFilterCategory(e.target.value)}
            aria-label="Filter category"
          >
            <option value="">All categories</option>
            {TAG_CATEGORIES.map((cat) => (
              <option key={cat} value={cat}>
                {cat}
              </option>
            ))}
          </select>
          <button
            className="rounded-full bg-[color:var(--accent)] px-4 py-2 text-[11px] font-semibold uppercase tracking-[0.2em] text-white transition hover:bg-[color:var(--accent-strong)]"
            onClick={openCreateDrawer}
            type="button"
          >
            Create Tag
          </button>
        </div>
      </header>

      {error ? (
        <div
          className="rounded-2xl border border-[color:var(--danger)] bg-[color:var(--surface)] px-4 py-3 text-sm text-[color:var(--danger-strong)]"
          role="alert"
        >
          {error} Try refreshing or checking Supabase config.
        </div>
      ) : null}

      <section className="flex flex-col gap-6">
        {Object.keys(groupedTags).length === 0 ? (
          <div
            className="rounded-2xl border border-[color:var(--border)] bg-[color:var(--surface)] p-6 text-center text-sm text-[color:var(--ink-muted)]"
            role="status"
            aria-live="polite"
          >
            No tags yet. Create one using the button above.
          </div>
        ) : (
          Object.entries(groupedTags).map(([category, categoryTags]) => (
            <div key={category} className="rounded-2xl border border-[color:var(--border)] bg-[color:var(--surface)]">
              <div className="border-b border-[color:var(--border)] bg-[color:var(--surface-soft)] px-4 py-3">
                <h3 className="text-sm font-medium text-[color:var(--ink)] capitalize">{category}</h3>
              </div>
              <div className="flex flex-wrap gap-2 p-4">
                {categoryTags.map((tag) => (
                  <div
                    key={tag.id}
                    className={`group flex items-center gap-2 rounded-full border px-3 py-1.5 text-xs transition ${
                      editingId === tag.id
                        ? "border-[color:var(--accent-strong)] bg-[color:var(--accent)] text-white"
                        : "border-[color:var(--border)] bg-[color:var(--surface)] text-[color:var(--ink)] hover:border-[color:var(--accent-strong)]"
                    }`}
                  >
                    <button
                      type="button"
                      onClick={() => openEditDrawer(tag)}
                      className="text-left"
                      aria-label={`Edit tag ${tag.name}`}
                    >
                      {tag.name}
                    </button>
                    <div className="flex items-center gap-1 opacity-0 transition-opacity group-hover:opacity-100">
                      <button
                        className="text-[10px] uppercase tracking-[0.2em] hover:text-[color:var(--ink)]"
                        onClick={(event) => {
                          event.stopPropagation();
                          openEditDrawer(tag);
                        }}
                        type="button"
                        title="Edit"
                        aria-label={`Edit tag ${tag.name}`}
                      >
                        Edit
                      </button>
                      <button
                        className="text-[10px] uppercase tracking-[0.2em] text-[color:var(--danger-strong)]"
                        onClick={(event) => {
                          event.stopPropagation();
                          void handleDelete(tag);
                        }}
                        type="button"
                        title="Delete"
                        aria-label={`Delete tag ${tag.name}`}
                      >
                        Delete
                      </button>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          ))
        )}
      </section>

      <div className="text-xs text-[color:var(--ink-muted)]">
        Total: {tags.length} tags across {Object.keys(groupedTags).length} categories
      </div>

      {drawerOpen ? (
        <div className="fixed inset-0 z-40 flex justify-end">
          <button className="absolute inset-0 bg-black/30" onClick={closeDrawer} aria-label="Close drawer" />
          <aside className="relative z-10 flex h-full w-full max-w-md flex-col gap-4 overflow-auto overscroll-contain bg-[color:var(--surface)] p-6 shadow-2xl">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-[11px] uppercase tracking-[0.2em] text-[color:var(--ink-muted)]">
                  {drawerMode === "edit" ? "Edit Tag" : "Create Tag"}
                </p>
                <p className="text-sm font-semibold text-[color:var(--ink)]">
                  {drawerMode === "edit" ? "Update Tag" : "New Tag"}
                </p>
              </div>
              <button
                className="text-[10px] uppercase tracking-[0.2em] text-[color:var(--ink-muted)] transition hover:text-[color:var(--ink)]"
                onClick={closeDrawer}
              >
                Close
              </button>
            </div>

            {drawerMode === "edit" && selectedTag ? (
              <div className="rounded-2xl border border-[color:var(--border)] bg-[color:var(--surface-soft)] p-4">
                <p className="text-[11px] uppercase tracking-[0.2em] text-[color:var(--ink-muted)]">Tag details</p>
                <dl className="mt-3 space-y-2 text-sm">
                  <div className="flex items-start justify-between gap-3">
                    <dt className="text-xs text-[color:var(--ink-muted)]">ID</dt>
                    <dd className="text-xs text-[color:var(--ink)]">
                      <span className="font-mono break-all">{selectedTag.id}</span>
                    </dd>
                  </div>
                </dl>
              </div>
            ) : null}

            <div className="grid gap-4 text-sm text-[color:var(--ink)]">
              <label className="grid gap-1 text-[10px] uppercase tracking-[0.2em] text-[color:var(--ink-muted)]">
                Name
                <input
                  name="tagName"
                  className="rounded-xl border border-[color:var(--border)] bg-[color:var(--surface)] px-3 py-2 text-sm"
                  value={form.name}
                  onChange={(e) => setForm({ ...form, name: e.target.value })}
                  placeholder="e.g., algebra, geometry…"
                  autoComplete="off"
                />
              </label>
              <label className="grid gap-1 text-[10px] uppercase tracking-[0.2em] text-[color:var(--ink-muted)]">
                Category
                <select
                  name="tagCategory"
                  className="rounded-xl border border-[color:var(--border)] bg-[color:var(--surface)] px-3 py-2 text-sm"
                  value={form.category}
                  onChange={(e) => setForm({ ...form, category: e.target.value })}
                >
                  {TAG_CATEGORIES.map((cat) => (
                    <option key={cat} value={cat}>
                      {cat}
                    </option>
                  ))}
                </select>
              </label>
              <div className="flex flex-wrap gap-2 pt-2">
                <button
                  className="rounded-full bg-[color:var(--accent)] px-4 py-2 text-[11px] font-semibold uppercase tracking-[0.2em] text-white transition hover:bg-[color:var(--accent-strong)] disabled:opacity-60"
                  disabled={saving || !form.name.trim()}
                  onClick={handleSave}
                  type="button"
                >
                  {drawerMode === "edit" ? "Save Changes" : "Create Tag"}
                </button>
                <button
                  className="rounded-full border border-[color:var(--border)] px-4 py-2 text-[10px] uppercase tracking-[0.2em] text-[color:var(--ink-muted)]"
                  onClick={closeDrawer}
                  type="button"
                  disabled={saving}
                >
                  Cancel
                </button>
              </div>
            </div>
          </aside>
        </div>
      ) : null}
    </main>
  );
}
