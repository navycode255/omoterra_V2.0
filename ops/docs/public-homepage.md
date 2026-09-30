# Public homepage

Run from `ops`:

```sh
npm install
npm run dev -- --port 3001
```

Open http://localhost:3001. Validate with `npm run lint` and `npm run build`.

## Implementation

- `app/(public)/page.tsx`: homepage entry, metadata, Inter font.
- `components/home/homepage.tsx`: Header, Hero, LivestockCard, LivestockSection, BenefitsBlock, ProcessSteps, MarketplaceSection, CTASection, Footer, and Homepage.
- `components/home/homepage.module.css`: reference layout, responsive styling, focus states, and motion.
- `components/home/motion.tsx`: IntersectionObserver section reveals and scroll-sensitive sticky header.
- `components/home/utilities.css`, `postcss.config.mjs`: prefixed Tailwind utilities without a global reset, preserving existing application styles.
- `app/layout.tsx`: adds Manrope weight 800 for headings.
- `package.json`, `package-lock.json`: Tailwind/PostCSS dependencies.

Manrope is used for headings and Inter for body/UI. CSS supplies hero entrance, card stagger, section reveal, button lift, and image hover effects. Reduced-motion preferences disable animations. Content stays visible without JavaScript.

The desktop layout follows the supplied reference: farmer-and-goat hero, five category cards, rounded Tanzania landscape, integrated four-step process, sunset cattle CTA, and compact footer. The written brief's three benefits are included beneath the marketplace introduction. Mobile stacks the imagery and uses a two-column category/process layout.

Existing optimized assets under `public/images/marketing` are reused: `logo.png`, `farmer-goat-hero-v2.webp`, `category_broilers.jpg`, `supplier-hen-v1.webp`, `category_goats.jpg`, `category_cow.jpg`, `sheep-v1.webp`, `tanzania-highlands-v1.webp`, and `cattle-sunset-v1.webp`. These are real project assets, not placeholders, but are not the identical photographs from the reference. Leaves and interface icons are inline SVG.

Social icons become outbound links when the actual company profile URLs are configured using `NEXT_PUBLIC_LINKEDIN_URL`, `NEXT_PUBLIC_INSTAGRAM_URL`, `NEXT_PUBLIC_FACEBOOK_URL`, and `NEXT_PUBLIC_YOUTUBE_URL`. Unconfigured icons are noninteractive. Contact Sales opens `hello@omoterra.co.tz`; registration and login buttons use the existing application routes. The search icon scrolls to Explore Livestock.

Browser checks cover desktop 1024px and mobile 390px/320px widths, image loading, and horizontal overflow. Changes are local; publishing requires the normal deployment workflow.
