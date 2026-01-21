import type { AiJobKind } from "../../types.js";
import type { JobHandlerContext } from "./types.js";
import { handleAttemptInsightJob } from "./attemptInsightHandler.js";
import { handleCoachReplyJob } from "./coachReplyHandler.js";
import { handleProgressReportJob } from "./progressReportHandler.js";
import { handleSnapshotRefreshJob } from "./snapshotRefreshHandler.js";
import { handleUnimplementedJob } from "./unimplementedHandler.js";

export type JobHandler = (ctx: JobHandlerContext) => Promise<void>;

export const jobHandlers: Record<AiJobKind, JobHandler> = {
  attempt_insight: handleAttemptInsightJob,
  coach_reply: handleCoachReplyJob,
  progress_report: handleProgressReportJob,
  snapshot_refresh: handleSnapshotRefreshJob,
  thread_summary: handleUnimplementedJob,
  procedure_merge: handleUnimplementedJob,
};
