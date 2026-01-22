import apn from "apn";

import type { SenderConfig } from "./config.js";

export type ApnsProvider = apn.Provider;

export function createApnsProvider(config: SenderConfig): ApnsProvider {
  if (!config.apnsTeamId || !config.apnsKeyId || !config.apnsPrivateKey || !config.apnsBundleId) {
    throw new Error("missing_apns_config");
  }

  const key = normalizePrivateKey(config.apnsPrivateKey);

  return new apn.Provider({
    token: {
      key,
      keyId: config.apnsKeyId,
      teamId: config.apnsTeamId,
    },
    production: config.apnsEnv === "production",
  });
}

export function buildFriendMessageNotification(params: {
  bundleId: string;
  preview: string;
  threadId: string;
  senderId: string;
}): apn.Notification {
  const notification = new apn.Notification();
  notification.topic = params.bundleId;
  notification.alert = {
    title: "好友消息",
    body: params.preview || "你收到一条新消息",
  };
  notification.sound = "default";
  notification.payload = {
    thread_id: params.threadId,
    sender_id: params.senderId,
  };
  return notification;
}

function normalizePrivateKey(value: string): string | Buffer {
  const trimmed = value.trim();
  if (trimmed.startsWith("-----BEGIN")) {
    return trimmed.replace(/\\n/g, "\n");
  }

  try {
    return Buffer.from(trimmed, "base64");
  } catch {
    return trimmed;
  }
}
