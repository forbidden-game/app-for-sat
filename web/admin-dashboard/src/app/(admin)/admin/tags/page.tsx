import { Suspense } from "react";

import TagsClient from "./TagsClient";

function LoadingState() {
  return (
    <main className="mx-auto max-w-[1440px] px-6 py-12">
      <p className="text-sm text-[color:var(--ink-muted)]" role="status" aria-live="polite">
        Loading tags…
      </p>
    </main>
  );
}

export default function TagsPage() {
  return (
    <Suspense fallback={<LoadingState />}>
      <TagsClient />
    </Suspense>
  );
}
