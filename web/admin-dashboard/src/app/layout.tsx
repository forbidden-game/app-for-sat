import type { Metadata, Viewport } from "next";
import { IBM_Plex_Mono, IBM_Plex_Sans } from "next/font/google";
import "./globals.css";

const plexSans = IBM_Plex_Sans({
  variable: "--font-sans",
  weight: ["400", "500", "600", "700"],
  subsets: ["latin"],
});

const plexMono = IBM_Plex_Mono({
  variable: "--font-mono",
  weight: ["400", "500", "600"],
  subsets: ["latin"],
});

export const metadata: Metadata = {
  title: "Backside of Meng's Dream Admin Console",
  description: "Admin console for Backside of Meng's Dream operations.",
};

export const viewport: Viewport = {
  themeColor: [
    { media: "(prefers-color-scheme: light)", color: "#ffffff" },
    { media: "(prefers-color-scheme: dark)", color: "#0f172a" },
  ],
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <head>
        <script
          dangerouslySetInnerHTML={{
            __html: `
              (function() {
                try {
                  var m = localStorage.getItem('theme');
                  var supportDark = window.matchMedia('(prefers-color-scheme: dark)').matches === true;
                  if (!m && supportDark) document.documentElement.classList.add('dark');
                } catch (e) {}
              })()
            `,
          }}
        />
      </head>
      <body className={`${plexSans.variable} ${plexMono.variable} antialiased`} style={{ colorScheme: "light dark" }}>
        <a className="skip-link" href="#main">
          Skip to content
        </a>
        <div id="main">{children}</div>
      </body>
    </html>
  );
}
