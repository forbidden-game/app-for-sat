import { Suspense } from "react";

import QuestionsClient from "./QuestionsClient";

function LoadingState() {
  return (
    <main className="mx-auto max-w-[1280px] px-6 py-12">
      <p className="text-sm text-[color:var(--ink-muted)]" role="status" aria-live="polite">
        Loading questions…
      </p>
    </main>
  );
}

export default function QuestionsPage() {
  return (
    <Suspense fallback={<LoadingState />}>
      <QuestionsClient />
    </Suspense>
  );
}
