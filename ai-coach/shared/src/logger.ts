import pino, { type Logger } from "pino";

import { getLogContext } from "./observability.js";

type LoggerOptions = {
  service?: string;
};

export function createLogger(options: LoggerOptions = {}): Logger {
  const base = options.service ? { service: options.service } : undefined;
  const redact =
    process.env["LOG_REDACT"] === "false"
      ? undefined
      : {
          paths: [
            "password",
            "pass",
            "token",
            "access_token",
            "refresh_token",
            "api_key",
            "apikey",
            "authorization",
            "cookie",
            "set-cookie",
            "device_token",
            "deviceToken",
            "email",
            "phone",
            "phone_number",
            "ssn",
            "student_id",
            "studentId",
            "user_id",
            "userId",
            "*.password",
            "*.pass",
            "*.token",
            "*.access_token",
            "*.refresh_token",
            "*.api_key",
            "*.apikey",
            "*.authorization",
            "*.cookie",
            "*.set-cookie",
            "*.device_token",
            "*.deviceToken",
            "*.email",
            "*.phone",
            "*.phone_number",
            "*.ssn",
            "*.student_id",
            "*.studentId",
            "*.user_id",
            "*.userId",
          ],
          censor: "[redacted]",
        };

  return pino({
    level: process.env["LOG_LEVEL"] ?? "info",
    base,
    redact,
    mixin: () => getLogContext(),
  });
}
