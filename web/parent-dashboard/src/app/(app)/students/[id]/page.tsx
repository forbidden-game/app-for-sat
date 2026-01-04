export default function StudentPage({ params }: { params: { id: string } }) {
  return (
    <main className="p-6">
      <h1 className="text-2xl font-semibold">Student {params.id}</h1>
      <p className="mt-2">Session history will appear here.</p>
    </main>
  );
}
