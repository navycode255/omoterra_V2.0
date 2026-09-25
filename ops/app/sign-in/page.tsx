import Image from 'next/image';
import { redirect } from 'next/navigation';
import { pendingChallenge, setupState, signedIn } from '@/lib/session';

export const metadata = { title: 'Sign in · Omoterra Operations' };

const PHONE_ICON = (
  <svg aria-hidden="true" viewBox="0 0 24 24">
    <rect x="7" y="3" width="10" height="18" rx="2" />
    <path d="M11 18h2" />
  </svg>
);
const LOCK_ICON = (
  <svg aria-hidden="true" viewBox="0 0 24 24">
    <rect x="5" y="10" width="14" height="11" rx="2" />
    <path d="M8 10V7a4 4 0 0 1 8 0v3" />
  </svg>
);
const PERSON_ICON = (
  <svg aria-hidden="true" viewBox="0 0 24 24">
    <circle cx="12" cy="8" r="4" />
    <path d="M4 21c1.5-4 4.5-6 8-6s6.5 2 8 6" />
  </svg>
);

function PhoneField({ label }: { label: string }) {
  return <>
    <label htmlFor="phone">{label}</label>
    <div className="signin-input-wrap">
      {PHONE_ICON}
      <input id="phone" name="phone" type="tel" autoComplete="tel" autoFocus placeholder="0712 345 678" required />
    </div>
  </>;
}

function CodeField({ phone, developmentCode, label = 'Sign-in code' }: { phone?: string; developmentCode?: string; label?: string }) {
  return <>
    <p className="signin-hint">We sent a code to {phone}.</p>
    {developmentCode && <div className="notice">Development code: <strong>{developmentCode}</strong></div>}
    <label htmlFor="code">{label}</label>
    <div className="signin-input-wrap">
      {LOCK_ICON}
      <input id="code" name="code" inputMode="numeric" autoComplete="one-time-code"
        pattern="[0-9]{4,8}" autoFocus placeholder="Enter the code" required />
    </div>
  </>;
}

const SIGN_IN_ERRORS: Record<string, string> = {
  phone: 'Enter a Tanzanian mobile number, like 0712 345 678.',
  unknown: 'This number is not an active Omoterra operator. Ask an admin to add you.',
  wait: 'Please wait a minute before requesting another code.',
  code: 'That code is not right. Check it and try again.',
  expired: 'Your sign-in has expired. Please sign in again.',
  server: 'We could not sign you in just now. Please try again.',
};

const SETUP_ERRORS: Record<string, string> = {
  passphrase: 'That passphrase is not right.',
  locked: 'Too many attempts. Wait 15 minutes, or a minute before asking for another code.',
  phone: 'Enter a Tanzanian mobile number, like 0712 345 678.',
  denied: 'That is not allowed. Check the number is an active admin, or that admin setup is switched on.',
  code: 'That code is not right. Check it and try again.',
  taken: 'This number already has a dashboard account. An admin can make it an admin from Staff.',
  expired: 'Admin setup has expired. Start again with the passphrase.',
  server: 'We could not complete that just now. Please try again.',
};

export default async function SignIn({
  searchParams,
}: {
  searchParams: Promise<{ error?: string; step?: string; mode?: string }>;
}) {
  if (await signedIn()) redirect('/manage');
  const { error, step, mode } = await searchParams;
  const setupMode = mode === 'setup';
  const setup = setupMode ? await setupState() : null;
  const challenge = !setupMode && step === 'code' ? await pendingChallenge() : null;

  let action = '/sign-in/session';
  let heading = 'Operations';
  let hidden = 'phone';
  let submit = 'Send code';
  let body: React.ReactNode = <PhoneField label="Phone number" />;
  let footer: React.ReactNode = <a className="signin-admin-link" href="/sign-in?mode=setup">Admin setup</a>;
  const errors = setupMode ? SETUP_ERRORS : SIGN_IN_ERRORS;

  if (!setupMode && challenge) {
    hidden = 'code';
    submit = 'Sign In';
    body = <CodeField phone={challenge.phone} developmentCode={challenge.developmentCode} />;
    footer = <a className="signin-alt" href="/sign-in">Use a different number</a>;
  } else if (setupMode) {
    // Admin setup: passphrase, then (when an admin exists) that admin's
    // approval code, then the new admin's details and their own code.
    action = '/sign-in/setup';
    heading = 'Admin setup';
    footer = <a className="signin-alt" href="/sign-in/setup">Back to sign in</a>;
    const stage = setup?.stage;
    if (!setup || !stage) {
      hidden = 'passphrase';
      submit = 'Continue';
      body = <>
        <p className="signin-hint">Register an operations admin. You need the setup passphrase.</p>
        <label htmlFor="passphrase">Setup passphrase</label>
        <div className="signin-input-wrap">
          {LOCK_ICON}
          <input id="passphrase" name="passphrase" type="password" autoComplete="off" autoFocus
            placeholder="Enter the passphrase" required />
        </div>
      </>;
    } else if (stage === 'approve-phone') {
      hidden = 'approve-phone';
      submit = 'Send approval code';
      body = <>
        <p className="signin-hint">An admin already exists, so an existing admin must approve this. Enter their phone number and they will get a code.</p>
        <PhoneField label="Existing admin’s phone" />
      </>;
    } else if (stage === 'approve-code') {
      hidden = 'approve-code';
      submit = 'Approve';
      body = <CodeField phone={setup.phone} developmentCode={setup.developmentCode} label="Admin’s approval code" />;
    } else if (stage === 'details') {
      hidden = 'details';
      submit = 'Send code to new admin';
      body = <>
        {setup.approvedBy && <div className="notice">Approved by {setup.approvedBy}.</div>}
        <p className="signin-hint">Who is the new admin? They confirm with a code sent to their phone.</p>
        <label htmlFor="name">Full name</label>
        <div className="signin-input-wrap">
          {PERSON_ICON}
          <input id="name" name="name" autoComplete="name" autoFocus placeholder="Full name" required minLength={2} />
        </div>
        <label htmlFor="phone" className="signin-label-gap">New admin’s phone</label>
        <div className="signin-input-wrap">
          {PHONE_ICON}
          <input id="phone" name="phone" type="tel" autoComplete="tel" placeholder="0712 345 678" required />
        </div>
      </>;
    } else {
      hidden = 'new-code';
      submit = 'Create admin and sign in';
      body = <CodeField phone={setup.phone} developmentCode={setup.developmentCode} label="New admin’s code" />;
    }
  }

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

        <form action={action} method="post" className="signin-card">
          <Image
            className="signin-logo"
            src="/images/marketing/logo.png"
            alt="Omoterra — Where Markets Meet Supply"
            width={370}
            height={112}
            priority
          />
          <div className="signin-form-content">
            <h1>{heading}</h1>
            {error && (
              <div className="notice" data-tone="error">
                {errors[error] ?? errors.server}
              </div>
            )}
            <input type="hidden" name="step" value={hidden} />
            {body}
            <button type="submit" className="signin-submit">{submit}</button>
            {footer}
          </div>
        </form>
      </section>
    </main>
  );
}
