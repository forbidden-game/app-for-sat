import { logger } from "../../logger.js";
import type { JobHandlerContext } from "./types.js";

export async function handleUnimplementedJob(ctx: JobHandlerContext): Promise<void> {
  logger.info({ kind: ctx.job.kind }, "job kind not implemented, skipping");
}
