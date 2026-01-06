"use client";

import { useEffect, useMemo, useState } from "react";
import { getSupabaseClient } from "@/lib/supabaseClient";
import {
  createTag,
  deleteTag,
  listTags,
  updateTag,
  type Tag,
  type TagInput,
} from "./actions";

const TAG_CATEGORIES = ["topic", "skill", "difficulty", "source", "general"];

const EMPTY_FORM: TagInput = {
  name: "",
  category: "general",
};

export default function TagsPage() {
  const supabase = getSupabaseClient();
  const [tags, setTags] = useState<Tag[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [form, setForm] = useState<TagInput>({ ...EMPTY_FORM });
  const [editingId, setEditingId] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);
  const [filterCategory, setFilterCategory] = useState<string>("");

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
          setError(
            loadError instanceof Error
              ? loadError.message
              : "Failed to load tags.",
          );
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
        setTags((prev) =>
          prev.map((tag) => (tag.id === updated.id ? updated : tag)),
        );
      } else {
        const created = await createTag(session.access_token, form);
        setTags((prev) => [...prev, created]);
      }
      resetForm();
    } catch (saveError) {
      setError(
        saveError instanceof Error ? saveError.message : "Failed to save tag.",
      );
    } finally {
      setSaving(false);
    }
  }

  async function handleDelete(tag: Tag) {
    if (!supabase) return;
    const confirmed = window.confirm(
      `Delete tag "${tag.name}"? Questions using this tag will be untagged.`,
    );
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
      }
    } catch (deleteError) {
      setError(
        deleteError instanceof Error
          ? deleteError.message
          : "Failed to delete tag.",
      );
    } finally {
      setSaving(false);
    }
  }

  function startEdit(tag: Tag) {
    setEditingId(tag.id);
    setForm({
      name: tag.name,
      category: tag.category,
    });
  }

  if (loading) {
    return (
      <main className="mx-auto max-w-6xl px-6 py-12">
        <p className="text-sm text-zinc-500">Loading tags...</p>
      </main>
    );
  }

  if (error && tags.length === 0) {
    return (
      <main className="mx-auto max-w-6xl px-6 py-12">
        <p className="text-sm text-red-600">{error}</p>
      </main>
    );
  }

  return (
    <main className="mx-auto flex max-w-6xl flex-col gap-8 px-6 py-8">
      <header className="flex flex-wrap items-center justify-between gap-4">
        <div>
          <p className="text-xs uppercase tracking-[0.2em] text-zinc-400">
            Admin Console
          </p>
          <h1 className="text-2xl font-semibold text-zinc-900">Tags</h1>
          <p className="text-sm text-zinc-500">
            Manage tags for categorizing questions.
          </p>
        </div>
        <div className="flex items-center gap-3">
          <select
            className="rounded-lg border border-zinc-200 px-3 py-2 text-sm"
            value={filterCategory}
            onChange={(e) => setFilterCategory(e.target.value)}
          >
            <option value="">All categories</option>
            {TAG_CATEGORIES.map((cat) => (
              <option key={cat} value={cat}>
                {cat}
              </option>
            ))}
          </select>
          <button
            className="rounded-full border border-zinc-200 bg-white px-4 py-2 text-sm text-zinc-700 shadow-sm transition hover:border-zinc-300"
            onClick={resetForm}
            type="button"
          >
            Reset form
          </button>
        </div>
      </header>

      {error ? (
        <div className="rounded-2xl border border-amber-200 bg-amber-50 px-4 py-3 text-sm text-amber-800">
          {error}
        </div>
      ) : null}

      <section className="grid gap-6 lg:grid-cols-[minmax(0,2fr)_minmax(0,1fr)]">
        <div className="flex flex-col gap-6">
          {Object.keys(groupedTags).length === 0 ? (
            <div className="rounded-2xl border border-zinc-200 bg-white p-6 text-center text-sm text-zinc-500">
              No tags yet. Create one using the form.
            </div>
          ) : (
            Object.entries(groupedTags).map(([category, categoryTags]) => (
              <div
                key={category}
                className="rounded-2xl border border-zinc-200 bg-white"
              >
                <div className="border-b border-zinc-100 bg-zinc-50 px-4 py-3">
                  <h3 className="text-sm font-medium text-zinc-700 capitalize">
                    {category}
                  </h3>
                </div>
                <div className="flex flex-wrap gap-2 p-4">
                  {categoryTags.map((tag) => (
                    <div
                      key={tag.id}
                      className={`group flex items-center gap-2 rounded-full border px-3 py-1.5 text-sm transition ${
                        editingId === tag.id
                          ? "border-zinc-900 bg-zinc-900 text-white"
                          : "border-zinc-200 bg-white text-zinc-700 hover:border-zinc-300"
                      }`}
                    >
                      <span>{tag.name}</span>
                      <div className="flex items-center gap-1 opacity-0 group-hover:opacity-100 transition-opacity">
                        <button
                          className="text-xs hover:text-zinc-900"
                          onClick={() => startEdit(tag)}
                          type="button"
                          title="Edit"
                        >
                          ✎
                        </button>
                        <button
                          className="text-xs hover:text-red-600"
                          onClick={() => handleDelete(tag)}
                          type="button"
                          title="Delete"
                        >
                          ×
                        </button>
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            ))
          )}
        </div>

        <div className="rounded-2xl border border-zinc-200 bg-white p-5 shadow-sm h-fit">
          <h2 className="text-lg font-semibold text-zinc-900">
            {editingId ? "Edit tag" : "Create new tag"}
          </h2>
          <div className="mt-4 grid gap-4 text-sm text-zinc-700">
            <label className="grid gap-1">
              Name
              <input
                className="rounded-lg border border-zinc-200 px-3 py-2 text-sm"
                value={form.name}
                onChange={(e) => setForm({ ...form, name: e.target.value })}
                placeholder="e.g., algebra, geometry"
              />
            </label>
            <label className="grid gap-1">
              Category
              <select
                className="rounded-lg border border-zinc-200 px-3 py-2 text-sm"
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
                className="rounded-lg bg-zinc-900 px-4 py-2 text-sm font-semibold text-white disabled:opacity-60"
                disabled={saving || !form.name.trim()}
                onClick={handleSave}
                type="button"
              >
                {editingId ? "Save changes" : "Create tag"}
              </button>
              {editingId ? (
                <button
                  className="rounded-lg border border-zinc-200 px-4 py-2 text-sm text-zinc-700"
                  onClick={resetForm}
                  type="button"
                >
                  Cancel
                </button>
              ) : null}
            </div>
          </div>
        </div>
      </section>

      <div className="text-xs text-zinc-400">
        Total: {tags.length} tags across {Object.keys(groupedTags).length} categories
      </div>
    </main>
  );
}
