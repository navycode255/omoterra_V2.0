import Image from 'next/image';
import Link from 'next/link';

export const metadata = {
  title: 'Omoterra · Real Markets for Real People',
  description:
    'A trusted livestock marketplace connecting Tanzanian farmers, buyers and reliable delivery.',
};

const categories = [
  { name: 'Broilers', image: 'category_broilers.jpg', alt: 'Healthy broiler chickens on a farm' },
  { name: 'Layers', image: 'category_eggs.jpg', alt: 'Fresh eggs from laying hens' },
  { name: 'Goats', image: 'category_goats.jpg', alt: 'Goat raised on a local farm' },
  { name: 'Cattle', image: 'category_cow.jpg', alt: 'Brown cattle in a pasture' },
  { name: 'Sheep', image: 'sheep-v1.webp', alt: 'White sheep grazing in a green pasture' },
  { name: 'Other Livestock', image: 'cattle-herd-v1.webp', alt: 'A herd grazing on a Tanzanian farm' },
];

function Mark({ kind }: { kind: 'shield' | 'truck' | 'chart' | 'leaf' | 'people' | 'document' | 'search' }) {
  const common = { fill: 'none', stroke: 'currentColor', strokeWidth: 1.8, strokeLinecap: 'round' as const, strokeLinejoin: 'round' as const };
  const shapes = {
    shield: <><path {...common} d="M12 2.8 19 5.5v5.2c0 4.8-2.9 8.3-7 10.5-4.1-2.2-7-5.7-7-10.5V5.5z"/><path {...common} d="m8.7 11.7 2.2 2.2 4.5-4.6"/></>,
    truck: <><path {...common} d="M2.5 6h11v10h-11zM13.5 9h4l4 4v3h-8z"/><circle {...common} cx="7" cy="18" r="2"/><circle {...common} cx="18" cy="18" r="2"/></>,
    chart: <><path {...common} d="M3 20h18"/><path fill="currentColor" d="M5 13h4v7H5zM11 9h4v11h-4zM17 4h4v16h-4z"/><path {...common} d="m5 9 5-4 4 2 6-5"/></>,
    leaf: <><path {...common} d="M20.5 3.5C11 3.5 5 5.8 5 12.1c0 3 2.1 5.2 5.1 5.2 6.2 0 8.1-7.2 10.4-13.8Z"/><path {...common} d="M3 21c3-5.4 7.3-8.6 13.2-11.4"/></>,
    people: <><circle {...common} cx="9" cy="8" r="3"/><path {...common} d="M3.5 20v-1.2a5.5 5.5 0 0 1 11 0V20z"/><path {...common} d="M16 5.4a3 3 0 0 1 0 5.7M17 14a4.8 4.8 0 0 1 3.5 4.6v1.3h-4"/></>,
    document: <><path {...common} d="M6 2.8h8l4 4V21H6z"/><path {...common} d="M14 3v5h5M9 12h6M9 16h6"/></>,
    search: <><circle {...common} cx="10.8" cy="10.8" r="6.8"/><path {...common} d="m16 16 5 5"/></>,
  };
  return <svg aria-hidden="true" viewBox="0 0 24 24" className="marketing-icon">{shapes[kind]}</svg>;
}

