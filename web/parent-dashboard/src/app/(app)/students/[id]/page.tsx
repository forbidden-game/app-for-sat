import { formatPercent } from "../../../../lib/format";

export default function StudentPage({ params }: { params: { id: string } }) {
  const summary = {
    name: "Avery Chen",
    grade: "11",
    weeklyAccuracy: 0.84,
    totalSessions: 12,
  };
  const recentSessions = [
    { id: "sess_1", date: "Jan 3, 2026", accuracy: 0.82 },
    { id: "sess_2", date: "Jan 1, 2026", accuracy: 0.76 },
  ];

  return (
    <main className="mx-auto max-w-5xl px-6 py-8">
      <div className="flex flex-wrap items-center justify-between gap-4">
        <div>
          <p className="text-sm text-zinc-500">Student profile</p>
          <h1 className="text-2xl font-semibold text-zinc-900">
            {summary.name}
          </h1>
          <p className="text-sm text-zinc-500">Grade {summary.grade}</p>
        </div>
        <div className="rounded-xl border border-zinc-200 bg-white px-4 py-3 text-sm shadow-sm">
          <p className="text-zinc-500">Weekly accuracy</p>
          <p className="text-lg font-semibold text-zinc-900">
            {formatPercent(summary.weeklyAccuracy)}
          </p>
        </div>
      </div>

      <div className="mt-6 grid gap-4 sm:grid-cols-3">
        <div className="rounded-xl border border-zinc-200 bg-white p-4 shadow-sm">
          <p className="text-sm text-zinc-500">Student ID</p>
          <p className="mt-2 text-sm font-medium text-zinc-900">{params.id}</p>
        </div>
        <div className="rounded-xl border border-zinc-200 bg-white p-4 shadow-sm">
          <p className="text-sm text-zinc-500">Total sessions</p>
          <p className="mt-2 text-sm font-medium text-zinc-900">
            {summary.totalSessions}
          </p>
        </div>
        <div className="rounded-xl border border-zinc-200 bg-white p-4 shadow-sm">
          <p className="text-sm text-zinc-500">Last activity</p>
          <p className="mt-2 text-sm font-medium text-zinc-900">Jan 3, 2026</p>
        </div>
      </div>

      <section className="mt-8 rounded-xl border border-zinc-200 bg-white p-5 shadow-sm">
        <h2 className="text-base font-semibold text-zinc-900">
          Recent sessions
        </h2>
        <div className="mt-4 divide-y divide-zinc-100">
          {recentSessions.map((session) => (
            <div key={session.id} className="flex items-center py-3 text-sm">
              <div className="flex-1">
                <p className="font-medium text-zinc-900">{session.date}</p>
                <p className="text-xs text-zinc-500">Session {session.id}</p>
              </div>
              <div className="text-right">
                <p className="font-semibold text-zinc-900">
                  {formatPercent(session.accuracy)}
                </p>
                <p className="text-xs text-zinc-400">Accuracy</p>
              </div>
            </div>
          ))}
        </div>
      </section>
    </main>
  );
}
