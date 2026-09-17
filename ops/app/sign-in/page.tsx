import { redirect } from 'next/navigation';
import { signedIn, startSession, verifyPassphrase } from '@/lib/session';

export const metadata = { title: 'Sign in · Omoterra Operations' };

export default async function SignIn({
  searchParams,
}: {
  searchParams: Promise<{ error?: string }>;
}) {
  if (await signedIn()) redirect('/');
  const { error } = await searchParams;

  async function submit(formData: FormData) {
    'use server';
    const passphrase = String(formData.get('passphrase') ?? '');
    if (!verifyPassphrase(passphrase)) redirect('/sign-in?error=1');
    await startSession();
    redirect('/');
  }

  return (
    <main
      style={{
        minHeight: '100vh',
        display: 'grid',
        placeItems: 'center',
        padding: 'var(--s5)',
      }}
    >
      <form action={submit} className="card stack" style={{ width: 380, padding: 'var(--s7)' }}>
        <div>
          <div className="brand" style={{ padding: 0, marginBottom: 'var(--s5)' }}>
            Omoterra
          </div>
          <h1>Operations</h1>
          <p className="muted small" style={{ marginTop: 'var(--s2)' }}>
            Internal access only. This dashboard manages live supply, orders and payments.
          </p>
        </div>
        {error && (
          <div className="notice" data-tone="error">
            That passphrase was not recognised.
          </div>
        )}
        <div className="field">
          <label htmlFor="passphrase">Operator passphrase</label>
          <input
            id="passphrase"
            name="passphrase"
            type="password"
            className="input"
            autoComplete="current-password"
            autoFocus
            required
          />
        </div>
        <button type="submit" className="button">
          Sign in
        </button>
      </form>
    </main>
  );
}
