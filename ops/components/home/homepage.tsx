import Image from 'next/image';
import Link from 'next/link';
import type { CSSProperties, ReactNode } from 'react';
import styles from './homepage.module.css';
import { HomeMotion } from './motion';
import './utilities.css';

const assets = '/images/marketing/';
type IconName = 'search' | 'document' | 'truck' | 'chart' | 'shield' | 'people' | 'arrow' | 'chevron';
function Icon({ name }: { name: IconName }) {
  const paths: Record<IconName, ReactNode> = {
    search: <><circle cx="10" cy="10" r="6.5"/><path d="m15 15 6 6"/></>,
    document: <><path d="M5 3h10l4 4v14H5zM14 3v5h5M8 12h8M8 16h8"/></>,
    truck: <><path d="M2 5h12v12H2zM14 9h4l4 5v3h-8"/><circle cx="6" cy="19" r="2"/><circle cx="18" cy="19" r="2"/></>,
    chart: <><path d="M3 21V14h4v7m3 0V10h4v11m3 0V5h4v16M3 9l15-7m-5 0h5v5"/></>,
    shield: <><path d="m12 2 8 3v6c0 5-4 8-8 11-4-3-8-6-8-11V5zM8 11l3 3 5-6"/></>,
    people: <><circle cx="9" cy="7" r="3"/><path d="M3 21v-3a6 6 0 0 1 12 0v3M16 4a3 3 0 0 1 0 6m2 4a5 5 0 0 1 3 5v2"/></>,
    arrow: <path d="M2 12h20m-7-7 7 7-7 7"/>,
    chevron: <path d="m9 5 7 7-7 7"/>,
  };
  return <svg aria-hidden="true" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">{paths[name]}</svg>;
}
function Leaves({ className = '', pair = false }: { className?: string; pair?: boolean }) {
  return <svg className={`${styles.leaves} ${className}`} viewBox={pair ? '0 0 120 120' : '0 0 120 250'} fill="none" aria-hidden="true">
    {pair ? <><path fill="#aacb98" d="M79 103C33 83 13 46 8 5c47 15 70 47 71 98Z"/><path fill="#bdd6ad" d="M99 112C78 83 79 51 89 25c28 31 31 62 10 87Z"/><path stroke="#f4f9ee" d="M13 12c22 40 44 68 66 91m10-71 10 80"/></> : <><path fill="#a6c98f" d="M91 116C35 96 13 53 12 7c48 25 77 60 79 109Z"/><path fill="#b6d4a1" d="M91 178C36 157 7 132 2 96c53 11 82 40 89 82Z"/><path fill="#bdd8ae" d="M110 245C48 225 19 195 12 161c53 10 87 39 98 84Z"/><path stroke="#f5faef" strokeWidth="1.2" d="M18 17c33 62 68 79 73 99M8 103l81 75m-69-10 90 77"/></>}
  </svg>;
}
function Logo() { return <Link href="/" className={styles.logo} aria-label="Omoterra home"><Image src={`${assets}logo.png`} width={205} height={62} alt="Omoterra — Where Markets Meet Supply" priority/></Link>; }
function Button({ href, children, outline = false }: { href: string; children: ReactNode; outline?: boolean }) {
  return <Link href={href} className={`${styles.button} ${outline ? styles.outline : ''}`}>{children}</Link>;
}
const links = [['Home', '#home'], ['For Buyers', '#for-buyers'], ['For Suppliers', '/register/supplier'], ['About', '#about'], ['Contact', '#contact']];
function Navigation({ footer = false, mobile = false }: { footer?: boolean; mobile?: boolean }) {
  return <nav className={footer ? styles.footerNav : styles.nav} aria-label={footer ? 'Footer navigation' : 'Main navigation'}>
    {links.map(([label, href], i) => <span key={label} className="home:contents">
      {i === 3 && <details className={styles.solutions}><summary>Solutions <span aria-hidden="true">⌄</span></summary><div><Link href="#process">Livestock sourcing</Link><Link href="#process">Delivery &amp; logistics</Link><Link href="/register/supplier">Supplier network</Link></div></details>}
      <Link href={href} className={i === 0 && !footer ? styles.active : ''} aria-current={i === 0 && !footer ? 'page' : undefined}>{label}</Link>
    </span>)}
    {mobile && <Link href="/login" className={styles.mobileLogin}>Login to your account</Link>}
  </nav>;
}
export function Header() {
  return <header className={styles.header}><div className={`${styles.headerInner} home:flex home:items-center home:justify-between`}><Logo/><Navigation/><div className={`${styles.actions} home:flex home:items-center`}><a href="#for-buyers" className={styles.search} aria-label="Explore livestock"><Icon name="search"/></a><Link href="/login" className={styles.login}>Login</Link><Button href="/register">Get Started</Button><details className={styles.mobileMenu}><summary aria-label="Open navigation"><span/><span/><span/></summary><Navigation mobile/></details></div></div></header>;
}
export function Hero() {
  return <section className={styles.hero} id="home" aria-labelledby="hero-title"><div className={styles.heroImage}><Image src={`${assets}farmer-goat-hero-v2.webp`} alt="Tanzanian farmer in a green shirt holding a young goat" fill sizes="(max-width: 640px) 100vw, 70vw" priority/></div><div className={styles.heroWash}/><Leaves className={styles.heroLeaves} pair/><svg className={styles.heroEdge} viewBox="0 0 70 310" fill="none" aria-hidden="true"><path fill="#bdd6ad" d="M0 37C13 17 36 6 66 4 49 36 29 56 0 66Z"/><path fill="#c6ddba" d="M0 223c8-27 22-44 51-53-3 36-20 63-51 78Z"/><path fill="#accd99" d="M0 270c15-18 37-27 65-28-15 32-36 50-65 58Z"/></svg><Leaves className={styles.heroCorner}/><div className={`${styles.container} ${styles.heroInner}`}><div className={styles.heroCopy}><h1 id="hero-title">Number1<br/>Marketplace<br/>for <em>Livestock</em></h1><p>Omoterra connects farmers, buyers and markets to make livestock supply simple and reliable across Tanzania.</p><div className={styles.buttons}><Button href="/register/buyer">Request Supply</Button></div></div></div></section>;
}
const livestock = [
  ['Broilers', 'category_broilers.jpg', 'White broiler chickens on a farm'],
  ['Layers', 'supplier-hen-v1.webp', 'A healthy laying hen on a green farm'],
  ['Goats', 'category_goats.jpg', 'A goat in a sunny farm pasture'],
  ['Cattle', 'category_cow.jpg', 'Brown cattle on a Tanzanian farm'],
  ['Sheep', 'sheep-v1.webp', 'A sheep grazing in green pasture'],
];
export function LivestockCard({ name, image, alt, index }: { name: string; image: string; alt: string; index: number }) {
  return <Link href={`/register/buyer?category=${name.toLowerCase()}`} className={styles.categoryCard} data-reveal style={{ '--delay': `${index * 65}ms` } as CSSProperties}><div><Image src={assets + image} alt={alt} fill sizes="(max-width: 640px) 44vw, 18vw"/></div><h3>{name}</h3></Link>;
}
export function LivestockSection() {
  return <section id="for-buyers" className={`${styles.container} ${styles.categories}`} aria-labelledby="livestock-title"><div className="home:flex home:items-center home:justify-between home:gap-4"><h2 id="livestock-title">Explore Livestock</h2><Link href="/register/buyer" className={styles.viewAll}>View all <Icon name="chevron"/></Link></div><div className={styles.categoryGrid}>{livestock.map(([name,image,alt], index) => <LivestockCard key={name} {...{name,image,alt,index}}/>)}</div></section>;
}
export function BenefitsBlock() {
  return <ul className={styles.benefits}>{([['shield', 'Quality livestock'], ['truck', 'End-to-end logistics'], ['people', 'Trusted network']] as const).map(([icon,label]) => <li key={label}><Icon name={icon}/>{label}</li>)}</ul>;
}
export function ProcessSteps() {
  const steps = [['document', 'Tell us what you need'], ['search', 'We match'], ['truck', 'We deliver'], ['chart', 'Your growth']] as const;
  return <ol className={styles.process} id="process" aria-label="How it works" data-reveal>{steps.map(([icon,label], i) => <li key={label}><span className={styles.processIcon}><Icon name={icon}/></span><h3>{label}</h3>{i < 3 && <span className={styles.processArrow}><Icon name="arrow"/></span>}</li>)}</ol>;
}
export function MarketplaceSection() {
  return <section className={styles.marketplace} id="about" aria-labelledby="about-title"><div className={styles.landscape}><Image src={`${assets}tanzania-highlands-v1.webp`} alt="Mount Kilimanjaro rising above Tanzania’s green farmland" fill sizes="(max-width: 640px) 100vw, 55vw"/></div><Leaves className={styles.aboutLeaves}/><Leaves className={styles.aboutEdge}/><div className={styles.container}><div className={styles.aboutCopy} data-reveal><h2 id="about-title">More than a<br/><em>marketplace</em></h2><p>We connect people, supply and opportunity to strengthen Tanzania’s livestock sector.</p><BenefitsBlock/></div><ProcessSteps/></div></section>;
}
export function CTASection() {
  return <section className={styles.closing} id="contact" aria-labelledby="cta-title"><div className={styles.closingImage}><Image src={`${assets}cattle-sunset-v1.webp`} alt="Cattle grazing beneath a warm Tanzanian sunset" fill sizes="(max-width: 640px) 100vw, 75vw"/></div><div className={styles.closingWash}/><Leaves className={styles.closingLeaves}/><div className={styles.container}><div className={styles.closingCopy} data-reveal><h2 id="cta-title">Let’s build better<br/><em>livestock markets</em></h2><p>Join farmers and businesses creating a stronger, more food-secure Tanzania.</p><div className={styles.buttons}><Button href="/register">Get Started</Button><Button href="mailto:hello@omoterra.co.tz" outline>Contact Sales</Button></div></div></div></section>;
}
function SocialIcon({ name }: {name: string}) {
  return <svg viewBox="0 0 24 24" aria-hidden="true" fill="currentColor">{name === 'LinkedIn' ? <path d="M3 8h4v13H3zm2-6a2.3 2.3 0 1 0 0 4.6A2.3 2.3 0 0 0 5 2Zm5 6h4v2c1-2 7-4 7 4v7h-4v-7c0-3-3-3-3 0v7h-4Z"/> : name === 'Instagram' ? <><rect x="3" y="3" width="18" height="18" rx="5" fill="none" stroke="currentColor" strokeWidth="2"/><circle cx="12" cy="12" r="4" fill="none" stroke="currentColor" strokeWidth="2"/><circle cx="17.5" cy="6.5" r="1"/></> : name === 'Facebook' ? <path d="M22 12a10 10 0 1 0-12 9.8V15H7v-3h3V9c0-4 3-5 7-4v3h-2c-1 0-1 1-1 2v2h3l-.5 3H14v6.8A10 10 0 0 0 22 12Z"/> : <><rect x="2" y="5" width="20" height="14" rx="4"/><path fill="white" d="m10 9 6 3-6 3Z"/></>}</svg>;
}
export function Footer() {
  // Only configured company profiles become outbound links.
  const socials = [['LinkedIn', process.env.NEXT_PUBLIC_LINKEDIN_URL], ['Instagram', process.env.NEXT_PUBLIC_INSTAGRAM_URL], ['Facebook', process.env.NEXT_PUBLIC_FACEBOOK_URL], ['YouTube', process.env.NEXT_PUBLIC_YOUTUBE_URL]];
  return <footer className={styles.footer}><div className={styles.footerInner}><Logo/><Navigation footer/><div className={styles.footerMeta}><div className={styles.socials}>{socials.map(([name,url]) => url?.startsWith('https://') ? <a key={name} href={url} aria-label={name} target="_blank" rel="noopener noreferrer"><SocialIcon name={name!}/></a> : <span key={name} role="img" aria-label={`${name} profile coming soon`} title={`${name} profile coming soon`}><SocialIcon name={name!}/></span>)}</div><small>© {new Date().getFullYear()} Omoterra. All rights reserved.</small><div className={styles.legal}><Link href="/terms">Terms</Link><Link href="/privacy">Privacy</Link></div></div></div></footer>;
}
export function Homepage({ fontClass }: {fontClass: string}) {
  return <div className={`${styles.site} ${fontClass}`} data-home><HomeMotion/><a href="#main-content" className={styles.skip}>Skip to content</a><Header/><main id="main-content"><Hero/><LivestockSection/><MarketplaceSection/><CTASection/></main><Footer/></div>;
}
