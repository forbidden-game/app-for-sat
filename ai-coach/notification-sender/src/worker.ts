import type { SupabaseClient } from "@supabase/supabase-js";
import { sleep } from "@ai-coach/shared";

import type { SenderConfig } from "./config.js";
import { logger } from "./logger.js";
import type { NotificationEventRow } from "./types.js";

type PushTokenRow = {
  device_token: string;
  platform: string;
};

export async function claimEvents(
  supabase: SupabaseClient,
  workerId: string,
  limit: number,
): Promise<NotificationEventRow[]> {
  const { data, error } = await supabase.rpc("claim_notification_events", {
    p_worker_id: workerId,
    p_limit: limit,
  });

  if (error) throw new Error(error.message);
  return (data ?? []) as NotificationEventRow[];
}

export async function loadPushTokens(
  supabase: SupabaseClient,
  studentId: string,
): Promise<PushTokenRow[]> {
  const { data, error } = await supabase
    .from("push_tokens")
    .select("device_token, platform")
    .eq("student_id", studentId);

  if (error) throw new Error(error.message);
  return (data ?? []) as PushTokenRow[];
}

export async function markSent(supabase: SupabaseClient, eventId: string): Promise<void> {
  const { error } = await supabase
    .from("notification_events")
    .update({ status: "sent", error: null, updated_at: new Date().toISOString() })
    .eq("id", eventId);

  if (error) throw new Error(error.message);
}

export async function markError(
  supabase: SupabaseClient,
  eventId: string,
  message: string,
): Promise<void> {
  const { error } = await supabase
    .from("notification_events")
    .update({ status: "error", error: message, updated_at: new Date().toISOString() })
    .eq("id", eventId);

  if (error) throw new Error(error.message);
}

export async function handleEvent(
  supabase: SupabaseClient,
  config: SenderConfig,
  event: NotificationEventRow,
): Promise<void> {
  const tokens = await loadPushTokens(supabase, event.student_id);

  if (config.mode === "log") {
    logger.info(
      {
        eventId: event.id,
        eventType: event.event_type,
        studentId: event.student_id,
        tokens: tokens.map((t) => ({ platform: t.platform, tokenSuffix: t.device_token.slice(-6) })),
      },
      "notification event claimed",
    );
  }

  await markSent(supabase, event.id);
}

async function processEvent(
  config: SenderConfig,
  supabase: SupabaseClient,
  event: NotificationEventRow,
): Promise<void> {
  try {
    await handleEvent(supabase, config, event);
  } catch (err) {
    const message = err instanceof Error ? err.message : "unknown_error";
    logger.error({ err, eventId: event.id }, "notification send failed");
    try {
      await markError(supabase, event.id, message);
    } catch (markErr) {
      logger.error({ err: markErr, eventId: event.id }, "failed to mark notification error");
    }
  }
}

export async function runWorker(config: SenderConfig, supabase: SupabaseClient): Promise<void> {
  let shuttingDown = false;
  const inFlight = new Set<Promise<void>>();

  const requestShutdown = (signal: string) => {
    if (shuttingDown) return;
    shuttingDown = true;
    logger.info({ signal }, "shutdown requested");
  };

  process.on("SIGTERM", () => requestShutdown("SIGTERM"));
  process.on("SIGINT", () => requestShutdown("SIGINT"));

  while (!shuttingDown) {
    if (inFlight.size >= config.maxConcurrency) {
      await Promise.race(inFlight);
      continue;
    }

    let events: NotificationEventRow[] = [];

    try {
      const capacity = Math.max(1, config.maxConcurrency - inFlight.size);
      events = await claimEvents(supabase, config.workerId, Math.min(config.claimLimit, capacity));
    } catch (err) {
      logger.error({ err }, "failed to claim notification events");
      await sleep(config.pollIntervalMs);
      continue;
    }

    if (events.length === 0) {
      await sleep(config.pollIntervalMs);
      continue;
    }

    for (const event of events) {
      const task = processEvent(config, supabase, event).finally(() => {
        inFlight.delete(task);
      });
      inFlight.add(task);
    }
  }

  if (inFlight.size > 0) {
    logger.info({ pending: inFlight.size }, "draining in-flight notifications");
    await Promise.allSettled(inFlight);
  }
}
