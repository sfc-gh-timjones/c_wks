import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "WKS Restaurant Group — Snowflake Demo",
  description: "Sales and HR analytics powered by Snowflake Dynamic Tables and Cortex Agent",
};

export default function RootLayout({
  children,
}: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
