import Link from 'next/link';

export const metadata = { title: 'Get started · Omoterra' };

const stroke = { fill: 'none', stroke: 'currentColor', strokeWidth: 1.7, strokeLinecap: 'round' as const, strokeLinejoin: 'round' as const };

function Cart() {
  return <svg viewBox="0 0 24 24" aria-hidden="true"><path {...stroke} d="M2.5 3.5h2.2l2.4 11h11.2l2.2-7.8H6.1" /><path {...stroke} d="M8.3 11h11.1" /><circle {...stroke} cx="9" cy="19" r="1.5" /><circle {...stroke} cx="17.5" cy="19" r="1.5" /></svg>;
}

function Barn() {
  return <svg viewBox="0 0 24 24" aria-hidden="true"><path {...stroke} d="M3.5 20.5V9.8L12 3.5l8.5 6.3v10.7z" /><path {...stroke} d="M8 20.5v-6.8h8v6.8M8 13.7l8 6.8M16 13.7l-8 6.8" /><circle {...stroke} cx="12" cy="9.3" r="1.3" /></svg>;
}

export default function ChooseRegistration() {
  return (
    <section className="join-card join-choice">
      <p className="join-eyebrow">Join Omoterra</p>
      <h1>Register as</h1>
      <div className="join-choices">
        <Link className="join-choice-card" href="/register/buyer">
          <span className="join-choice-icon"><Cart /></span>
          <strong>Buyer</strong><span>Buy livestock and request supply</span>
        </Link>
        <Link className="join-choice-card" href="/register/supplier">
          <span className="join-choice-icon"><Barn /></span>
          <strong>Supplier</strong><span>Sell your livestock through Omoterra</span>
        </Link>
      </div>
    </section>
  );
}
