import { formatPercent } from "../../../lib/format";

export default function DashboardPage() {
  const stats = { weeklyAccuracy: 0.82, totalQuestions: 120, totalTimeMin: 340 };
  return (
    <main className="p-6">
      <h1 className="text-2xl font-semibold">Dashboard</h1>
      <div className="mt-4 space-y-2">
        <div>Accuracy: {formatPercent(stats.weeklyAccuracy)}</div>
        <div>Total Questions: {stats.totalQuestions}</div>
        <div>Total Time (min): {stats.totalTimeMin}</div>
      </div>
    </main>
  );
}
