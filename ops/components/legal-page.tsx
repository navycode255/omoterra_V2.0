import Link from 'next/link';
import { legalOperator, legalUpdated, type LegalDocument } from '@/lib/legal';

const pages = [['terms', '/terms', 'Terms of Use'], ['privacy', '/privacy', 'Privacy Policy']] as const;

// One legal document: a banner with the Terms/Privacy switch, a contents list
// that stays in view on wide screens, numbered sections, and who to contact.
export function LegalPage({ document, current }: { document: LegalDocument; current: 'terms' | 'privacy' }) {
  const { name, address, email, support_email: support, phone } = legalOperator;
  return (
    <>
      <section className="legal-hero">
        <div className="legal-hero-copy">
          <p className="eyebrow">Omoterra legal</p>
          <h1>{document.title}</h1>
          <p>{document.summary}</p>
          <span className="legal-updated">Last updated {legalUpdated}</span>
        </div>
        <nav className="legal-switch" aria-label="Legal documents">
          {pages.map(([key, href, label]) => (
            <Link key={key} href={href} className={key === current ? 'is-active' : ''} aria-current={key === current ? 'page' : undefined}>{label}</Link>
          ))}
        </nav>
      </section>

      <div className="legal-body">
        <nav className="legal-contents" aria-label="On this page">
          <strong>On this page</strong>
          <ol>{document.sections.map((section) => <li key={section.id}><a href={`#${section.id}`}>{section.heading}</a></li>)}</ol>
        </nav>

        <article className="legal-document">
          {document.sections.map((section, at) => (
            <section key={section.id} id={section.id} className="legal-section">
              <h2><span className="legal-number">{at + 1}</span>{section.heading}</h2>
              {section.body.map((block, index) => 'p' in block
                ? <p key={index}>{block.p}</p>
                : <ul key={index}>{block.ul.map((item) => <li key={item}>{item}</li>)}</ul>)}
            </section>
          ))}

          <section className="legal-contact" id="contact">
            <h2>Questions or requests</h2>
            <p>Omoterra is operated by {name}, {address}.</p>
            <div className="legal-contact-links">
              <a className="button button-primary" href={`mailto:${email}`}>Email {email}</a>
              <a className="button button-outline" href={`tel:${phone.replace(/\s/g, '')}`}>Call {phone}</a>
            </div>
            <p className="legal-muted">For help with an order or payout you can also write to {support}.</p>
          </section>
        </article>
      </div>

      <footer className="legal-footer">
        <span>© 2026 Omoterra · operated by {name}</span>
        <nav aria-label="Legal">
          <Link href="/">Home</Link>
          {pages.map(([key, href, label]) => <Link key={key} href={href}>{label}</Link>)}
        </nav>
      </footer>
    </>
  );
}
