import Link from "next/link";
import { formatPercent } from "../../../lib/format";

type TrendPoint = {
  id: string;
  date: string;
  accuracy: number;
  rankPercentile: number | null;
  attempts: number;
  durationMinutes: number;
};

type TopicStat = {
  id: string;
  name: string;
  accuracy: number;
  attempts: number;
};

const chartWidth = 520;
const chartHeight = 180;
const chartPadding = 16;

function buildLinePoints(values: number[], width: number, height: number) {
  if (values.length === 0) return "";
  const step = values.length === 1 ? 0 : (width - chartPadding * 2) / (values.length - 1);
  return values
    .map((value, index) => {
      const x = chartPadding + step * index;
      const y = chartPadding + (1 - value) * (height - chartPadding * 2);
      return `${x},${y}`;
    })
    .join(" ");
}

export default function DashboardPage() {
  const dashboard = {
    student: {
      name: "Avery Chen",
      grade: "11",
    },
    overview: {
      windowDays: 7,
      practiceMinutes: 312.5,
      accuracy: 0.84,
      errorRate: 0.16,
      rankPercentile: 0.78,
      attempts: 42,
    },
    trend: [
      {
        id: "sess_5",
        date: "Jan 5, 2026",
        accuracy: 0.86,
        rankPercentile: 0.79,
        attempts: 18,
        durationMinutes: 32.0,
      },
      {
        id: "sess_4",
        date: "Jan 4, 2026",
        accuracy: 0.81,
        rankPercentile: 0.74,
        attempts: 20,
        durationMinutes: 36.0,
      },
      {
        id: "sess_3",
        date: "Jan 2, 2026",
        accuracy: 0.79,
        rankPercentile: 0.71,
        attempts: 17,
        durationMinutes: 28.5,
      },
      {
        id: "sess_2",
        date: "Jan 1, 2026",
        accuracy: 0.83,
        rankPercentile: 0.76,
        attempts: 22,
        durationMinutes: 40.0,
      },
      {
        id: "sess_1",
        date: "Dec 30, 2025",
        accuracy: 0.74,
        rankPercentile: 0.66,
        attempts: 16,
        durationMinutes: 24.0,
      },
    ] satisfies TrendPoint[],
    topics: [
      { id: "tag_alg", name: "Algebra", accuracy: 0.72, attempts: 18 },
      { id: "tag_geo", name: "Geometry", accuracy: 0.64, attempts: 14 },
      { id: "tag_read", name: "Reading", accuracy: 0.88, attempts: 22 },
      { id: "tag_grammar", name: "Grammar", accuracy: 0.81, attempts: 16 },
      { id: "tag_prob", name: "Probability", accuracy: 0.58, attempts: 12 },
      { id: "tag_stats", name: "Statistics", accuracy: 0.76, attempts: 15 },
    ] satisfies TopicStat[],
  };

  const accuracySeries = dashboard.trend.map((point) => point.accuracy);
  const rankSeries = dashboard.trend
    .map((point) => point.rankPercentile)
    .filter((value): value is number => value !== null);
  const accuracyPoints = buildLinePoints(
    accuracySeries,
    chartWidth,
    chartHeight,
  );
  const rankPoints = buildLinePoints(rankSeries, chartWidth, chartHeight);

  const sortedTopics = [...dashboard.topics].sort(
    (a, b) => a.accuracy - b.accuracy,
  );
  const weaknesses = sortedTopics.slice(0, 3);
  const strengths = sortedTopics.slice(-3).reverse();

  return (
    <main className="mx-auto max-w-5xl px-6 py-8">
      <div className="flex flex-col gap-2">
        <p className="text-sm text-zinc-500">Parent overview</p>
        <h1 className="text-2xl font-semibold text-zinc-900">
          {dashboard.student.name}
        </h1>
        <p className="text-sm text-zinc-500">Grade {dashboard.student.grade}</p>
      </div>

      <div className="mt-6 grid gap-4 sm:grid-cols-3">
        <div className="rounded-xl border border-zinc-200 bg-white p-4 shadow-sm">
          <p className="text-sm text-zinc-500">Study time (7d)</p>
          <p className="mt-2 text-2xl font-semibold text-zinc-900">
            {dashboard.overview.practiceMinutes.toFixed(1)} min
          </p>
          <p className="mt-1 text-xs text-zinc-400">
            {dashboard.overview.attempts} attempts
          </p>
        </div>
        <div className="rounded-xl border border-zinc-200 bg-white p-4 shadow-sm">
          <p className="text-sm text-zinc-500">Error rate (7d)</p>
          <p className="mt-2 text-2xl font-semibold text-zinc-900">
            {formatPercent(dashboard.overview.errorRate)}
          </p>
          <p className="mt-1 text-xs text-zinc-400">
            Accuracy {formatPercent(dashboard.overview.accuracy)}
          </p>
        </div>
        <div className="rounded-xl border border-zinc-200 bg-white p-4 shadow-sm">
          <p className="text-sm text-zinc-500">Rank percentile (7d)</p>
          <p className="mt-2 text-2xl font-semibold text-zinc-900">
            {formatPercent(dashboard.overview.rankPercentile)}
          </p>
          <p className="mt-1 text-xs text-zinc-400">
            All users · min 20 attempts
          </p>
        </div>
      </div>

      <div className="mt-8 grid gap-6 lg:grid-cols-[2fr,1fr]">
        <section className="rounded-xl border border-zinc-200 bg-white p-5 shadow-sm">
          <div className="flex items-center justify-between">
            <h2 className="text-base font-semibold text-zinc-900">
              Last 5 sessions trend
            </h2>
            <span className="text-xs text-zinc-400">
              Accuracy vs rank percentile
            </span>
          </div>
          <div className="mt-4 rounded-lg border border-zinc-100 bg-zinc-50 p-3">
            <svg
              viewBox={`0 0 ${chartWidth} ${chartHeight}`}
              className="h-40 w-full"
              role="img"
              aria-label="Accuracy and rank percentile trend"
            >
              <polyline
                fill="none"
                stroke="#18181b"
                strokeWidth="3"
                points={accuracyPoints}
              />
              <polyline
                fill="none"
                stroke="#71717a"
                strokeWidth="2"
                strokeDasharray="6 6"
                points={rankPoints}
              />
            </svg>
          </div>
          <div className="mt-3 flex items-center gap-4 text-xs text-zinc-500">
            <div className="flex items-center gap-2">
              <span className="h-2 w-6 rounded-full bg-zinc-900" />
              <span>Accuracy</span>
            </div>
            <div className="flex items-center gap-2">
              <span className="h-0.5 w-6 bg-zinc-400" />
              <span>Rank percentile</span>
            </div>
          </div>
        </section>

        <section className="rounded-xl border border-zinc-200 bg-white p-5 shadow-sm">
          <h2 className="text-base font-semibold text-zinc-900">Strengths & weaknesses</h2>
          <p className="mt-1 text-xs text-zinc-400">Last 7 days · min 10 attempts</p>
          <div className="mt-4">
            <p className="text-xs font-semibold uppercase text-zinc-500">Strengths</p>
            <div className="mt-3 space-y-3">
              {strengths.map((topic) => (
                <div key={topic.id} className="flex items-center justify-between text-sm">
                  <div>
                    <p className="font-medium text-zinc-900">{topic.name}</p>
                    <p className="text-xs text-zinc-500">{topic.attempts} attempts</p>
                  </div>
                  <span className="text-zinc-900">{formatPercent(topic.accuracy)}</span>
                </div>
              ))}
            </div>
          </div>
          <div className="mt-6">
            <p className="text-xs font-semibold uppercase text-zinc-500">Weaknesses</p>
            <div className="mt-3 space-y-3">
              {weaknesses.map((topic) => (
                <div key={topic.id} className="flex items-center justify-between text-sm">
                  <div>
                    <p className="font-medium text-zinc-900">{topic.name}</p>
                    <p className="text-xs text-zinc-500">{topic.attempts} attempts</p>
                  </div>
                  <span className="text-zinc-900">{formatPercent(topic.accuracy)}</span>
                </div>
              ))}
            </div>
          </div>
        </section>
      </div>

      <section className="mt-8 rounded-xl border border-zinc-200 bg-white p-5 shadow-sm">
        <div className="flex items-center justify-between">
          <h2 className="text-base font-semibold text-zinc-900">Recent sessions</h2>
          <Link href="/sessions" className="text-xs font-semibold text-zinc-500 hover:text-zinc-900">
            View all
          </Link>
        </div>
        <div className="mt-4 divide-y divide-zinc-100">
          {dashboard.trend.map((session) => (
            <div key={session.id} className="flex flex-wrap items-center justify-between gap-4 py-3 text-sm">
              <div>
                <p className="font-medium text-zinc-900">{session.date}</p>
                <p className="text-xs text-zinc-500">
                  {session.attempts} attempts · {session.durationMinutes.toFixed(1)} min
                </p>
              </div>
              <div className="flex items-center gap-6 text-right">
                <div>
                  <p className="font-semibold text-zinc-900">
                    {formatPercent(session.accuracy)}
                  </p>
                  <p className="text-xs text-zinc-400">
                    Rank {session.rankPercentile === null ? "N/A" : formatPercent(session.rankPercentile)}
                  </p>
                </div>
                <Link
                  href={`/sessions/${session.id}`}
                  className="text-xs font-semibold text-zinc-500 hover:text-zinc-900"
                >
                  View details
                </Link>
              </div>
            </div>
          ))}
        </div>
      </section>
    </main>
  );
}
