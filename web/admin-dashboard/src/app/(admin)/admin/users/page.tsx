"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import { getSupabaseClient } from "@/lib/supabaseClient";
import {
  createUser,
  deleteUser,
  listUsers,
  updateUser,
  type ListUsersResult,
  type UserInput,
  type UserListItem,
  type UserRole,
} from "./actions";

const ROLE_OPTIONS: UserRole[] = ["student", "parent", "admin"];

const EMPTY_FORM: UserInput = {
  email: "",
  display_name: "",
  role: "student",
};

const PAGE_SIZE = 20;

function formatDateTime(value: string) {
  return new Date(value).toLocaleString();
}

export default function UsersPage() {
  const supabase = getSupabaseClient();
  const [users, setUsers] = useState<UserListItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [form, setForm] = useState<UserInput>({ ...EMPTY_FORM });
  const [editingId, setEditingId] = useState<string | null>(null);
  const [page, setPage] = useState(1);
  const [hasNext, setHasNext] = useState(false);
  const [roleFilter, setRoleFilter] = useState<string>("");

  const getAccessToken = useCallback(async () => {
    if (!supabase) {
      setError("Supabase not configured.");
      return null;
    }

    const { data: sessionData } = await supabase.auth.getSession();
    const session = sessionData.session;
    if (!session) {
      setError("You are not signed in.");
      return null;
    }

    return session.access_token;
  }, [supabase]);

  const loadUsers = useCallback(async (targetPage: number) => {
    const safePage = Math.max(1, targetPage);
    setLoading(true);
    setError(null);

    const accessToken = await getAccessToken();
    if (!accessToken) {
      setLoading(false);
      return;
    }

    try {
      const result: ListUsersResult = await listUsers(accessToken, {
        page: safePage,
        pageSize: PAGE_SIZE,
      });
      setUsers(result.users);
      setPage(result.page);
      setHasNext(result.hasNext);
    } catch (loadError) {
      setError(
        loadError instanceof Error ? loadError.message : "Failed to load users.",
      );
    } finally {
      setLoading(false);
    }
  }, [getAccessToken]);

  useEffect(() => {
    void loadUsers(1);
  }, [loadUsers]);

  const filteredUsers = useMemo(() => {
    if (!roleFilter) return users;
    return users.filter((user) => user.role === roleFilter);
  }, [users, roleFilter]);

  function resetForm() {
    setForm({ ...EMPTY_FORM });
    setEditingId(null);
  }

  async function handleSave() {
    const accessToken = await getAccessToken();
    if (!accessToken) return;

    setSaving(true);
    setError(null);

    try {
      if (editingId) {
        const updated = await updateUser(accessToken, editingId, form);
        setUsers((prev) =>
          prev.map((user) => (user.id === updated.id ? updated : user)),
        );
      } else {
        const created = await createUser(accessToken, form);
        setUsers((prev) => [created, ...prev]);
      }
      resetForm();
    } catch (saveError) {
      setError(
        saveError instanceof Error ? saveError.message : "Failed to save user.",
      );
    } finally {
      setSaving(false);
    }
  }

  async function handleDelete(user: UserListItem) {
    const accessToken = await getAccessToken();
    if (!accessToken) return;

    const confirmed = window.confirm(
      `Delete user ${user.email ?? user.id}? This removes auth and profile data.`,
    );
    if (!confirmed) return;

    setSaving(true);
    setError(null);

    try {
      await deleteUser(accessToken, user.id);
      setUsers((prev) => prev.filter((item) => item.id !== user.id));
      if (editingId === user.id) {
        resetForm();
      }
    } catch (deleteError) {
      setError(
        deleteError instanceof Error
          ? deleteError.message
          : "Failed to delete user.",
      );
    } finally {
      setSaving(false);
    }
  }

  function startEdit(user: UserListItem) {
    setEditingId(user.id);
    setForm({
      email: user.email ?? "",
      display_name: user.display_name ?? "",
      role: (user.role ?? "student") as UserRole,
    });
  }

  if (loading) {
    return (
      <main className="mx-auto max-w-6xl px-6 py-12">
        <p className="text-sm text-[color:var(--ink-muted)]" role="status" aria-live="polite">
          Loading users…
        </p>
      </main>
    );
  }

  if (error && users.length === 0) {
    return (
      <main className="mx-auto max-w-6xl px-6 py-12">
        <p className="text-sm text-red-600" role="alert">
          {error}
        </p>
      </main>
    );
  }

  return (
    <main className="mx-auto flex max-w-6xl flex-col gap-8 px-6 py-8">
      <header className="flex flex-wrap items-center justify-between gap-4">
        <div>
          <p className="text-xs uppercase tracking-[0.2em] text-[color:var(--ink-muted)]">
            Admin Console
          </p>
          <h1 className="text-2xl font-semibold text-[color:var(--ink)]">Users</h1>
          <p className="mt-1 text-sm text-[color:var(--ink-muted)]">
            Create users via email invite and manage roles across student, parent,
            and admin accounts.
          </p>
        </div>
        <div className="flex items-center gap-3">
          <label
            className="text-xs uppercase tracking-[0.2em] text-[color:var(--ink-muted)]"
            htmlFor="role-filter"
          >
            Filter role
          </label>
          <select
            id="role-filter"
            name="roleFilter"
            className="rounded-full border border-[color:var(--border)] bg-[color:var(--surface)] px-3 py-2 text-sm"
            value={roleFilter}
            onChange={(event) => setRoleFilter(event.target.value)}
          >
            <option value="">All</option>
            {ROLE_OPTIONS.map((role) => (
              <option key={role} value={role}>
                {role}
              </option>
            ))}
          </select>
        </div>
      </header>

      {error ? (
        <p className="text-sm text-red-600" role="alert">
          {error}
        </p>
      ) : null}

      <section className="grid gap-6 lg:grid-cols-[minmax(0,2fr)_minmax(0,1fr)]">
        <div className="overflow-hidden rounded-2xl border border-[color:var(--border)] bg-[color:var(--surface)]">
          <div className="flex items-center justify-between border-b border-[color:var(--border)] px-4 py-3">
            <div>
              <p className="text-sm font-semibold text-[color:var(--ink)]">User List</p>
              <p className="text-xs text-[color:var(--ink-muted)]">
                Showing page {page}. Filters only apply to the current page.
              </p>
            </div>
            <div className="flex items-center gap-2 text-xs text-[color:var(--ink-muted)]">
              <button
                className="rounded-full border border-[color:var(--border)] px-3 py-1 text-[color:var(--ink)] transition hover:bg-[color:var(--surface-soft)] disabled:cursor-not-allowed disabled:opacity-50"
                onClick={() => loadUsers(page - 1)}
                disabled={page <= 1 || loading}
              >
                Prev
              </button>
              <button
                className="rounded-full border border-[color:var(--border)] px-3 py-1 text-[color:var(--ink)] transition hover:bg-[color:var(--surface-soft)] disabled:cursor-not-allowed disabled:opacity-50"
                onClick={() => loadUsers(page + 1)}
                disabled={!hasNext || loading}
              >
                Next
              </button>
            </div>
          </div>
          <div className="max-h-[560px] overflow-auto">
            <table className="min-w-full text-left text-sm">
              <thead className="sticky top-0 bg-[color:var(--surface)]">
                <tr className="border-b border-[color:var(--border)] text-xs uppercase tracking-[0.16em] text-[color:var(--ink-muted)]">
                  <th className="px-4 py-3">Email</th>
                  <th className="px-4 py-3">Name</th>
                  <th className="px-4 py-3">Role</th>
                  <th className="px-4 py-3">Created</th>
                  <th className="px-4 py-3">Last sign-in</th>
                  <th className="px-4 py-3">Actions</th>
                </tr>
              </thead>
              <tbody>
                {filteredUsers.length === 0 ? (
                  <tr>
                    <td
                      className="px-4 py-6 text-sm text-[color:var(--ink-muted)]"
                      colSpan={6}
                      role="status"
                      aria-live="polite"
                    >
                      No users found on this page.
                    </td>
                  </tr>
                ) : (
                  filteredUsers.map((user) => (
                    <tr key={user.id} className="border-b border-[color:var(--border)]">
                      <td className="px-4 py-3 text-[color:var(--ink)]">
                        {user.email ?? "(no email)"}
                      </td>
                      <td className="px-4 py-3 text-[color:var(--ink)]">
                        {user.display_name ?? "—"}
                      </td>
                      <td className="px-4 py-3 text-[color:var(--ink)]">
                        {user.role ?? "unknown"}
                      </td>
                      <td className="px-4 py-3 text-[color:var(--ink-muted)]">
                        {formatDateTime(user.created_at)}
                      </td>
                      <td className="px-4 py-3 text-[color:var(--ink-muted)]">
                        {user.last_sign_in_at
                          ? formatDateTime(user.last_sign_in_at)
                          : "—"}
                      </td>
                      <td className="px-4 py-3">
                        <div className="flex flex-wrap gap-2">
                          <button
                            className="rounded-full border border-[color:var(--border)] px-3 py-1 text-xs text-[color:var(--ink)] transition hover:bg-[color:var(--surface-soft)]"
                            onClick={() => startEdit(user)}
                          >
                            Edit
                          </button>
                          <button
                            className="rounded-full border border-rose-200 px-3 py-1 text-xs text-rose-700 transition hover:bg-rose-50"
                            onClick={() => handleDelete(user)}
                            disabled={saving}
                          >
                            Delete
                          </button>
                        </div>
                      </td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>
        </div>

        <div className="rounded-2xl border border-[color:var(--border)] bg-[color:var(--surface)] p-5">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-xs uppercase tracking-[0.2em] text-[color:var(--ink-muted)]">
                {editingId ? "Edit User" : "Create User"}
              </p>
              <p className="text-sm font-semibold text-[color:var(--ink)]">
                {editingId ? "Update Profile" : "Send Invite"}
              </p>
            </div>
            {editingId ? (
              <button
                className="text-xs text-[color:var(--ink-muted)] transition hover:text-[color:var(--ink-muted)]"
                onClick={resetForm}
              >
                Cancel
              </button>
            ) : null}
          </div>

          <div className="mt-4 flex flex-col gap-4 text-sm">
            <label className="flex flex-col gap-2 text-xs uppercase tracking-[0.16em] text-[color:var(--ink-muted)]">
              Email
              <input
                name="email"
                className="rounded-xl border border-[color:var(--border)] px-3 py-2 text-sm text-[color:var(--ink)]"
                value={form.email}
                onChange={(event) =>
                  setForm((prev) => ({ ...prev, email: event.target.value }))
                }
                placeholder="name@example.com…"
                autoComplete="email"
                spellCheck={false}
              />
            </label>
            <label className="flex flex-col gap-2 text-xs uppercase tracking-[0.16em] text-[color:var(--ink-muted)]">
              Display name
              <input
                name="displayName"
                className="rounded-xl border border-[color:var(--border)] px-3 py-2 text-sm text-[color:var(--ink)]"
                value={form.display_name}
                onChange={(event) =>
                  setForm((prev) => ({
                    ...prev,
                    display_name: event.target.value,
                  }))
                }
                placeholder="Optional…"
                autoComplete="name"
              />
            </label>
            <label className="flex flex-col gap-2 text-xs uppercase tracking-[0.16em] text-[color:var(--ink-muted)]">
              Role
              <select
                name="role"
                className="rounded-xl border border-[color:var(--border)] bg-[color:var(--surface)] px-3 py-2 text-sm"
                value={form.role}
                onChange={(event) =>
                  setForm((prev) => ({
                    ...prev,
                    role: event.target.value as UserRole,
                  }))
                }
              >
                {ROLE_OPTIONS.map((role) => (
                  <option key={role} value={role}>
                    {role}
                  </option>
                ))}
              </select>
            </label>
          </div>

          <div className="mt-6 flex flex-col gap-2">
            <button
              className="rounded-full bg-[color:var(--accent)] px-4 py-2 text-sm font-semibold text-white transition hover:bg-[color:var(--accent-strong)] disabled:cursor-not-allowed disabled:opacity-60"
              onClick={handleSave}
              disabled={saving}
            >
              {editingId ? "Update User" : "Create & Send Invite"}
            </button>
            <p className="text-xs text-[color:var(--ink-muted)]">
              Invites use the Supabase email flow. Role changes do not edit
              parent/student links.
            </p>
          </div>
        </div>
      </section>
    </main>
  );
}
