import type { SupabaseClient } from "@supabase/supabase-js";
import { afterAll, afterEach, beforeAll, beforeEach, describe, expect, it, vi } from "vitest";

import type { SenderConfig } from "../src/config.js";
import { logger } from "../src/logger.js";
import { claimEvents, handleEvent, loadPushTokens, markError, markSent } from "../src/worker.js";

import {
  clearNotificationData,
  createLocalSupabase,
  createTestUser,
  deleteTestUser,
  fetchNotificationEvent,
  insertNotificationEvent,
  insertPushToken,
  getEnv,
} from "./helpers.js";

describe.sequential("notification sender", () => {
  let supabase: SupabaseClient;
  let studentId = "";
  let otherStudentId = "";
  const workerId = "notification-sender-test";

  const buildConfig = (mode: SenderConfig["mode"]): SenderConfig => ({
    supabaseUrl: getEnv("SUPABASE_URL", "http://127.0.0.1:54321"),
    supabaseServiceRoleKey: getEnv(
      "SUPABASE_SERVICE_ROLE_KEY",
      "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImV4cCI6MTk4MzgxMjk5Nn0.EGIM96RAZx35lJzdJsyH-qQwv8Hdp7fsn3W0YpN81IU",
    ),
    workerId,
    pollIntervalMs: 0,
    claimLimit: 10,
    mode,
  });

  beforeAll(async () => {
    supabase = createLocalSupabase();
    studentId = await createTestUser(supabase);
    otherStudentId = await createTestUser(supabase);
  });

  beforeEach(async () => {
    await clearNotificationData(supabase, studentId);
    await clearNotificationData(supabase, otherStudentId);
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  afterAll(async () => {
    await deleteTestUser(supabase, studentId);
    await deleteTestUser(supabase, otherStudentId);
  });

  it("claims no events when queue empty", async () => {
    const events = await claimEvents(supabase, workerId, 5);
    expect(events).toEqual([]);
  });

  it("claims queued events and marks them sending", async () => {
    const event = await insertNotificationEvent(supabase, { studentId });

    const events = await claimEvents(supabase, workerId, 5);

    expect(events).toHaveLength(1);
    expect(events[0]?.id).toBe(event.id);
    expect(events[0]?.status).toBe("sending");

    const stored = await fetchNotificationEvent(supabase, event.id);
    expect(stored?.status).toBe("sending");
    expect(stored?.locked_by).toBe(workerId);
    expect(stored?.locked_at).not.toBeNull();
  });

  it("claims events in created_at order", async () => {
    const older = new Date(Date.now() - 120_000).toISOString();
    const newer = new Date().toISOString();

    const firstEvent = await insertNotificationEvent(supabase, {
      studentId,
      createdAt: older,
      updatedAt: older,
    });
    const secondEvent = await insertNotificationEvent(supabase, {
      studentId,
      createdAt: newer,
      updatedAt: newer,
    });

    const firstClaim = await claimEvents(supabase, workerId, 1);
    expect(firstClaim[0]?.id).toBe(firstEvent.id);

    const secondClaim = await claimEvents(supabase, workerId, 1);
    expect(secondClaim[0]?.id).toBe(secondEvent.id);
  });

  it("respects claim limits", async () => {
    await insertNotificationEvent(supabase, { studentId });
    await insertNotificationEvent(supabase, { studentId });
    await insertNotificationEvent(supabase, { studentId });

    const events = await claimEvents(supabase, workerId, 2);

    expect(events).toHaveLength(2);
  });

  it("skips recently updated sending events", async () => {
    await insertNotificationEvent(supabase, {
      studentId,
      status: "sending",
      updatedAt: new Date().toISOString(),
    });

    const events = await claimEvents(supabase, workerId, 3);

    expect(events).toHaveLength(0);
  });

  it("claims stale sending events", async () => {
    const stale = new Date(Date.now() - 11 * 60 * 1000).toISOString();
    const event = await insertNotificationEvent(supabase, {
      studentId,
      status: "sending",
      updatedAt: stale,
    });

    const events = await claimEvents(supabase, workerId, 1);

    expect(events).toHaveLength(1);
    expect(events[0]?.id).toBe(event.id);
  });

  it("does not claim sent or error events", async () => {
    await insertNotificationEvent(supabase, { studentId, status: "sent" });
    await insertNotificationEvent(supabase, { studentId, status: "error" });

    const events = await claimEvents(supabase, workerId, 5);

    expect(events).toHaveLength(0);
  });

  it("loads push tokens for a student", async () => {
    await insertPushToken(supabase, {
      studentId,
      deviceToken: "token-apns-123456",
      platform: "apns",
    });
    await insertPushToken(supabase, {
      studentId,
      deviceToken: "token-fcm-abcdef",
      platform: "fcm",
    });

    const tokens = await loadPushTokens(supabase, studentId);

    expect(tokens).toHaveLength(2);
    expect(tokens).toEqual(
      expect.arrayContaining([
        { device_token: "token-apns-123456", platform: "apns" },
        { device_token: "token-fcm-abcdef", platform: "fcm" },
      ]),
    );
  });

  it("ignores push tokens for other students", async () => {
    await insertPushToken(supabase, {
      studentId: otherStudentId,
      deviceToken: "token-other-123",
      platform: "apns",
    });
    await insertPushToken(supabase, {
      studentId,
      deviceToken: "token-main-456",
      platform: "fcm",
    });

    const tokens = await loadPushTokens(supabase, studentId);

    expect(tokens).toHaveLength(1);
    expect(tokens[0]).toEqual({ device_token: "token-main-456", platform: "fcm" });
  });

  it("marks events sent and clears errors", async () => {
    const event = await insertNotificationEvent(supabase, {
      studentId,
      status: "sending",
      error: "previous",
    });

    await markSent(supabase, event.id);

    const stored = await fetchNotificationEvent(supabase, event.id);
    expect(stored?.status).toBe("sent");
    expect(stored?.error).toBeNull();
  });

  it("updates updated_at when marking sent", async () => {
    const oldTimestamp = "2000-01-01T00:00:00.000Z";
    const event = await insertNotificationEvent(supabase, {
      studentId,
      updatedAt: oldTimestamp,
      createdAt: oldTimestamp,
    });

    await markSent(supabase, event.id);

    const stored = await fetchNotificationEvent(supabase, event.id);
    expect(new Date(stored?.updated_at ?? 0).getTime()).toBeGreaterThan(
      new Date(oldTimestamp).getTime(),
    );
  });

  it("marks events errored", async () => {
    const event = await insertNotificationEvent(supabase, {
      studentId,
      status: "sending",
    });

    await markError(supabase, event.id, "send_failed");

    const stored = await fetchNotificationEvent(supabase, event.id);
    expect(stored?.status).toBe("error");
  });

  it("stores error message when marking errored", async () => {
    const event = await insertNotificationEvent(supabase, {
      studentId,
      status: "sending",
    });

    await markError(supabase, event.id, "network_timeout");

    const stored = await fetchNotificationEvent(supabase, event.id);
    expect(stored?.error).toBe("network_timeout");
  });

  it("updates updated_at when marking errored", async () => {
    const oldTimestamp = "2001-01-01T00:00:00.000Z";
    const event = await insertNotificationEvent(supabase, {
      studentId,
      updatedAt: oldTimestamp,
      createdAt: oldTimestamp,
    });

    await markError(supabase, event.id, "send_failed");

    const stored = await fetchNotificationEvent(supabase, event.id);
    expect(new Date(stored?.updated_at ?? 0).getTime()).toBeGreaterThan(
      new Date(oldTimestamp).getTime(),
    );
  });

  it("logs token suffixes in log mode", async () => {
    await insertPushToken(supabase, {
      studentId,
      deviceToken: "token-abcdef123456",
      platform: "apns",
    });
    const event = await insertNotificationEvent(supabase, { studentId });

    const infoSpy = vi.spyOn(logger, "info").mockImplementation(() => undefined);

    await handleEvent(supabase, buildConfig("log"), event);

    expect(infoSpy).toHaveBeenCalledTimes(1);
    const payload = infoSpy.mock.calls[0]?.[0] as { tokens: Array<{ tokenSuffix: string }> };
    expect(payload.tokens[0]?.tokenSuffix).toBe("123456");
  });

  it("logs event metadata in log mode", async () => {
    await insertPushToken(supabase, {
      studentId,
      deviceToken: "token-meta-123456",
      platform: "fcm",
    });
    const event = await insertNotificationEvent(supabase, { studentId });

    const infoSpy = vi.spyOn(logger, "info").mockImplementation(() => undefined);

    await handleEvent(supabase, buildConfig("log"), event);

    const payload = infoSpy.mock.calls[0]?.[0] as {
      eventId: string;
      eventType: string;
      studentId: string;
    };
    expect(payload.eventId).toBe(event.id);
    expect(payload.eventType).toBe(event.event_type);
    expect(payload.studentId).toBe(event.student_id);
  });

  it("skips logging in noop mode", async () => {
    const event = await insertNotificationEvent(supabase, { studentId });
    const infoSpy = vi.spyOn(logger, "info").mockImplementation(() => undefined);

    await handleEvent(supabase, buildConfig("noop"), event);

    expect(infoSpy).not.toHaveBeenCalled();
  });

  it("marks events sent after handling", async () => {
    const event = await insertNotificationEvent(supabase, { studentId });

    await handleEvent(supabase, buildConfig("log"), event);

    const stored = await fetchNotificationEvent(supabase, event.id);
    expect(stored?.status).toBe("sent");
  });

  it("uses full token when suffix shorter than six chars", async () => {
    await insertPushToken(supabase, {
      studentId,
      deviceToken: "abc",
      platform: "apns",
    });
    const event = await insertNotificationEvent(supabase, { studentId });

    const infoSpy = vi.spyOn(logger, "info").mockImplementation(() => undefined);

    await handleEvent(supabase, buildConfig("log"), event);

    const payload = infoSpy.mock.calls[0]?.[0] as { tokens: Array<{ tokenSuffix: string }> };
    expect(payload.tokens[0]?.tokenSuffix).toBe("abc");
  });

  it("returns empty token list when none exist", async () => {
    const tokens = await loadPushTokens(supabase, studentId);

    expect(tokens).toEqual([]);
  });
});
