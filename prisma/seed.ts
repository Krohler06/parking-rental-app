import { PrismaClient, SpotStatus, SpotType, VehicleType } from "@prisma/client";
import bcrypt from "bcryptjs";

const prisma = new PrismaClient();

async function main() {
  const adminEmail = process.env.ADMIN_EMAIL || "admin@example.local";
  const adminPassword = process.env.ADMIN_PASSWORD || "ChangeMoi123!";
  const adminName = process.env.ADMIN_NAME || "Administrateur";

  const passwordHash = await bcrypt.hash(adminPassword, 12);

  await prisma.admin.upsert({
    where: { email: adminEmail },
    update: {
      passwordHash,
      name: adminName,
      isActive: true
    },
    create: {
      email: adminEmail,
      passwordHash,
      name: adminName,
      role: "SUPER_ADMIN"
    }
  });

  await prisma.siteSetting.upsert({
    where: { id: "default" },
    update: {},
    create: {
      id: "default",
      companyName: "Parking Sécurisé",
      headline: "Location mensuelle de places de parking",
      description:
        "Parking fermé et sécurisé pour voitures et deux-roues, disponible à la location mensuelle.",
      address: "Adresse à compléter",
      phone: "Téléphone à compléter",
      email: "contact@example.local",
      openingHours: "Lundi au samedi, sur rendez-vous"
    }
  });

  const floors = [
    { name: "Étage 1", levelNumber: 1 },
    { name: "Étage 2", levelNumber: 2 },
    { name: "Étage 3", levelNumber: 3 }
  ];

  for (const floor of floors) {
    const createdFloor = await prisma.parkingFloor.upsert({
      where: { levelNumber: floor.levelNumber },
      update: { name: floor.name, isActive: true },
      create: {
        name: floor.name,
        levelNumber: floor.levelNumber,
        isActive: true
      }
    });

    for (let spotNumber = 1; spotNumber <= 40; spotNumber++) {
      await prisma.parkingSpot.upsert({
        where: {
          floorId_spotNumber: {
            floorId: createdFloor.id,
            spotNumber
          }
        },
        update: {},
        create: {
          floorId: createdFloor.id,
          spotNumber,
          label: `${floor.name} - Place ${spotNumber}`,
          spotType: SpotType.BOTH,
          status: SpotStatus.AVAILABLE,
          isActive: true
        }
      });
    }
  }

  await prisma.service.createMany({
    data: [
      {
        title: "Parking fermé",
        description: "Un espace fermé pour stationner votre véhicule en toute tranquillité.",
        icon: "shield",
        sortOrder: 1
      },
      {
        title: "Voitures et deux-roues",
        description: "Des places adaptées aux véhicules particuliers, motos et scooters.",
        icon: "car",
        sortOrder: 2
      },
      {
        title: "Location mensuelle",
        description: "Une gestion simple avec montant, durée, date d’entrée et véhicule.",
        icon: "calendar",
        sortOrder: 3
      }
    ],
    skipDuplicates: true
  });

  await prisma.pricing.createMany({
    data: [
      {
        title: "Place voiture",
        description: "Location mensuelle pour véhicule particulier.",
        vehicleType: VehicleType.CAR,
        priceMonthly: 120,
        currency: "EUR",
        sortOrder: 1
      },
      {
        title: "Place deux-roues",
        description: "Location mensuelle pour moto ou scooter.",
        vehicleType: VehicleType.MOTORCYCLE,
        priceMonthly: 60,
        currency: "EUR",
        sortOrder: 2
      }
    ],
    skipDuplicates: true
  });

  const brands = [
    {
      name: "Renault",
      models: [
        { name: "Clio", vehicleType: VehicleType.CAR },
        { name: "Captur", vehicleType: VehicleType.CAR }
      ]
    },
    {
      name: "Peugeot",
      models: [
        { name: "208", vehicleType: VehicleType.CAR },
        { name: "308", vehicleType: VehicleType.CAR }
      ]
    },
    {
      name: "Citroën",
      models: [
        { name: "C3", vehicleType: VehicleType.CAR },
        { name: "C4", vehicleType: VehicleType.CAR }
      ]
    },
    {
      name: "BMW",
      models: [
        { name: "Série 1", vehicleType: VehicleType.CAR },
        { name: "Série 3", vehicleType: VehicleType.CAR }
      ]
    },
    {
      name: "Mercedes",
      models: [
        { name: "Classe A", vehicleType: VehicleType.CAR },
        { name: "Classe C", vehicleType: VehicleType.CAR }
      ]
    },
    {
      name: "Yamaha",
      models: [
        { name: "MT-07", vehicleType: VehicleType.MOTORCYCLE },
        { name: "XMAX", vehicleType: VehicleType.MOTORCYCLE }
      ]
    },
    {
      name: "Honda",
      models: [
        { name: "Forza", vehicleType: VehicleType.MOTORCYCLE },
        { name: "CB500F", vehicleType: VehicleType.MOTORCYCLE }
      ]
    }
  ];

  for (const brand of brands) {
    const createdBrand = await prisma.vehicleBrand.upsert({
      where: { name: brand.name },
      update: {},
      create: { name: brand.name }
    });

    for (const model of brand.models) {
      await prisma.vehicleModel.upsert({
        where: {
          brandId_name: {
            brandId: createdBrand.id,
            name: model.name
          }
        },
        update: {},
        create: {
          brandId: createdBrand.id,
          name: model.name,
          vehicleType: model.vehicleType
        }
      });
    }
  }

  console.log("Seed terminé.");
  console.log(`Admin local : ${adminEmail}`);
}

main()
  .catch((error) => {
    console.error(error);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
