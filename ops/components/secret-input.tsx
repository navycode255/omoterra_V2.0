'use client';

import { useState, type InputHTMLAttributes } from 'react';

const EYE = (
  <svg aria-hidden="true" viewBox="0 0 24 24">
    <path d="M2 12s3.6-7 10-7 10 7 10 7-3.6 7-10 7S2 12 2 12Z" />
    <circle cx="12" cy="12" r="3" />
  </svg>
);
const EYE_OFF = (
  <svg aria-hidden="true" viewBox="0 0 24 24">
    <path d="M10.6 5.1A9.8 9.8 0 0 1 12 5c6.4 0 10 7 10 7a17 17 0 0 1-2.6 3.5M6.6 6.6C3.7 8.4 2 12 2 12s3.6 7 10 7a9.5 9.5 0 0 0 5.4-1.6" />
    <path d="M9.9 9.9a3 3 0 0 0 4.2 4.2" />
    <path d="m3 3 18 18" />
  </svg>
);

// A passphrase or PIN input with an eye button to show what was typed, so a
// mistake can be spotted before submitting. Hidden by default.
export function SecretInput({ label = 'PIN', ...props }: Omit<InputHTMLAttributes<HTMLInputElement>, 'type'> & { label?: string }) {
  const [shown, setShown] = useState(false);
  return (
    <span className="secret-field">
      <input {...props} type={shown ? 'text' : 'password'} data-secret="" />
      <button
        type="button"
        className="secret-toggle"
        aria-label={`${shown ? 'Hide' : 'Show'} ${label}`}
        aria-pressed={shown}
        aria-controls={props.id}
        // Keep focus (and the keyboard) on the input when tapped.
        onMouseDown={(event) => event.preventDefault()}
        onClick={() => setShown((value) => !value)}
      >
        {shown ? EYE_OFF : EYE}
      </button>
    </span>
  );
}
