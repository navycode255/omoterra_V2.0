import Image from 'next/image';
import Link from 'next/link';
import { redirect } from 'next/navigation';
import { pendingChallenge, pendingSignIn, setupState, signedIn } from '@/lib/session';
import { SecretInput } from '@/components/secret-input';

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

function PhoneField({ label, focus = true }: { label: string; focus?: boolean }) {
  return <>
    <label htmlFor="phone">{label}</label>
    <div className="signin-input-wrap">
      {PHONE_ICON}
      <input id="phone" name="phone" type="tel" autoComplete="tel" autoFocus={focus} placeholder="0712 345 678" required />
    </div>
  </>;
}

function PinFields({ label, confirm, autoComplete }: { label: string; confirm?: boolean; autoComplete: string }) {
  return <>
    <label htmlFor="pin">{label}</label>
    <div className="signin-input-wrap">
      {LOCK_ICON}
      <SecretInput label={label} id="pin" name="pin" inputMode="numeric" autoComplete={autoComplete} autoFocus
        pattern="[0-9]{4,6}" maxLength={6} placeholder="4 to 6 digits" required />
    </div>
    {confirm && <>
      <label htmlFor="confirm" className="signin-label-gap">Confirm PIN</label>
      <div className="signin-input-wrap">
        {LOCK_ICON}
        <SecretInput label="Confirm PIN" id="confirm" name="confirm" inputMode="numeric" autoComplete="new-password"
          pattern="[0-9]{4,6}" maxLength={6} placeholder="Repeat the PIN" required />
      </div>
    </>}
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
  passphrase: 'That passphrase is not right.',
  'staff-off': 'Staff sign-in is switched off on the server: set OMOTERRA_STAFF_PASSPHRASE (or OMOTERRA_ADMIN_SETUP_PASSPHRASE) in the backend .env and restart.',
  pin: 'The phone number or PIN is incorrect.',
  'pin-format': 'Enter a PIN of 4 to 6 digits.',
  'pin-mismatch': 'The PINs do not match.',
  'pin-easy': 'Choose a PIN that is harder to guess, not 1234 or 0000.',
  'pin-paused': 'Too many wrong PINs. Wait 15 minutes, or reset your PIN with a code.',
  'pin-blocked': 'This PIN is blocked after too many wrong tries. Use “Forgot PIN?” to set a new one.',
  locked: 'Too many wrong passphrases. Wait 15 minutes and try again.',
  phone: 'Enter a Tanzanian mobile number, like 0712 345 678.',
  unknown: 'This number is not an active Omoterra operator. Ask an admin to add you.',
  wait: 'Please wait a minute before requesting another code.',
  code: 'That code is not right. Check it and try again.',
  expired: 'Your sign-in has expired. Please sign in again.',
  server: 'We could not sign you in just now. Please try again.',
  connection: 'The dashboard is not connected to the Omoterra API: its OMOTERRA_OPS_TOKEN does not match the backend .env.',
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
  connection: 'The dashboard is not connected to the Omoterra API: its OMOTERRA_OPS_TOKEN does not match the backend .env.',
  'setup-off': 'Admin setup is switched off on the server: set OMOTERRA_ADMIN_SETUP_PASSPHRASE in the backend .env and restart.',
};

export default async function SignIn({
  searchParams,
}: {
  searchParams: Promise<{ error?: string; step?: string; mode?: string }>;
}) {
  const { error, step, mode } = await searchParams;
  // Signed in by a texted code but without a PIN yet: stay to create one.
  const creatingAfterCode = step === 'new-pin' && await signedIn();
  if (!creatingAfterCode && await signedIn()) redirect('/manage');
  const setupMode = mode === 'setup';
  const setup = setupMode ? await setupState() : null;
  const challenge = !setupMode && step === 'code' ? await pendingChallenge() : null;
  const signIn = !setupMode && (step === 'pin' || step === 'create') ? await pendingSignIn() : null;

  // Staff sign in with the staff passphrase and phone, then their PIN. No SMS
  // is sent to sign in; only a forgotten PIN is reset with a texted code.
  let action = '/sign-in/session';
  let heading = 'Operations';
  let hidden = 'start';
  let submit = 'Continue';
  let body: React.ReactNode = <>
    <label htmlFor="passphrase">Staff passphrase</label>
    <div className="signin-input-wrap">
      {LOCK_ICON}
      <SecretInput label="passphrase" id="passphrase" name="passphrase" autoComplete="off" autoFocus placeholder="Enter the passphrase" required />
    </div>
    <div className="signin-label-gap" />
    <PhoneField label="Phone number" focus={false} />
  </>;
  let footer: React.ReactNode = <a className="signin-admin-link" href="/sign-in?mode=setup">Admin setup</a>;
  const errors = setupMode ? SETUP_ERRORS : SIGN_IN_ERRORS;

  if (creatingAfterCode) {
    hidden = 'new-pin';
    heading = 'Create your PIN';
    submit = 'Save PIN';
    body = <>
      <p className="signin-hint">You will sign in with this PIN from now on, without an SMS code.</p>
      <PinFields label="New PIN" confirm autoComplete="new-password" />
    </>;
    footer = null;
  } else if (signIn?.hasPin && step === 'pin') {
    hidden = 'pin';
    submit = 'Sign in';
    body = <>
      <p className="signin-hint">Signing in as {signIn.phone}.</p>
      <PinFields label="PIN" autoComplete="current-password" />
    </>;
    footer = <div className="signin-links">
      <button type="submit" name="action" value="reset" formNoValidate className="signin-alt signin-link-button">Forgot PIN? Get a code by SMS</button>
      <a className="signin-alt" href="/sign-in">Use a different number</a>
    </div>;
  } else if (signIn && !signIn.hasPin && step === 'create') {
    hidden = 'create';
    heading = 'Create your PIN';
    submit = 'Create PIN and sign in';
    body = <>
      <p className="signin-hint">First sign-in for {signIn.phone}. Choose a 4 to 6 digit PIN; you will use it every time you sign in.</p>
      <PinFields label="New PIN" confirm autoComplete="new-password" />
    </>;
    footer = <a className="signin-alt" href="/sign-in">Use a different number</a>;
  } else if (!setupMode && challenge) {
    hidden = 'code';
    submit = 'Continue';
    body = <CodeField phone={challenge.phone} developmentCode={challenge.developmentCode} label="Code from SMS" />;
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
          <SecretInput label="passphrase" id="passphrase" name="passphrase" autoComplete="off" autoFocus
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
          <Link href="/" className="signin-logo-link" aria-label="Omoterra home">
            <Image
              className="signin-logo"
              src="/images/marketing/logo.png"
              alt="Omoterra — Where Markets Meet Supply"
              width={370}
              height={112}
              priority
            />
          </Link>
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
            {/* This page is staff only; members who land here need a way out. */}
            <p className="signin-exit">
              Buyer or supplier? <Link href="/login">Log in to your account</Link>
              <span aria-hidden="true"> · </span><Link href="/">Back to website</Link>
            </p>
          </div>
        </form>
      </section>
    </main>
  );
}
