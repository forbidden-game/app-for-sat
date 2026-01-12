export class JobDeferredError extends Error {
  public delayMs: number;

  constructor(message: string, delayMs: number) {
    super(message);
    this.name = "JobDeferredError";
    this.delayMs = delayMs;
  }
}
