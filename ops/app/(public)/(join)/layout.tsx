import Image from 'next/image';
import Link from 'next/link';

export default function JoinLayout({ children }: { children: React.ReactNode }) {
  return (
    <main className="marketing-site join-site">
      <header className="marketing-header join-header">
        <Link href="/" className="marketing-logo" aria-label="Omoterra home">
          <Image src="/images/marketing/logo.png" alt="Omoterra" width={185} height={56} priority />
        </Link>
        <Link className="button button-light" href="/login">Login</Link>
      </header>
      <div className="join-body">{children}</div>
    </main>
  );
}
