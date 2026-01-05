import Link from "next/link";

const links = [
  { href: "/admin", label: "Overview" },
  { href: "/admin#content", label: "Content" },
  { href: "/admin#users", label: "Users" },
  { href: "/dashboard", label: "Parent dashboard" },
];

export function AdminNav() {
  return (
    <nav className="sticky top-0 z-10 border-b border-zinc-200 bg-white/90 backdrop-blur">
      <div className="mx-auto flex max-w-6xl items-center gap-6 px-6 py-4">
        <div className="flex items-baseline gap-2">
          <span className="text-sm font-semibold text-zinc-900">SAT Prep</span>
          <span className="text-xs text-zinc-400">Admin Console</span>
        </div>
        <div className="flex flex-wrap items-center gap-2 text-sm text-zinc-700">
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