export default function MarketingHome() {
  return (
    <main className="marketing-site">
      <header className="marketing-header">
        <Link href="/" className="marketing-logo" aria-label="Omoterra home">
          <Image src="/images/marketing/logo.png" alt="Omoterra — Where Markets Meet Supply" width={185} height={56} priority />
        </Link>
        <nav className="marketing-nav" aria-label="Main navigation">
          <Link className="is-active" href="#home">Home</Link>
          <Link href="#for-buyers">For Buyers</Link>
          <Link href="#for-suppliers">For Suppliers</Link>
          <details className="solutions-menu">
            <summary>Solutions <span aria-hidden="true">⌄</span></summary>
            <div className="solutions-popover">
              <Link href="#how-it-works">Livestock sourcing</Link>
              <Link href="#how-it-works">Delivery and fulfilment</Link>
              <Link href="/sign-in">Operations dashboard</Link>
            </div>
          </details>
          <Link href="#about">About</Link>
          <Link href="#contact">Contact</Link>
        </nav>
        <div className="marketing-actions">
          <Link className="search-link" href="#explore-livestock" aria-label="Explore livestock"><Mark kind="search" /></Link>
          <Link className="button button-light" href="/sign-in">Login</Link>
          <Link className="button button-primary" href="#for-buyers">Get Started</Link>
        </div>
      </header>

      <section className="marketing-hero" id="home">
        <div className="hero-photo" role="img" aria-label="Tanzanian farmer holding a young goat on a green farm" />
        <div className="hero-shade" />
        <div className="hero-copy">
          <p className="eyebrow">Livestock sale opportunities</p>
          <h1>Real Markets<br />for Real People</h1>
          <p className="hero-description">Omoterra connects farmers, buyers and markets to make livestock supply simple, transparent and reliable across Tanzania.</p>
          <div className="hero-buttons">
            <Link className="button button-primary" href="#for-buyers">Buy Livestock</Link>
            <Link className="button button-outline" href="#for-suppliers">Request Supply</Link>
          </div>
          <div className="trust-points">
            <span><Mark kind="shield" /> Verified supply</span>
            <span><Mark kind="truck" /> Reliable delivery</span>
            <span><Mark kind="chart" /> Growing together</span>
          </div>
        </div>
        <div className="hero-script" aria-hidden="true">Livestock Sale<br />Opportunities</div>
        <div className="healthy-badge"><span className="badge-leaf"><Mark kind="leaf" /></span><span>Healthy Livestock</span></div>
      </section>

      <section className="category-section" id="for-buyers">
        <div id="explore-livestock" />
        <div className="section-heading-row">
          <p className="eyebrow">Explore livestock</p>
          <Link className="text-link" href="#for-buyers">View all <span aria-hidden="true">→</span></Link>
        </div>
        <div className="category-grid">
          {categories.map((category) => (
            <Link className="category-card" href="#for-buyers" key={category.name}>
              <Image src={`/images/marketing/${category.image}`} alt={category.alt} width={400} height={250} />
              <span>{category.name}</span>
            </Link>
          ))}
        </div>
      </section>

      <section className="marketplace-section" id="about">
        <div className="marketplace-copy">
          <p className="eyebrow">From farms to opportunities</p>
          <h2>More than a marketplace</h2>
          <p>Omoterra is a managed livestock sourcing and fulfilment network. We handle the matching, logistics and verification, so you can focus on what matters most — your business.</p>
          <div className="benefits-grid">
            <div><Mark kind="leaf" /><strong>Quality livestock</strong><span>Verified and healthy</span></div>
            <div><Mark kind="truck" /><strong>End-to-end logistics</strong><span>We handle the movement</span></div>
            <div><Mark kind="people" /><strong>Trusted network</strong><span>Farmers, buyers, markets</span></div>
          </div>
        </div>
        <div className="landscape-card" role="img" aria-label="A green Tanzanian farm landscape">
          <div className="landscape-note">Connecting<br />Tanzania’s livestock<br />future<span /></div>
        </div>
      </section>

      <section className="process-section" id="for-suppliers">
        <p className="eyebrow" id="how-it-works">How Omoterra works</p>
        <div className="process-grid">
          <article><span className="process-icon"><Mark kind="document" /></span><h3>1. Tell us what you need</h3><p>Buy available stock or request specific supply.</p></article>
          <span className="process-arrow" aria-hidden="true">⟶</span>
          <article><span className="process-icon"><Mark kind="search" /></span><h3>2. We match and verify</h3><p>We source from trusted farmers and partners.</p></article>
          <span className="process-arrow" aria-hidden="true">⟶</span>
          <article><span className="process-icon"><Mark kind="truck" /></span><h3>3. We deliver</h3><p>Your livestock, on time, where you need it.</p></article>
          <span className="process-arrow" aria-hidden="true">⟶</span>
          <article><span className="process-icon"><Mark kind="chart" /></span><h3>4. You grow</h3><p>Focus on your business while we handle the rest.</p></article>
        </div>
      </section>

      <section className="closing-section" id="contact">
        <div className="closing-photo" role="img" aria-label="Cattle grazing in a green field at sunset" />
        <div className="closing-copy">
          <p className="eyebrow">Together for a stronger tomorrow</p>
          <h2>Let’s build better<br />livestock markets</h2>
          <p>Join farmers and businesses creating a stronger, more food-secure Tanzania with Omoterra.</p>
          <div className="hero-buttons">
            <Link className="button button-primary" href="#for-buyers">Get Started</Link>
            <a className="button button-outline" href="mailto:hello@omoterra.co.tz">Contact Sales</a>
          </div>
        </div>
        <div className="closing-script" aria-hidden="true">A brighter<br />future for<br />farmers<span /></div>
      </section>

      <footer className="marketing-footer">
        <Link href="/" className="marketing-logo" aria-label="Omoterra home">
          <Image src="/images/marketing/logo.png" alt="Omoterra" width={170} height={52} />
        </Link>
        <nav aria-label="Footer navigation">
          <Link href="#home">Home</Link><Link href="#for-buyers">For Buyers</Link><Link href="#for-suppliers">For Suppliers</Link><Link href="#how-it-works">Solutions</Link><Link href="#about">About</Link><Link href="#contact">Contact</Link>
        </nav>
        <div className="footer-meta">
          <div className="footer-social" aria-label="Social media">
            <a href="https://www.linkedin.com" aria-label="LinkedIn">in</a>
            <a href="https://www.instagram.com" aria-label="Instagram">◎</a>
            <a href="https://www.facebook.com" aria-label="Facebook">f</a>
            <a href="https://www.youtube.com" aria-label="YouTube">▶</a>
          </div>
          <span>© 2026 Omoterra. All rights reserved.</span>
        </div>
      </footer>
    </main>
  );
}
