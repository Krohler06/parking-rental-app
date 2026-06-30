export const dynamic = "force-dynamic";
export const revalidate = 0;

import { AdminShell } from "@/components/admin/AdminShell";
import { prisma } from "@/lib/prisma";

function euro(value: number) {
  return new Intl.NumberFormat("fr-FR", {
    style: "currency",
    currency: "EUR"
  }).format(value);
}

export default async function AdminDashboardPage() {
  const [
    totalSpots,
    availableSpots,
    occupiedSpots,
    reservedSpots,
    activeRentals,
    newMessages,
    customers,
    vehicles,
    rentals
  ] = await Promise.all([
    prisma.parkingSpot.count(),
    prisma.parkingSpot.count({ where: { status: "AVAILABLE" } }),
    prisma.parkingSpot.count({ where: { status: "OCCUPIED" } }),
    prisma.parkingSpot.count({ where: { status: "RESERVED" } }),
    prisma.rental.count({ where: { status: "ACTIVE" } }),
    prisma.contactMessage.count({ where: { status: "NEW" } }),
    prisma.customer.count(),
    prisma.vehicle.count(),
    prisma.rental.findMany({ where: { status: "ACTIVE" } })
  ]);

  const monthlyRevenue = rentals.reduce(
    (total, rental) => total + Number(rental.amountMonthly),
    0
  );

  const occupancyRate =
    totalSpots > 0 ? Math.round((occupiedSpots / totalSpots) * 100) : 0;

  const cards = [
    { label: "Places totales", value: totalSpots, detail: "3 étages de 40 places" },
    { label: "Disponibles", value: availableSpots, detail: "Prêtes à louer" },
    { label: "Occupées", value: occupiedSpots, detail: `${occupancyRate}% d’occupation` },
    { label: "Réservées", value: reservedSpots, detail: "En attente de confirmation" },
    { label: "Locations actives", value: activeRentals, detail: "Contrats en cours" },
    { label: "Messages non lus", value: newMessages, detail: "Demandes à traiter" },
    { label: "Clients", value: customers, detail: "Contacts enregistrés" },
    { label: "Véhicules", value: vehicles, detail: "Plaques suivies" },
    { label: "Revenu mensuel", value: euro(monthlyRevenue), detail: "Estimation active" }
  ];

  return (
    <AdminShell
      title="Tableau de bord"
      subtitle="Vue rapide de l’activité du parking : disponibilité, occupation, demandes entrantes et revenu mensuel estimé."
    >
      <div className="grid gap-5 md:grid-cols-2 xl:grid-cols-3">
        {cards.map((card) => (
          <article
            key={card.label}
            className="rounded-[1.5rem] border border-slate-200 bg-white p-6 shadow-sm"
          >
            <p className="text-sm font-bold uppercase tracking-wide text-slate-500">
              {card.label}
            </p>
            <p className="mt-3 text-4xl font-black text-slate-950">
              {card.value}
            </p>
            <p className="mt-2 text-sm text-slate-500">
              {card.detail}
            </p>
          </article>
        ))}
      </div>

      <section className="mt-8 rounded-[1.5rem] bg-slate-950 p-8 text-white">
        <p className="text-sm font-bold uppercase tracking-[0.25em] text-yellow-300">
          Priorités
        </p>
        <h3 className="mt-3 text-2xl font-black">Ce qu’il faut surveiller</h3>

        <div className="mt-6 grid gap-4 md:grid-cols-3">
          <div className="rounded-2xl bg-white/10 p-5">
            <p className="font-bold">Messages entrants</p>
            <p className="mt-2 text-sm text-slate-300">
              Traiter rapidement les demandes augmente les chances de convertir une place libre.
            </p>
          </div>

          <div className="rounded-2xl bg-white/10 p-5">
            <p className="font-bold">Places disponibles</p>
            <p className="mt-2 text-sm text-slate-300">
              Les places libres doivent être visibles dans les tarifs et le discours commercial.
            </p>
          </div>

          <div className="rounded-2xl bg-white/10 p-5">
            <p className="font-bold">Locations actives</p>
            <p className="mt-2 text-sm text-slate-300">
              Garder les plaques et dates d’entrée à jour évite les erreurs terrain.
            </p>
          </div>
        </div>
      </section>
    </AdminShell>
  );
}
