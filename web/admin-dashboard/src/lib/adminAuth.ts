import "server-only";
import { cache } from "react";
import { getSupabaseAdminClient } from "./supabaseAdmin";

type AdminSupabase = NonNullable<ReturnType<typeof getSupabaseAdminClient>>;

export type AdminContext = {
  supabase: AdminSupabase;
  admin: {
    id: string;
    email: string | null;
    display_name: string | null;
  };
};

const requireAdminCached = cache(async (accessToken: string): Promise<AdminContext> => {
  const supabase = getSupabaseAdminClient();
  if (!supabase) {
    throw new Error("Supabase admin not configured.");
  }

  const { data: userData, error: userError } = await supabase.auth.getUser(
    accessToken,
  );
  if (userError || !userData.user) {
    throw new Error("Invalid session.");
  }

  const { data: profile, error: profileError } = await supabase
    .from("profiles")
    .select("role, display_name")
    .eq("id", userData.user.id)
    .single();

  if (profileError || !profile || profile.role !== "admin") {
    throw new Error("Admin access required.");
  }

  return {
    supabase,
    admin: {
      id: userData.user.id,
      email: userData.user.email ?? null,
      display_name: profile.display_name ?? null,
    },
  };
});

export const requireAdmin = requireAdminCached;
