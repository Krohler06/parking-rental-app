export default async function AdminLoginPage({
  searchParams
}: {
  searchParams?: Promise<{ error?: string }>;
}) {
  const params = searchParams ? await searchParams : {};

  return (
    <main className="flex min-h-screen items-center justify-center bg-[radial-gradient(circle_at_top,#1e293b,#020617_55%)] px-6">
      <section className="w-full max-w-md overflow-hidden rounded-[2rem] border border-white/10 bg-white shadow-2xl">
        <div className="bg-slate-950 px-8 py-8 text-white">
          <p className="text-xs font-bold uppercase tracking-[0.35em] text-yellow-300">
            Gambetta Park
          </p>
          <h1 className="mt-4 text-3xl font-black">Connexion admin</h1>
          <p className="mt-3 text-sm leading-6 text-slate-300">
            Accès réservé à la gestion des places, clients, véhicules et locations.
          </p>
        </div>

        <div className="p-8">
          {params.error && (
            <p className="mb-5 rounded-2xl bg-red-50 px-4 py-3 text-sm font-semibold text-red-700">
              Identifiants incorrects. Vérifie ADMIN_EMAIL et ADMIN_PASSWORD dans ton fichier .env.
            </p>
          )}

          <form action="/api/auth/login" method="post" className="space-y-5">
            <div>
              <label className="text-sm font-bold text-slate-800">Email</label>
              <input
                name="email"
                type="email"
                required
                className="mt-2 w-full rounded-2xl border border-slate-300 px-4 py-3 outline-none transition focus:border-yellow-500 focus:ring-4 focus:ring-yellow-100"
                placeholder="admin@example.local"
              />
            </div>

            <div>
              <label className="text-sm font-bold text-slate-800">Mot de passe</label>
              <input
                name="password"
                type="password"
                required
                className="mt-2 w-full rounded-2xl border border-slate-300 px-4 py-3 outline-none transition focus:border-yellow-500 focus:ring-4 focus:ring-yellow-100"
                placeholder="Mot de passe"
              />
            </div>

            <button className="w-full rounded-2xl bg-slate-950 px-4 py-3 font-black text-white transition hover:bg-slate-800">
              Se connecter
            </button>
          </form>

          <a
            href="/"
            className="mt-6 block text-center text-sm font-semibold text-slate-500 hover:text-slate-900"
          >
            Retour au site public
          </a>
        </div>
      </section>
    </main>
  );
}
