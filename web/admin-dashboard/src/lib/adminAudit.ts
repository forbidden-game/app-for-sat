import "server-only";
import type { AdminContext } from "./adminAuth";

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
    const { error } = await context.supabase.from("admin_audit_logs").insert({
      actor_id: context.admin.id,
      actor_email: context.admin.email,
      action: event.action,
      resource_type: event.resourceType,
      resource_id: event.resourceId ?? null,
      metadata: event.metadata ?? {},
    });
    if (error) {
      console.warn("admin_audit_log_failed", error.message);
    }
  } catch (err) {
    console.warn("admin_audit_log_failed", err);
  }
}
