import { formatPercent } from "../../../lib/format";

export default function DashboardPage() {
  const stats = [
    { label: "Weekly accuracy", value: formatPercent(0.82), detail: "Last 7 days" },
    { label: "Questions answered", value: "120", detail: "All time" },
    { label: "Total time", value: "340 min", detail: "All time" },
  ];
  const topicTrends = [
    { label: "Algebra", value: 0.78 },
    { label: "Geometry", value: 0.71 },
    { label: "Reading", value: 0.86 },
  ];
  const recentSessions = [
    { id: "sess_1", date: "Jan 3, 2026", accuracy: 0.82, questions: 20 },
    { id: "sess_2", date: "Jan 1, 2026", accuracy: 0.76, questions: 18 },
  ];
  return (
    <main className="mx-auto max-w-5xl px-6 py-8">
      <div className="flex flex-col gap-2">
        <p className="text-sm text-zinc-500">Welcome back</p>
        <h1 className="text-2xl font-semibold text-zinc-900">Dashboard</h1>
      </div>

      <div className="mt-6 grid gap-4 sm:grid-cols-3">
        {stats.map((stat) => (
          <div
            key={stat.label}
            className="rounded-xl border border-zinc-200 bg-white p-4 shadow-sm"
          >
            <p className="text-sm text-zinc-500">{stat.label}</p>
            <p className="mt-2 text-2xl font-semibold text-zinc-900">
              {stat.value}
            </p>
            <p className="mt-1 text-xs text-zinc-400">{stat.detail}</p>
          </div>
        ))}
      </div>

      <div className="mt-8 grid gap-6 lg:grid-cols-[2fr,1fr]">
        <section className="rounded-xl border border-zinc-200 bg-white p-5 shadow-sm">
          <div className="flex items-center justify-between">
            <h2 className="text-base font-semibold text-zinc-900">
              Weekly trend
            </h2>
            <span className="text-xs text-zinc-400">Placeholder</span>
          </div>
          <div className="mt-4 h-36 rounded-lg border border-dashed border-zinc-200 bg-zinc-50" />
          <p className="mt-3 text-sm text-zinc-500">
            Chart placeholder for accuracy and time spent.
          </p>
        </section>

        <section className="rounded-xl border border-zinc-200 bg-white p-5 shadow-sm">
          <h2 className="text-base font-semibold text-zinc-900">
            Topic momentum
          </h2>
          <div className="mt-4 space-y-4">
            {topicTrends.map((topic) => (
              <div key={topic.label}>
                <div className="flex items-center justify-between text-sm">
                  <span className="text-zinc-600">{topic.label}</span>
                  <span className="text-zinc-900">
                    {formatPercent(topic.value)}
                  </span>
                </div>
                <div className="mt-2 h-2 rounded-full bg-zinc-100">
                  <div
                    className="h-2 rounded-full bg-zinc-900"
                    style={{ width: `${Math.round(topic.value * 100)}%` }}
                  />
                </div>
              </div>
            ))}
          </div>
        </section>
      </div>

      <section className="mt-8 rounded-xl border border-zinc-200 bg-white p-5 shadow-sm">
        <div className="flex items-center justify-between">
          <h2 className="text-base font-semibold text-zinc-900">
            Recent sessions
          </h2>
          <span className="text-xs text-zinc-400">Updated weekly</span>
        </div>
        <div className="mt-4 divide-y divide-zinc-100">
          {recentSessions.map((session) => (
            <div key={session.id} className="flex items-center py-3 text-sm">
              <div className="flex-1">
                <p className="font-medium text-zinc-900">{session.date}</p>
                <p className="text-xs text-zinc-500">
                  {session.questions} questions answered
                </p>
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
