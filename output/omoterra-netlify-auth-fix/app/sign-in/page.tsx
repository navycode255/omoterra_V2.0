import Image from 'next/image';
import { redirect } from 'next/navigation';
import { signedIn } from '@/lib/session';

export const metadata = { title: 'Sign in · Omoterra Operations' };

export default async function SignIn({
  searchParams,
}: {
  searchParams: Promise<{ error?: string }>;
}) {
  if (await signedIn()) redirect('/manage');
  const { error } = await searchParams;

  return (
    <main className="signin-page">
      <section
        className="signin-photo"
        role="img"
        aria-label="A Tanzanian farm at sunset with a goat, chicken, vegetables and grain"
      />
      <section className="signin-panel">
        <span className="signin-hex signin-hex-a" aria-hidden="true" />
        <span className="signin-hex signin-hex-b" aria-hidden="true" />
        <span className="signin-hex signin-hex-c" aria-hidden="true" />
        <span className="signin-hex signin-hex-d" aria-hidden="true" />

        <form action="/sign-in/session" method="post" className="signin-card">
          <Image
            className="signin-logo"
            src="/images/marketing/logo.png"
            alt="Omoterra — Where Markets Meet Supply"
            width={370}
            height={112}
            priority
          />
          <div className="signin-form-content">
            <h1>Operations</h1>
            {error && (
              <div className="notice" data-tone="error">
                {error === 'config'
                  ? 'Sign-in is not configured on the server. Check the Netlify environment variables and redeploy.'
                  : error === 'session'
                    ? 'The secure session could not be created. Please try again.'
                    : 'That passphrase was not recognised.'}
              </div>
            )}
            <label htmlFor="passphrase">Operator passphrase</label>
            <div className="signin-input-wrap">
              <svg aria-hidden="true" viewBox="0 0 24 24">
                <rect x="5" y="10" width="14" height="11" rx="2" />
                <path d="M8 10V7a4 4 0 0 1 8 0v3" />
              </svg>
              <input
                id="passphrase"
                name="passphrase"
                type="password"
                autoComplete="current-password"
                autoFocus
                placeholder="Enter your passphrase"
                required
              />
              <svg className="signin-eye" aria-hidden="true" viewBox="0 0 24 24">
                <path d="M3 3l18 18" />
                <path d="M10.6 10.7a2 2 0 0 0 2.7 2.7" />
                <path d="M9.9 4.2A10.8 10.8 0 0 1 12 4c5.5 0 9 6 9 6a16.5 16.5 0 0 1-3.1 3.8M6.2 6.2C4.2 7.6 3 10 3 10s3.5 6 9 6c.8 0 1.5-.1 2.2-.3" />
              </svg>
            </div>
            <button type="submit" className="signin-submit">Sign In</button>
          </div>
        </form>
      </section>
    </main>
  );
}
