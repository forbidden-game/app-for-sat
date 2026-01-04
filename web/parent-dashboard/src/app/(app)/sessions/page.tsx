import Link from "next/link";
import { formatPercent } from "../../../lib/format";

export default function SessionsPage() {
  const sessions = [
    {
      id: "sess_1",
      date: "Jan 3, 2026",
      student: "Avery Chen",
      accuracy: 0.82,
      questions: 20,
    },
    {
      id: "sess_2",
      date: "Jan 1, 2026",
      student: "Jordan Patel",
      accuracy: 0.76,
      questions: 18,
    },
  ];

  return (
    <main className="mx-auto max-w-5xl px-6 py-8">
      <div>
        <p className="text-sm text-zinc-500">Practice history</p>
        <h1 className="text-2xl font-semibold text-zinc-900">Sessions</h1>
      </div>
      <div className="mt-6 space-y-4">
        {sessions.map((session) => (
          <Link
            key={session.id}
            href={`/sessions/${session.id}`}
            className="block rounded-xl border border-zinc-200 bg-white p-5 shadow-sm transition hover:-translate-y-0.5 hover:shadow-md"
          >
            <div className="flex flex-wrap items-center justify-between gap-3">
              <div>
                <p className="text-sm font-semibold text-zinc-900">
                  {session.date}
                </p>
                <p className="text-xs text-zinc-500">{session.student}</p>
              </div>
              <div className="text-right text-xs text-zinc-500">
                <p className="text-sm font-semibold text-zinc-900">
                  {formatPercent(session.accuracy)}
                </p>
                <p>{session.questions} questions</p>
              </div>
            </div>
          </Link>
        ))}
      </div>
    </main>
  );
}
