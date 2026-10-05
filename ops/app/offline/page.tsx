import Image from 'next/image';

export const metadata = { title: 'Offline · Omoterra' };
export const dynamic = 'force-static';

// Shown by the service worker when a page is opened without a connection.
export default function Offline() {
  return (
    <main className="offline-page">
      <Image src="/icons/icon-192.png" alt="" width={72} height={72} priority />
      <h1>You are offline</h1>
      <p>Omoterra needs an internet connection. Check your data or Wi-Fi, then try again.</p>
      {/* The worker serves this at the page the user asked for, so an empty
          href reloads that page through the network. */}
      <a className="offline-retry" href="">Try again</a>
    </main>
  );
}
