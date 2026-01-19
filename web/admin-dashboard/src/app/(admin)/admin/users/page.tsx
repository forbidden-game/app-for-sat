import { Suspense } from "react";

import UsersClient from "./UsersClient";

function LoadingState() {
  return (
    <main className="mx-auto max-w-[1280px] px-6 py-12">
      <p className="text-sm text-[color:var(--ink-muted)]" role="status" aria-live="polite">
        Loading users…
      </p>
    </main>
  );
}

export default function UsersPage() {
  return (
    <Suspense fallback={<LoadingState />}>
      <UsersClient />
    </Suspense>
  );
}
