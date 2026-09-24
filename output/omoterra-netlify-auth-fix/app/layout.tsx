import type { Metadata } from 'next';
import { Manrope } from 'next/font/google';
import './globals.css';

const manrope = Manrope({
  subsets: ['latin'],
  variable: '--font-manrope',
  weight: ['400', '500', '600', '700'],
});

export const metadata: Metadata = {
  title: 'Omoterra · Real Markets for Real People',
  description: 'A trusted livestock marketplace connecting Tanzanian farmers, buyers and reliable delivery.',
  metadataBase: new URL(
    process.env.OMOTERRA_APP_URL ?? 'https://omoterra.jopex.co.tz',
  ),
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className={manrope.variable}>
      <body>{children}</body>
    </html>
  );
}
