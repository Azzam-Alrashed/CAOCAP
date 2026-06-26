import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "CAOCAP | Learn Software by Building",
  description:
    "CAOCAP is a creative canvas where people learn software by building real apps with an AI mentor.",
  openGraph: {
    title: "CAOCAP | Learn Software by Building",
    description:
      "Learn software by building real Mini-Apps through spatial nodes, live previews, and an AI mentor on iOS and iPadOS.",
    type: "website",
    url: "https://caocap.com",
    siteName: "CAOCAP"
  },
  twitter: {
    card: "summary_large_image",
    title: "CAOCAP | Learn Software by Building",
    description:
      "A creative canvas where people learn software by building real apps with an AI mentor."
  }
};

const themeScript = `
(function() {
  try {
    var key = "caocap-theme";
    var preference = window.localStorage.getItem(key) || "system";
    if (preference !== "system" && preference !== "light" && preference !== "dark") {
      preference = "system";
    }
    var prefersDark = window.matchMedia && window.matchMedia("(prefers-color-scheme: dark)").matches;
    var theme = preference === "system" ? (prefersDark ? "dark" : "light") : preference;
    var root = document.documentElement;
    root.dataset.theme = theme;
    root.dataset.themePreference = preference;
    root.style.colorScheme = theme;
  } catch (error) {
    document.documentElement.dataset.theme = "dark";
    document.documentElement.dataset.themePreference = "system";
    document.documentElement.style.colorScheme = "dark";
  }
})();
`;

export default function RootLayout({
  children
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" suppressHydrationWarning>
      <head>
        <script dangerouslySetInnerHTML={{ __html: themeScript }} />
      </head>
      <body>{children}</body>
    </html>
  );
}
