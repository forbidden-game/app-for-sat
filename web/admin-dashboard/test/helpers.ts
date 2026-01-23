import { createClient, SupabaseClient } from "@supabase/supabase-js";
import { serviceClient, TEST_ADMIN_EMAIL, TEST_ADMIN_PASSWORD } from "./setup";

const SUPABASE_URL = process.env.NEXT_PUBLIC_SUPABASE_URL!;
const SUPABASE_ANON_KEY = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!;

export type TestRole = "admin" | "student" | "parent";

export interface TestClient extends SupabaseClient {
  userId: string;
  userEmail: string;
}

export async function createClientAs(role: TestRole, email?: string): Promise<TestClient> {
  if (!serviceClient) {
    throw new Error("Service client not initialized");
  }

  const testEmail =
    email || `${role}_${Date.now()}_${Math.random().toString(36).slice(2)}@test.com`;
  const testPassword = "testpassword123";

  let userId: string;

  const { data: authData, error: authError } = await serviceClient.auth.admin.createUser({
    email: testEmail,
    password: testPassword,
    email_confirm: true,
  });

  if (authError) {
    if (authError.message.includes("already registered")) {
      const { data: existingUser } = await serviceClient.auth.admin.listUsers();
      const existing = existingUser?.users?.find((u) => u.email === testEmail);
      if (!existing) throw authError;
      userId = existing.id;
    } else {
      throw authError;
    }
  } else {
    userId = authData.user.id;
  }

  await serviceClient
    .from("profiles")
    .update({ role, display_name: `Test ${role}` })
    .eq("id", userId);

  const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
    },
  });

  await userClient.auth.signInWithPassword({
    email: testEmail,
    password: testPassword,
  });

  return Object.assign(userClient, { userId, userEmail: testEmail }) as TestClient;
}

export async function getAdminClient(): Promise<TestClient> {
  if (!serviceClient) {
    throw new Error("Service client not initialized");
  }

  const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
    },
  });

  const { data, error } = await userClient.auth.signInWithPassword({
    email: TEST_ADMIN_EMAIL,
    password: TEST_ADMIN_PASSWORD,
  });

  if (error) throw error;

  return Object.assign(userClient, {
    userId: data.user.id,
    userEmail: TEST_ADMIN_EMAIL,
  }) as TestClient;
}

export async function cleanupTestUser(email: string): Promise<void> {
  if (!serviceClient) return;

  const { data } = await serviceClient.auth.admin.listUsers();
  const user = data?.users?.find((u) => u.email === email);

  if (user) {
    await serviceClient.auth.admin.deleteUser(user.id);
  }
}

export function skipIfNoSupabase(): boolean {
  return !serviceClient;
}
