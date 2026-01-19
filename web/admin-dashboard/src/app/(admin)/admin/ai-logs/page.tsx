import { Suspense } from "react";

import AiLogsClient from "./AiLogsClient";

function LoadingState() {
  return (
    <main className="mx-auto max-w-[1280px] px-6 py-12">
      <p className="text-sm text-[color:var(--ink-muted)]" role="status" aria-live="polite">
        Loading agent logs…
      </p>
    </main>
  );
}

export default function AiLogsPage() {
  return (
    <Suspense fallback={<LoadingState />}>
      <AiLogsClient />
    </Suspense>
  );
}
