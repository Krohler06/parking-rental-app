import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Parking sécurisé",
  description: "Location mensuelle de places de parking sécurisées pour voitures et deux-roues."
};

export default function RootLayout({
  children
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="fr">
      <body>{children}</body>
    </html>
  );
}
