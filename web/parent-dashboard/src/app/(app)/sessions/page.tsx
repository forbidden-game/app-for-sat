export default function SessionsPage() {
  const sessions = [
    { id: "sess_1", date: "Jan 3, 2026", accuracy: "82%" },
    { id: "sess_2", date: "Jan 1, 2026", accuracy: "76%" },
  ];

  return (
    <main className="p-6">
      <h1 className="text-2xl font-semibold">Sessions</h1>
      <div className="mt-4 space-y-3">
        {sessions.map((session) => (
          <div
            key={session.id}
            className="rounded-lg border border-zinc-200 p-4"
          >
            <div className="text-sm font-medium text-zinc-900">
              {session.date}
            </div>
            <div className="text-sm text-zinc-600">
              Accuracy {session.accuracy}
            </div>
          </div>
        ))}
      </div>
    </main>
  );
}
