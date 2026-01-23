import { AsyncLocalStorage } from "node:async_hooks";
import * as Sentry from "@sentry/node";

type RequestContext = {
  traceId?: string;
  requestId?: string;
  jobId?: string;
  eventId?: string;
  workerId?: string;
};

const requestContextStorage = new AsyncLocalStorage<RequestContext>();

export function runWithRequestContext<T>(context: RequestContext, fn: () => T): T {
  const parent = requestContextStorage.getStore();
  const merged = parent ? { ...parent, ...context } : context;
  return requestContextStorage.run(merged, fn);
}

export function getRequestContext(): RequestContext | undefined {
  return requestContextStorage.getStore();
}

export function getLogContext(): Record<string, string> {
  const ctx = requestContextStorage.getStore();
  if (!ctx) return {};

  const logContext: Record<string, string> = {};
  if (ctx.traceId) logContext.trace_id = ctx.traceId;
  if (ctx.requestId) logContext.request_id = ctx.requestId;
  if (ctx.jobId) logContext.job_id = ctx.jobId;
  if (ctx.eventId) logContext.event_id = ctx.eventId;
  if (ctx.workerId) logContext.worker_id = ctx.workerId;
  return logContext;
}

let errorReportingEnabled = false;

type ErrorReportingOptions = {
  service: string;
  environment?: string;
  release?: string;
};

export function initErrorReporting(options: ErrorReportingOptions): void {
  const dsn = process.env["SENTRY_DSN"];
  if (!dsn) return;

  Sentry.init({
    dsn,
    environment:
      options.environment ??
      process.env["SENTRY_ENVIRONMENT"] ??
      process.env["NODE_ENV"] ??
      "production",
    release: options.release ?? process.env["APP_RELEASE"],
    tracesSampleRate: Number(process.env["SENTRY_TRACES_SAMPLE_RATE"] ?? "0"),
  });

  Sentry.setTag("service", options.service);
  errorReportingEnabled = true;
}

export function captureError(err: unknown, context?: Record<string, unknown>): void {
  if (!errorReportingEnabled) return;

  Sentry.withScope((scope) => {
    const ctx = requestContextStorage.getStore();
    if (ctx?.traceId) scope.setTag("trace_id", ctx.traceId);
    if (ctx?.requestId) scope.setTag("request_id", ctx.requestId);
    if (ctx?.jobId) scope.setTag("job_id", ctx.jobId);
    if (ctx?.eventId) scope.setTag("event_id", ctx.eventId);
    if (ctx?.workerId) scope.setTag("worker_id", ctx.workerId);
    if (context) scope.setExtras(context);
    Sentry.captureException(err);
  });
}
