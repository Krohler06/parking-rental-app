import Link from "next/link";

const links = [
  { href: "/admin/dashboard", label: "Tableau de bord" },
  { href: "/admin/spots", label: "Places" },
  { href: "/admin/customers", label: "Clients" },
  { href: "/admin/vehicles", label: "Véhicules" },
  { href: "/admin/rentals", label: "Locations" },
  { href: "/admin/services", label: "Services" },
  { href: "/admin/pricing", label: "Tarifs" },
  { href: "/admin/messages", label: "Messages" }
];

export function AdminShell({
  title,
  subtitle,
  children
}: {
  title: string;
  subtitle?: string;
  children: React.ReactNode;
}) {
  return (
    <main className="min-h-screen bg-slate-100">
      <div className="grid min-h-screen md:grid-cols-[280px_1fr]">
        <aside className="bg-slate-950 p-6 text-white">
          <div>
            <p className="text-xs font-semibold uppercase tracking-[0.3em] text-yellow-300">
              Gambetta Park
            </p>
            <h1 className="mt-3 text-2xl font-black">Administration</h1>
            <p className="mt-2 text-sm text-slate-400">
              Gestion des places, clients, véhicules et locations.
            </p>
          </div>

          <nav className="mt-10 space-y-2">
            {links.map((link) => (
              <Link
                key={link.href}
                href={link.href}
                className="block rounded-2xl px-4 py-3 text-sm font-semibold text-slate-300 transition hover:bg-white/10 hover:text-white"
              >
                {link.label}
              </Link>
            ))}
          </nav>

          <form action="/api/auth/logout" method="post" className="mt-10">
            <button className="w-full rounded-2xl bg-yellow-300 px-4 py-3 text-sm font-black text-slate-950 transition hover:bg-yellow-200">
              Déconnexion
            </button>
          </form>

          <a
            href="/"
            className="mt-4 block text-center text-xs font-semibold text-slate-500 hover:text-slate-300"
          >
            Retour au site public
          </a>
        </aside>

        <section className="p-6 md:p-10">
          <div className="mb-8">
            <p className="text-sm font-bold uppercase tracking-[0.2em] text-yellow-600">
              Back-office
            </p>
            <h2 className="mt-2 text-4xl font-black tracking-tight text-slate-950">
              {title}
            </h2>
            {subtitle && (
              <p className="mt-3 max-w-3xl text-slate-600">{subtitle}</p>
            )}
          </div>

          {children}
        </section>
      </div>
    </main>
  );
}
