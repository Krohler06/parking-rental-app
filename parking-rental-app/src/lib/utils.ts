import { PaymentStatus, RentalStatus, SpotStatus, VehicleType } from "@prisma/client";

export function formatCurrency(value: number | string) {
  const amount = typeof value === "string" ? Number(value) : value;

  return new Intl.NumberFormat("fr-FR", {
    style: "currency",
    currency: "EUR"
  }).format(amount);
}

export function formatDate(value: Date | string | null | undefined) {
  if (!value) {
    return "-";
  }

  return new Intl.DateTimeFormat("fr-FR").format(new Date(value));
}

export function spotStatusLabel(status: SpotStatus) {
  const labels: Record<SpotStatus, string> = {
    AVAILABLE: "Disponible",
    OCCUPIED: "Occupée",
    RESERVED: "Réservée",
    MAINTENANCE: "Maintenance",
    INACTIVE: "Inactive"
  };

  return labels[status];
}

export function spotStatusClass(status: SpotStatus) {
  const classes: Record<SpotStatus, string> = {
    AVAILABLE: "bg-emerald-100 text-emerald-800 border-emerald-200",
    OCCUPIED: "bg-red-100 text-red-800 border-red-200",
    RESERVED: "bg-amber-100 text-amber-800 border-amber-200",
    MAINTENANCE: "bg-slate-200 text-slate-800 border-slate-300",
    INACTIVE: "bg-zinc-100 text-zinc-500 border-zinc-200"
  };

  return classes[status];
}

export function vehicleTypeLabel(type: VehicleType) {
  const labels: Record<VehicleType, string> = {
    CAR: "Voiture",
    MOTORCYCLE: "Deux-roues",
    OTHER: "Autre"
  };

  return labels[type];
}

export function rentalStatusLabel(status: RentalStatus) {
  const labels: Record<RentalStatus, string> = {
    PENDING: "En attente",
    ACTIVE: "Active",
    ENDED: "Terminée",
    CANCELLED: "Annulée"
  };

  return labels[status];
}

export function paymentStatusLabel(status: PaymentStatus) {
  const labels: Record<PaymentStatus, string> = {
    PAID: "Payée",
    UNPAID: "Non payée",
    PARTIAL: "Partielle",
    LATE: "En retard"
  };

  return labels[status];
}
