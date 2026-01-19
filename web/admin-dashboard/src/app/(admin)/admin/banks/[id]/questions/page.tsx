import { Suspense } from "react";

import BankQuestionsClient from "./BankQuestionsClient";

function LoadingState() {
  return (
    <main className="mx-auto max-w-[1280px] px-6 py-12">
      <p className="text-sm text-[color:var(--ink-muted)]" role="status" aria-live="polite">
        Loading…
      </p>
    </main>
  );
}

export default function BankQuestionsPage() {
  return (
    <Suspense fallback={<LoadingState />}>
      <BankQuestionsClient />
    </Suspense>
  );
}
