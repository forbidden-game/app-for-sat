import Link from "next/link";

const links = [
  { href: "/dashboard", label: "Dashboard" },
  { href: "/students", label: "Students" },
  { href: "/sessions", label: "Sessions" },
];

export function AppNav() {
  return (
    <nav className="sticky top-0 z-10 border-b border-zinc-200 bg-white/90 backdrop-blur">
      <div className="mx-auto flex max-w-5xl items-center gap-6 px-6 py-4">
        <div className="flex items-baseline gap-2">
          <span className="text-sm font-semibold text-zinc-900">SAT Prep</span>
          <span className="text-xs text-zinc-400">Parent Dashboard</span>
        </div>
        <div className="flex items-center gap-4 text-sm text-zinc-700">
          {links.map((link) => (
            <Link
              key={link.href}
              href={link.href}
              className="rounded-full px-3 py-1 transition hover:bg-zinc-100 hover:text-zinc-900"
            >
              {link.label}
            </Link>
          ))}
        </div>
      </div>
    </nav>
  );
}
