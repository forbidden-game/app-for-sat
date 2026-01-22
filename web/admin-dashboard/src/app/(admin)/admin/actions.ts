"use server";

import "server-only";
import { requireAdmin } from "@/lib/adminAuth";

const ONE_WEEK_MS = 7 * 24 * 60 * 60 * 1000;

type Metric = {
  label: string;
  value: number;
  helper?: string;
};

export type AdminOverview = {
  admin: {
    id: string;
    email: string | null;
    display_name: string | null;
  };
  generated_at: string;
  metrics: Metric[];
  question_banks: Array<{
    id: string;
    slug: string;
    title: string;
    mode: string;
    question_limit: number | null;
    is_active: boolean;
    sort_order: number | null;
  }>;
  recent_users: Array<{
    id: string;
    display_name: string | null;
    role: string | null;
    created_at: string | null;
  }>;
};

async function requireCount(
  query: PromiseLike<{ count: number | null; error: unknown }>,
) {
  const { count, error } = await query;
  if (error || count === null) {
    throw new Error("Failed to load admin metrics.");
  }
  return count;
}

export async function getAdminOverview(accessToken: string): Promise<AdminOverview> {
  const { supabase, admin } = await requireAdmin(accessToken);
  const since = new Date(Date.now() - ONE_WEEK_MS).toISOString();

  const [
    studentCount,
    parentCount,
    adminCount,
    questionCount,
    bankCount,
    activeBankCount,
    sessionsWeekCount,
    attemptsWeekCount,
  ] = await Promise.all([
    requireCount(
      supabase
        .from("profiles")
        .select("id", { count: "exact", head: true })
        .eq("role", "student"),
    ),
    requireCount(
      supabase
        .from("profiles")
        .select("id", { count: "exact", head: true })
        .eq("role", "parent"),
    ),
    requireCount(
      supabase
        .from("profiles")
        .select("id", { count: "exact", head: true })
        .eq("role", "admin"),
    ),
    requireCount(
      supabase
        .from("questions")
        .select("id", { count: "exact", head: true }),
    ),
    requireCount(
      supabase
        .from("question_banks")
        .select("id", { count: "exact", head: true }),
    ),
    requireCount(
      supabase
        .from("question_banks")
        .select("id", { count: "exact", head: true })
        .eq("is_active", true),
    ),
    requireCount(
      supabase
        .from("sessions")
        .select("id", { count: "exact", head: true })
        .gte("created_at", since),
    ),
    requireCount(
      supabase
        .from("attempts")
        .select("id", { count: "exact", head: true })
        .gte("created_at", since),
    ),
  ]);

  const { data: questionBanks, error: bankError } = await supabase
    .from("question_banks")
    .select("id, slug, title, mode, question_limit, is_active, sort_order")
    .order("sort_order", { ascending: true })
    .limit(50);

  if (bankError) {
    throw new Error("Failed to load question banks.");
  }

  const { data: recentUsers, error: userError } = await supabase
    .from("profiles")
    .select("id, display_name, role, created_at")
    .order("created_at", { ascending: false })
    .limit(12);

  if (userError) {
    throw new Error("Failed to load users.");
  }

  return {
    admin,
    generated_at: new Date().toISOString(),
    metrics: [
      { label: "Students", value: studentCount },
      { label: "Parents", value: parentCount },
      { label: "Admins", value: adminCount },
      { label: "Questions", value: questionCount },
      {
        label: "Question banks",
        value: bankCount,
        helper: `${activeBankCount} active`,
      },
      {
        label: "Sessions (7d)",
        value: sessionsWeekCount,
      },
      {
        label: "Attempts (7d)",
        value: attemptsWeekCount,
      },
    ],
    question_banks: questionBanks ?? [],
    recent_users: recentUsers ?? [],
  };
}
