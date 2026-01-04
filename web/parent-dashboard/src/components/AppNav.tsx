import Link from "next/link";

const links = [
  { href: "/dashboard", label: "Dashboard" },
  { href: "/students", label: "Students" },
  { href: "/sessions", label: "Sessions" },
];

export function AppNav() {
  return (
    <nav className="border-b border-zinc-200 bg-white">
      <div className="mx-auto flex max-w-5xl items-center gap-6 px-6 py-4">
        <span className="text-sm font-semibold text-zinc-900">SAT Prep</span>
        <div className="flex items-center gap-4 text-sm text-zinc-700">
          {links.map((link) => (
            <Link
              key={link.href}
              href={link.href}
              className="hover:text-zinc-900"
            >
              {link.label}
            </Link>
          ))}
        </div>
      </div>
    </nav>
  );
}
