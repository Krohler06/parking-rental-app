export const dynamic = "force-dynamic";
export const revalidate = 0;

import { prisma } from "@/lib/prisma";

function euro(value: number | string) {
  return new Intl.NumberFormat("fr-FR", {
    style: "currency",
    currency: "EUR"
  }).format(Number(value));
}

function vehicleLabel(type: string) {
  const labels: Record<string, string> = {
    CAR: "Voiture",
    MOTORCYCLE: "Deux-roues",
    OTHER: "Autre"
  };

  return labels[type] || type;
}

export default async function HomePage({
  searchParams
}: {
  searchParams?: Promise<{ contact?: string }>;
}) {
  const params = searchParams ? await searchParams : {};

  const [services, pricing, totalSpots, availableSpots] = await Promise.all([
    prisma.service.findMany({
      where: { isActive: true },
      orderBy: { sortOrder: "asc" }
    }),
    prisma.pricing.findMany({
      where: { isActive: true },
      orderBy: { sortOrder: "asc" }
    }),
    prisma.parkingSpot.count(),
    prisma.parkingSpot.count({ where: { status: "AVAILABLE" } })
  ]);

  return (
    <main className="min-h-screen bg-slate-950 text-white">
      <header className="sticky top-0 z-50 border-b border-white/10 bg-slate-950/90 backdrop-blur">
        <div className="mx-auto flex max-w-7xl items-center justify-between px-6 py-5">
          <a href="/" className="flex items-center gap-3">
            <span className="flex h-11 w-11 items-center justify-center rounded-2xl bg-yellow-300 font-black text-slate-950">
              P
            </span>
            <span>
              <span className="block text-lg font-black leading-none">Gambetta Park</span>
              <span className="block text-xs font-semibold text-slate-400">
                Parking mensuel sécurisé
              </span>
            </span>
          </a>

          <nav className="hidden items-center gap-7 text-sm font-bold text-slate-300 md:flex">
            <a href="#avantages" className="hover:text-yellow-300">Avantages</a>
            <a href="#tarifs" className="hover:text-yellow-300">Tarifs</a>
            <a href="#contact" className="hover:text-yellow-300">Contact</a>
          </nav>

          <a
            href="#contact"
            className="rounded-full bg-yellow-300 px-5 py-3 text-sm font-black text-slate-950 transition hover:bg-yellow-200"
          >
            Vérifier une disponibilité
          </a>
        </div>
      </header>

      <section className="relative overflow-hidden">
        <div className="absolute inset-0 bg-[radial-gradient(circle_at_20%_20%,rgba(250,204,21,0.24),transparent_30%),radial-gradient(circle_at_80%_10%,rgba(37,99,235,0.18),transparent_28%)]" />
        <div className="absolute inset-x-0 bottom-0 h-32 bg-gradient-to-t from-slate-950 to-transparent" />

        <div className="relative mx-auto grid min-h-[82vh] max-w-7xl items-center gap-12 px-6 py-20 lg:grid-cols-[1.1fr_0.9fr]">
          <div>
            <p className="mb-5 inline-flex rounded-full border border-yellow-300/30 bg-yellow-300/10 px-4 py-2 text-sm font-bold text-yellow-200">
              Location mensuelle · Voiture · Moto · Scooter
            </p>

            <h1 className="max-w-5xl text-5xl font-black tracking-tight md:text-7xl">
              Une place claire, sécurisée, et réservée pour votre véhicule.
            </h1>

            <p className="mt-7 max-w-2xl text-lg leading-8 text-slate-300">
              Gambetta Park propose des emplacements mensuels dans un parking fermé,
              organisé sur 3 étages, avec des places numérotées et une gestion simple
              pour voitures et deux-roues.
            </p>

            <div className="mt-9 flex flex-wrap gap-4">
              <a
                href="#contact"
                className="rounded-2xl bg-yellow-300 px-7 py-4 font-black text-slate-950 transition hover:bg-yellow-200"
              >
                Demander une place
              </a>

              <a
                href="#tarifs"
                className="rounded-2xl border border-white/15 px-7 py-4 font-black text-white transition hover:bg-white/10"
              >
                Voir les tarifs
              </a>
            </div>

            <div className="mt-10 grid max-w-xl grid-cols-3 gap-4">
              <div className="rounded-2xl border border-white/10 bg-white/5 p-4">
                <p className="text-3xl font-black text-yellow-300">3</p>
                <p className="mt-1 text-xs font-semibold text-slate-400">étages</p>
              </div>

              <div className="rounded-2xl border border-white/10 bg-white/5 p-4">
                <p className="text-3xl font-black text-yellow-300">{totalSpots}</p>
                <p className="mt-1 text-xs font-semibold text-slate-400">places</p>
              </div>

              <div className="rounded-2xl border border-white/10 bg-white/5 p-4">
                <p className="text-3xl font-black text-yellow-300">{availableSpots}</p>
                <p className="mt-1 text-xs font-semibold text-slate-400">disponibles</p>
              </div>
            </div>
          </div>

          <div className="relative">
            <div className="rounded-[2rem] border border-white/10 bg-white/10 p-5 shadow-2xl backdrop-blur">
              <div className="rounded-[1.5rem] bg-slate-900 p-6">
                <div className="flex items-center justify-between">
                  <p className="text-sm font-bold uppercase tracking-[0.25em] text-yellow-300">
                    Plan parking
                  </p>
                  <span className="rounded-full bg-emerald-400/15 px-3 py-1 text-xs font-bold text-emerald-300">
                    Accès fermé
                  </span>
                </div>

                <div className="mt-8 space-y-5">
                  {[1, 2, 3].map((floor) => (
                    <div key={floor} className="rounded-2xl bg-white p-4 text-slate-950">
                      <div className="flex items-center justify-between">
                        <p className="font-black">Étage {floor}</p>
                        <p className="text-sm font-bold text-slate-500">40 places</p>
                      </div>

                      <div className="mt-4 grid grid-cols-10 gap-1">
                        {Array.from({ length: 40 }).map((_, index) => (
                          <span
                            key={index}
                            className={`h-4 rounded ${
                              index % 7 === 0
                                ? "bg-red-400"
                                : index % 5 === 0
                                  ? "bg-amber-300"
                                  : "bg-emerald-400"
                            }`}
                          />
                        ))}
                      </div>
                    </div>
                  ))}
                </div>

                <div className="mt-6 flex flex-wrap gap-3 text-xs font-bold text-slate-300">
                  <span className="flex items-center gap-2">
                    <i className="h-3 w-3 rounded bg-emerald-400" /> Disponible
                  </span>
                  <span className="flex items-center gap-2">
                    <i className="h-3 w-3 rounded bg-amber-300" /> Réservée
                  </span>
                  <span className="flex items-center gap-2">
                    <i className="h-3 w-3 rounded bg-red-400" /> Occupée
                  </span>
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>

      <section id="avantages" className="bg-white py-24 text-slate-950">
        <div className="mx-auto max-w-7xl px-6">
          <div className="max-w-3xl">
            <p className="text-sm font-black uppercase tracking-[0.25em] text-yellow-600">
              Pourquoi Gambetta Park ?
            </p>
            <h2 className="mt-4 text-4xl font-black tracking-tight md:text-5xl">
              Un stationnement mensuel simple, lisible et sécurisé.
            </h2>
            <p className="mt-5 text-lg leading-8 text-slate-600">
              Fini les recherches de place, les stationnements improvisés ou les
              contraintes du quotidien. Vous disposez d’un emplacement identifié,
              dans un parking organisé et suivi.
            </p>
          </div>

          <div className="mt-12 grid gap-6 md:grid-cols-3">
            {(services.length > 0
              ? services
              : [
                  {
                    id: "1",
                    title: "Parking fermé",
                    description: "Un espace fermé pour stationner votre véhicule avec plus de sérénité."
                  },
                  {
                    id: "2",
                    title: "Places numérotées",
                    description: "Chaque emplacement est identifié par étage et numéro de place."
                  },
                  {
                    id: "3",
                    title: "Voiture ou deux-roues",
                    description: "Des solutions adaptées aux véhicules particuliers, motos et scooters."
                  }
                ]
            ).map((service) => (
              <article
                key={service.id}
                className="rounded-[1.5rem] border border-slate-200 bg-slate-50 p-7"
              >
                <div className="mb-6 flex h-12 w-12 items-center justify-center rounded-2xl bg-yellow-300 font-black">
                  ✓
                </div>
                <h3 className="text-2xl font-black">{service.title}</h3>
                <p className="mt-4 leading-7 text-slate-600">{service.description}</p>
              </article>
            ))}
          </div>
        </div>
      </section>

      <section id="tarifs" className="bg-slate-100 py-24 text-slate-950">
        <div className="mx-auto max-w-7xl px-6">
          <div className="flex flex-col justify-between gap-6 md:flex-row md:items-end">
            <div>
              <p className="text-sm font-black uppercase tracking-[0.25em] text-yellow-600">
                Tarifs
              </p>
              <h2 className="mt-4 text-4xl font-black tracking-tight md:text-5xl">
                Des formules mensuelles sans complication.
              </h2>
            </div>
            <p className="max-w-xl text-slate-600">
              Les tarifs peuvent évoluer selon la disponibilité, le type de véhicule
              et la durée souhaitée. Contactez-nous pour confirmer une place.
            </p>
          </div>

          <div className="mt-12 grid gap-6 md:grid-cols-2">
            {(pricing.length > 0
              ? pricing
              : [
                  {
                    id: "fallback-car",
                    title: "Place voiture",
                    description: "Location mensuelle pour véhicule particulier.",
                    vehicleType: "CAR",
                    priceMonthly: "120"
                  },
                  {
                    id: "fallback-moto",
                    title: "Place deux-roues",
                    description: "Location mensuelle pour moto ou scooter.",
                    vehicleType: "MOTORCYCLE",
                    priceMonthly: "60"
                  }
                ]
            ).map((price) => (
              <article
                key={price.id}
                className="rounded-[2rem] bg-white p-8 shadow-sm ring-1 ring-slate-200"
              >
                <p className="text-sm font-black uppercase tracking-[0.2em] text-yellow-600">
                  {vehicleLabel(String(price.vehicleType))}
                </p>
                <h3 className="mt-4 text-3xl font-black">{price.title}</h3>
                <p className="mt-4 min-h-14 leading-7 text-slate-600">
                  {price.description}
                </p>
                <p className="mt-8 text-5xl font-black">
                  {euro(price.priceMonthly.toString())}
                  <span className="text-base font-bold text-slate-500"> / mois</span>
                </p>
              </article>
            ))}
          </div>
        </div>
      </section>

      <section id="contact" className="bg-white py-24 text-slate-950">
        <div className="mx-auto grid max-w-7xl gap-12 px-6 lg:grid-cols-[0.9fr_1.1fr]">
          <div>
            <p className="text-sm font-black uppercase tracking-[0.25em] text-yellow-600">
              Contact
            </p>
            <h2 className="mt-4 text-4xl font-black tracking-tight md:text-5xl">
              Une place vous intéresse ?
            </h2>
            <p className="mt-6 text-lg leading-8 text-slate-600">
              Envoyez votre demande avec le type de véhicule, la durée souhaitée
              et vos coordonnées. Nous vous recontacterons pour confirmer la
              disponibilité et les modalités.
            </p>

            <div className="mt-10 space-y-4">
              <div className="rounded-2xl bg-slate-100 p-5">
                <p className="font-black">Idéal pour</p>
                <p className="mt-1 text-slate-600">
                  Résidents, actifs du quartier, deux-roues, véhicules secondaires.
                </p>
              </div>

              <div className="rounded-2xl bg-slate-100 p-5">
                <p className="font-black">Informations utiles</p>
                <p className="mt-1 text-slate-600">
                  Précisez le véhicule, la plaque si disponible, et la date d’entrée souhaitée.
                </p>
              </div>
            </div>
          </div>

          <form
            action="/api/contact"
            method="post"
            className="rounded-[2rem] border border-slate-200 bg-slate-50 p-6 shadow-sm md:p-8"
          >
            {params.contact === "success" && (
              <p className="mb-6 rounded-2xl bg-emerald-50 px-4 py-3 text-sm font-bold text-emerald-700">
                Votre message a bien été envoyé. Nous reviendrons vers vous rapidement.
              </p>
            )}

            {params.contact === "error" && (
              <p className="mb-6 rounded-2xl bg-red-50 px-4 py-3 text-sm font-bold text-red-700">
                Merci de renseigner au minimum votre nom, email et message.
              </p>
            )}

            <div className="grid gap-4 md:grid-cols-2">
              <div>
                <label className="text-sm font-bold">Nom</label>
                <input
                  name="name"
                  required
                  placeholder="Votre nom"
                  className="mt-2 w-full rounded-2xl border border-slate-300 bg-white px-4 py-3 outline-none focus:border-yellow-500 focus:ring-4 focus:ring-yellow-100"
                />
              </div>

              <div>
                <label className="text-sm font-bold">Email</label>
                <input
                  name="email"
                  required
                  type="email"
                  placeholder="vous@email.fr"
                  className="mt-2 w-full rounded-2xl border border-slate-300 bg-white px-4 py-3 outline-none focus:border-yellow-500 focus:ring-4 focus:ring-yellow-100"
                />
              </div>

              <div>
                <label className="text-sm font-bold">Téléphone</label>
                <input
                  name="phone"
                  placeholder="06..."
                  className="mt-2 w-full rounded-2xl border border-slate-300 bg-white px-4 py-3 outline-none focus:border-yellow-500 focus:ring-4 focus:ring-yellow-100"
                />
              </div>

              <div>
                <label className="text-sm font-bold">Objet</label>
                <input
                  name="subject"
                  placeholder="Demande de place"
                  className="mt-2 w-full rounded-2xl border border-slate-300 bg-white px-4 py-3 outline-none focus:border-yellow-500 focus:ring-4 focus:ring-yellow-100"
                />
              </div>
            </div>

            <div className="mt-4">
              <label className="text-sm font-bold">Message</label>
              <textarea
                name="message"
                required
                rows={6}
                placeholder="Bonjour, je recherche une place mensuelle pour une voiture à partir du..."
                className="mt-2 w-full rounded-2xl border border-slate-300 bg-white px-4 py-3 outline-none focus:border-yellow-500 focus:ring-4 focus:ring-yellow-100"
              />
            </div>

            <button className="mt-6 w-full rounded-2xl bg-slate-950 px-6 py-4 font-black text-white transition hover:bg-slate-800">
              Envoyer ma demande
            </button>

            <p className="mt-4 text-center text-xs text-slate-500">
              Vos informations servent uniquement à traiter votre demande de stationnement.
            </p>
          </form>
        </div>
      </section>

      <footer className="border-t border-white/10 bg-slate-950 px-6 py-10 text-slate-400">
        <div className="mx-auto flex max-w-7xl flex-col gap-4 md:flex-row md:items-center md:justify-between">
          <div>
            <p className="font-black text-white">Gambetta Park</p>
            <p className="mt-1 text-sm">
              Location mensuelle de places de parking sécurisées.
            </p>
          </div>

          <div className="flex flex-wrap gap-5 text-sm">
            <a href="#avantages" className="hover:text-yellow-300">Avantages</a>
            <a href="#tarifs" className="hover:text-yellow-300">Tarifs</a>
            <a href="#contact" className="hover:text-yellow-300">Contact</a>
            <a href="/admin/login" className="text-slate-600 hover:text-slate-300">
              Espace gestion
            </a>
          </div>
        </div>
      </footer>
    </main>
  );
}
