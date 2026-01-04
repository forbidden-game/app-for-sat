import Link from "next/link";
import { formatPercent } from "../../../lib/format";

export default function StudentsPage() {
  const students = [
    { id: "stu_1", name: "Avery Chen", grade: "11", accuracy: 0.84 },
    { id: "stu_2", name: "Jordan Patel", grade: "10", accuracy: 0.76 },
  ];

  return (
    <main className="mx-auto max-w-5xl px-6 py-8">
      <div className="flex items-center justify-between">
        <div>
          <p className="text-sm text-zinc-500">Student overview</p>
          <h1 className="text-2xl font-semibold text-zinc-900">Students</h1>
        </div>
      </div>
      <div className="mt-6 grid gap-4 sm:grid-cols-2">
        {students.map((student) => (
          <Link
            key={student.id}
            href={`/students/${student.id}`}
            className="rounded-xl border border-zinc-200 bg-white p-5 shadow-sm transition hover:-translate-y-0.5 hover:shadow-md"
          >
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm font-semibold text-zinc-900">
                  {student.name}
                </p>
                <p className="text-xs text-zinc-500">Grade {student.grade}</p>
              </div>
              <span className="rounded-full bg-zinc-900 px-3 py-1 text-xs font-semibold text-white">
                {formatPercent(student.accuracy)}
              </span>
            </div>
            <div className="mt-4 text-xs text-zinc-500">
              Last 7 days accuracy
            </div>
          </Link>
        ))}
      </div>
    </main>
  );
}
