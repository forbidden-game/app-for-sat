import { formatPercent } from "../../../../lib/format";

export default function SessionPage({ params }: { params: { id: string } }) {
  const summary = {
    date: "Jan 3, 2026",
    student: "Avery Chen",
    accuracy: 0.82,
    duration: "42 min",
    totalQuestions: 20,
  };
  const wrongQuestions = [
    { id: "Q12", topic: "Algebra", note: "Linear equations" },
    { id: "Q18", topic: "Reading", note: "Main idea" },
  ];

  return (
    <main className="mx-auto max-w-5xl px-6 py-8">
      <div className="flex flex-wrap items-center justify-between gap-4">
        <div>
          <p className="text-sm text-zinc-500">Session detail</p>
          <h1 className="text-2xl font-semibold text-zinc-900">{summary.date}</h1>
          <p className="text-sm text-zinc-500">
            {summary.student} • Session {params.id}
          </p>
        </div>
        <div className="rounded-xl border border-zinc-200 bg-white px-4 py-3 text-sm shadow-sm">
          <p className="text-zinc-500">Accuracy</p>
          <p className="text-lg font-semibold text-zinc-900">{formatPercent(summary.accuracy)}</p>
        </div>
      </div>

      <div className="mt-6 grid gap-4 sm:grid-cols-3">
        <div className="rounded-xl border border-zinc-200 bg-white p-4 shadow-sm">
          <p className="text-sm text-zinc-500">Total questions</p>
          <p className="mt-2 text-sm font-medium text-zinc-900">{summary.totalQuestions}</p>
        </div>
        <div className="rounded-xl border border-zinc-200 bg-white p-4 shadow-sm">
          <p className="text-sm text-zinc-500">Session duration</p>
          <p className="mt-2 text-sm font-medium text-zinc-900">{summary.duration}</p>
        </div>
        <div className="rounded-xl border border-zinc-200 bg-white p-4 shadow-sm">
          <p className="text-sm text-zinc-500">Questions missed</p>
          <p className="mt-2 text-sm font-medium text-zinc-900">{wrongQuestions.length}</p>
        </div>
      </div>

      <section className="mt-8 rounded-xl border border-zinc-200 bg-white p-5 shadow-sm">
        <h2 className="text-base font-semibold text-zinc-900">Questions to review</h2>
        <div className="mt-4 space-y-3">
          {wrongQuestions.map((question) => (
            <div
              key={question.id}
              className="rounded-lg border border-zinc-100 bg-zinc-50 p-4 text-sm"
            >
              <p className="font-medium text-zinc-900">{question.topic}</p>
              <p className="text-xs text-zinc-500">
                {question.note} • Question {question.id}
              </p>
            </div>
          ))}
        </div>
      </section>
    </main>
  );
}
