"use server";

import "server-only";
import { requireAdmin } from "@/lib/adminAuth";
import { purgeOldAdminAuditLogs } from "@/lib/adminAudit";

export type AdminAuditLog = {
  id: string;
  actor_id: string | null;
  action: string;
  entity_type: string;
  entity_id: string | null;
  payload: Record<string, unknown>;
  created_at: string;
};

export async function listAdminAuditLogs(
  accessToken: string,
  limit: number = 200,
): Promise<AdminAuditLog[]> {
  const { supabase } = await requireAdmin(accessToken);
  await purgeOldAdminAuditLogs(supabase);

  const { data, error } = await supabase
    .from("admin_audit_logs")
    .select("id, actor_id, action, entity_type, entity_id, payload, created_at")
    .order("created_at", { ascending: false })
    .limit(limit);

  if (error) {
    throw new Error("Failed to load audit logs.");
  }

  return (data ?? []) as AdminAuditLog[];
}
