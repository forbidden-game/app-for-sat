import pino, { type Logger } from "pino";

import { getLogContext } from "./observability.js";

type LoggerOptions = {
  service?: string;
};

export function createLogger(options: LoggerOptions = {}): Logger {
  const base = options.service ? { service: options.service } : undefined;
  return pino({
    level: process.env["LOG_LEVEL"] ?? "info",
    base,
    mixin: () => getLogContext(),
  });
}
