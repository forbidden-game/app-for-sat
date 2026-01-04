export default function StudentsPage() {
  const students = [
    { id: "stu_1", name: "Avery Chen", grade: "11" },
    { id: "stu_2", name: "Jordan Patel", grade: "10" },
  ];

  return (
    <main className="p-6">
      <h1 className="text-2xl font-semibold">Students</h1>
      <div className="mt-4 space-y-3">
        {students.map((student) => (
          <div
            key={student.id}
            className="rounded-lg border border-zinc-200 p-4"
          >
            <div className="text-sm font-medium text-zinc-900">
              {student.name}
            </div>
            <div className="text-sm text-zinc-600">
              Grade {student.grade}
            </div>
          </div>
        ))}
      </div>
    </main>
  );
}
