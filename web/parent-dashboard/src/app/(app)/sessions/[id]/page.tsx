export default function SessionPage({ params }: { params: { id: string } }) {
  return (
    <main className="p-6">
      <h1 className="text-2xl font-semibold">Session {params.id}</h1>
      <p className="mt-2">Wrong questions list will appear here.</p>
    </main>
  );
}
