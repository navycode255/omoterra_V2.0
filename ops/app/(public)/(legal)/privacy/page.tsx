import { LegalPage } from '@/components/legal-page';
import { privacy } from '@/lib/legal';

export const metadata = { title: 'Privacy Policy · Omoterra', description: privacy.summary };

export default function Privacy() {
  return <LegalPage document={privacy} current="privacy" />;
}
