import Image from 'next/image';
import Link from 'next/link';

export default function LegalLayout({ children }: { children: React.ReactNode }) {
  return (
    <main className="marketing-site legal-site">
      <header className="marketing-header join-header">
        <Link href="/" className="marketing-logo" aria-label="Omoterra home">
          <Image src="/images/marketing/logo.png" alt="Omoterra" width={185} height={56} priority />
        </Link>
        <div className="legal-header-actions">
          <Link className="button button-light" href="/login">Login</Link>
          <Link className="button button-primary" href="/register">Get Started</Link>
        </div>
      </header>
      {children}
    </main>
  );
}
