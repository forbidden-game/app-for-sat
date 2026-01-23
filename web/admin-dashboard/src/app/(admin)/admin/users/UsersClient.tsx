"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import { usePathname, useRouter, useSearchParams } from "next/navigation";
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
import { Skeleton } from "@/components/Skeleton";
import { EmptyState } from "@/components/EmptyState";
import { LoadingButton } from "@/components/Button";
import { useSortable, renderSortIcon } from "@/hooks/useSortable";

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
  const router = useRouter();
  const pathname = usePathname();
  const searchParams = useSearchParams();
  const [users, setUsers] = useState<UserListItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [form, setForm] = useState<UserInput>({ ...EMPTY_FORM });
  const [editingId, setEditingId] = useState<string | null>(null);
  const [roleFilter, setRoleFilter] = useState<string>(() => searchParams.get("role") ?? "");
  const [page, setPage] = useState(() => {
    const value = Number(searchParams.get("page"));
    return Number.isFinite(value) && value > 0 ? value : 1;
  });
  const [hasNext, setHasNext] = useState(false);

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

  const loadUsersPage = useCallback(async () => {
    setLoading(true);
    setError(null);

    const accessToken = await getAccessToken();
    if (!accessToken) {
      setLoading(false);
      return;
    }

    try {
      const result: ListUsersResult = await listUsers(accessToken, {
        page,
        pageSize: PAGE_SIZE,
        role: roleFilter ? (roleFilter as UserRole) : undefined,
      });
      setUsers(result.users);
      setHasNext(result.hasNext);
    } catch (loadError) {
      setError(loadError instanceof Error ? loadError.message : "Failed to load users.");
    } finally {
      setLoading(false);
    }
  }, [getAccessToken, page, roleFilter]);

  useEffect(() => {
    void loadUsersPage();
  }, [loadUsersPage]);

  useEffect(() => {
    setRoleFilter(searchParams.get("role") ?? "");
    const value = Number(searchParams.get("page"));
    setPage(Number.isFinite(value) && value > 0 ? value : 1);
  }, [searchParams]);

  useEffect(() => {
    const nextParams = new URLSearchParams(searchParams);
    if (roleFilter) {
      nextParams.set("role", roleFilter);
    } else {
      nextParams.delete("role");
    }

    if (page > 1) {
      nextParams.set("page", String(page));
    } else {
      nextParams.delete("page");
    }

    const nextQuery = nextParams.toString();
    const currentQuery = searchParams.toString();
    if (nextQuery !== currentQuery) {
      router.replace(nextQuery ? `${pathname}?${nextQuery}` : pathname, { scroll: false });
    }
  }, [page, roleFilter, pathname, router, searchParams]);

  const filteredUsers = useMemo(() => {
    if (!roleFilter) return users;
    return users.filter((user) => user.role === roleFilter);
  }, [users, roleFilter]);

  // Sortable hook for user table - sorting current page
  const {
    sortedData: sortedUsers,
    handleSort: handleUserSort,
    sortConfig: userSortConfig,
  } = useSortable(filteredUsers, "created_at", "desc");

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
        await updateUser(accessToken, editingId, form);
        await loadUsersPage();
      } else {
        await createUser(accessToken, form);
        setPage(1);
      }
      resetForm();
    } catch (saveError) {
      setError(saveError instanceof Error ? saveError.message : "Failed to save user.");
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
      if (editingId === user.id) {
        resetForm();
      }
      await loadUsersPage();
    } catch (deleteError) {
      setError(deleteError instanceof Error ? deleteError.message : "Failed to delete user.");
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
      <main className="mx-auto flex max-w-[1280px] flex-col gap-6 px-6 pb-10 pt-8">
        <header className="flex flex-wrap items-center justify-between gap-4">
          <div className="flex flex-col gap-2">
            <Skeleton variant="text" width="80px" />
            <Skeleton variant="text" width="200px" height="28px" />
            <Skeleton variant="text" width="300px" />
          </div>
        </header>

        <section className="grid gap-6 lg:grid-cols-[minmax(0,2fr)_minmax(0,1fr)]">
          <div className="overflow-hidden rounded-xl border border-[color:var(--border)] bg-[color:var(--surface)]">
            <div className="flex flex-wrap items-center justify-between gap-3 border-b border-[color:var(--border)] px-4 py-3">
              <Skeleton variant="text" width="100px" />
              <div className="flex gap-2">
                <Skeleton variant="rectangular" width="60px" height="32px" />
                <Skeleton variant="rectangular" width="60px" height="32px" />
              </div>
            </div>
            <div className="max-h-[560px] overflow-auto">
              <div className="min-w-full">
                <div className="sticky top-0 flex bg-[color:var(--surface-soft)] px-4 py-3">
                  {Array.from({ length: 6 }).map((_, i) => (
                    <Skeleton key={i} variant="text" width="16%" className="mr-4" />
                  ))}
                </div>
                {Array.from({ length: 5 }).map((_, rowIndex) => (
                  <div
                    key={rowIndex}
                    className="flex items-center gap-4 border-t border-[color:var(--border)] px-4 py-3"
                  >
                    {Array.from({ length: 6 }).map((_, colIndex) => (
                      <Skeleton key={colIndex} variant="text" width="16%" />
                    ))}
                  </div>
                ))}
              </div>
            </div>
          </div>

          <div className="rounded-xl border border-[color:var(--border)] bg-[color:var(--surface)] p-5">
            <Skeleton variant="text" width="80px" className="mb-2" />
            <Skeleton variant="text" width="120px" height="20px" className="mb-4" />
            <div className="mt-4 flex flex-col gap-4">
              <Skeleton variant="rectangular" height="40px" />
              <Skeleton variant="rectangular" height="40px" />
              <Skeleton variant="rectangular" height="40px" />
            </div>
            <Skeleton variant="rectangular" height="36px" className="mt-6" />
          </div>
        </section>
      </main>
    );
  }

  if (error && users.length === 0) {
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
          <p className="text-xs font-medium text-[color:var(--ink-muted)]">Admin Console</p>
          <h1 className="text-2xl font-semibold tracking-tight text-[color:var(--ink)]">Users</h1>
          <p className="mt-1 text-sm text-[color:var(--ink-muted)]">
            Create users via email invite and manage roles across student, parent, and admin
            accounts.
          </p>
        </div>
        <div className="flex items-center gap-3">
          <label
            className="text-xs font-medium text-[color:var(--ink-muted)]"
            htmlFor="role-filter"
          >
            Filter role
          </label>
          <select
            id="role-filter"
            name="roleFilter"
            className="rounded-full border border-[color:var(--border)] bg-[color:var(--surface)] px-3 py-1.5 text-xs font-medium text-[color:var(--ink)]"
            value={roleFilter}
            onChange={(event) => {
              setRoleFilter(event.target.value);
              setPage(1);
            }}
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
        <p className="text-sm text-[color:var(--danger-strong)]" role="alert">
          {error} Try refreshing or checking Supabase config.
        </p>
      ) : null}

      <section className="grid gap-6 lg:grid-cols-[minmax(0,2fr)_minmax(0,1fr)]">
        <div className="overflow-hidden rounded-xl border border-[color:var(--border)] bg-[color:var(--surface)]">
          <div className="flex flex-wrap items-center justify-between gap-3 border-b border-[color:var(--border)] px-4 py-3">
            <div>
              <p className="text-sm font-semibold text-[color:var(--ink)]">User List</p>
              <p className="text-xs text-[color:var(--ink-muted)]">
                Showing {sortedUsers.length} users on page {page}. Click column headers to sort.
              </p>
            </div>
            <div className="flex items-center gap-2 text-xs text-[color:var(--ink-muted)]">
              <button
                type="button"
                onClick={() => setPage((prev) => Math.max(1, prev - 1))}
                disabled={page <= 1}
                className="rounded-full border border-[color:var(--border)] bg-[color:var(--surface)] px-3 py-1.5 font-medium text-[color:var(--ink-muted)] transition hover:border-[color:var(--accent)] hover:text-[color:var(--ink)] disabled:cursor-not-allowed disabled:opacity-60"
              >
                Prev
              </button>
              <span className="tabular-nums">Page {page}</span>
              <button
                type="button"
                onClick={() => setPage((prev) => prev + 1)}
                disabled={!hasNext}
                className="rounded-full border border-[color:var(--border)] bg-[color:var(--surface)] px-3 py-1.5 font-medium text-[color:var(--ink-muted)] transition hover:border-[color:var(--accent)] hover:text-[color:var(--ink)] disabled:cursor-not-allowed disabled:opacity-60"
              >
                Next
              </button>
            </div>
          </div>
          <div className="max-h-[560px] overflow-auto scrollbar-thin scrollbar-thumb-[color:var(--border)] scrollbar-track-transparent">
            <table className="min-w-full text-left text-sm text-[color:var(--ink-muted)] min-w-[800px]">
              <thead className="sticky top-0 bg-[color:var(--surface-soft)] z-10">
                <tr className="border-b border-[color:var(--border)] text-xs font-medium text-[color:var(--ink-muted)]">
                  <th
                    scope="col"
                    className="px-4 py-3 sticky left-0 bg-[color:var(--surface-soft)] min-w-[180px] cursor-pointer select-none hover:text-[color:var(--ink)]"
                    onClick={() => handleUserSort("email" as keyof UserListItem)}
                  >
                    <span className="inline-flex items-center gap-1">
                      Email
                      {renderSortIcon(userSortConfig.column === "email", userSortConfig.direction)}
                    </span>
                  </th>
                  <th
                    scope="col"
                    className="px-4 py-3 min-w-[120px] cursor-pointer select-none hover:text-[color:var(--ink)]"
                    onClick={() => handleUserSort("display_name" as keyof UserListItem)}
                  >
                    <span className="inline-flex items-center gap-1">
                      Name
                      {renderSortIcon(
                        userSortConfig.column === "display_name",
                        userSortConfig.direction,
                      )}
                    </span>
                  </th>
                  <th
                    scope="col"
                    className="px-4 py-3 min-w-[90px] cursor-pointer select-none hover:text-[color:var(--ink)]"
                    onClick={() => handleUserSort("role" as keyof UserListItem)}
                  >
                    <span className="inline-flex items-center gap-1">
                      Role
                      {renderSortIcon(userSortConfig.column === "role", userSortConfig.direction)}
                    </span>
                  </th>
                  <th
                    scope="col"
                    className="px-4 py-3 min-w-[140px] cursor-pointer select-none hover:text-[color:var(--ink)]"
                    onClick={() => handleUserSort("created_at" as keyof UserListItem)}
                  >
                    <span className="inline-flex items-center gap-1">
                      Created
                      {renderSortIcon(
                        userSortConfig.column === "created_at",
                        userSortConfig.direction,
                      )}
                    </span>
                  </th>
                  <th
                    scope="col"
                    className="px-4 py-3 min-w-[140px] cursor-pointer select-none hover:text-[color:var(--ink)]"
                    onClick={() => handleUserSort("last_sign_in_at" as keyof UserListItem)}
                  >
                    <span className="inline-flex items-center gap-1">
                      Last sign-in
                      {renderSortIcon(
                        userSortConfig.column === "last_sign_in_at",
                        userSortConfig.direction,
                      )}
                    </span>
                  </th>
                  <th
                    scope="col"
                    className="px-4 py-3 sticky right-0 bg-[color:var(--surface-soft)] min-w-[120px]"
                  >
                    Actions
                  </th>
                </tr>
              </thead>
              <tbody>
                {sortedUsers.length === 0 ? (
                  <tr>
                    <td colSpan={6}>
                      <EmptyState
                        title={roleFilter ? `No ${roleFilter} users found` : "No users found"}
                        description={
                          roleFilter
                            ? "Try selecting a different role filter."
                            : "Users will appear here once they sign up."
                        }
                        icon="users"
                        className="m-4"
                      />
                    </td>
                  </tr>
                ) : (
                  sortedUsers.map((user) => (
                    <tr
                      key={user.id}
                      className="border-b border-[color:var(--border)] hover:bg-[color:var(--surface-soft)] transition-colors"
                    >
                      <td className="px-4 py-3 text-[color:var(--ink)] sticky left-0 bg-[color:var(--surface)]">
                        {user.email ?? "(no email)"}
                      </td>
                      <td className="px-4 py-3 text-[color:var(--ink)]">
                        {user.display_name ?? "—"}
                      </td>
                      <td className="px-4 py-3 text-[color:var(--ink)]">
                        {user.role ?? "unknown"}
                      </td>
                      <td className="px-4 py-3 text-xs text-[color:var(--ink-muted)]">
                        {formatDateTime(user.created_at)}
                      </td>
                      <td className="px-4 py-3 text-xs text-[color:var(--ink-muted)]">
                        {user.last_sign_in_at ? formatDateTime(user.last_sign_in_at) : "—"}
                      </td>
                      <td className="px-4 py-3 sticky right-0 bg-[color:var(--surface)]">
                        <div className="flex flex-wrap gap-2">
                          <button
                            className="rounded-full border border-[color:var(--border)] bg-[color:var(--surface)] px-3 py-1 text-xs font-medium text-[color:var(--ink-muted)] transition hover:border-[color:var(--accent)] hover:text-[color:var(--ink)]"
                            onClick={() => startEdit(user)}
                          >
                            Edit
                          </button>
                          <button
                            className="rounded-full border border-[color:var(--danger)] px-3 py-1 text-xs font-medium text-[color:var(--danger-strong)] transition hover:bg-[color:var(--surface-soft)]"
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

        <div className="rounded-xl border border-[color:var(--border)] bg-[color:var(--surface)] p-5">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-xs font-medium text-[color:var(--ink-muted)]">
                {editingId ? "Edit User" : "Create User"}
              </p>
              <p className="text-sm font-semibold tracking-tight text-[color:var(--ink)]">
                {editingId ? "Update Profile" : "Send Invite"}
              </p>
            </div>
            {editingId ? (
              <button
                className="text-xs font-medium text-[color:var(--ink-muted)] transition hover:text-[color:var(--ink)]"
                onClick={resetForm}
              >
                Cancel
              </button>
            ) : null}
          </div>

          <div className="mt-4 flex flex-col gap-4 text-sm">
            <label className="flex flex-col gap-2 text-xs font-medium text-[color:var(--ink-muted)]">
              Email
              <input
                name="email"
                type="email"
                inputMode="email"
                className="rounded-lg border border-[color:var(--border)] bg-[color:var(--surface)] px-3 py-2 text-sm text-[color:var(--ink)]"
                value={form.email}
                onChange={(event) => setForm((prev) => ({ ...prev, email: event.target.value }))}
                placeholder="name@example.com…"
                autoComplete="email"
                spellCheck={false}
              />
            </label>
            <label className="flex flex-col gap-2 text-xs font-medium text-[color:var(--ink-muted)]">
              Display name
              <input
                name="displayName"
                className="rounded-lg border border-[color:var(--border)] bg-[color:var(--surface)] px-3 py-2 text-sm text-[color:var(--ink)]"
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
            <label className="flex flex-col gap-2 text-xs font-medium text-[color:var(--ink-muted)]">
              Role
              <select
                name="role"
                className="rounded-lg border border-[color:var(--border)] bg-[color:var(--surface)] px-3 py-2 text-sm text-[color:var(--ink)]"
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
            <LoadingButton loading={saving} onClick={handleSave}>
              {editingId ? "Update User" : "Create & Send Invite"}
            </LoadingButton>
            <p className="text-xs text-[color:var(--ink-muted)]">
              Invites use the Supabase email flow. Role changes do not edit parent/student links.
            </p>
          </div>
        </div>
      </section>
    </main>
  );
}
