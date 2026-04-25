import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "CAOCAP | Mindmap Your HTML",
  description:
    "CAOCAP is a spatial, mindmap-driven way to build HTML, CSS, and JavaScript on iOS and iPadOS.",
  openGraph: {
    title: "CAOCAP | Mindmap Your HTML",
    description:
      "Build web ideas through spatial nodes, live previews, and an AI companion on iOS and iPadOS.",
    type: "website",
    url: "https://caocap.com",
    siteName: "CAOCAP"
  },
  twitter: {
    card: "summary_large_image",
    title: "CAOCAP | Mindmap Your HTML",
    description:
      "A spatial, mindmap-driven way to build HTML, CSS, and JavaScript on iOS and iPadOS."
  }
};

export default function RootLayout({
  children
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
