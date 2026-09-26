import legal from '@/content/legal.json';

// The Terms of Use and Privacy Policy. content/legal.json is the one source:
// the mobile app bundles a copy (mobile/assets/legal/legal.json, kept equal by
// a mobile test), so the website and the app always say the same thing.
export type LegalBlock = { p: string } | { ul: string[] };
export type LegalSection = { id: string; heading: string; body: LegalBlock[] };
export type LegalDocument = { title: string; summary: string; sections: LegalSection[] };

export const legalUpdated: string = legal.updated;
export const legalOperator = legal.operator;
export const terms: LegalDocument = legal.terms;
export const privacy: LegalDocument = legal.privacy;
