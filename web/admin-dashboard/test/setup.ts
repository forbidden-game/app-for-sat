import { beforeAll, afterAll, vi } from "vitest";
import { createClient } from "@supabase/supabase-js";

vi.mock("server-only", () => ({}));

const SUPABASE_URL = process.env.NEXT_PUBLIC_SUPABASE_URL;
const SUPABASE_SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!SUPABASE_URL || !SUPABASE_SERVICE_KEY) {
  console.warn(
    "⚠️  Missing Supabase environment variables. Integration tests will be skipped."
  );
}

export const serviceClient = SUPABASE_URL && SUPABASE_SERVICE_KEY
  ? createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY, {
      auth: {
        autoRefreshToken: false,
        persistSession: false,
      },
    })
  : null;

export const TEST_ADMIN_EMAIL = "admin@test.com";
export const TEST_ADMIN_PASSWORD = "admin123456";

beforeAll(async () => {
  if (!serviceClient) return;

  try {
    const { data: existingProfiles } = await serviceClient
      .from("profiles")
      .select("id")
      .eq("role", "admin")
      .limit(1);

    if (existingProfiles && existingProfiles.length > 0) {
      return;
    }

    const { data: authData, error: authError } =
      await serviceClient.auth.admin.createUser({
        email: TEST_ADMIN_EMAIL,
        password: TEST_ADMIN_PASSWORD,
        email_confirm: true,
      });

    if (authError && !authError.message.includes("already registered")) {
      throw authError;
    }

    if (authData?.user) {
      await serviceClient
        .from("profiles")
        .update({ role: "admin", display_name: "Test Admin" })
        .eq("id", authData.user.id);
    }
  } catch (error) {
    console.error("Failed to setup test admin:", error);
  }
});

afterAll(async () => {});
