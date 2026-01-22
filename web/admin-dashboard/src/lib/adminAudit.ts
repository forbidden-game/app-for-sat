import "server-only";
import type { AdminContext } from "./adminAuth";
import type { Database } from "../../../../supabase/database.types";

export type AdminAuditEvent = {
  action: string;
  resourceType: string;
  resourceId?: string | null;
  metadata?: Record<string, unknown>;
};

const RETENTION_DAYS = 7;

export async function purgeOldAdminAuditLogs(supabase: AdminContext["supabase"]) {
  const cutoff = new Date(Date.now() - RETENTION_DAYS * 24 * 60 * 60 * 1000).toISOString();
  await supabase.from("admin_audit_logs").delete().lt("created_at", cutoff);
}

export async function recordAdminEvent(
  context: AdminContext,
  event: AdminAuditEvent,
): Promise<void> {
  try {
    await purgeOldAdminAuditLogs(context.supabase);
    const insertPayload = {
      actor_id: context.admin.id,
      action: event.action,
      entity_type: event.resourceType,
      entity_id: event.resourceId ?? null,
      payload: event.metadata ?? {},
    } as unknown as Database["public"]["Tables"]["admin_audit_logs"]["Insert"];
    const { error } = await context.supabase.from("admin_audit_logs").insert(insertPayload);
    if (error) {
      console.warn("admin_audit_log_failed", error.message);
    }
  } catch (err) {
    console.warn("admin_audit_log_failed", err);
  }
}
