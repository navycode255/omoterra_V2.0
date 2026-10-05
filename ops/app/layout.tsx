import type { Metadata, Viewport } from 'next';
import { Manrope } from 'next/font/google';
import { ServiceWorker } from '@/components/pwa';
import './globals.css';

const manrope = Manrope({
  subsets: ['latin'],
  variable: '--font-manrope',
  weight: ['400', '500', '600', '700', '800'],
});

export const metadata: Metadata = {
  title: 'Omoterra · Real Markets for Real People',
  description: 'A trusted livestock marketplace connecting Tanzanian farmers, buyers and reliable delivery.',
  metadataBase: new URL(
    process.env.OMOTERRA_APP_URL ?? 'https://omoterra.jopex.co.tz',
  ),
  applicationName: 'Omoterra',
  // Installed to the iOS home screen, open full screen with the app's name.
  appleWebApp: { capable: true, title: 'Omoterra', statusBarStyle: 'default' },
  formatDetection: { telephone: false },
};

export const viewport: Viewport = {
  themeColor: '#0e6f50',
  width: 'device-width',
  initialScale: 1,
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className={manrope.variable}>
      <body>
        {children}
        <ServiceWorker />
      </body>
    </html>
  );
}
