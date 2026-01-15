"use client";

import { useEffect, useMemo, useState } from "react";
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

  useEffect(() => {
    void loadUsers(1);
  }, [supabase]);

  async function getAccessToken() {
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
  }

  async function loadUsers(targetPage: number) {
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
  }

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
        <p className="text-sm text-zinc-500">Loading users...</p>
      </main>
    );
  }

  if (error && users.length === 0) {
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
          <h1 className="text-2xl font-semibold text-zinc-900">Users</h1>
          <p className="mt-1 text-sm text-zinc-500">
            Create users via email invite and manage roles across student, parent,
            and admin accounts.
          </p>
        </div>
        <div className="flex items-center gap-3">
          <label
            className="text-xs uppercase tracking-[0.2em] text-zinc-400"
            htmlFor="role-filter"
          >
            Filter role
          </label>
          <select
            id="role-filter"
            className="rounded-full border border-zinc-200 bg-white px-3 py-2 text-sm"
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

      {error ? <p className="text-sm text-red-600">{error}</p> : null}

      <section className="grid gap-6 lg:grid-cols-[minmax(0,2fr)_minmax(0,1fr)]">
        <div className="overflow-hidden rounded-2xl border border-zinc-200 bg-white">
          <div className="flex items-center justify-between border-b border-zinc-100 px-4 py-3">
            <div>
              <p className="text-sm font-semibold text-zinc-900">User list</p>
              <p className="text-xs text-zinc-500">
                Showing page {page}. Filters only apply to the current page.
              </p>
            </div>
            <div className="flex items-center gap-2 text-xs text-zinc-400">
              <button
                className="rounded-full border border-zinc-200 px-3 py-1 text-zinc-700 transition hover:bg-zinc-50 disabled:cursor-not-allowed disabled:opacity-50"
                onClick={() => loadUsers(page - 1)}
                disabled={page <= 1 || loading}
              >
                Prev
              </button>
              <button
                className="rounded-full border border-zinc-200 px-3 py-1 text-zinc-700 transition hover:bg-zinc-50 disabled:cursor-not-allowed disabled:opacity-50"
                onClick={() => loadUsers(page + 1)}
                disabled={!hasNext || loading}
              >
                Next
              </button>
            </div>
          </div>
          <div className="max-h-[560px] overflow-auto">
            <table className="min-w-full text-left text-sm">
              <thead className="sticky top-0 bg-white">
                <tr className="border-b border-zinc-100 text-xs uppercase tracking-[0.16em] text-zinc-400">
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
                    <td className="px-4 py-6 text-sm text-zinc-500" colSpan={6}>
                      No users found on this page.
                    </td>
                  </tr>
                ) : (
                  filteredUsers.map((user) => (
                    <tr key={user.id} className="border-b border-zinc-100">
                      <td className="px-4 py-3 text-zinc-900">
                        {user.email ?? "(no email)"}
                      </td>
                      <td className="px-4 py-3 text-zinc-700">
                        {user.display_name ?? "—"}
                      </td>
                      <td className="px-4 py-3 text-zinc-700">
                        {user.role ?? "unknown"}
                      </td>
                      <td className="px-4 py-3 text-zinc-500">
                        {formatDateTime(user.created_at)}
                      </td>
                      <td className="px-4 py-3 text-zinc-500">
                        {user.last_sign_in_at
                          ? formatDateTime(user.last_sign_in_at)
                          : "—"}
                      </td>
                      <td className="px-4 py-3">
                        <div className="flex flex-wrap gap-2">
                          <button
                            className="rounded-full border border-zinc-200 px-3 py-1 text-xs text-zinc-700 transition hover:bg-zinc-50"
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

        <div className="rounded-2xl border border-zinc-200 bg-white p-5">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-xs uppercase tracking-[0.2em] text-zinc-400">
                {editingId ? "Edit user" : "Create user"}
              </p>
              <p className="text-sm font-semibold text-zinc-900">
                {editingId ? "Update profile" : "Send invite"}
              </p>
            </div>
            {editingId ? (
              <button
                className="text-xs text-zinc-400 transition hover:text-zinc-600"
                onClick={resetForm}
              >
                Cancel
              </button>
            ) : null}
          </div>

          <div className="mt-4 flex flex-col gap-4 text-sm">
            <label className="flex flex-col gap-2 text-xs uppercase tracking-[0.16em] text-zinc-400">
              Email
              <input
                className="rounded-xl border border-zinc-200 px-3 py-2 text-sm text-zinc-900"
                value={form.email}
                onChange={(event) =>
                  setForm((prev) => ({ ...prev, email: event.target.value }))
                }
                placeholder="name@example.com"
              />
            </label>
            <label className="flex flex-col gap-2 text-xs uppercase tracking-[0.16em] text-zinc-400">
              Display name
              <input
                className="rounded-xl border border-zinc-200 px-3 py-2 text-sm text-zinc-900"
                value={form.display_name}
                onChange={(event) =>
                  setForm((prev) => ({
                    ...prev,
                    display_name: event.target.value,
                  }))
                }
                placeholder="Optional"
              />
            </label>
            <label className="flex flex-col gap-2 text-xs uppercase tracking-[0.16em] text-zinc-400">
              Role
              <select
                className="rounded-xl border border-zinc-200 bg-white px-3 py-2 text-sm"
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
              className="rounded-full bg-zinc-900 px-4 py-2 text-sm font-semibold text-white transition hover:bg-zinc-800 disabled:cursor-not-allowed disabled:opacity-60"
              onClick={handleSave}
              disabled={saving}
            >
              {editingId ? "Update user" : "Create and send invite"}
            </button>
            <p className="text-xs text-zinc-500">
              Invites use the Supabase email flow. Role changes do not edit
              parent/student links.
            </p>
          </div>
        </div>
      </section>
    </main>
  );
}
