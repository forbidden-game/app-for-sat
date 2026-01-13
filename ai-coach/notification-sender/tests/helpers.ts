import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import { randomUUID } from "crypto";
import * as dotenv from "dotenv";

import type { NotificationEventRow, NotificationStatus } from "../src/types.js";

dotenv.config({ path: ".env" });
dotenv.config({ path: ".env.local" });
dotenv.config({ path: ".env.test" });

const DEFAULT_SUPABASE_URL = "http://127.0.0.1:54321";
const DEFAULT_SERVICE_ROLE_KEY =
  "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImV4cCI6MTk4MzgxMjk5Nn0.EGIM96RAZx35lJzdJsyH-qQwv8Hdp7fsn3W0YpN81IU";

export function getEnv(name: string, fallback?: string): string {
  const value = process.env[name];
  if (value && value.length > 0) return value;
  if (fallback) return fallback;
  throw new Error(`Missing env var: ${name}`);
}

export function createLocalSupabase(): SupabaseClient {
  const supabaseUrl = getEnv("SUPABASE_URL", DEFAULT_SUPABASE_URL);
  const supabaseServiceRoleKey = getEnv("SUPABASE_SERVICE_ROLE_KEY", DEFAULT_SERVICE_ROLE_KEY);

  return createClient(supabaseUrl, supabaseServiceRoleKey, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
    },
  });
}

export async function createTestUser(supabase: SupabaseClient): Promise<string> {
  const email = `notification-sender-${randomUUID()}@example.com`;
  const { data, error } = await supabase.auth.admin.createUser({
    email,
    password: `Test-${randomUUID()}`,
    email_confirm: true,
  });

  if (error || !data.user) {
    throw new Error(`Failed to create test user: ${error?.message ?? "unknown"}`);
  }

  return data.user.id;
}

export async function deleteTestUser(supabase: SupabaseClient, userId: string): Promise<void> {
  const { error } = await supabase.auth.admin.deleteUser(userId);
  if (error) throw new Error(`Failed to delete test user: ${error.message}`);
}

export async function clearNotificationData(
  supabase: SupabaseClient,
  studentId: string,
): Promise<void> {
  const { error: eventError } = await supabase
    .from("notification_events")
    .delete()
    .eq("student_id", studentId);
  if (eventError) throw new Error(`Failed to clear notification_events: ${eventError.message}`);

  const { error: tokenError } = await supabase
    .from("push_tokens")
    .delete()
    .eq("student_id", studentId);
  if (tokenError) throw new Error(`Failed to clear push_tokens: ${tokenError.message}`);
}

type NotificationEventInsert = {
  studentId: string;
  status?: NotificationStatus;
  eventType?: NotificationEventRow["event_type"];
  payload?: Record<string, unknown>;
  error?: string | null;
  createdAt?: string;
  updatedAt?: string;
  lockedAt?: string | null;
  lockedBy?: string | null;
};

export async function insertNotificationEvent(
  supabase: SupabaseClient,
  {
    studentId,
    status = "queued",
    eventType = "attempt_insight_ready",
    payload = {},
    error = null,
    createdAt = new Date().toISOString(),
    updatedAt = createdAt,
    lockedAt = null,
    lockedBy = null,
  }: NotificationEventInsert,
): Promise<NotificationEventRow> {
  const { data, error: insertError } = await supabase
    .from("notification_events")
    .insert({
      student_id: studentId,
      event_type: eventType,
      payload,
      status,
      error,
      created_at: createdAt,
      updated_at: updatedAt,
      locked_at: lockedAt,
      locked_by: lockedBy,
    })
    .select("*")
    .single();

  if (insertError || !data) {
    throw new Error(`Failed to insert notification event: ${insertError?.message ?? "unknown"}`);
  }

  return data as NotificationEventRow;
}

export async function fetchNotificationEvent(
  supabase: SupabaseClient,
  eventId: string,
): Promise<NotificationEventRow | null> {
  const { data, error } = await supabase
    .from("notification_events")
    .select("*")
    .eq("id", eventId)
    .maybeSingle();

  if (error) throw new Error(`Failed to fetch notification event: ${error.message}`);
  return data as NotificationEventRow | null;
}

type PushTokenInsert = {
  studentId: string;
  deviceToken: string;
  platform?: "apns" | "fcm";
  lastSeenAt?: string;
};

export async function insertPushToken(
  supabase: SupabaseClient,
  { studentId, deviceToken, platform = "apns", lastSeenAt }: PushTokenInsert,
): Promise<void> {
  const { error } = await supabase.from("push_tokens").insert({
    student_id: studentId,
    device_token: deviceToken,
    platform,
    last_seen_at: lastSeenAt,
  });

  if (error) throw new Error(`Failed to insert push token: ${error.message}`);
}
